#!/bin/bash
# HyperSpeed Pro - Complete Deployment Fix
# Runs diagnostics and fixes all deployment issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}HyperSpeed Pro - Deployment Fix${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Check if files exist
echo -e "${YELLOW}Step 1: Verifying downloaded files...${NC}"
cd /root/hyperspeed-install/hyperspeed-pro-cpanel || {
    echo -e "${RED}Error: Source directory not found${NC}"
    exit 1
}

for file in "uapi/HyperSpeed.pm" "lib/sync-users.php" "cpanel-interface/index.html" "cpanel-interface/assets/dashboard.js"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ Found $file ($(stat -c%s $file) bytes)${NC}"
    else
        echo -e "${RED}✗ Missing $file${NC}"
        exit 1
    fi
done

# Step 2: Check Redis connectivity
echo ""
echo -e "${YELLOW}Step 2: Checking Redis connectivity...${NC}"
if redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Redis is running${NC}"
    HITS=$(redis-cli INFO stats 2>/dev/null | grep -oP 'keyspace_hits:\K\d+' || echo "0")
    MISSES=$(redis-cli INFO stats 2>/dev/null | grep -oP 'keyspace_misses:\K\d+' || echo "0")
    echo -e "${GREEN}  Redis stats: $HITS hits, $MISSES misses${NC}"
else
    echo -e "${RED}✗ Redis not responding${NC}"
    echo "  Starting Redis..."
    systemctl start redis || service redis start || {
        echo -e "${RED}Failed to start Redis${NC}"
        exit 1
    }
fi

# Step 3: Check Perl syntax
echo ""
echo -e "${YELLOW}Step 3: Validating UAPI module syntax...${NC}"
if perl -I/usr/local/cpanel -c uapi/HyperSpeed.pm 2>&1 | grep -q "syntax OK"; then
    echo -e "${GREEN}✓ UAPI module syntax valid${NC}"
else
    echo -e "${RED}✗ UAPI module has syntax errors:${NC}"
    perl -I/usr/local/cpanel -c uapi/HyperSpeed.pm
    exit 1
fi

# Step 4: Install files
echo ""
echo -e "${YELLOW}Step 4: Installing files to cPanel paths...${NC}"

install -d /usr/local/cpanel/Cpanel/API
install -m 0644 uapi/HyperSpeed.pm /usr/local/cpanel/Cpanel/API/HyperSpeed.pm
echo -e "${GREEN}✓ Installed UAPI module${NC}"

install -d /usr/local/cpanel/lib/hyperspeed_pro
install -m 0755 lib/sync-users.php /usr/local/cpanel/lib/hyperspeed_pro/sync-users.php
echo -e "${GREEN}✓ Installed sync worker${NC}"

for theme in jupiter paper_lantern; do
    if [ -d "/usr/local/cpanel/base/frontend/$theme" ]; then
        install -d "/usr/local/cpanel/base/frontend/$theme/hyperspeed/assets"
        install -m 0644 cpanel-interface/index.html "/usr/local/cpanel/base/frontend/$theme/hyperspeed/index.html"
        install -m 0644 cpanel-interface/index.live.php "/usr/local/cpanel/base/frontend/$theme/hyperspeed/index.live.php"
        install -m 0644 cpanel-interface/assets/dashboard.js "/usr/local/cpanel/base/frontend/$theme/hyperspeed/assets/dashboard.js"
        install -m 0644 cpanel-interface/assets/style.css "/usr/local/cpanel/base/frontend/$theme/hyperspeed/assets/style.css"
        echo -e "${GREEN}✓ Installed to $theme theme${NC}"
    fi
done

# Step 5: Create sync wrapper with proper PHP selection
echo ""
echo -e "${YELLOW}Step 5: Creating sync service wrapper...${NC}"

cat > /usr/local/cpanel/scripts/hyperspeed-sync << 'SYNCEOF'
#!/bin/bash
# HyperSpeed Pro - Sync Service Wrapper
# Prefer PHP with Redis extension loaded

PHP_BIN=""
FALLBACK_PHP=""

for p in /opt/cpanel/ea-php*/root/usr/bin/php /usr/bin/php /usr/local/cpanel/3rdparty/bin/php; do
    [ -x "$p" ] || continue
    
    if [ -z "$FALLBACK_PHP" ]; then
        FALLBACK_PHP="$p"
    fi
    
    if "$p" -r 'exit(class_exists("Redis") ? 0 : 1);' >/dev/null 2>&1; then
        PHP_BIN="$p"
        break
    fi
done

if [ -z "$PHP_BIN" ]; then
    PHP_BIN="$FALLBACK_PHP"
fi

if [ -z "$PHP_BIN" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No PHP binary found" >> /var/log/hyperspeed_pro/sync.log
    exit 1
fi

if ! "$PHP_BIN" -r 'exit(class_exists("Redis") ? 0 : 1);' >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: PHP binary lacks Redis extension: $PHP_BIN" >> /var/log/hyperspeed_pro/sync.log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Sync may have limited functionality" >> /var/log/hyperspeed_pro/sync.log
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting sync worker with $PHP_BIN" >> /var/log/hyperspeed_pro/sync.log

while true; do
    "$PHP_BIN" /usr/local/cpanel/lib/hyperspeed_pro/sync-users.php >> /var/log/hyperspeed_pro/sync.log 2>&1 || true
    sleep 60
done
SYNCEOF

chmod +x /usr/local/cpanel/scripts/hyperspeed-sync
echo -e "${GREEN}✓ Created sync wrapper${NC}"

# Step 6: Restart services
echo ""
echo -e "${YELLOW}Step 6: Restarting services...${NC}"

mkdir -p /var/log/hyperspeed_pro
touch /var/log/hyperspeed_pro/sync.log
chmod 644 /var/log/hyperspeed_pro/sync.log

systemctl daemon-reload
systemctl restart hyperspeed-cpanel-sync 2>&1 | grep -v '^$' || echo "  (service restarted)"
echo -e "${GREEN}✓ Restarted sync service${NC}"

/usr/local/cpanel/scripts/restartsrv_cpsrvd 2>&1 | head -5
echo -e "${GREEN}✓ Restarted cpsrvd${NC}"

sleep 3

# Step 7: Run validation tests
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Running Validation Tests${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Test 1: UAPI get_status${NC}"
uapi --output=jsonpretty --user=deecoolmapsot HyperSpeed get_status | head -30 || {
    echo -e "${RED}✗ UAPI get_status failed${NC}"
}

echo ""
echo -e "${YELLOW}Test 2: UAPI get_security_stats${NC}"
uapi --output=jsonpretty --user=deecoolmapsot HyperSpeed get_security_stats || {
    echo -e "${RED}✗ UAPI get_security_stats failed${NC}"
}

echo ""
echo -e "${YELLOW}Test 3: Sync service status${NC}"
systemctl --no-pager status hyperspeed-cpanel-sync | head -15

echo ""
echo -e "${YELLOW}Test 4: Sync log (last 20 lines)${NC}"
tail -n 20 /var/log/hyperspeed_pro/sync.log

echo ""
echo -e "${YELLOW}Test 5: Check for Redis warnings in UAPI${NC}"
if uapi --user=deecoolmapsot HyperSpeed get_status 2>&1 | grep -i "redis.*warning"; then
    echo -e "${RED}✗ Redis warnings detected in UAPI output${NC}"
else
    echo -e "${GREEN}✓ No Redis warnings${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Fix Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next: Check cPanel dashboard at https://YOUR_IP:2083"
echo "Look for 'Software → HyperSpeed Pro' in cPanel interface"
