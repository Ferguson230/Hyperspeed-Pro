#!/bin/bash
###############################################################################
# HyperSpeed Pro - One-Command Installation Script
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh | sudo bash
#
# Or download and inspect first:
#   wget -O quick-install.sh https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh
#   chmod +x quick-install.sh
#   sudo ./quick-install.sh
###############################################################################

# Do NOT use set -e — we handle every error explicitly so nothing fails silently.
# Log file is open from the very first line so every error is captured.

GITHUB_REPO="Ferguson230/Hyperspeed-Pro"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
GITHUB_ARCHIVE="https://github.com/${GITHUB_REPO}/archive/refs/heads/main.tar.gz"
HS_VERSION="v1.0.0"
INSTALL_DIR="/root/hyperspeed-install"
LOG="/var/log/hyperspeed-quick-install.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure log directory exists before anything else
mkdir -p /var/log
exec > >(tee -a "$LOG") 2>&1
echo "=== HyperSpeed Pro Quick Install - $(date) ===" >> "$LOG"

# Trap ANY unexpected exit and print the line number
trap 'code=$?; if [ $code -ne 0 ]; then echo -e "\n${RED}ERROR: script exited unexpectedly at line $LINENO (exit code $code)${NC}"; echo "Full log: $LOG"; fi' EXIT

###############################################################################
# Root check
###############################################################################
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: must be run as root (use sudo)${NC}"
    exit 1
fi

###############################################################################
# Banner
###############################################################################
echo ""
echo -e "${PURPLE}==========================================================${NC}"
echo -e "${PURPLE}   HyperSpeed Pro - Quick Installation  v${HS_VERSION}${NC}"
echo -e "${PURPLE}   Faster than LiteSpeed. Better than Varnish.${NC}"
echo -e "${PURPLE}==========================================================${NC}"
echo ""
echo -e "${BLUE}GitHub :${NC} https://github.com/${GITHUB_REPO}"
echo -e "${BLUE}Log    :${NC} $LOG"
echo ""

###############################################################################
# [1/7] System checks
###############################################################################
echo -e "${BLUE}[1/7] System checks...${NC}"

if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Cannot detect OS — /etc/os-release missing${NC}"; exit 1
fi
. /etc/os-release
OS_NAME="$ID"; OS_VERSION="$VERSION_ID"
case "$OS_NAME" in
    ubuntu)
        if [[ "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ]]; then
            echo -e "${GREEN}OK${NC} Ubuntu $OS_VERSION"
            PKG_MGR="apt-get"
        else
            echo -e "${RED}Unsupported Ubuntu version $OS_VERSION (need 22.04 or 24.04)${NC}"; exit 1
        fi ;;
    almalinux|rocky)
        if [[ "$OS_VERSION" =~ ^9\. ]]; then
            echo -e "${GREEN}OK${NC} $OS_NAME $OS_VERSION"
            PKG_MGR="dnf"
        else
            echo -e "${RED}Unsupported $OS_NAME version $OS_VERSION (need 9.x)${NC}"; exit 1
        fi ;;
    *)
        echo -e "${YELLOW}Warning: untested OS ($OS_NAME $OS_VERSION) — continuing${NC}"
        PKG_MGR="dnf" ;;
esac

if [ ! -d /usr/local/cpanel ]; then
    echo -e "${RED}cPanel/WHM not found at /usr/local/cpanel${NC}"; exit 1
fi
CPANEL_VER=$(cat /usr/local/cpanel/version 2>/dev/null || echo "unknown")
echo -e "${GREEN}OK${NC} cPanel $CPANEL_VER"

FREE_KB=$(df / | awk 'NR==2{print $4}')
echo -e "${GREEN}OK${NC} Disk free: $((FREE_KB/1024)) MB"

RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
echo -e "${GREEN}OK${NC} RAM: ${RAM_MB} MB"
echo ""

###############################################################################
# Confirm
###############################################################################
echo -e "${YELLOW}Installing:${NC} WHM Plugin, cPanel Plugin, Redis, Memcached, performance engine"
echo ""

###############################################################################
# [2/7] Prepare directory
###############################################################################
echo -e "${BLUE}[2/7] Preparing install directory...${NC}"

if [ -d "$INSTALL_DIR" ]; then
    BACKUP="${INSTALL_DIR}.bak.$(date +%Y%m%d_%H%M%S)"
    echo "  Existing dir found — moving to $BACKUP"
    mv "$INSTALL_DIR" "$BACKUP" || { echo -e "${RED}Cannot move $INSTALL_DIR — check permissions${NC}"; exit 1; }
fi

mkdir -p "$INSTALL_DIR" || { echo -e "${RED}Cannot create $INSTALL_DIR${NC}"; exit 1; }
cd "$INSTALL_DIR"       || { echo -e "${RED}Cannot cd to $INSTALL_DIR${NC}"; exit 1; }
echo -e "${GREEN}OK${NC} $INSTALL_DIR"
echo ""

###############################################################################
# [3/7] Download
###############################################################################
echo -e "${BLUE}[3/7] Downloading from GitHub...${NC}"

if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
    echo "  Installing wget..."
    $PKG_MGR install -y wget
fi

if command -v wget &>/dev/null; then
    wget --show-progress -O hyperspeed-pro.tar.gz "$GITHUB_ARCHIVE" \
        || { echo -e "${RED}wget download failed${NC}"; exit 1; }
else
    curl -L --progress-bar -o hyperspeed-pro.tar.gz "$GITHUB_ARCHIVE" \
        || { echo -e "${RED}curl download failed${NC}"; exit 1; }
fi

if [ ! -s hyperspeed-pro.tar.gz ]; then
    echo -e "${RED}Downloaded file is empty — check internet / firewall${NC}"; exit 1
fi

echo "  Extracting..."
tar -xzf hyperspeed-pro.tar.gz || { echo -e "${RED}tar extraction failed${NC}"; exit 1; }

# GitHub names the directory RepoName-branch (e.g. Hyperspeed-Pro-main)
EXTRACTED=$(find "$INSTALL_DIR" -maxdepth 1 -mindepth 1 -type d | grep -v '\.bak\.' | head -1)
if [ -z "$EXTRACTED" ] || [ ! -d "$EXTRACTED" ]; then
    echo -e "${RED}Could not find extracted directory in $INSTALL_DIR${NC}"
    ls -la "$INSTALL_DIR"
    exit 1
fi
echo "  Extracted: $EXTRACTED"
[ "$EXTRACTED" != "$INSTALL_DIR/hyperspeed-pro" ] && mv "$EXTRACTED" "$INSTALL_DIR/hyperspeed-pro"
echo -e "${GREEN}OK${NC} Source ready"
echo ""

###############################################################################
# [4/7] Install WHM Plugin
###############################################################################
echo -e "${BLUE}[4/7] Installing WHM Plugin...${NC}"

WHM_DIR="$INSTALL_DIR/hyperspeed-pro/hyperspeed-pro"
if [ ! -d "$WHM_DIR" ]; then
    echo -e "${RED}WHM plugin directory not found: $WHM_DIR${NC}"
    echo "  Contents of $INSTALL_DIR/hyperspeed-pro:"
    ls -la "$INSTALL_DIR/hyperspeed-pro/" 2>/dev/null || echo "  (empty)"
    exit 1
fi

cd "$WHM_DIR"
chmod +x install.sh
echo "  Running install.sh from $(pwd)"
echo "  (full output in $LOG)"
echo ""

if bash install.sh; then
    echo -e "${GREEN}OK${NC} WHM Plugin installed"
else
    echo -e "${RED}WHM Plugin install.sh failed (exit $?)${NC}"
    echo "  Check: $LOG  and  /var/log/hyperspeed_pro/install.log"
    exit 1
fi
echo ""

###############################################################################
# [5/7] Install cPanel Plugin
###############################################################################
echo -e "${BLUE}[5/7] Installing cPanel Plugin...${NC}"

CPANEL_DIR="$INSTALL_DIR/hyperspeed-pro/hyperspeed-pro-cpanel"
if [ ! -d "$CPANEL_DIR" ]; then
    echo -e "${RED}cPanel plugin directory not found: $CPANEL_DIR${NC}"
    ls -la "$INSTALL_DIR/hyperspeed-pro/" 2>/dev/null
    exit 1
fi

cd "$CPANEL_DIR"
chmod +x install.sh
echo "  Running install.sh from $(pwd)"
echo ""

if bash install.sh; then
    echo -e "${GREEN}OK${NC} cPanel Plugin installed"
else
    echo -e "${RED}cPanel Plugin install.sh failed (exit $?)${NC}"
    echo "  Check: $LOG"
    exit 1
fi
echo ""

###############################################################################
# [6/7] Enable services
###############################################################################
echo -e "${BLUE}[6/7] Enabling services...${NC}"

for svc in redis memcached hyperspeed-engine hyperspeed-cpanel-sync; do
    if systemctl list-unit-files --no-pager 2>/dev/null | grep -q "^${svc}\.service"; then
        systemctl enable "$svc" 2>/dev/null && echo -e "  ${GREEN}enabled${NC} $svc" || echo "  (could not enable $svc)"
        systemctl start  "$svc" 2>/dev/null && echo -e "  ${GREEN}started${NC} $svc" || echo "  (could not start $svc)"
    fi
done
echo ""

###############################################################################
# [7/7] Verify
###############################################################################
echo -e "${BLUE}[7/7] Verifying installation...${NC}"

cd "$INSTALL_DIR"
if [ -f "$INSTALL_DIR/hyperspeed-pro/verify-installation.sh" ]; then
    bash "$INSTALL_DIR/hyperspeed-pro/verify-installation.sh" || true
elif command -v wget &>/dev/null; then
    wget -q "${GITHUB_RAW}/verify-installation.sh" -O verify-installation.sh \
        && bash verify-installation.sh || true
fi
echo ""

###############################################################################
# Done
###############################################################################
trap - EXIT   # clear error trap — we succeeded

echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}   HyperSpeed Pro installed successfully!${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "${CYAN}WHM Plugin :${NC} https://${SERVER_IP}:2087  -> Plugins -> HyperSpeed Pro"
echo -e "${CYAN}cPanel     :${NC} https://${SERVER_IP}:2083  -> Software -> HyperSpeed Pro"
echo -e "${CYAN}Logs       :${NC} $LOG"
echo -e "${CYAN}Docs       :${NC} https://github.com/${GITHUB_REPO}"
echo ""
echo -e "${GREEN}Done at $(date)${NC}"
exit 0
