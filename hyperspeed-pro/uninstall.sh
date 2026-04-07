#!/bin/bash
#
# HyperSpeed Pro - Uninstallation Script
# Compatible with cPanel & WHM on Ubuntu 22.04 and 24.04
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directories
PLUGIN_NAME="hyperspeed_pro"
BASE_DIR="/usr/local/cpanel"
PLUGIN_DIR="${BASE_DIR}/whostmgr/docroot/cgi/${PLUGIN_NAME}"
ADDON_DIR="${BASE_DIR}/whostmgr/docroot/addon_plugins"
LIB_DIR="${BASE_DIR}/lib/${PLUGIN_NAME}"
BIN_DIR="/usr/local/bin/${PLUGIN_NAME}"
CONFIG_DIR="/etc/${PLUGIN_NAME}"
CACHE_DIR="/var/cache/${PLUGIN_NAME}"
LOG_DIR="/var/log/${PLUGIN_NAME}"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}HyperSpeed Pro Uninstallation${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Confirmation
read -p "Are you sure you want to uninstall HyperSpeed Pro? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo -e "${YELLOW}Stopping HyperSpeed service...${NC}"
systemctl stop hyperspeed-engine.service > /dev/null 2>&1 || true
systemctl disable hyperspeed-engine.service > /dev/null 2>&1 || true
rm -f /etc/systemd/system/hyperspeed-engine.service
systemctl daemon-reload
echo -e "${GREEN}✓ Service stopped${NC}"

echo -e "${YELLOW}Unregistering from AppConfig...${NC}"
/usr/local/cpanel/bin/unregister_appconfig "${PLUGIN_NAME}" > /dev/null 2>&1 || true
echo -e "${GREEN}✓ AppConfig unregistered${NC}"

echo -e "${YELLOW}Removing plugin files...${NC}"
rm -rf "${PLUGIN_DIR}"
rm -rf "${LIB_DIR}"
rm -rf "${BIN_DIR}"
rm -f "${ADDON_DIR}/hyperspeed-icon.png"
echo -e "${GREEN}✓ Plugin files removed${NC}"

echo -e "${YELLOW}Removing configuration...${NC}"
read -p "Remove configuration files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "${CONFIG_DIR}"
    echo -e "${GREEN}✓ Configuration removed${NC}"
else
    echo -e "${YELLOW}Configuration preserved at ${CONFIG_DIR}${NC}"
fi

echo -e "${YELLOW}Removing cache...${NC}"
rm -rf "${CACHE_DIR}"
echo -e "${GREEN}✓ Cache cleared${NC}"

echo -e "${YELLOW}Removing logs...${NC}"
read -p "Remove log files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "${LOG_DIR}"
    rm -f /etc/logrotate.d/hyperspeed-pro
    echo -e "${GREEN}✓ Logs removed${NC}"
else
    echo -e "${YELLOW}Logs preserved at ${LOG_DIR}${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Uninstallation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "HyperSpeed Pro has been removed from your system."
echo ""

exit 0
