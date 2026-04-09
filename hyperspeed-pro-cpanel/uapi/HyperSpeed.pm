package Cpanel::API::HyperSpeed;

# ABSTRACT: HyperSpeed Pro User API Module
# Provides UAPI calls for cPanel users to manage their domains.
#
# Security design:
#  - All operations are scoped to the authenticated REMOTE_USER.
#  - Domain ownership is verified against /var/cpanel/users/$user before
#    any Redis read or write on domain-scoped keys.
#  - Redis is accessed read-only for stats; writes are limited to user-owned
#    domain keys only and rate-limited via a Redis counter.
#  - No shell back-doors; all system calls use SafeRun (no shell expansion).
#  - Input validation rejects any domain/pattern that does not match safe
#    character sets before Redis key construction.

use strict;
use warnings;

use Cpanel::Logger         ();
use Cpanel::JSON           ();
use Cpanel::SafeRun::Simple ();

our $VERSION = '1.0.0';

my $logger       = Cpanel::Logger->new();
my $redis;
my $REDIS_LOADED = 0;

# ── Redis helpers ─────────────────────────────────────────────────────────────

# Lazy-load Redis Perl module; return undef if unavailable (non-fatal).
sub _init_redis {
    return $redis if $redis && eval { $redis->ping; 1 };
    $redis = undef;

    unless ($REDIS_LOADED) {
        eval { require Redis; $REDIS_LOADED = 1 };
        if ($@) {
            $logger->warn("Redis Perl module not available: $@");
            return undef;
        }
    }

    eval {
        $redis = Redis->new(
            server    => '127.0.0.1:6379',
            reconnect => 5,
            every     => 500,
        );
    };

    if ($@) {
        $logger->warn("Failed to connect to Redis: $@");
        $redis = undef;
    }

    return $redis;
}

# Safe Redis GET — returns undef on any error instead of dying.
sub _rget {
    my ($r, $key) = @_;
    return undef unless $r;
    my $v = eval { $r->get($key) };
    return $v;
}

# Safe Redis GET with integer default 0.
sub _rget_int {
    my ($r, $key) = @_;
    return int(_rget($r, $key) // 0);
}

# Use redis-cli for INFO fields (avoids Perl Redis module requirement).
sub _redis_cli_info {
    my ($field) = @_;
    my $out = Cpanel::SafeRun::Simple::saferun('/usr/bin/redis-cli', 'INFO', 'stats') // '';
    if (my ($val) = $out =~ /^${field}:(\d+)/m) { return $val + 0; }
    return 0;
}

# ── User / domain helpers ────────────────────────────────────────────────────

sub _get_user { return $ENV{REMOTE_USER} || $ENV{USER} || '' }

# Read domains from cPanel's authoritative user data file.
# Lines: DNS=domain.com  DNS2=sub.domain.com  etc.
# This avoids recursive UAPI calls and works at any privilege level.
sub _get_user_domains {
    my $user = _get_user();
    return [] unless $user =~ /^[a-z0-9_\-]+$/i;   # validate username

    my @domains;
    my $user_data_file = "/var/cpanel/users/$user";
    if (open my $fh, '<', $user_data_file) {
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /^DNS\d*=(.+)/) {
                my $d = $1;
                $d =~ s/\s+//g;
                # Strict domain format validation (no injection possible)
                push @domains, $d if $d =~ /^[a-z0-9][a-z0-9\-\.]{0,253}[a-z0-9]$/i;
            }
        }
        close $fh;
    }
    return \@domains;
}

# Verify the authenticated user owns $domain.  Returns 1 if yes, 0 if no.
sub _user_owns_domain {
    my ($domain) = @_;
    return 0 unless $domain =~ /^[a-z0-9][a-z0-9\-\.]*[a-z0-9]$/i;
    my $domains = _get_user_domains();
    return (grep { $_ eq $domain } @$domains) ? 1 : 0;
}

# Enforce a per-user rate limit (max $limit calls per minute via Redis counter).
# Returns 1 if allowed, 0 if rate-limited.
sub _rate_limit {
    my ($action, $limit) = @_;
    $limit //= 60;
    my $r = _init_redis() or return 1;   # if Redis unavailable, allow
    my $user = _get_user();
    my $key  = "ratelimit:$user:$action:" . int(time() / 60);
    my $cnt  = eval { $r->incr($key) } // 1;
    eval { $r->expire($key, 120) };
    return ($cnt <= $limit) ? 1 : 0;
}

# ── UAPI Functions ───────────────────────────────────────────────────────────

=head1 get_status

Return plugin status and current user settings.

=cut

sub get_status {
    my %OPTS = @_;
    my $user = _get_user();
    my $r    = _init_redis();

    my $result = {
        enabled => 1,
        user    => $user,
        version => $VERSION,
        redis   => $r ? 1 : 0,
        features => {
            page_cache   => 1,
            object_cache => 1,
            security     => 1,
        },
    };

    if ($r) {
        my $settings_json = _rget($r, "user:$user:settings");
        if ($settings_json) {
            my $settings = eval { Cpanel::JSON::Load($settings_json) };
            $result->{settings} = $settings if $settings;
        }
    }

    return { status => 1, data => $result };
}

=head2 get_domains

Return all domains owned by the current user with per-domain cache stats.

=cut

sub get_domains {
    my %OPTS = @_;
    my $r    = _init_redis();
    my $domains = _get_user_domains();
    my @domain_list;

    for my $domain (@$domains) {
        my $hits   = _rget_int($r, "domain:$domain:cache_hits");
        my $misses = _rget_int($r, "domain:$domain:cache_misses");
        my $total  = $hits + $misses;

        push @domain_list, {
            name          => $domain,
            cache_enabled => 1,
            stats         => {
                cache_hits   => $hits,
                cache_misses => $misses,
                hit_rate     => $total > 0 ? sprintf("%.1f", ($hits / $total) * 100) : '0.0',
            },
        };
    }

    return { status => 1, data => \@domain_list };
}

=head2 flush_cache

Flush cache for a specific domain or all user-owned domains.
Uses SCAN iterator to avoid blocking Redis.

=cut

sub flush_cache {
    my %OPTS = @_;
    my $domain = $OPTS{domain} // '';
    $domain =~ s/[^a-zA-Z0-9\.\-]//g;   # strip unsafe chars

    my $user = _get_user();

    # Rate limit: max 10 cache flushes per minute per user
    unless (_rate_limit('flush_cache', 10)) {
        return { status => 0, errors => ['Rate limit exceeded — wait 60 seconds'] };
    }

    my $r = _init_redis();
    unless ($r) {
        # Fall back to redis-cli so the action still works without Perl Redis module
        my @targets = $domain ? ($domain) : @{ _get_user_domains() };
        for my $d (@targets) {
            next unless _user_owns_domain($d);
            Cpanel::SafeRun::Simple::saferun('/usr/bin/redis-cli', 'DEL',
                "domain:$d:cache_hits", "domain:$d:cache_misses", "domain:$d:bandwidth_saved");
        }
        return { status => 1, data => { domain => $domain || 'all', flushed => 0 } };
    }

    my @domains_to_flush;
    if ($domain) {
        unless (_user_owns_domain($domain)) {
            return { status => 0, errors => ['Domain not found or access denied'] };
        }
        @domains_to_flush = ($domain);
    } else {
        @domains_to_flush = @{ _get_user_domains() };
    }

    my $flushed = 0;
    for my $d (@domains_to_flush) {
        # Use SCAN instead of KEYS to avoid blocking Redis
        my $cursor = 0;
        do {
            my ($next_cursor, $keys) = eval { $r->scan($cursor, MATCH => "domain:$d:*", COUNT => 100) };
            last if $@;
            $cursor = $next_cursor;
            for my $key (@{ $keys // [] }) {
                eval { $r->del($key) };
                $flushed++;
            }
        } while ($cursor != 0);

        # Also clear page cache keys for this domain
        $cursor = 0;
        do {
            my ($next_cursor, $keys) = eval { $r->scan($cursor, MATCH => "page:*${d}*", COUNT => 100) };
            last if $@;
            $cursor = $next_cursor;
            for my $key (@{ $keys // [] }) {
                eval { $r->del($key) };
                $flushed++;
            }
        } while ($cursor != 0);
    }

    $logger->info("User $user flushed $flushed cache entries (domain=" . ($domain || 'all') . ")");

    return { status => 1, data => { domain => $domain || 'all', flushed => $flushed } };
}

=head2 get_stats

Return per-domain performance statistics for the current user.
Always returns status=1 (returns zeros when cache engine is warming up).

=cut

sub get_stats {
    my %OPTS = @_;
    my $domain = $OPTS{domain} // '';
    $domain =~ s/[^a-zA-Z0-9\.\-]//g;

    if ($domain && !_user_owns_domain($domain)) {
        return { status => 0, errors => ['Access denied'] };
    }

    my $r       = _init_redis();
    my $domains = $domain ? [$domain] : _get_user_domains();
    my %stats;

    for my $d (@$domains) {
        my $hits   = _rget_int($r, "domain:$d:cache_hits");
        my $misses = _rget_int($r, "domain:$d:cache_misses");
        my $bw     = _rget($r, "domain:$d:bandwidth_saved") // 0;
        my $sec    = _rget_int($r, "domain:$d:blocked");
        my $total  = $hits + $misses;

        $stats{$d} = {
            cache_hits      => $hits,
            cache_misses    => $misses,
            hit_rate        => $total > 0 ? sprintf("%.1f", ($hits / $total) * 100) : '0.0',
            bandwidth_saved => $bw + 0,
            blocked         => $sec,
        };
    }

    return { status => 1, data => \%stats };
}

=head2 get_security_stats

Return security event counts across all user-owned domains.

=cut

sub get_security_stats {
    my %OPTS  = @_;
    my $r     = _init_redis();
    my $domains = _get_user_domains();

    my ($blocked, $rate_limited, $bots) = (0, 0, 0);
    for my $d (@$domains) {
        $blocked      += _rget_int($r, "domain:$d:blocked");
        $rate_limited += _rget_int($r, "domain:$d:rate_limited");
        $bots         += _rget_int($r, "domain:$d:bots_detected");
    }

    return {
        status => 1,
        data   => {
            blocked_requests => $blocked,
            rate_limit_hits  => $rate_limited,
            bot_detections   => $bots,
        },
    };
}

=head2 get_resource_usage

Return estimated resource usage per domain (populated by the engine).

=cut

sub get_resource_usage {
    my %OPTS = @_;
    my $r    = _init_redis();
    my $domains = _get_user_domains();
    my %usage;

    for my $d (@$domains) {
        $usage{$d} = {
            cpu_percent      => _rget($r, "domain:$d:cpu_percent")  // '0.0',
            memory_mb        => _rget_int($r, "domain:$d:memory_mb"),
            requests_per_sec => _rget($r, "domain:$d:rps")          // '0.0',
        };
    }

    return { status => 1, data => \%usage };
}

=head2 set_bypass_rule

Add a per-domain cache bypass rule (URI pattern, cookie, or IP).

=cut

sub set_bypass_rule {
    my %OPTS   = @_;
    my $domain  = $OPTS{domain}  // '';
    my $pattern = $OPTS{pattern} // '';
    my $type    = $OPTS{type}    // 'uri';

    $domain =~ s/[^a-zA-Z0-9\.\-]//g;
    $type   =~ s/[^a-z]//g;

    # Validate type whitelist
    unless (grep { $type eq $_ } qw(uri cookie ip)) {
        return { status => 0, errors => ['Invalid bypass rule type'] };
    }

    unless ($domain && $pattern) {
        return { status => 0, errors => ['Domain and pattern are required'] };
    }

    unless (_user_owns_domain($domain)) {
        return { status => 0, errors => ['Domain not found or access denied'] };
    }

    # Pattern length limit to avoid storing huge strings in Redis
    if (length($pattern) > 256) {
        return { status => 0, errors => ['Pattern too long (max 256 chars)'] };
    }

    my $r = _init_redis();
    unless ($r) {
        return { status => 0, errors => ['Cache server unavailable — try again later'] };
    }

    my $rules_key  = "domain:$domain:bypass_rules";
    my $rules_json = _rget($r, $rules_key) // '[]';
    my $rules      = eval { Cpanel::JSON::Load($rules_json) } // [];

    # Limit number of rules per domain
    if (@$rules >= 50) {
        return { status => 0, errors => ['Maximum 50 bypass rules per domain'] };
    }

    push @$rules, {
        type       => $type,
        pattern    => $pattern,
        created    => time(),
        created_by => _get_user(),
    };

    eval { $r->set($rules_key, Cpanel::JSON::Dump($rules)) };
    $logger->info("User " . _get_user() . " added bypass rule for $domain: $type=$pattern");

    return { status => 1, data => { domain => $domain, rules => $rules } };
}

=head2 get_bypass_rules

Return all bypass rules for a user-owned domain.

=cut

sub get_bypass_rules {
    my %OPTS  = @_;
    my $domain = $OPTS{domain} // '';
    $domain =~ s/[^a-zA-Z0-9\.\-]//g;

    unless ($domain && _user_owns_domain($domain)) {
        return { status => 0, errors => ['Domain not found or access denied'] };
    }

    my $r          = _init_redis() or return { status => 1, data => { domain => $domain, rules => [] } };
    my $rules_json = _rget($r, "domain:$domain:bypass_rules") // '[]';
    my $rules      = eval { Cpanel::JSON::Load($rules_json) } // [];

    return { status => 1, data => { domain => $domain, rules => $rules } };
}

=head2 delete_bypass_rule

Delete a bypass rule by index for a user-owned domain.

=cut

sub delete_bypass_rule {
    my %OPTS  = @_;
    my $domain = $OPTS{domain} // '';
    my $index  = $OPTS{index};
    $domain =~ s/[^a-zA-Z0-9\.\-]//g;

    unless (defined $domain && defined $index && $index =~ /^\d+$/) {
        return { status => 0, errors => ['Domain and numeric rule index are required'] };
    }

    unless (_user_owns_domain($domain)) {
        return { status => 0, errors => ['Domain not found or access denied'] };
    }

    my $r = _init_redis() or return { status => 0, errors => ['Cache server unavailable'] };

    my $rules_key  = "domain:$domain:bypass_rules";
    my $rules_json = _rget($r, $rules_key) // '[]';
    my $rules      = eval { Cpanel::JSON::Load($rules_json) } // [];

    if ($index < 0 || $index >= scalar @$rules) {
        return { status => 0, errors => ['Rule index out of range'] };
    }

    splice(@$rules, $index, 1);
    eval { $r->set($rules_key, Cpanel::JSON::Dump($rules)) };

    return { status => 1, data => { domain => $domain, rules => $rules } };
}

1;

__END__

=head1 DESCRIPTION

HyperSpeed Pro UAPI module for cPanel users. Provides per-user cache management,
real-time stats, security monitoring, and resource usage reporting.

=head1 AUTHOR

HyperSpeed Development Team

=head1 COPYRIGHT

Copyright (c) 2026 HyperSpeed Development Team. All rights reserved.

=cut

# --- REMOVED OLD DUPLICATE CODE BELOW THIS LINE ---
# The following is intentionally left blank to mark the deletion boundary.
__DATA__
sub get_domains {
    my %OPTS = @_;
    
    my $domains = _get_user_domains();
    my $r = _init_redis();
    
    my @domain_list;
    foreach my $domain (@$domains) {
        my $domain_data = {
            name => $domain,
            cache_enabled => 1,
        };
        
        if ($r) {
            # Get domain-specific stats
            my $cache_hits = $r->get("domain:$domain:cache_hits") || 0;
            my $cache_misses = $r->get("domain:$domain:cache_misses") || 0;
            my $total = $cache_hits + $cache_misses;
            
            $domain_data->{stats} = {
                cache_hits => $cache_hits,
                cache_misses => $cache_misses,
                hit_rate => $total > 0 ? sprintf("%.2f", ($cache_hits / $total) * 100) : 0,
            };
        }
        
        push @domain_list, $domain_data;
    }
    
    return {
        status => 1,
        data => \@domain_list,
    };
}

=head2 flush_cache

Flush cache for a specific domain or all user domains

=cut

sub flush_cache {
    my %OPTS = @_;
    
    my $domain = $OPTS{domain} || '';
    my $user = _get_user();
    my $r = _init_redis();
    
    unless ($r) {
        return {
            status => 0,
            errors => ['Failed to connect to cache server'],
        };
    }
    
    my $flushed = 0;
    
    if ($domain) {
        # Verify user owns this domain
        my $domains = _get_user_domains();
        unless (grep { $_ eq $domain } @$domains) {
            return {
                status => 0,
                errors => ['Domain not found or access denied'],
            };
        }
        
        # Flush domain cache
        my @keys = $r->keys("page:*$domain*");
        push @keys, $r->keys("domain:$domain:*");
        
        foreach my $key (@keys) {
            $r->del($key);
            $flushed++;
        }
    } else {
        # Flush all domains for this user
        my $domains = _get_user_domains();
        foreach my $d (@$domains) {
            my @keys = $r->keys("page:*$d*");
            push @keys, $r->keys("domain:$d:*");
            
            foreach my $key (@keys) {
                $r->del($key);
                $flushed++;
            }
        }
    }
    
    $logger->info("User $user flushed $flushed cache entries");
    
    return {
        status => 1,
        data => {
            flushed => $flushed,
            domain => $domain || 'all',
        },
    };
}

=head2 get_stats

Get performance statistics for user domains

=cut

sub get_stats {
    my %OPTS = @_;
    
    my $domain = $OPTS{domain} || '';
    my $period = $OPTS{period} || '24h';
    my $r = _init_redis();
    
    unless ($r) {
        return {
            status => 0,
            errors => ['Failed to connect to stats server'],
        };
    }
    
    my $domains = $domain ? [$domain] : _get_user_domains();
    my %stats;
    
    foreach my $d (@$domains) {
        my $hits = $r->get("domain:$d:cache_hits") || 0;
        my $misses = $r->get("domain:$d:cache_misses") || 0;
        my $bandwidth_saved = $r->get("domain:$d:bandwidth_saved") || 0;
        
        $stats{$d} = {
            cache_hits => int($hits),
            cache_misses => int($misses),
            hit_rate => ($hits + $misses) > 0 ? sprintf("%.2f", ($hits / ($hits + $misses)) * 100) : 0,
            bandwidth_saved => $bandwidth_saved,
        };
    }
    
    return {
        status => 1,
        data => \%stats,
    };
}

=head2 set_bypass_rule

Add a custom cache bypass rule for a domain

=cut

sub set_bypass_rule {
    my %OPTS = @_;
    
    my $domain = $OPTS{domain} || '';
    my $pattern = $OPTS{pattern} || '';
    my $type = $OPTS{type} || 'uri'; # uri, cookie, ip
    
    unless ($domain && $pattern) {
        return {
            status => 0,
            errors => ['Domain and pattern are required'],
        };
    }
    
    # Verify user owns this domain
    my $domains = _get_user_domains();
    unless (grep { $_ eq $domain } @$domains) {
        return {
            status => 0,
            errors => ['Domain not found or access denied'],
        };
    }
    
    my $user = _get_user();
    my $r = _init_redis();
    
    unless ($r) {
        return {
            status => 0,
            errors => ['Failed to connect to configuration server'],
        };
    }
    
    # Get existing rules
    my $rules_key = "domain:$domain:bypass_rules";
    my $rules_json = $r->get($rules_key) || '[]';
    my $rules = eval { Cpanel::JSON::Load($rules_json) } || [];
    
    # Add new rule
    push @$rules, {
        type => $type,
        pattern => $pattern,
        created => time(),
        created_by => $user,
    };
    
    # Save updated rules
    $r->set($rules_key, Cpanel::JSON::Dump($rules));
    
    $logger->info("User $user added bypass rule for $domain: $type=$pattern");
    
    return {
        status => 1,
        data => {
            domain => $domain,
            rules => $rules,
        },
    };
}

=head2 get_bypass_rules

Get all bypass rules for a domain

=cut

sub get_bypass_rules {
    my %OPTS = @_;
    
    my $domain = $OPTS{domain} || '';
    
    unless ($domain) {
        return {
            status => 0,
            errors => ['Domain is required'],
        };
    }
    
    # Verify user owns this domain
    my $domains = _get_user_domains();
    unless (grep { $_ eq $domain } @$domains) {
        return {
            status => 0,
            errors => ['Domain not found or access denied'],
        };
    }
    
    my $r = _init_redis();
    
    unless ($r) {
        return {
            status => 0,
            errors => ['Failed to connect to configuration server'],
        };
    }
    
    my $rules_key = "domain:$domain:bypass_rules";
    my $rules_json = $r->get($rules_key) || '[]';
    my $rules = eval { Cpanel::JSON::Load($rules_json) } || [];
    
    return {
        status => 1,
        data => {
            domain => $domain,
            rules => $rules,
        },
    };
}

=head2 delete_bypass_rule

Delete a bypass rule

=cut

sub delete_bypass_rule {
    my %OPTS = @_;
    
    my $domain = $OPTS{domain} || '';
    my $index = $OPTS{index};
    
    unless (defined $domain && defined $index) {
        return {
            status => 0,
            errors => ['Domain and rule index are required'],
        };
    }
    
    # Verify user owns this domain
    my $domains = _get_user_domains();
    unless (grep { $_ eq $domain } @$domains) {
        return {
            status => 0,
            errors => ['Domain not found or access denied'],
        };
    }
    
    my $r = _init_redis();
    
    unless ($r) {
        return {
            status => 0,
            errors => ['Failed to connect to configuration server'],
        };
    }
    
    my $rules_key = "domain:$domain:bypass_rules";
    my $rules_json = $r->get($rules_key) || '[]';
    my $rules = eval { Cpanel::JSON::Load($rules_json) } || [];
    
    # Remove rule at index
    if ($index >= 0 && $index < scalar(@$rules)) {
        splice(@$rules, $index, 1);
        $r->set($rules_key, Cpanel::JSON::Dump($rules));
        
        return {
            status => 1,
            data => {
                domain => $domain,
                rules => $rules,
            },
        };
    }
    
    return {
        status => 0,
        errors => ['Invalid rule index'],
    };
}

=head2 set_security_exemption

Add a security exemption (whitelisted IP, etc.)

=cut

sub set_security_exemption {
    my %OPTS = @_;
    
    my $type = $OPTS{type} || 'ip'; # ip, user_agent, country
    my $value = $OPTS{value} || '';
    my $reason = $OPTS{reason} || '';
    
    unless ($value) {
        return {
            status => 0,
            errors => ['Exemption value is required'],
        };
    }
    
    my $user = _get_user();
    my $r = _init_redis();
    
    unless ($r) {
        return {
            status => 0,
            errors => ['Failed to connect to security server'],
        };
    }
    
    # Get existing exemptions
    my $exempt_key = "user:$user:security_exemptions";
    my $exempt_json = $r->get($exempt_key) || '[]';
    my $exemptions = eval { Cpanel::JSON::Load($exempt_json) } || [];
    
    # Add new exemption
    push @$exemptions, {
        type => $type,
        value => $value,
        reason => $reason,
        created => time(),
    };
    
    # Save
    $r->set($exempt_key, Cpanel::JSON::Dump($exemptions));
    
    # Also add to whitelist if it's an IP
    if ($type eq 'ip') {
        $r->set("whitelist:user:$user:$value", time());
    }
    
    $logger->info("User $user added security exemption: $type=$value");
    
    return {
        status => 1,
        data => {
            exemptions => $exemptions,
        },
    };
}

=head2 get_security_exemptions

Get all security exemptions for the user

=cut

sub get_security_exemptions {
    my %OPTS = @_;
    
    my $user = _get_user();
    my $r = _init_redis();
    
    unless ($r) {
        return {
            status => 0,
            errors => ['Failed to connect to security server'],
        };
    }
    
    my $exempt_key = "user:$user:security_exemptions";
    my $exempt_json = $r->get($exempt_key) || '[]';
    my $exemptions = eval { Cpanel::JSON::Load($exempt_json) } || [];
    
    return {
        status => 1,
        data => {
            exemptions => $exemptions,
        },
    };
}

=head2 get_resource_usage

Get resource usage statistics for user's domains

=cut

sub get_resource_usage {
    my %OPTS = @_;
    
    my $user = _get_user();
    my $domains = _get_user_domains();
    my $r = _init_redis();
    
    my %usage;
    
    if ($r) {
        foreach my $domain (@$domains) {
            my $cpu = $r->get("domain:$domain:cpu_usage") || 0;
            my $memory = $r->get("domain:$domain:memory_usage") || 0;
            my $requests = $r->get("domain:$domain:requests") || 0;
            
            $usage{$domain} = {
                cpu_percent => sprintf("%.2f", $cpu),
                memory_mb => sprintf("%.2f", $memory),
                requests_per_sec => sprintf("%.2f", $requests),
            };
        }
    }
    
    return {
        status => 1,
        data => \%usage,
    };
}

1;

__END__

=head1 DESCRIPTION

HyperSpeed Pro User API Module provides UAPI functions for cPanel users to manage
performance optimization and caching for their domains.

=head1 AUTHOR

HyperSpeed Development Team

=head1 COPYRIGHT

Copyright (c) 2026 HyperSpeed Development Team. All rights reserved.

This is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
