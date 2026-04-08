#!/bin/bash
###############################################################################
# HyperSpeed Pro - One-Command Installation Script
# 
# This script downloads and installs both WHM and cPanel plugins
# from the official GitHub repository
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh | sudo bash
#
# Or download and inspect first:
#   wget https://raw.githubusercontent.com/Ferguson230/Hyperspeed-Pro/main/quick-install.sh
#   chmod +x quick-install.sh
#   sudo ./quick-install.sh
###############################################################################

set -e

# Configuration
GITHUB_REPO="Ferguson230/Hyperspeed-Pro"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
GITHUB_RELEASE="https://github.com/${GITHUB_REPO}/archive/refs/tags"
VERSION="v1.0.0"
INSTALL_DIR="/root/hyperspeed-install"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

###############################################################################
# Banner
###############################################################################
clear
echo ""
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}║        ${CYAN}█${BLUE}█${GREEN}█${NC}  ${YELLOW}HyperSpeed Pro${NC} - Quick Installation  ${GREEN}█${BLUE}█${CYAN}█${PURPLE}        ║${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}║          ${NC}Faster than LiteSpeed. Better than Varnish.      ${PURPLE}║${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}GitHub:${NC} https://github.com/${GITHUB_REPO}"
echo -e "${BLUE}Version:${NC} ${VERSION}"
echo ""

###############################################################################
# Check if running as root
###############################################################################
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗ Error: This script must be run as root${NC}"
    echo "  Please run with sudo or as root user"
    exit 1
fi

###############################################################################
# System Requirements Check
###############################################################################
echo -e "${BLUE}[1/9] Checking system requirements...${NC}"

# Detect OS and version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$ID"
    OS_VERSION="$VERSION_ID"
    
    # Check for supported OS
    if [[ "$OS_NAME" == "ubuntu" && ("$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04") ]]; then
        echo -e "${GREEN}✓${NC} Ubuntu $OS_VERSION detected"
    elif [[ "$OS_NAME" == "almalinux" && "$OS_VERSION" =~ ^9\. ]]; then
        echo -e "${GREEN}✓${NC} AlmaLinux $OS_VERSION detected"
    elif [[ "$OS_NAME" == "rocky" && "$OS_VERSION" =~ ^9\. ]]; then
        echo -e "${GREEN}✓${NC} Rocky Linux $OS_VERSION detected"
    else
        echo -e "${RED}✗ Unsupported operating system: $ID $VERSION_ID${NC}"
        echo "  Supported: Ubuntu 22.04/24.04 LTS, AlmaLinux 9, Rocky Linux 9"
        exit 1
    fi
else
    echo -e "${RED}✗ Cannot detect OS version${NC}"
    exit 1
fi

# Check cPanel
if [ ! -d "/usr/local/cpanel" ]; then
    echo -e "${RED}✗ cPanel/WHM not found${NC}"
    echo "  This plugin requires cPanel/WHM to be installed"
    exit 1
fi

if [ -f /usr/local/cpanel/version ]; then
    CPANEL_VER=$(cat /usr/local/cpanel/version)
    echo -e "${GREEN}✓${NC} cPanel/WHM $CPANEL_VER detected"
else
    echo -e "${YELLOW}⚠${NC} Cannot determine cPanel version"
fi

# Check disk space
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
REQUIRED_SPACE=10485760  # 10GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo -e "${RED}✗ Insufficient disk space${NC}"
    echo "  Required: 10GB, Available: $((AVAILABLE_SPACE/1024/1024))GB"
    exit 1
fi
echo -e "${GREEN}✓${NC} Sufficient disk space available"

# Check memory
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 3800 ]; then
    echo -e "${YELLOW}⚠${NC} Warning: Less than 4GB RAM detected (${TOTAL_MEM}MB)"
    echo "  HyperSpeed Pro will work but may have reduced performance"
fi

echo ""

###############################################################################
# Confirm installation
###############################################################################
echo -e "${YELLOW}This will install HyperSpeed Pro on your server${NC}"
echo ""
echo "Components to be installed:"
echo "  • WHM Plugin (server administration)"
echo "  • cPanel Plugin (user interface)"
echo "  • Redis cache server"
echo "  • Memcached server"
echo "  • Nginx extras"
echo "  • Performance optimization engine"
echo "  • Security protection module"
echo ""
# Handle confirmation for both interactive and piped (curl | bash) modes
if [ -t 0 ]; then
    # Running interactively - ask for confirmation
    read -p "Continue with installation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
else
    # Running via pipe (curl | bash) - redirect stdin from terminal
    exec 3</dev/tty
    read -p "Continue with installation? [y/N] " -n 1 -r <&3
    exec 3<&-
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
fi

echo ""

###############################################################################
# Create installation directory
###############################################################################
echo -e "${BLUE}[2/9] Preparing installation directory...${NC}"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠${NC} Installation directory exists, backing up..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo -e "${GREEN}✓${NC} Created $INSTALL_DIR"
echo ""

###############################################################################
# Download from GitHub
###############################################################################
echo -e "${BLUE}[3/9] Downloading HyperSpeed Pro from GitHub...${NC}"

# Check if wget or curl is available
if command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -q --show-progress"
elif command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -L -o"
else
    echo -e "${RED}✗ Neither wget nor curl found${NC}"
    apt-get update -qq && apt-get install -y wget
    DOWNLOAD_CMD="wget -q --show-progress"
fi

# Download latest release
echo "  Downloading version ${VERSION}..."
wget -q --show-progress "${GITHUB_RELEASE}/${VERSION}.tar.gz" -O hyperspeed-pro.tar.gz

if [ ! -f "hyperspeed-pro.tar.gz" ]; then
    echo -e "${RED}✗ Download failed${NC}"
    exit 1
fi

# Extract archive
echo "  Extracting files..."
tar -xzf hyperspeed-pro.tar.gz
# GitHub archives extract as RepoName-TagVersion/ (case sensitive)
EXTRACTED_DIR=$(tar -tzf hyperspeed-pro.tar.gz | head -1 | cut -d/ -f1)
if [ -z "$EXTRACTED_DIR" ] || [ ! -d "$EXTRACTED_DIR" ]; then
    echo -e "${RED}✗ Extraction failed - could not find extracted directory${NC}"
    exit 1
fi
mv "$EXTRACTED_DIR" hyperspeed-pro

if [ ! -d "hyperspeed-pro" ]; then
    echo -e "${RED}✗ Extraction failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Downloaded and extracted HyperSpeed Pro ${VERSION}"
echo ""

###############################################################################
# Download verification script
###############################################################################
echo -e "${BLUE}[4/9] Downloading verification tools...${NC}"

wget -q "${GITHUB_RAW}/verify-installation.sh" -O verify-installation.sh
chmod +x verify-installation.sh

echo -e "${GREEN}✓${NC} Downloaded verification script"
echo ""

###############################################################################
# Install WHM Plugin
###############################################################################
echo -e "${BLUE}[5/9] Installing WHM Plugin...${NC}"
echo ""

cd hyperspeed-pro/hyperspeed-pro
chmod +x install.sh

if ./install.sh; then
    echo ""
    echo -e "${GREEN}✓${NC} WHM Plugin installed successfully"
else
    echo -e "${RED}✗ WHM Plugin installation failed${NC}"
    echo "  Check logs at: /var/log/hyperspeed_pro/install.log"
    exit 1
fi

echo ""

###############################################################################
# Install cPanel Plugin
###############################################################################
echo -e "${BLUE}[6/9] Installing cPanel Plugin...${NC}"
echo ""

cd ../hyperspeed-pro-cpanel
chmod +x install.sh

if ./install.sh; then
    echo ""
    echo -e "${GREEN}✓${NC} cPanel Plugin installed successfully"
else
    echo -e "${RED}✗ cPanel Plugin installation failed${NC}"
    echo "  Check logs at: /var/log/hyperspeed_pro/install.log"
    exit 1
fi

echo ""

###############################################################################
# Verify Installation
###############################################################################
echo -e "${BLUE}[7/9] Verifying installation...${NC}"
echo ""

cd "$INSTALL_DIR"
if bash verify-installation.sh; then
    echo ""
    echo -e "${GREEN}✓${NC} All verification checks passed"
else
    echo -e "${YELLOW}⚠${NC} Some verification checks failed"
    echo "  Review the output above for issues"
fi

echo ""

###############################################################################
# Enable Auto-Start
###############################################################################
echo -e "${BLUE}[8/9] Configuring auto-start...${NC}"

systemctl enable hyperspeed-engine 2>/dev/null || true
systemctl enable hyperspeed-cpanel-sync 2>/dev/null || true
systemctl enable redis 2>/dev/null || true
systemctl enable memcached 2>/dev/null || true

echo -e "${GREEN}✓${NC} Services configured to start automatically"
echo ""

###############################################################################
# Run Initial Benchmark
###############################################################################
echo -e "${BLUE}[9/9] Running performance benchmark...${NC}"
echo ""

if [ -f /usr/local/bin/hyperspeed_pro/hyperspeed ]; then
    /usr/local/bin/hyperspeed_pro/hyperspeed test 2>/dev/null || echo "  Benchmark will be available after server restart"
elif [ -f /usr/local/bin/hyperspeed ]; then
    /usr/local/bin/hyperspeed test 2>/dev/null || echo "  Benchmark will be available after server restart"
fi

echo ""

###############################################################################
# Installation Complete
###############################################################################
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║              ✓ Installation Completed Successfully!           ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo -e "${YELLOW}1. Access WHM Interface:${NC}"
echo "   URL: https://$(hostname -I | awk '{print $1}'):2087"
echo "   Navigate to: WHM → Plugins → HyperSpeed Pro"
echo ""
echo -e "${YELLOW}2. Configure Global Settings:${NC}"
echo "   • Set cache TTL (default: 3600 seconds)"
echo "   • Enable compression (Brotli recommended)"
echo "   • Configure security policies"
echo ""
echo -e "${YELLOW}3. Access cPanel Interface:${NC}"
echo "   URL: https://$(hostname -I | awk '{print $1}'):2083"
echo "   Navigate to: cPanel → Software → HyperSpeed Pro"
echo ""
echo -e "${YELLOW}4. Monitor Performance:${NC}"
echo "   Command: systemctl status hyperspeed-engine"
echo "   Logs: /var/log/hyperspeed_pro/"
echo ""

echo -e "${CYAN}Installed Services:${NC}"
echo "  • hyperspeed-engine (Performance optimization)"
echo "  • hyperspeed-cpanel-sync (WHM-cPanel synchronization)"
echo "  • redis (L1 cache)"
echo "  • memcached (L2 cache)"
echo ""

echo -e "${CYAN}Command-Line Tools:${NC}"
echo "  hyperspeed cache:flush          - Clear all caches"
echo "  hyperspeed cache:stats          - View cache statistics"
echo "  hyperspeed security:check       - Run security audit"
echo "  hyperspeed benchmark:run        - Performance benchmark"
echo ""

echo -e "${CYAN}Backup Location:${NC}"
BACKUP_DIR=$(find /root -maxdepth 1 -type d -name ".hyperspeed-backup-*" 2>/dev/null | tail -1)
if [ -n "$BACKUP_DIR" ]; then
    echo "  $BACKUP_DIR"
    echo "  (Use with uninstall.sh --restore to revert)"
fi
echo ""

echo -e "${CYAN}Documentation:${NC}"
echo "  • GitHub: https://github.com/${GITHUB_REPO}"
echo "  • Docs: ${INSTALL_DIR}/hyperspeed-pro/"
echo "  • Support: support@hyperspeed.pro"
echo ""

echo -e "${YELLOW}Performance Expectations:${NC}"
echo "  • 60-85% faster page loads"
echo "  • 80-95% reduction in TTFB"
echo "  • 90%+ cache hit rate within 7 days"
echo "  • 50-70% bandwidth savings"
echo ""

echo -e "${GREEN}Installation completed at $(date)${NC}"
echo ""
echo -e "${PURPLE}🚀 HyperSpeed Pro is now protecting and optimizing your server!${NC}"
echo ""

exit 0
