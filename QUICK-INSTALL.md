# HyperSpeed Pro - Quick Installation from GitHub

**One-command installation for production servers**

---

## Installation Command

```bash
curl -sSL https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh | sudo bash
```

**Or download and inspect first (recommended):**

```bash
wget -O quick-install.sh https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh
chmod +x quick-install.sh
sudo ./quick-install.sh
```

---

## What This Does

The installation script will:

1. ✅ Verify system requirements (Ubuntu 22.04/24.04/AlmaLinux 9, cPanel/WHM)
2. ✅ Backup existing configurations
3. ✅ Download latest release from GitHub
4. ✅ Install dependencies (Redis, Memcached, Nginx extras)
5. ✅ Install WHM plugin with performance engine
6. ✅ Install cPanel user plugin
7. ✅ Configure and start services
8. ✅ Run verification tests
9. ✅ Display access instructions

**Total time**: ~7 minutes

---

## System Requirements

**Minimum:**
- **Operating System**: Ubuntu 22.04/24.04 LTS, AlmaLinux 9, or Rocky Linux 9
- cPanel/WHM 11.110+
- 2 CPU cores
- 4 GB RAM
- 20 GB free disk space
- Root access

**Recommended:**
- 4+ CPU cores
- 8 GB+ RAM
- SSD storage

---

## Manual Installation

### Step 1: Download Latest Release

```bash
cd /root
wget https://github.com/Ferguson230/Hyperspeed-Pro/archive/refs/tags/v1.0.0.tar.gz
tar -xzf v1.0.0.tar.gz
cd hyperspeed-pro-1.0.0
```

### Step 2: Install WHM Plugin

```bash
cd hyperspeed-pro
chmod +x install.sh
./install.sh
```

**Watch for**: Installation progress and green checkmarks ✓

### Step 3: Install cPanel Plugin

```bash
cd ../hyperspeed-pro-cpanel
chmod +x install.sh
./install.sh
```

### Step 4: Verify Installation

```bash
cd ..
bash verify-installation.sh
```

**Expected result**: All 8 checks pass with no errors

---

## Access Your Installation

### WHM Interface (Admin)
```
URL: https://your-server.com:2087
Navigate to: WHM → Plugins → HyperSpeed Pro
```

### cPanel Interface (Users)
```
URL: https://your-server.com:2083
Navigate to: cPanel → Software → HyperSpeed Pro
```

---

## Post-Installation

### Enable Auto-Start (Recommended)

```bash
systemctl enable hyperspeed-engine
systemctl enable hyperspeed-cpanel-sync
systemctl enable redis
systemctl enable memcached
```

### Check Service Status

```bash
systemctl status hyperspeed-engine
systemctl status hyperspeed-cpanel-sync
systemctl status redis
systemctl status memcached
```

### Run Benchmark

```bash
/usr/local/bin/hyperspeed benchmark:run
```

---

## Uninstallation

### Keep User Data (Recommended)

```bash
cd /root/hyperspeed-pro-cpanel
./uninstall.sh

cd /root/hyperspeed-pro
./uninstall.sh
```

### Complete Removal (Including Data)

```bash
cd /root/hyperspeed-pro-cpanel
./uninstall.sh --purge

cd /root/hyperspeed-pro
./uninstall.sh --purge
```

### Restore Original Configuration

```bash
# Find your backup directory
ls -la /root/.hyperspeed-backup-*

# Restore from backup
cd /root/hyperspeed-pro
./uninstall.sh --restore /root/.hyperspeed-backup-YYYYMMDD_HHMMSS
```

---

## Troubleshooting

### Installation Failed

**Check logs:**
```bash
tail -f /var/log/hyperspeed_pro/install.log
```

**Common issues:**
1. **Port conflicts**: Ensure ports 6379 (Redis) and 11211 (Memcached) are free
2. **Disk space**: Verify at least 20GB free
3. **cPanel version**: Must be 11.110 or higher

### Services Won't Start

```bash
# Check Redis
systemctl status redis
redis-cli PING

# Check Memcached
systemctl status memcached
echo "stats" | nc localhost 11211

# Check HyperSpeed Engine
journalctl -u hyperspeed-engine -n 50
```

### Dashboard Not Loading

```bash
# Rebuild cPanel themes
/usr/local/cpanel/scripts/rebuild_sprites

# Check CGI permissions
chmod 755 /usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed_pro/index.cgi
```

---

## Updating to Latest Version

```bash
cd /root
wget https://github.com/Ferguson230/Hyperspeed-Pro/archive/refs/tags/latest.tar.gz
tar -xzf latest.tar.gz
cd hyperspeed-pro-latest

# Backup current installation first
cp -r /usr/local/cpanel/lib/hyperspeed_pro /root/hyperspeed-backup-$(date +%Y%m%d)

# Run update
bash update.sh
```

---

## Getting Help

**Documentation:**
- Full README: [README.md](https://github.com/Ferguson230/Hyperspeed-Pro)
- System Overview: [SYSTEM-OVERVIEW.md](https://github.com/Ferguson230/Hyperspeed-Pro/blob/main/SYSTEM-OVERVIEW.md)
- Installation Checklist: [INSTALLATION-CHECKLIST.md](https://github.com/Ferguson230/Hyperspeed-Pro/blob/main/INSTALLATION-CHECKLIST.md)

**Community:**
- Forum: https://community.hyperspeed.pro
- Discord: https://discord.gg/hyperspeed
- GitHub Issues: https://github.com/Ferguson230/Hyperspeed-Pro/issues

**Professional Support:**
- Email: support@hyperspeed.pro
- Tickets: https://support.hyperspeed.pro

---

## Performance Expectations

After installation, you should see:

**Within 24 hours:**
- 📈 Page load times reduced by 60-85%
- 📈 TTFB (Time to First Byte) reduced by 80-95%
- 📈 Cache hit rate reaching 80%+
- 📈 Bandwidth usage reduced by 50-70%

**Within 7 days:**
- 📈 Cache hit rate at 90%+
- 📈 Server load reduced by 50-70%
- 📈 Able to handle 3-5x more concurrent visitors

---

## Contributing

Found a bug? Want to contribute?

See [CONTRIBUTING.md](https://github.com/Ferguson230/Hyperspeed-Pro/blob/main/CONTRIBUTING.md) for guidelines.

---

**HyperSpeed Pro** - Making your server faster than LiteSpeed, better than Varnish! 🚀

*Star ⭐ this repo if it helped you!*
