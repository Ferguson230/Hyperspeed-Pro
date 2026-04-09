#!/bin/bash
###############################################################################
# HyperSpeed Pro - Quick Installation Script
#
#   curl -sSL https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh | sudo bash
#
# Or:
#   wget -O /tmp/hs-install.sh https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh && bash /tmp/hs-install.sh
###############################################################################

GITHUB_REPO="Ferguson230/Hyperspeed-Pro"
INSTALL_DIR="/root/hyperspeed-install"
LOG="/var/log/hyperspeed-install.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
info() { echo -e "${BLUE}[..]${NC}  $*"; }
warn() { echo -e "${YELLOW}[!!]${NC}  $*"; }
die()  { echo -e "${RED}[FAIL]${NC} $*"; echo "Full log: $LOG"; exit 1; }

mkdir -p /var/log
echo "=== HyperSpeed Pro Install $(date) ===" > "$LOG"

###############################################################################
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  HyperSpeed Pro Quick Installer${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

[ "$EUID" -ne 0 ] && die "Must be run as root"

###############################################################################
info "Checking system..."
[ -f /etc/os-release ] || die "Cannot detect OS"
. /etc/os-release
echo "OS: $ID $VERSION_ID" >> "$LOG"

case "$ID" in
  ubuntu)
    [[ "$VERSION_ID" == "22.04" || "$VERSION_ID" == "24.04" ]] \
      || die "Ubuntu $VERSION_ID not supported (need 22.04 or 24.04)"
    PKG_MGR="apt-get" ;;
  almalinux|rocky)
    [[ "$VERSION_ID" =~ ^9\. ]] \
      || die "$ID $VERSION_ID not supported (need 9.x)"
    PKG_MGR="dnf" ;;
  *)
    warn "Untested OS $ID $VERSION_ID — proceeding"
    PKG_MGR="dnf" ;;
esac

[ -d /usr/local/cpanel ] || die "cPanel not found at /usr/local/cpanel"
CPANEL_VER=$(cat /usr/local/cpanel/version 2>/dev/null || echo "?")
ok "$ID $VERSION_ID | cPanel $CPANEL_VER"
echo ""

###############################################################################
info "Preparing $INSTALL_DIR ..."
[ -d "$INSTALL_DIR" ] && mv "$INSTALL_DIR" "${INSTALL_DIR}.bak.$(date +%s)"
mkdir -p "$INSTALL_DIR" || die "Cannot create $INSTALL_DIR"
cd "$INSTALL_DIR"       || die "Cannot cd to $INSTALL_DIR"
ok "Ready"
echo ""

###############################################################################
info "Downloading files from GitHub..."
RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# Download one file: fetch $1 (repo-relative path) into $INSTALL_DIR/$1
dl() {
    local path="$1"
    local dest="$INSTALL_DIR/$path"
    mkdir -p "$(dirname "$dest")"
    wget -q --timeout=30 -O "$dest" "${RAW}/${path}" >> "$LOG" 2>&1 \
        || die "Failed to download: $path"
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

ok "All files downloaded"
echo ""

###############################################################################
run_installer() {
    local label="$1" dir="$2"
    info "Installing $label..."
    [ -d "$dir" ] || die "$label directory not found: $dir"
    cd "$dir"
    chmod +x install.sh

    # Run with stdin closed (/dev/null) so no prompt can hang the script.
    # Output goes directly to log; progress shown by spinner.
    bash install.sh </dev/null >> "$LOG" 2>&1 &
    local pid=$! spin=0
    local chars=('|' '/' '-' '\\')
    while kill -0 $pid 2>/dev/null; do
        printf "\r  %s  Installing %s (this may take 2-3 min)..." "${chars[$((spin % 4))]}" "$label"
        spin=$((spin+1)); sleep 1
    done
    printf "\r%-60s\r" " "   # clear spinner line
    wait $pid
    local rc=$?
    [ $rc -eq 0 ] && ok "$label installed" || die "$label install.sh failed (exit $rc) — see $LOG"
    echo ""
}

run_installer "WHM Plugin"    "$INSTALL_DIR/hyperspeed-pro"
run_installer "cPanel Plugin" "$INSTALL_DIR/hyperspeed-pro-cpanel"

###############################################################################
info "Enabling services..."
for svc in redis memcached hyperspeed-engine hyperspeed-cpanel-sync; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
        systemctl enable "$svc" >> "$LOG" 2>&1 \
          && systemctl start "$svc" >> "$LOG" 2>&1 \
          && ok "  $svc" \
          || warn "  $svc could not start (check $LOG)"
    fi
done
echo ""

###############################################################################
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  HyperSpeed Pro installed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "  WHM   : https://${SERVER_IP}:2087  > Plugins > HyperSpeed Pro"
echo -e "  cPanel: https://${SERVER_IP}:2083  > Software > HyperSpeed Pro"
echo -e "  Log   : $LOG"
echo ""
exit 0
