#!/bin/bash
#
# HyperSpeed Pro - cPanel User Plugin Installation
# This installs the user-level interface for individual cPanel accounts
# Compatible with Ubuntu 22.04/24.04 and AlmaLinux 9
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# OS Detection variables
OS_TYPE=""
OS_VERSION=""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}HyperSpeed Pro - cPanel User Plugin${NC}"
echo -e "${GREEN}Installation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Detect OS type and version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE="$ID"
    OS_VERSION="$VERSION_ID"
    
    if [[ "$ID" == "ubuntu" && "$VERSION_ID" =~ ^(22|24)\. ]]; then
        echo -e "${GREEN}✓ Ubuntu $VERSION_ID detected${NC}"
    elif [[ "$ID" == "almalinux" && "$VERSION_ID" =~ ^9\. ]]; then
        echo -e "${GREEN}✓ AlmaLinux $VERSION_ID detected${NC}"
    elif [[ "$ID" == "rocky" && "$VERSION_ID" =~ ^9\. ]]; then
        echo -e "${GREEN}✓ Rocky Linux $VERSION_ID detected${NC}"
    else
        echo -e "${YELLOW}Warning: Detected $ID $VERSION_ID (proceeding with installation)${NC}"
    fi
fi

# Check if WHM plugin is installed
if [ ! -d "/usr/local/cpanel/lib/hyperspeed_pro" ]; then
    echo -e "${RED}Error: HyperSpeed Pro WHM plugin must be installed first${NC}"
    echo "Please install the WHM plugin before installing the cPanel user plugin."
    exit 1
fi

echo -e "${YELLOW}Installing cPanel user interface...${NC}"

# Directories
CPANEL_BASE="/usr/local/cpanel"
PLUGIN_DIR="${CPANEL_BASE}/base/frontend/paper_lantern/hyperspeed"
API_DIR="${CPANEL_BASE}/Cpanel/API/HyperSpeed"
UAPI_DIR="${CPANEL_BASE}/Cpanel/API"
SCRIPTS_DIR="${CPANEL_BASE}/scripts"

# Create directories
mkdir -p "${PLUGIN_DIR}"
mkdir -p "${PLUGIN_DIR}/assets"
mkdir -p "${API_DIR}"

echo -e "${YELLOW}Copying plugin files...${NC}"

# Copy interface files
if [ -d "./cpanel-interface" ]; then
    cp -r ./cpanel-interface/* "${PLUGIN_DIR}/"
fi

# Copy API modules
if [ -d "./cpanel-api" ]; then
    cp -r ./cpanel-api/* "${API_DIR}/"
fi

# Copy UAPI module
if [ -f "./uapi/HyperSpeed.pm" ]; then
    cp ./uapi/HyperSpeed.pm "${UAPI_DIR}/"
fi

# Set permissions
chmod 755 "${PLUGIN_DIR}"
find "${PLUGIN_DIR}" -name "*.html" -exec chmod 644 {} \; 2>/dev/null || true
find "${PLUGIN_DIR}/assets" -type f -exec chmod 644 {} \; 2>/dev/null || true
chmod 755 "${API_DIR}"
find "${API_DIR}" -name "*.pm" -exec chmod 644 {} \; 2>/dev/null || true
if [ -f "${UAPI_DIR}/HyperSpeed.pm" ]; then
    chmod 644 "${UAPI_DIR}/HyperSpeed.pm"
fi

echo -e "${GREEN}✓ Plugin files installed${NC}"

# Register with cPanel
echo -e "${YELLOW}Registering with cPanel...${NC}"

# Install dynamicui configuration
DYNAMICUI_DIR="${CPANEL_BASE}/etc/cpanel/dynamicui"
mkdir -p "${DYNAMICUI_DIR}"
cat > "${DYNAMICUI_DIR}/hyperspeed.conf" << 'EOF'
---
name: HyperSpeed Pro
url: hyperspeed/index.html
icon: hyperspeed-icon.svg
description: Advanced Performance Optimization & Caching
group: software
order: 10
version: 1.0.0
EOF

echo -e "${GREEN}✓ Registered with cPanel${NC}"

# Create user data directory structure
echo -e "${YELLOW}Creating user data structure...${NC}"

mkdir -p /var/cpanel/hyperspeed_pro
chmod 755 /var/cpanel/hyperspeed_pro

echo -e "${GREEN}✓ Data structure created${NC}"

# Rebuild cPanel themes
echo -e "${YELLOW}Rebuilding cPanel themes...${NC}"

/usr/local/cpanel/bin/rebuild_sprites > /dev/null 2>&1 || true
/usr/local/cpanel/scripts/rebuildhttpdconf > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Themes rebuilt${NC}"

# Create sync service
echo -e "${YELLOW}Installing sync service...${NC}"

cat > /etc/systemd/system/hyperspeed-cpanel-sync.service << 'EOF'
[Unit]
Description=HyperSpeed Pro cPanel-WHM Sync Service
After=network.target hyperspeed-engine.service

[Service]
Type=simple
ExecStart=/usr/local/cpanel/scripts/hyperspeed-sync
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create sync script
cat > /usr/local/cpanel/scripts/hyperspeed-sync << 'EOFSCRIPT'
#!/bin/bash
# Sync cPanel user settings with WHM master settings
# Use cPanel's managed PHP if available, fall back to system PHP
PHP_BIN=""
for p in /usr/local/cpanel/3rdparty/bin/php /opt/cpanel/ea-php*/root/usr/bin/php /usr/bin/php; do
    if [ -x "$p" ]; then
        PHP_BIN="$p"
        break
    fi
done

if [ -z "$PHP_BIN" ]; then
    echo "No PHP binary found" >> /var/log/hyperspeed_pro/sync.log
    exit 1
fi

while true; do
    "$PHP_BIN" /usr/local/cpanel/lib/hyperspeed_pro/sync-users.php >> /var/log/hyperspeed_pro/sync.log 2>&1 || true
    sleep 60
done
EOFSCRIPT

chmod +x /usr/local/cpanel/scripts/hyperspeed-sync

systemctl daemon-reload
systemctl enable hyperspeed-cpanel-sync.service >> /var/log/hyperspeed_pro/install.log 2>&1 || true
systemctl start hyperspeed-cpanel-sync.service >> /var/log/hyperspeed_pro/install.log 2>&1 || \
    echo -e "${YELLOW}⚠ Sync service will start automatically on next boot${NC}"

echo -e "${GREEN}✓ Sync service installed${NC}"

# Final message
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "cPanel User Plugin installed successfully on ${GREEN}${OS_TYPE} ${OS_VERSION}${NC}."
echo ""
echo -e "cPanel users can now access HyperSpeed Pro from:"
echo -e "${YELLOW}cPanel → Software → HyperSpeed Pro${NC}"
echo ""
echo ""
echo -e "Features available to users:"
echo -e "  ✓ Per-domain cache management"
echo -e "  ✓ Performance analytics"
echo -e "  ✓ Custom bypass rules"
echo -e "  ✓ Security settings"
echo -e "  ✓ Resource monitoring"
echo ""
echo -e "Sync service status: ${GREEN}$(systemctl is-active hyperspeed-cpanel-sync)${NC}"
echo ""

exit 0
