# Manual HyperSpeed Pro cPanel Plugin Deployment

## Quick Deploy (Run on server as root)

```bash
# 1. Download fixed files directly to cPanel paths
cd /tmp
wget -O HyperSpeed.pm "https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/hyperspeed-pro-cpanel/uapi/HyperSpeed.pm"
wget -O sync-users.php "https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/hyperspeed-pro-cpanel/lib/sync-users.php"
wget -O dashboard.js "https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/hyperspeed-pro-cpanel/cpanel-interface/assets/dashboard.js"

# 2. Install UAPI module
install -d /usr/local/cpanel/Cpanel/API
install -m 0644 HyperSpeed.pm /usr/local/cpanel/Cpanel/API/HyperSpeed.pm

# 3. Install sync worker
install -d /usr/local/cpanel/lib/hyperspeed_pro
install -m 0755 sync-users.php /usr/local/cpanel/lib/hyperspeed_pro/sync-users.php

# 4. Install dashboard for both themes
for theme in jupiter paper_lantern; do
  if [ -d "/usr/local/cpanel/base/frontend/$theme" ]; then
    install -d "/usr/local/cpanel/base/frontend/$theme/hyperspeed/assets"
    install -m 0644 dashboard.js "/usr/local/cpanel/base/frontend/$theme/hyperspeed/assets/dashboard.js"
  fi
done

# 5. Verify UAPI syntax
perl -I/usr/local/cpanel -c /usr/local/cpanel/Cpanel/API/HyperSpeed.pm

# 6. Restart services
systemctl restart hyperspeed-cpanel-sync 2>&1 | head -5
/usr/local/cpanel/scripts/restartsrv_cpsrvd 2>&1 | head -5

# 7. Test UAPI
sleep 3
uapi --output=jsonpretty --user=deecoolmapsot HyperSpeed get_status | head -50
```

## Validation Tests

```bash
# Check UAPI returns valid JSON (no warnings)
uapi --user=deecoolmapsot HyperSpeed get_status 2>&1 | grep -i warning

# Check sync service is running
systemctl status hyperspeed-cpanel-sync --no-pager | head -10

# Check Redis connectivity
redis-cli INFO stats | grep -E 'keyspace_hits|keyspace_misses'

# View sync log
tail -20 /var/log/hyperspeed_pro/sync.log
```

## What This Fixes

1. **Removed 600+ lines of duplicate code** from HyperSpeed.pm that was causing parsing issues
2. **Cleaned UAPI module** - now ends at proper `1;` with just POD documentation after
3. **Direct installation** - bypasses installer scripts that were failing silently
4. **Syntax validation** - verifies Perl module loads correctly before restart

## Expected Outputs

### Successful UAPI test should show:
```json
{
   "status" : 1,
   "data" : {
      "enabled" : 1,
      "user" : "deecoolmapsot",
      "version" : "1.0.0",
      "redis" : 1,
      "summary" : {
         "cache_hits" : 12345,
         "hit_rate" : "75.3",
         ...
      }
   }
}
```

### No warnings in output - clean JSON only
