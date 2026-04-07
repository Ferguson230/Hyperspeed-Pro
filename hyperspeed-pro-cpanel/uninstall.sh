#!/bin/bash
##############################################################################
# HyperSpeed Pro - cPanel Plugin Uninstall Script
# 
# This script cleanly removes the HyperSpeed Pro cPanel user plugin
# while optionally preserving user data and settings
#
# Usage:
#   ./uninstall.sh              # Remove plugin, keep user data
#   ./uninstall.sh --purge      # Remove everything including data
#   ./uninstall.sh --help       # Show help
##############################################################################

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KEEP_DATA=1
INTERACTIVE=1

##############################################################################
# Parse command line arguments
##############################################################################
while [[ $# -gt 0 ]]; do
    case $1 in
        --purge)
            KEEP_DATA=0
            shift
            ;;
        --yes|-y)
            INTERACTIVE=0
            shift
            ;;
        --help|-h)
            echo "HyperSpeed Pro cPanel Plugin - Uninstall Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --purge          Remove all data including user settings"
            echo "  --yes, -y        Skip confirmation prompts"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Default: Removes plugin but keeps user data in Redis"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

##############################################################################
# Header
##############################################################################
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  HyperSpeed Pro cPanel Plugin - Uninstallation              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

##############################################################################
# Check if running as root
##############################################################################
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

##############################################################################
# Confirm uninstallation
##############################################################################
if [ $INTERACTIVE -eq 1 ]; then
    echo -e "${YELLOW}Warning: This will remove the HyperSpeed Pro cPanel plugin${NC}"
    if [ $KEEP_DATA -eq 1 ]; then
        echo "User data and settings will be preserved in Redis"
    else
        echo -e "${RED}ALL USER DATA WILL BE DELETED (--purge mode)${NC}"
    fi
    echo ""
    read -p "Continue with uninstallation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}Starting uninstallation...${NC}"
echo ""

##############################################################################
# Stop and disable services
##############################################################################
echo -e "${BLUE}[1/8] Stopping services...${NC}"

if systemctl is-active --quiet hyperspeed-cpanel-sync; then
    systemctl stop hyperspeed-cpanel-sync
    echo -e "${GREEN}✓${NC} Stopped HyperSpeed Sync service"
else
    echo -e "${YELLOW}⚠${NC} Sync service not running"
fi

if systemctl is-enabled --quiet hyperspeed-cpanel-sync 2>/dev/null; then
    systemctl disable hyperspeed-cpanel-sync
    echo -e "${GREEN}✓${NC} Disabled auto-start"
fi

echo ""

##############################################################################
# Remove systemd service
##############################################################################
echo -e "${BLUE}[2/8] Removing systemd service...${NC}"

if [ -f /etc/systemd/system/hyperspeed-cpanel-sync.service ]; then
    rm -f /etc/systemd/system/hyperspeed-cpanel-sync.service
    systemctl daemon-reload
    echo -e "${GREEN}✓${NC} Removed systemd service file"
else
    echo -e "${YELLOW}⚠${NC} Service file not found"
fi

echo ""

##############################################################################
# Remove UAPI module
##############################################################################
echo -e "${BLUE}[3/8] Removing UAPI module...${NC}"

if [ -f /usr/local/cpanel/Cpanel/API/HyperSpeed.pm ]; then
    rm -f /usr/local/cpanel/Cpanel/API/HyperSpeed.pm
    echo -e "${GREEN}✓${NC} Removed UAPI module"
else
    echo -e "${YELLOW}⚠${NC} UAPI module not found"
fi

echo ""

##############################################################################
# Remove cPanel interfaces
##############################################################################
echo -e "${BLUE}[4/8] Removing cPanel interfaces...${NC}"

# Paper Lantern theme
if [ -d /usr/local/cpanel/base/frontend/paper_lantern/hyperspeed ]; then
    rm -rf /usr/local/cpanel/base/frontend/paper_lantern/hyperspeed
    echo -e "${GREEN}✓${NC} Removed Paper Lantern interface"
fi

# Jupiter theme
if [ -d /usr/local/cpanel/base/frontend/jupiter/hyperspeed ]; then
    rm -rf /usr/local/cpanel/base/frontend/jupiter/hyperspeed
    echo -e "${GREEN}✓${NC} Removed Jupiter interface"
fi

# Rebuild cPanel themes
echo "  Rebuilding cPanel themes..."
/usr/local/cpanel/scripts/rebuild_sprites > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Themes rebuilt"

echo ""

##############################################################################
# Remove sync library
##############################################################################
echo -e "${BLUE}[5/8] Removing sync library...${NC}"

if [ -f /usr/local/cpanel/lib/hyperspeed_pro/sync-users.php ]; then
    rm -f /usr/local/cpanel/lib/hyperspeed_pro/sync-users.php
    echo -e "${GREEN}✓${NC} Removed sync library"
fi

# Note: Don't remove the parent directory as WHM plugin may still be installed
echo ""

##############################################################################
# Clean up logs
##############################################################################
echo -e "${BLUE}[6/8] Cleaning up logs...${NC}"

if [ -f /var/log/hyperspeed_pro/sync.log ]; then
    # Archive the log before removing
    if [ -d /var/log/hyperspeed_pro/archive ]; then
        mkdir -p /var/log/hyperspeed_pro/archive
    fi
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    mv /var/log/hyperspeed_pro/sync.log \
       /var/log/hyperspeed_pro/archive/sync_${timestamp}.log 2>/dev/null
    
    echo -e "${GREEN}✓${NC} Archived sync logs"
fi

echo ""

##############################################################################
# Remove user data (if --purge)
##############################################################################
echo -e "${BLUE}[7/8] Handling user data...${NC}"

if [ $KEEP_DATA -eq 0 ]; then
    echo "  Removing user data from Redis..."
    
    # Remove all user settings
    redis-cli --scan --pattern "hyperspeed:user:*:settings" | \
        xargs -r redis-cli DEL > /dev/null 2>&1
    
    # Remove all user security exemptions
    redis-cli --scan --pattern "hyperspeed:user:*:security_exemptions" | \
        xargs -r redis-cli DEL > /dev/null 2>&1
    
    # Remove all domain bypass rules
    redis-cli --scan --pattern "hyperspeed:domain:*:bypass_rules" | \
        xargs -r redis-cli DEL > /dev/null 2>&1
    
    # Count removed keys
    echo -e "${GREEN}✓${NC} Purged all user data from Redis"
    
else
    echo -e "${YELLOW}⚠${NC} Keeping user data in Redis (use --purge to remove)"
    
    # Count preserved keys
    user_keys=$(redis-cli --scan --pattern "hyperspeed:user:*" | wc -l)
    domain_keys=$(redis-cli --scan --pattern "hyperspeed:domain:*" | wc -l)
    
    echo "  Preserved: $user_keys user keys, $domain_keys domain keys"
fi

echo ""

##############################################################################
# Final cleanup
##############################################################################
echo -e "${BLUE}[8/8] Final cleanup...${NC}"

# Remove logrotate config if no other HyperSpeed components
if [ ! -f /usr/local/cpanel/lib/hyperspeed_pro/PerformanceEngine.php ]; then
    # WHM plugin not installed, safe to remove log config
    if [ -f /etc/logrotate.d/hyperspeed-cpanel ]; then
        rm -f /etc/logrotate.d/hyperspeed-cpanel
        echo -e "${GREEN}✓${NC} Removed logrotate configuration"
    fi
fi

# Remove installation flag
rm -f /var/cpanel/hyperspeed_cpanel_installed

echo -e "${GREEN}✓${NC} Cleanup complete"
echo ""

##############################################################################
# Summary
##############################################################################
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Uninstallation Complete                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓${NC} HyperSpeed Pro cPanel plugin has been removed"
echo ""

echo "Removed components:"
echo "  • UAPI module"
echo "  • cPanel user interface (all themes)"
echo "  • Synchronization service"
echo "  • Systemd service files"
echo "  • Log files (archived)"

if [ $KEEP_DATA -eq 1 ]; then
    echo ""
    echo "Preserved:"
    echo "  • User settings in Redis"
    echo "  • Domain bypass rules"
    echo "  • Security exemptions"
    echo "  • Performance metrics"
    echo ""
    echo "To completely remove all data, run:"
    echo "  ./uninstall.sh --purge"
fi

echo ""
echo -e "${YELLOW}Note:${NC} The WHM HyperSpeed Pro plugin is still installed"
echo "       Users will no longer have cPanel access to the plugin"
echo ""

# Check if WHM plugin should be removed too
if [ $INTERACTIVE -eq 1 ]; then
    read -p "Would you like to uninstall the WHM plugin as well? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f /root/hyperspeed-pro/uninstall.sh ]; then
            echo ""
            echo "Launching WHM plugin uninstaller..."
            cd /root/hyperspeed-pro
            ./uninstall.sh
        else
            echo -e "${RED}WHM uninstaller not found at /root/hyperspeed-pro/uninstall.sh${NC}"
        fi
    fi
fi

echo ""
echo "Uninstallation completed at $(date)"
echo ""

exit 0
