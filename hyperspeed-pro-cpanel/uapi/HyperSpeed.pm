package Cpanel::API::HyperSpeed;

# ABSTRACT: HyperSpeed Pro User API Module
# This provides UAPI calls for cPanel users to manage their domains

use strict;
use warnings;

use Cpanel::Logger ();
use Cpanel::JSON ();
use Cpanel::SafeRun::Simple ();
use Redis;

our $VERSION = '1.0.0';

my $logger = Cpanel::Logger->new();
my $redis;

# Initialize Redis connection
sub _init_redis {
    return $redis if $redis;
    
    eval {
        $redis = Redis->new(
            server => '127.0.0.1:6379',
            reconnect => 60,
            every => 1000,
        );
    };
    
    if ($@) {
        $logger->warn("Failed to connect to Redis: $@");
        return undef;
    }
    
    return $redis;
}

# Get current user
sub _get_user {
    return $ENV{'REMOTE_USER'} || $ENV{'USER'};
}

# Get user's domains
sub _get_user_domains {
    my $user = _get_user();
    
    my @domains;
    my $domain_list = Cpanel::SafeRun::Simple::saferun('/usr/local/cpanel/bin/uapi', 
        '--output=json', '--user=' . $user, 'DomainInfo', 'list_domains');
    
    if ($domain_list) {
        my $data = eval { Cpanel::JSON::Load($domain_list) };
        if ($data && ref $data->{data} eq 'HASH') {
            push @domains, @{$data->{data}->{main_domain} || []};
            push @domains, @{$data->{data}->{sub_domains} || []};
            push @domains, @{$data->{data}->{addon_domains} || []};
        }
    }
    
    return \@domains;
}

=head1 UAPI Functions

=head2 get_status

Get HyperSpeed Pro status for the current user

=cut

sub get_status {
    my %OPTS = @_;
    
    my $user = _get_user();
    my $r = _init_redis();
    
    my $result = {
        enabled => 1,
        user => $user,
        features => {
            page_cache => 1,
            object_cache => 1,
            security => 1,
        },
    };
    
    if ($r) {
        # Get user-specific settings
        my $user_settings = $r->get("user:$user:settings");
        if ($user_settings) {
            my $settings = eval { Cpanel::JSON::Load($user_settings) };
            $result->{settings} = $settings if $settings;
        }
    }
    
    return {
        status => 1,
        data => $result,
    };
}

=head2 get_domains

Get all domains for the current user

=cut

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
