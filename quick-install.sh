#!/bin/bash
# HyperSpeed Pro Quick Installer v2
# wget --no-cache -O /tmp/hs.sh https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh && bash /tmp/hs.sh

set -euo pipefail

RAW="https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main"
DIR="/root/hyperspeed-install"
LOG="/var/log/hyperspeed-install.log"

echo "=== HyperSpeed Pro Install v2 $(date) ===" | tee "$LOG"
echo ""

[ "$EUID" -ne 0 ] && { echo "ERROR: run as root"; exit 1; }
[ -d /usr/local/cpanel ] || { echo "ERROR: cPanel not found"; exit 1; }

# Remove previous install dir if present
[ -d "$DIR" ] && rm -rf "$DIR"
mkdir -p "$DIR"

echo "[1/4] Downloading files from raw.githubusercontent.com..."

# Download function â€” fetches from raw CDN (never github.com which stalls)
dl() {
    local f="$1"
    mkdir -p "$DIR/$(dirname "$f")"
    wget -q --no-cache --timeout=30 -O "$DIR/$f" "$RAW/$f" \
        || { echo "FAILED: $f"; exit 1; }
}

# WHM plugin
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

# cPanel plugin
dl hyperspeed-pro-cpanel/install.sh
dl hyperspeed-pro-cpanel/uninstall.sh
dl hyperspeed-pro-cpanel/cpanel-interface/index.html
dl hyperspeed-pro-cpanel/cpanel-interface/assets/dashboard.js
dl hyperspeed-pro-cpanel/cpanel-interface/assets/style.css
dl hyperspeed-pro-cpanel/lib/sync-users.php
dl hyperspeed-pro-cpanel/systemd/hyperspeed-cpanel-sync.service
dl hyperspeed-pro-cpanel/uapi/HyperSpeed.pm

echo "   All files downloaded OK"
echo ""

echo "[2/4] Installing WHM Plugin..."
cd "$DIR/hyperspeed-pro"
chmod +x install.sh
bash install.sh </dev/null 2>&1 | tee -a "$LOG"
echo ""

echo "[3/4] Installing cPanel Plugin..."
cd "$DIR/hyperspeed-pro-cpanel"
chmod +x install.sh
bash install.sh </dev/null 2>&1 | tee -a "$LOG"
echo ""

echo "[4/4] Enabling services..."
for svc in redis memcached hyperspeed-engine hyperspeed-cpanel-sync; do
    systemctl enable "$svc" 2>/dev/null && systemctl start "$svc" 2>/dev/null \
        && echo "   started: $svc" || true
done
echo ""

IP=$(hostname -I | awk '{print $1}')
echo "================================================"
echo "  Done! HyperSpeed Pro installed."
echo "  WHM:    https://$IP:2087 > Plugins > HyperSpeed Pro"
echo "  cPanel: https://$IP:2083 > Software > HyperSpeed Pro"
echo "  Log:    $LOG"
echo "================================================"