# HyperSpeed Pro - Quick Deployment Guide

## Deployment Checklist for Server Administrators

### Prerequisites Verification

Before installing the cPanel plugin, ensure:

- [x] **WHM HyperSpeed Pro** is installed and running
- [x] **Redis** is active: `systemctl status redis`
- [x] **cPanel** version 11.110 or higher: `cat /usr/local/cpanel/version`
- [x] **Ubuntu** 22.04 or 24.04: `lsb_release -a`

### Installation Steps

#### 1. Prepare Installation Package

```bash
# Navigate to download location
cd /root/downloads

# Extract the plugin
tar -xzf hyperspeed-pro-cpanel.tar.gz
cd hyperspeed-pro-cpanel

# Verify file integrity
ls -la
```

Expected files:
- `install.sh` - Main installer
- `uninstall.sh` - Removal script
- `uapi/HyperSpeed.pm` - UAPI module
- `cpanel-interface/` - User interface
- `lib/sync-users.php` - Sync service
- `systemd/` - Service definitions

#### 2. Run Installation

```bash
# Make installer executable
chmod +x install.sh

# Run installation (as root)
./install.sh

# Expected output:
# ✓ Checking prerequisites...
# ✓ Installing UAPI module...
# ✓ Installing cPanel interface...
# ✓ Registering sync service...
# ✓ Rebuilding cPanel themes...
# ✓ Installation complete!
```

#### 3. Verify Installation

```bash
# Check UAPI module
/usr/local/cpanel/bin/uapi --list | grep HyperSpeed

# Should show:
# HyperSpeed

# Check sync service
systemctl status hyperspeed-cpanel-sync

# Should show: active (running)

# Test UAPI as a user
su - <cpanel_username>
uapi HyperSpeed get_status
exit
```

#### 4. Access User Interface

1. Log in to any cPanel account
2. Navigate to **Software → HyperSpeed Pro**
3. Verify dashboard loads with metrics

### Post-Installation Configuration

#### Enable Sync Service Auto-Start

```bash
systemctl enable hyperspeed-cpanel-sync
systemctl start hyperspeed-cpanel-sync
```

#### Configure Log Rotation

```bash
cat > /etc/logrotate.d/hyperspeed-cpanel << 'EOF'
/var/log/hyperspeed_pro/sync.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl reload hyperspeed-cpanel-sync > /dev/null 2>&1 || true
    endscript
}
EOF
```

#### Set WHM Global Policies

In WHM → HyperSpeed Pro → Settings:

1. **Enable Policy Enforcement** - Check "Enforce security settings on all users"
2. **Set Defaults** - Configure default cache TTL, compression
3. **Security Baseline** - Enable minimum security requirements
4. **Resource Limits** - Set per-user cache space limits

### User Onboarding

#### Notify Users

Send email to all cPanel users:

```
Subject: New Performance Optimization Available - HyperSpeed Pro

We've installed HyperSpeed Pro on the server, which can dramatically improve your website speed!

To access:
1. Log in to cPanel
2. Go to Software → HyperSpeed Pro
3. Click "Enable" for each domain

Your websites will automatically benefit from:
- 3-tier caching (Redis + Memcached + Nginx)
- Advanced compression (Brotli, Zstandard)
- Security protection (DDoS, rate limiting)
- Real-time performance monitoring

Questions? Check the HyperSpeed Pro docs or open a support ticket.
```

#### Create Knowledge Base Article

Add to your support documentation:
- Link to README.md
- Common troubleshooting steps
- Best practices by site type
- When to contact support

### Monitoring & Maintenance

#### Monitor Sync Service

```bash
# Check logs daily
tail -f /var/log/hyperspeed_pro/sync.log

# Check for errors
grep ERROR /var/log/hyperspeed_pro/sync.log

# Monitor Redis memory
redis-cli INFO memory | grep used_memory_human
```

#### Weekly Maintenance Tasks

```bash
# Check sync service health
systemctl status hyperspeed-cpanel-sync

# Verify all users syncing
redis-cli KEYS "user:*:settings" | wc -l

# Check Redis performance
redis-cli --latency -h 127.0.0.1 -p 6379

# Review security events
redis-cli KEYS "blacklist:*" | head -20
```

#### Monthly Tasks

- Review bandwidth savings across all users
- Check for orphaned Redis keys
- Update documentation for new users
- Review and adjust global policies
- Plan capacity expansion if needed

### Troubleshooting

#### Issue: UAPI Module Not Found

```bash
# Reinstall UAPI module
cp uapi/HyperSpeed.pm /usr/local/cpanel/Cpanel/API/HyperSpeed.pm
chmod 644 /usr/local/cpanel/Cpanel/API/HyperSpeed.pm

# Rebuild cPanel
/usr/local/cpanel/scripts/rebuildhttpdconf
```

#### Issue: Dashboard Not Showing

```bash
# Check theme installation
ls -la /usr/local/cpanel/base/frontend/paper_lantern/hyperspeed/

# Rebuild themes
/usr/local/cpanel/scripts/rebuild_sprites
/usr/local/cpanel/bin/update_local_rpm_versions --edit target_settings.cPanel --set rpm-targets.ea-cpanel-tools installed
```

#### Issue: Sync Service Failing

```bash
# Check Redis connection
redis-cli PING

# Check PHP installation
/usr/local/cpanel/3rdparty/bin/php -v

# Restart sync service
systemctl restart hyperspeed-cpanel-sync

# View detailed logs
journalctl -u hyperspeed-cpanel-sync -n 50 -f
```

#### Issue: Users Can't Clear Cache

```bash
# Verify domain ownership
redis-cli GET "domain:example.com:owner"

# Test UAPI as user
su - username
uapi HyperSpeed flush_cache domain=example.com
exit
```

### Performance Optimization

#### For Servers with 100+ Accounts

1. **Increase sync interval** (from 60s to 120s):
   ```bash
   # Edit lib/sync-users.php
   const SYNC_INTERVAL = 120;
   systemctl restart hyperspeed-cpanel-sync
   ```

2. **Tune Redis**:
   ```bash
   # Edit /etc/redis/redis.conf
   maxmemory 4gb
   maxmemory-policy allkeys-lru
   systemctl restart redis
   ```

3. **Enable Redis persistence**:
   ```bash
   # In redis.conf
   save 900 1
   save 300 10
   save 60 10000
   ```

### Upgrade Path

To upgrade to newer versions:

```bash
# Backup current installation
tar -czf hyperspeed-cpanel-backup-$(date +%Y%m%d).tar.gz \
  /usr/local/cpanel/Cpanel/API/HyperSpeed.pm \
  /usr/local/cpanel/base/frontend/*/hyperspeed/

# Backup Redis data
redis-cli SAVE
cp /var/lib/redis/dump.rdb /root/redis-backup-$(date +%Y%m%d).rdb

# Install new version
cd /root/hyperspeed-pro-cpanel-NEW
./install.sh --upgrade

# Verify
uapi HyperSpeed get_status
```

### Uninstallation

To remove (retain user data):

```bash
cd /root/hyperspeed-pro-cpanel
./uninstall.sh --keep-data
```

To completely remove:

```bash
./uninstall.sh --purge
```

### Support Contacts

- **Documentation**: https://docs.hyperspeed.pro
- **Community Forum**: https://community.hyperspeed.pro  
- **Emergency Support**: support@hyperspeed.pro

---

## Quick Reference Commands

```bash
# Check installation status
systemctl status hyperspeed-cpanel-sync
/usr/local/cpanel/bin/uapi --list | grep HyperSpeed

# View logs
tail -f /var/log/hyperspeed_pro/sync.log

# Test user access
su - username -c "uapi HyperSpeed get_status"

# Flush all caches (emergency)
redis-cli FLUSHDB

# Restart everything
systemctl restart redis hyperspeed-engine hyperspeed-cpanel-sync

# Check Redis stats
redis-cli INFO stats
```

---

**Deployment Complete!** Your users now have enterprise-grade performance optimization at their fingertips. 🚀
