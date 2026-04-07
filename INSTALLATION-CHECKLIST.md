# HyperSpeed Pro - Installation Checklist

**Quick Reference Card for Server Administrators**

---

## Pre-Installation Checklist

### System Requirements
- [ ] Ubuntu 22.04 or 24.04 LTS
- [ ] cPanel/WHM 11.110 or higher installed
- [ ] Minimum 2 CPU cores, 4GB RAM
- [ ] Minimum 20GB free disk space
- [ ] Root SSH access available
- [ ] Server backup completed

### Network & Access
- [ ] Ports 80 and 443 accessible
- [ ] Port 6379 available (Redis)
- [ ] Port 11211 available (Memcached)
- [ ] WHM root access verified
- [ ] cPanel test account created

---

## Installation Phase 1: WHM Plugin (15 minutes)

### Step 1: Prepare Environment
```bash
cd /root
mkdir hyperspeed-install
cd hyperspeed-install
```
- [ ] Working directory created

### Step 2: Upload and Extract WHM Plugin
```bash
# Upload hyperspeed-pro.tar.gz to /root/hyperspeed-install
tar -xzf hyperspeed-pro.tar.gz
cd hyperspeed-pro
ls -la
```
- [ ] Files extracted successfully
- [ ] install.sh present and readable

### Step 3: Run WHM Installation
```bash
chmod +x install.sh
./install.sh
```

**Watch for**:
- [ ] Checking prerequisites... ✓
- [ ] Installing system dependencies... ✓
- [ ] Configuring Redis... ✓
- [ ] Configuring Memcached... ✓
- [ ] Installing Nginx extras... ✓
- [ ] Installing performance engine... ✓
- [ ] Installing security module... ✓
- [ ] Setting up WHM interface... ✓
- [ ] Starting services... ✓
- [ ] Installation complete! ✓

### Step 4: Verify WHM Installation
```bash
# Check services
systemctl status hyperspeed-engine
systemctl status redis
systemctl status memcached

# Check Redis connection
redis-cli PING
# Should return: PONG

# Check files
ls -la /usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed/
ls -la /usr/local/cpanel/lib/hyperspeed_pro/
```
- [ ] hyperspeed-engine: active (running)
- [ ] redis: active (running)
- [ ] memcached: active (running)
- [ ] Redis responds to PING
- [ ] WHM files installed
- [ ] Library files installed

### Step 5: Access WHM Interface
```
URL: https://your-server.com:2087
Navigation: WHM → Plugins → HyperSpeed Pro
```
- [ ] WHM dashboard loads
- [ ] No errors in browser console
- [ ] Performance metrics visible

**Time checkpoint**: Should complete in ~10 minutes

---

## Installation Phase 2: cPanel Plugin (10 minutes)

### Step 1: Extract cPanel Plugin
```bash
cd /root/hyperspeed-install
tar -xzf hyperspeed-pro-cpanel.tar.gz
cd hyperspeed-pro-cpanel
ls -la
```
- [ ] Files extracted
- [ ] install.sh present

### Step 2: Run cPanel Installation
```bash
chmod +x install.sh
./install.sh
```

**Watch for**:
- [ ] Checking prerequisites... ✓
- [ ] Installing UAPI module... ✓
- [ ] Installing cPanel interface (Paper Lantern)... ✓
- [ ] Installing cPanel interface (Jupiter)... ✓
- [ ] Configuring sync service... ✓
- [ ] Rebuilding cPanel themes... ✓
- [ ] Starting sync service... ✓
- [ ] Installation complete! ✓

### Step 3: Verify cPanel Installation
```bash
# Check UAPI module
/usr/local/cpanel/bin/uapi --list | grep HyperSpeed
# Should show: HyperSpeed

# Check sync service
systemctl status hyperspeed-cpanel-sync
# Should show: active (running)

# List UAPI functions
/usr/local/cpanel/bin/uapi --list | grep -A 15 HyperSpeed
```
- [ ] UAPI module registered
- [ ] Sync service running
- [ ] 10 UAPI functions listed

### Step 4: Test cPanel Access
```bash
# Switch to test user
su - testuser

# Test UAPI
uapi HyperSpeed get_status

# Should return JSON with:
# - status: 1
# - enabled: true
# - version: 1.0.0

exit
```
- [ ] UAPI call succeeds
- [ ] Returns valid JSON
- [ ] No errors

### Step 5: Access cPanel Interface
```
URL: https://your-server.com:2083
Navigation: cPanel → Software → HyperSpeed Pro
Login as: test cPanel user
```
- [ ] Dashboard loads
- [ ] Domain list appears
- [ ] Performance cards show data
- [ ] No JavaScript errors

**Time checkpoint**: Should complete in ~7 minutes

---

## Post-Installation Verification (5 minutes)

### Run Automated Verification
```bash
cd /root/hyperspeed-install
bash verify-installation.sh
```

**Expected Output**:
```
[1/8] Checking System Requirements... ✓
[2/8] Checking WHM Plugin Installation... ✓
[3/8] Checking cPanel Plugin Installation... ✓
[4/8] Checking Dependencies... ✓
[5/8] Checking System Services... ✓
[6/8] Testing Redis Connectivity... ✓
[7/8] Testing UAPI Functionality... ✓
[8/8] Checking File Permissions... ✓

✓ Perfect! All checks passed successfully.
```

- [ ] All 8 checks pass
- [ ] 0 errors reported
- [ ] 0 warnings reported

### Quick Functionality Tests

**Test 1: WHM Cache Flush**
```bash
# Access WHM → HyperSpeed Pro
# Click "Flush All Caches"
# Confirm success message appears
```
- [ ] Cache flush succeeds
- [ ] Metrics updated

**Test 2: cPanel Domain Management**
```bash
# Access cPanel → HyperSpeed Pro
# Go to Domains tab
# Click "Cache Stats" on any domain
```
- [ ] Domain stats display
- [ ] Cache hit rate shown

**Test 3: Bypass Rule Creation**
```bash
# In cPanel → Cache Control
# Add bypass rule: /wp-admin/*
# Click "Add Rule"
```
- [ ] Rule added successfully
- [ ] Appears in rules list

**Test 4: Security Exemption**
```bash
# In cPanel → Security tab
# Add IP exemption: 192.168.1.100
# Reason: "Office IP"
```
- [ ] Exemption created
- [ ] Visible in exemptions list

### Performance Validation

**Benchmark Test**:
```bash
/usr/local/bin/hyperspeed benchmark:run
```
- [ ] Benchmark completes
- [ ] Response time <500ms
- [ ] No errors reported

**Redis Key Check**:
```bash
redis-cli KEYS "hyperspeed:*" | head -20
```
- [ ] Keys created
- [ ] Format: hyperspeed:domain:*, hyperspeed:user:*

---

## Configuration Phase (10 minutes)

### WHM Global Settings

1. **Access WHM → HyperSpeed Pro → Settings**
2. Configure:
   - [ ] Cache TTL: 3600 seconds
   - [ ] Compression: Brotli (Level 6)
   - [ ] HTTP/3: Enabled
   - [ ] DDoS Protection: Enabled
   - [ ] Rate Limiting: 100 req/min
   - [ ] Enforce settings on users: Checked

3. **Click "Save Configuration"**
   - [ ] Settings saved
   - [ ] Confirmation message shown

### Enable Auto-Start

```bash
systemctl enable hyperspeed-engine
systemctl enable hyperspeed-cpanel-sync
systemctl enable redis
systemctl enable memcached
```
- [ ] All services enabled for auto-start

### Configure Log Rotation

```bash
cat > /etc/logrotate.d/hyperspeed << 'EOF'
/var/log/hyperspeed_pro/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
}
EOF
```
- [ ] Log rotation configured

---

## User Onboarding (5 minutes)

### Notify All Users

**Email Template**:
```
Subject: New Performance Tool - HyperSpeed Pro Now Available!

Dear Valued Customer,

We're excited to announce HyperSpeed Pro is now available in your cPanel!

This powerful tool can dramatically improve your website speed with:
✓ Advanced caching (faster than LiteSpeed)
✓ Automatic optimization
✓ Real-time performance monitoring
✓ Easy one-click controls

To access:
1. Log in to cPanel
2. Go to Software → HyperSpeed Pro
3. Click "Enable" for your domains

Questions? Contact support or check the docs at:
https://your-server.com/docs/hyperspeed-pro

Happy optimizing!
```
- [ ] Email sent to all users

### Create Knowledge Base Article

**Required sections**:
- [ ] What is HyperSpeed Pro
- [ ] How to access
- [ ] How to enable for domains
- [ ] Common bypass rules
- [ ] Troubleshooting FAQs

---

## Monitoring Setup (Ongoing)

### Daily Checks
```bash
# Check service health
systemctl status hyperspeed-engine hyperspeed-cpanel-sync

# Check logs for errors
grep ERROR /var/log/hyperspeed_pro/*.log | tail -20

# Monitor Redis memory
redis-cli INFO memory | grep used_memory_human
```

### Weekly Reviews
- [ ] Review aggregate performance stats
- [ ] Check top performing domains
- [ ] Review security events
- [ ] Monitor server resources
- [ ] User feedback review

### Monthly Maintenance
- [ ] Redis memory optimization
- [ ] Clean old logs
- [ ] Review and update bypass rules
- [ ] Performance benchmark comparison
- [ ] Update documentation

---

## Troubleshooting Quick Reference

### Service Won't Start
```bash
# View detailed logs
journalctl -u hyperspeed-engine -n 50
journalctl -u hyperspeed-cpanel-sync -n 50

# Check configuration
/usr/local/bin/hyperspeed config:validate

# Restart services
systemctl restart hyperspeed-engine
systemctl restart hyperspeed-cpanel-sync
```

### Redis Issues
```bash
# Check Redis
redis-cli PING
systemctl restart redis

# Check Redis logs
tail -f /var/log/redis/redis-server.log
```

### Dashboard Not Loading
```bash
# Check WHM CGI permissions
chmod 755 /usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed/index.cgi

# Rebuild themes
/usr/local/cpanel/scripts/rebuild_sprites
```

### UAPI Not Working
```bash
# Reinstall UAPI module
cp hyperspeed-pro-cpanel/uapi/HyperSpeed.pm \
   /usr/local/cpanel/Cpanel/API/HyperSpeed.pm

# Test registration
/usr/local/cpanel/bin/uapi --list | grep HyperSpeed
```

---

## Final Checklist

### Installation Complete When:
- [ ] All services running and enabled
- [ ] WHM dashboard accessible and functional
- [ ] cPanel dashboard accessible to users
- [ ] UAPI endpoints responding correctly
- [ ] Redis storing keys properly
- [ ] Sync service running every 60 seconds
- [ ] Log rotation configured
- [ ] Users notified
- [ ] Documentation available
- [ ] Verify script passes all checks
- [ ] Backup of configuration created
- [ ] Monitoring alerts configured

### Success Metrics (After 24 Hours)
- [ ] Cache hit rate >80%
- [ ] No service crashes
- [ ] User adoption >10%
- [ ] No critical errors in logs
- [ ] Performance improvement visible

### Success Metrics (After 7 Days)
- [ ] Cache hit rate >90%
- [ ] User adoption >50%
- [ ] Bandwidth savings >60%
- [ ] Page load time reduced >70%
- [ ] Support tickets decreased

---

## Support Contacts

**Documentation**: 
- README.md (project root)
- SYSTEM-OVERVIEW.md (complete architecture)
- hyperspeed-pro/README.md (WHM guide)
- hyperspeed-pro-cpanel/README.md (cPanel guide)

**Emergency**:
- Email: support@hyperspeed.pro
- Forum: https://community.hyperspeed.pro

**Log all issues in**: /var/log/hyperspeed_pro/installation.log

---

## Installation Time Summary

| Phase | Expected Time | Your Time |
|-------|---------------|-----------|
| Pre-checks | 5 min | _______ |
| WHM Plugin | 15 min | _______ |
| cPanel Plugin | 10 min | _______ |
| Verification | 5 min | _______ |
| Configuration | 10 min | _______ |
| User Onboarding | 5 min | _______ |
| **Total** | **50 min** | _______ |

---

**Installation Date**: _______________
**Installed By**: _______________
**Server**: _______________
**Notes**: 
________________________________________________________________
________________________________________________________________
________________________________________________________________

---

**HyperSpeed Pro Installation Checklist v1.0** - Making servers fast! 🚀
