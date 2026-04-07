# HyperSpeed Pro - Installation Guide

## Prerequisites

Before installing HyperSpeed Pro, ensure your system meets the following requirements:

### Operating System
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 24.04 LTS (Noble Numbat)

### cPanel & WHM
- cPanel & WHM Version 11.110 or higher
- Root access to the server
- Active cPanel license

### Hardware
- **Minimum**: 2 CPU cores, 4 GB RAM, 20 GB disk space
- **Recommended**: 4+ CPU cores, 8+ GB RAM, 50+ GB disk space

### Network
- SSH access enabled
- Port 2087 (WHM) accessible
- Internet connectivity for downloading dependencies

## Installation Steps

### Step 1: Download HyperSpeed Pro

```bash
# SSH into your server as root
ssh root@your-server-ip

# Navigate to temporary directory
cd /tmp

# Download the latest release
wget https://releases.hyperspeed.pro/latest/hyperspeed-pro.tar.gz

# Verify the download (optional but recommended)
sha256sum hyperspeed-pro.tar.gz
```

### Step 2: Extract the Archive

```bash
# Extract the tarball
tar -xzf hyperspeed-pro.tar.gz

# Navigate to the extracted directory
cd hyperspeed-pro

# List contents to verify
ls -la
```

Expected files:
- `install.sh` - Installation script
- `uninstall.sh` - Uninstallation script
- `appconfig.conf` - AppConfig configuration
- `plugin.conf` - Plugin metadata
- `cgi/` - CGI scripts directory
- `lib/` - PHP library files
- `bin/` - Binary executables
- `config/` - Configuration templates
- `assets/` - UI assets (CSS, JS, images)
- `README.md` - Documentation
- `LICENSE` - License file

### Step 3: Run the Installer

```bash
# Make the installer executable
chmod +x install.sh

# Run the installation script
./install.sh
```

### Step 4: Monitor Installation

The installer will:

1. **Check System Requirements**
   - Verify Ubuntu version
   - Check cPanel installation
   - Validate root privileges

2. **Install Dependencies**
   - Redis Server
   - Memcached
   - Nginx extras
   - PHP-FPM and extensions
   - Brotli and Zstd compression libraries

3. **Create Directory Structure**
   ```
   /usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed_pro/
   /usr/local/cpanel/lib/hyperspeed_pro/
   /usr/local/bin/hyperspeed_pro/
   /etc/hyperspeed_pro/
   /var/cache/hyperspeed_pro/
   /var/log/hyperspeed_pro/
   ```

4. **Configure Services**
   - Optimize Redis configuration
   - Configure Memcached settings
   - Set up systemd service

5. **Register with AppConfig**
   - Register plugin with cPanel system
   - Create WHM interface entry

6. **Optimize System**
   - Tune kernel parameters
   - Set up log rotation
   - Configure security settings

### Step 5: Verify Installation

```bash
# Check service status
systemctl status hyperspeed-engine

# Verify Redis
redis-cli PING
# Expected output: PONG

# Verify Memcached
echo "stats" | nc localhost 11211
# Expected output: Statistics

# Check logs
tail -f /var/log/hyperspeed_pro/engine.log
```

### Step 6: Access WHM Dashboard

1. Open your web browser
2. Navigate to: `https://your-server-ip:2087`
3. Log in with your WHM root credentials
4. Go to: **Plugins → HyperSpeed Pro**
5. You should see the HyperSpeed Pro dashboard

## Post-Installation Configuration

### Initial Setup

1. **Review Settings**
   - Navigate to the Settings page
   - Configure cache TTL values
   - Set compression levels
   - Enable/disable features as needed

2. **Configure Security**
   - Review rate limiting settings
   - Configure DDoS protection thresholds
   - Set up email alerts

3. **Test Cache**
   - Visit a website on your server
   - Check cache statistics in dashboard
   - Verify cache hit rates

### Recommended Initial Settings

For most servers, these settings work well:

```json
{
  "cache": {
    "ttl": 3600,
    "page_cache": true,
    "object_cache": true
  },
  "compression": {
    "brotli": true,
    "zstd": true,
    "level": 6
  },
  "security": {
    "rate_limiting": true,
    "ddos_protection": true,
    "bot_detection": true
  }
}
```

## Troubleshooting Installation

### Issue: Redis Connection Failed

```bash
# Check Redis status
systemctl status redis-server

# Restart Redis
systemctl restart redis-server

# Test connection
redis-cli PING
```

### Issue: Memcached Not Running

```bash
# Check Memcached status
systemctl status memcached

# Restart Memcached
systemctl restart memcached

# Test connection
echo "stats" | nc localhost 11211
```

### Issue: AppConfig Registration Failed

```bash
# Manually register
/usr/local/cpanel/bin/register_appconfig /tmp/hyperspeed-pro/appconfig.conf

# Rebuild WHM interface cache
/usr/local/cpanel/scripts/rebuildhttpdconf
```

### Issue: Permission Errors

```bash
# Fix ownership
chown -R root:root /usr/local/cpanel/lib/hyperspeed_pro/
chown -R root:root /etc/hyperspeed_pro/

# Fix permissions
chmod -R 755 /usr/local/cpanel/lib/hyperspeed_pro/
chmod -R 755 /etc/hyperspeed_pro/
```

### Issue: Port Conflicts

If ports are already in use:

```bash
# Check what's using Redis port
lsof -i :6379

# Check what's using Memcached port
lsof -i :11211
```

## Upgrading from Previous Versions

If you're upgrading from a previous version:

```bash
# Stop the service
systemctl stop hyperspeed-engine

# Backup configuration
cp -r /etc/hyperspeed_pro /etc/hyperspeed_pro.backup

# Run the new installer
cd /tmp/hyperspeed-pro
./install.sh

# The installer will detect existing installation and upgrade
```

## Uninstallation

To remove HyperSpeed Pro:

```bash
cd /tmp/hyperspeed-pro
chmod +x uninstall.sh
./uninstall.sh
```

You'll be prompted to:
- Confirm uninstallation
- Choose whether to keep configuration files
- Choose whether to keep log files

## Getting Help

If you encounter issues during installation:

1. **Check Logs**
   ```bash
   cat /var/log/hyperspeed_pro/engine.log
   journalctl -u hyperspeed-engine
   ```

2. **Contact Support**
   - Email: support@hyperspeed.pro
   - Forum: https://community.hyperspeed.pro
   - Documentation: https://docs.hyperspeed.pro

3. **Report Issues**
   - GitHub: https://github.com/hyperspeed-pro/issues
   - Include log files and system information

## Next Steps

After successful installation:

1. Read the [User Guide](https://docs.hyperspeed.pro/user-guide)
2. Configure [Advanced Settings](https://docs.hyperspeed.pro/advanced)
3. Set up [Monitoring and Alerts](https://docs.hyperspeed.pro/monitoring)
4. Review [Security Best Practices](https://docs.hyperspeed.pro/security)
5. Optimize for [Your Specific CMS](https://docs.hyperspeed.pro/cms-guides)

---

**Welcome to HyperSpeed Pro! Your server is now optimized for maximum performance.**
