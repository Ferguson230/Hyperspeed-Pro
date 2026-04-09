#!/bin/bash
# HyperSpeed Pro Quick Installer
# Usage: wget --no-cache -O /tmp/hs.sh https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh && bash /tmp/hs.sh

RAW="https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main"
DIR="/root/hyperspeed-install"
LOG="/var/log/hyperspeed-install.log"

echo "================================================"
echo "  HyperSpeed Pro Quick Install"
echo "  Started: $(date)"
echo "================================================"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must be run as root"
    exit 1
fi

if [ ! -d /usr/local/cpanel ]; then
    echo "ERROR: cPanel not found at /usr/local/cpanel"
    exit 1
fi

# Start log (fall back to /tmp if /var/log not writable)
touch "$LOG" 2>/dev/null || LOG="/tmp/hyperspeed-install.log"
echo "Log: $LOG"
echo ""

# Clean previous download dir
rm -rf "$DIR"
mkdir -p "$DIR"

echo "[1/4] Downloading files..."

dl() {
    local f="$1"
    mkdir -p "$DIR/$(dirname "$f")"
    if ! wget -q --no-cache --timeout=30 -O "$DIR/$f" "$RAW/$f"; then
        echo "  ERROR: failed to download $f"
        exit 1
    fi
}

# WHM plugin files
dl hyperspeed-pro/install.sh
dl hyperspeed-pro/uninstall.sh
dl hyperspeed-pro/appconfig.conf
dl hyperspeed-pro/plugin.conf
dl hyperspeed-pro/assets/dashboard.js
dl hyperspeed-pro/assets/style.css
dl hyperspeed-pro/assets/hyperspeed-icon.txt
dl hyperspeed-pro/bin/hyperspeed
dl hyperspeed-pro/bin/benchmark.sh
dl hyperspeed-pro/cgi/index.cgi
dl hyperspeed-pro/config/nginx-hyperspeed.conf
dl hyperspeed-pro/lib/PerformanceEngine.php
dl hyperspeed-pro/lib/SecurityEngine.php
dl hyperspeed-pro/systemd/hyperspeed-engine.service

# cPanel plugin files
dl hyperspeed-pro-cpanel/install.sh
dl hyperspeed-pro-cpanel/uninstall.sh
dl hyperspeed-pro-cpanel/cpanel-interface/index.html
dl hyperspeed-pro-cpanel/cpanel-interface/assets/dashboard.js
dl hyperspeed-pro-cpanel/cpanel-interface/assets/style.css
dl hyperspeed-pro-cpanel/lib/sync-users.php
dl hyperspeed-pro-cpanel/systemd/hyperspeed-cpanel-sync.service
dl hyperspeed-pro-cpanel/uapi/HyperSpeed.pm

echo "  All files downloaded OK"
echo ""

echo "[2/4] Installing WHM plugin..."
cd "$DIR/hyperspeed-pro"
chmod +x install.sh
bash install.sh </dev/null 2>&1 | tee -a "$LOG"
echo ""

echo "[3/4] Installing cPanel plugin..."
cd "$DIR/hyperspeed-pro-cpanel"
chmod +x install.sh
bash install.sh </dev/null 2>&1 | tee -a "$LOG"
echo ""

echo "[4/4] Enabling services..."
for svc in redis memcached hyperspeed-engine hyperspeed-cpanel-sync; do
    systemctl enable "$svc" 2>/dev/null
    systemctl start "$svc" 2>/dev/null
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "  started: $svc"
    fi
done
echo ""

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "================================================"
echo "  Installation complete!"
echo "  WHM:    https://$IP:2087  > Plugins > HyperSpeed Pro"
echo "  cPanel: https://$IP:2083  > Software > HyperSpeed Pro"
echo "  Log:    $LOG"
echo "================================================"