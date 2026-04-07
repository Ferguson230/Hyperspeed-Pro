# HyperSpeed Pro - cPanel User Plugin

![HyperSpeed Pro](https://img.shields.io/badge/version-1.0.0-blue.svg)
![cPanel](https://img.shields.io/badge/cPanel-Compatible-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**Next-generation performance optimization for individual cPanel users**

---

## Overview

HyperSpeed Pro cPanel User Plugin provides individual cPanel account holders with powerful performance optimization and caching controls for their domains. It synchronizes seamlessly with the WHM-level HyperSpeed Pro plugin to provide a complete server-wide optimization solution.

## Features

### 🚀 Performance Optimization
- **Per-Domain Cache Management** - Control caching for each domain individually
- **Multi-Tier Caching** - Benefit from Redis + Memcached server-level caching
- **Real-Time Analytics** - View cache hit rates, bandwidth savings, and performance metrics
- **Custom Cache Rules** - Define bypass rules for specific URLs, cookies, or patterns
- **Automatic Optimization** - One-click optimization for maximum performance

### 🛡️ Security Controls
- **Security Exemptions** - Whitelist trusted IPs and user agents
- **DDoS Protection Stats** - Monitor blocked requests and threats
- **Bot Detection** - View good vs. bad bot classifications
- **Rate Limiting Dashboard** - Track rate limiting events

### 📊 Advanced Analytics
- **Performance Trends** - 24-hour, 7-day, and 30-day performance charts
- **Resource Usage** - Monitor CPU, memory, and bandwidth per domain
- **Cache Performance** - Detailed cache hit/miss statistics
- **Bandwidth Savings** - Track how much bandwidth you're saving

### ⚙️ Customization
- **Custom Bypass Rules** - Exclude specific URLs from caching
- **Compression Settings** - Choose between Brotli, Zstandard, or Gzip
- **Cache TTL Control** - Set custom cache time-to-live values
- **Asset Optimization** - Enable/disable minification and image optimization

## Prerequisites

1. **WHM HyperSpeed Pro Plugin** must be installed first
2. cPanel & WHM Version 11.110 or higher
3. Ubuntu 22.04 or 24.04 LTS
4. Active cPanel account with domain(s)

## Installation

### For Server Administrators

```bash
# SSH into the server as root
cd /tmp

# Download the cPanel plugin
wget https://releases.hyperspeed.pro/latest/hyperspeed-pro-cpanel.tar.gz
tar -xzf hyperspeed-pro-cpanel.tar.gz
cd hyperspeed-pro-cpanel

# Run installation script
chmod +x install.sh
./install.sh
```

### What Gets Installed

The installer will:
1. Install the cPanel user interface in Paper Lantern theme
2. Register UAPI module for backend functionality
3. Create synchronization service with WHM plugin
4. Set up user data directories
5. Configure automatic cache synchronization

## Usage

### Accessing the Dashboard

1. Log in to your cPanel account
2. Navigate to **Software → HyperSpeed Pro**
3. You'll see the HyperSpeed Pro dashboard with:
   - Performance overview
   - Your domain list
   - Cache management tools
   - Security settings
   - Analytics

### Common Tasks

#### Clear Cache for a Specific Domain

1. Go to **Domains** tab
2. Find your domain in the list
3. Click **Clear Cache** button

**OR use the Cache Control tab:**

1. Go to **Cache Control** tab
2. Select the domain from dropdown
3. Click **Flush Cache**

#### Add a Cache Bypass Rule

For example, to prevent caching of cart/checkout pages:

1. Go to **Cache Control** tab
2. Select your domain
3. Choose **URL Pattern** as type
4. Enter patterns like: `/cart`, `/checkout`, `/my-account`
5. Click **Add Bypass Rule**

Common bypass patterns:
- `/wp-admin/*` - WordPress admin
- `/administrator/*` - Joomla admin
- `wordpress_logged_in` - WordPress logged-in users (cookie)
- `/cart`, `/checkout` - E-commerce pages

#### Add a Security Exemption

To whitelist your office IP from security checks:

1. Go to **Security** tab
2. Select **IP Address** as type
3. Enter your IP address (e.g., `123.45.67.89`)
4. Add a reason: "Office IP"
5. Click **Add Exemption**

#### View Performance Analytics

1. Go to **Analytics** tab
2. Select time period (24h, 7d, 30d)
3. Optionally filter by domain
4. View charts for:
   - Cache performance
   - Bandwidth usage
   - Response times
   - Request distribution

## UAPI Functions

The plugin provides the following UAPI functions for developers:

### get_status
Get HyperSpeed Pro status for the current user

```bash
uapi HyperSpeed get_status
```

### get_domains
Get all domains with cache statistics

```bash
uapi HyperSpeed get_domains
```

### flush_cache
Flush cache for a domain or all domains

```bash
# Flush all caches
uapi HyperSpeed flush_cache

# Flush specific domain
uapi HyperSpeed flush_cache domain=example.com
```

### get_stats
Get performance statistics

```bash
# All domains
uapi HyperSpeed get_stats

# Specific domain
uapi HyperSpeed get_stats domain=example.com
```

### set_bypass_rule
Add a cache bypass rule

```bash
uapi HyperSpeed set_bypass_rule domain=example.com type=uri pattern=/checkout
```

### get_bypass_rules
Get bypass rules for a domain

```bash
uapi HyperSpeed get_bypass_rules domain=example.com
```

### set_security_exemption
Add a security exemption

```bash
uapi HyperSpeed set_security_exemption type=ip value=192.168.1.100 reason="Office IP"
```

### get_resource_usage
Get resource usage statistics

```bash
uapi HyperSpeed get_resource_usage
```

## Synchronization with WHM

The cPanel plugin automatically synchronizes with the WHM master configuration:

### What Gets Synced

- **Cache Settings** - TTL, compression, and optimization settings
- **Security Rules** - Rate limiting, DDoS protection settings (if enforced by WHM admin)
- **Global Exemptions** - Server-wide IP whitelists
- **Performance Metrics** - Aggregated and stored for analytics

### Sync Interval

The sync service runs every 60 seconds to ensure:
- User settings respect WHM administrator policies
- Global security rules are applied consistently
- Performance metrics are up-to-date
- Stale data is cleaned up

### WHM Admin Control

WHM administrators can:
- **Enforce security settings** - Override user settings for security features
- **Set global exemptions** - Apply server-wide whitelists
- **Monitor all users** - View aggregated statistics across all accounts
- **Manage resources** - Allocate cache resources per user

## Configuration

### User Settings File

Each user's settings are stored in Redis:
```
user:<username>:settings
```

### Domain-Specific Settings

Domain settings are stored as:
```
domain:<domain.com>:settings
domain:<domain.com>:bypass_rules
domain:<domain.com>:cache_config
```

### Resource Limits

Resources are automatically managed but can be viewed:
- **Cache Space** - Proportional to account disk quota
- **Request Rate** - Based on WHM server settings
- **Bandwidth** - Tracked for analytics only

## Troubleshooting

### Dashboard Not Showing Stats

```bash
# Check if UAPI module is loaded
uapi --list | grep HyperSpeed

# Test UAPI call
uapi HyperSpeed get_status
```

### Cache Not Clearing

```bash
# Check sync service status
systemctl status hyperspeed-cpanel-sync

# View sync logs
tail -f /var/log/hyperspeed_pro/sync.log
```

### Bypass Rules Not Working

1. Ensure the domain is correct (no leading `www`)
2. Check pattern syntax (use `/path` for URLs)
3. Wait 60 seconds for sync to apply changes
4. Clear cache after adding rules

### Performance Metrics Not Updating

```bash
# Check Redis connection
redis-cli PING

# Check if metrics are being stored
redis-cli KEYS "domain:*:cache_hits"
```

## Best Practices

### For WordPress Sites

1. Enable page caching
2. Enable object caching (database queries)
3. Add bypass rules:
   - `/wp-admin/*`
   - `/wp-login.php`
   - Cookie: `wordpress_logged_in`

### For E-commerce Sites

1. Enable page caching for static pages
2. Add bypass rules for:
   - `/cart`
   - `/checkout`
   - `/my-account`
   - `/payment`
3. Set shorter cache TTL (600-1800 seconds)
4. Whitelist payment gateway IPs

### For High-Traffic Sites

1. Use maximum cache TTL (7200+ seconds)
2. Enable all compression types
3. Enable asset minification
4. Enable image optimization
5. Monitor resource usage regularly

## Performance Tips

1. **Start with defaults** - The default settings work well for most sites
2. **Add bypass rules carefully** - Too many bypass rules reduce cache effectiveness
3. **Monitor cache hit rate** - Aim for 80%+ cache hit rate
4. **Use longer TTL for static content** - Increase TTL for blogs, marketing sites
5. **Clear cache after major updates** - After theme changes or new content

## Security Considerations

- **Whitelist carefully** - Only add trusted IPs to exemptions
- **Don't bypass security for entire site** - Use specific patterns only
- **Monitor blocked requests** - Check security tab regularly
- **Report suspicious activity** - Contact WHM administrator if you see unusual patterns

## Uninstallation

To remove the cPanel plugin (server admin only):

```bash
cd /tmp/hyperspeed-pro-cpanel
chmod +x uninstall.sh
./uninstall.sh
```

This removes:
- cPanel interface files
- UAPI modules
- Sync service
- User data (optional)

## Support

### Documentation
- User Guide: https://docs.hyperspeed.pro/cpanel
- API Reference: https://api.hyperspeed.pro/cpanel
- Video Tutorials: https://videos.hyperspeed.pro

### Community
- Forum: https://community.hyperspeed.pro
- Discord: https://discord.gg/hyperspeed

### Professional Support
- Email: support@hyperspeed.pro
- Ticket System: https://support.hyperspeed.pro

## Changelog

### Version 1.0.0 (2026-04-07)
- Initial release
- Full integration with WHM HyperSpeed Pro
- Per-domain cache management
- Custom bypass rules
- Security exemptions
- Performance analytics
- Resource monitoring
- Real-time sync with WHM settings

## License

MIT License - See LICENSE file

## Credits

HyperSpeed Pro is built with:
- **cPanel UAPI** - For seamless cPanel integration
- **Redis** - For high-performance caching
- **Modern Web Technologies** - HTML5, CSS3, JavaScript

---

**HyperSpeed Pro cPanel Plugin** - Empower your users with enterprise-grade performance optimization! 🚀

For server administrators: This plugin complements the WHM HyperSpeed Pro plugin and requires it to be installed first.
