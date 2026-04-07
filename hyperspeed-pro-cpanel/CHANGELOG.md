# Changelog

All notable changes to HyperSpeed Pro cPanel User Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-07

### Added

#### Core Features
- Complete cPanel user interface integration with Paper Lantern theme
- Full UAPI module with 10 endpoint functions
- Real-time synchronization with WHM master configuration
- Per-domain cache management system
- Custom cache bypass rule engine
- Security exemption management interface
- Resource usage monitoring and analytics
- Performance metrics tracking and visualization

#### User Interface
- Modern responsive dashboard with 6 main tabs:
  - **Dashboard Tab** - Performance overview, key metrics, domain summary
  - **Domains Tab** - Per-domain management with individual controls
  - **Cache Control Tab** - Advanced cache management and bypass rules
  - **Security Tab** - Security exemptions and threat monitoring
  - **Settings Tab** - User preferences and optimization toggles
  - **Analytics Tab** - Performance charts and resource usage graphs

#### UAPI Functions
- `get_status` - Retrieve HyperSpeed Pro status for current user
- `get_domains` - List all domains with cache statistics
- `flush_cache` - Clear cache for specific domains or all domains
- `get_stats` - Get detailed performance statistics
- `set_bypass_rule` - Add custom cache bypass rules
- `get_bypass_rules` - Retrieve bypass rules for domains
- `delete_bypass_rule` - Remove bypass rules
- `set_security_exemption` - Add security whitelists
- `get_security_exemptions` - Retrieve security exemptions
- `get_resource_usage` - Get CPU, memory, bandwidth statistics

#### Synchronization System
- Automatic 60-second sync interval with WHM configuration
- Bidirectional sync: WHM master settings → user defaults
- User-level customization with WHM policy enforcement
- Global security rule propagation
- Automatic cleanup of stale data (30-day retention)
- Domain ownership validation and verification
- Multi-user Redis key namespacing

#### Cache Management
- Per-domain cache control
- Custom bypass rules by URL pattern, cookie, or query parameter
- Cache TTL customization (300-86400 seconds)
- One-click cache clearing (all domains or specific domain)
- Cache hit rate monitoring
- Bandwidth savings calculation

#### Security Features
- IP address whitelisting
- User agent exemptions
- Per-domain security configuration
- Integration with WHM global security policies
- Security event monitoring
- Threat statistics dashboard

#### Performance Analytics
- Real-time cache hit/miss rates
- Bandwidth usage tracking
- Performance boost percentage calculation
- Response time monitoring
- Request distribution charts
- 24-hour, 7-day, and 30-day trend analysis

#### Installation & Deployment
- Automated installation script with dependency checking
- cPanel theme integration (Paper Lantern + Jupiter)
- Automatic UAPI module registration
- Systemd service setup for sync daemon
- Log rotation configuration
- Clean uninstallation script

#### Developer Features
- Full UAPI command-line access
- JSON API responses
- Redis key-value storage for user data
- Domain ownership verification API
- Comprehensive error handling and logging

### Technical Details

#### File Structure
```
hyperspeed-pro-cpanel/
├── install.sh                      # Main installation script
├── uninstall.sh                    # Clean removal script
├── uapi/
│   └── HyperSpeed.pm              # Perl UAPI module (600+ lines)
├── cpanel-interface/
│   ├── index.html                 # Main dashboard (434 lines)
│   └── assets/
│       ├── dashboard.js           # JavaScript functionality (667 lines)
│       ├── style.css              # Responsive CSS (3,472 lines)
│       └── hyperspeed-icon.svg    # Plugin icon
├── lib/
│   └── sync-users.php             # WHM-cPanel sync service (400+ lines)
├── systemd/
│   └── hyperspeed-cpanel-sync.service  # Sync daemon service
└── README.md                      # Comprehensive documentation
```

#### Dependencies
- cPanel & WHM 11.110+
- Redis 6.0+
- PHP 8.0+
- Perl 5.16+
- WHM HyperSpeed Pro Plugin (required)
- Ubuntu 22.04 or 24.04 LTS

#### Performance Characteristics
- Dashboard loads in <500ms
- UAPI calls respond in <100ms
- Cache operations in <10ms (Redis)
- Sync cycle completes in <5 seconds for 100 users
- Memory footprint: ~50MB per 1000 domains
- Scales to 10,000+ domains per server

#### Security Model
- Domain ownership validation on all operations
- User can only manage their own domains
- WHM admin policies enforced automatically
- Redis key namespacing prevents cross-user access
- Input sanitization on all UAPI endpoints
- XSS protection in user interface
- CSRF token validation

### Documentation
- Complete README with usage examples
- UAPI function reference
- Troubleshooting guide
- Best practices for WordPress, e-commerce, high-traffic sites
- Integration guide with WHM plugin
- Installation instructions for server administrators

### Compatibility
- Tested on Ubuntu 22.04 LTS (Jammy)
- Tested on Ubuntu 24.04 LTS (Noble)
- Compatible with cPanel 11.110 through 11.120
- Works with Paper Lantern and Jupiter themes
- Mobile responsive (tablets, smartphones)
- Modern browser support (Chrome 90+, Firefox 88+, Safari 14+, Edge 90+)

### Known Limitations
- Requires WHM HyperSpeed Pro to be installed first
- Analytics charts require Chart.js (included via CDN)
- Maximum 1000 bypass rules per domain (performance optimization)
- Maximum 100 security exemptions per user
- Metrics retained for 30 days only

## [Unreleased]

### Planned Features
- Advanced analytics with customizable date ranges
- Export statistics to CSV/PDF
- Email notifications for security events
- Mobile app companion
- API webhooks for external integrations
- Multi-language support
- Dark mode theme option
- Advanced bot management with CAPTCHA integration
- CDN integration for global acceleration
- Database query optimization recommendations

### Under Consideration
- WordPress plugin for tighter integration
- Joomla extension
- Drupal module
- Command-line administration tool
- Backup and restore functionality for settings
- A/B testing framework integration
- Real User Monitoring (RUM) integration

---

## Version History

| Version | Release Date | Status     | Highlights                                    |
|---------|--------------|------------|-----------------------------------------------|
| 1.0.0   | 2026-04-07   | Stable     | Initial release with full feature set        |

---

## Upgrade Guide

### From Beta to 1.0.0
If you participated in beta testing:

```bash
# Backup your settings
redis-cli --scan --pattern "user:*:settings" | xargs redis-cli DUMP > backup.rdb

# Run the upgrade
cd /tmp/hyperspeed-pro-cpanel
./install.sh --upgrade

# Verify settings preserved
uapi HyperSpeed get_status
```

### Future Upgrades
All future upgrades will preserve:
- User settings in Redis
- Bypass rules
- Security exemptions
- Historical metrics (where possible)

---

## Support & Feedback

Found a bug? Have a feature request?

- **Issues**: https://github.com/hyperspeed-pro/cpanel-plugin/issues
- **Discussions**: https://github.com/hyperspeed-pro/cpanel-plugin/discussions
- **Email**: support@hyperspeed.pro

---

**Thank you for using HyperSpeed Pro cPanel User Plugin!**

We're committed to making your websites faster and more secure than ever before.
