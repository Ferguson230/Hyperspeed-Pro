#!/bin/bash
##############################################################################
# HyperSpeed Pro - Installation Verification Script
# 
# This script verifies both WHM and cPanel plugins are properly installed
# Run as: bash verify-installation.sh
##############################################################################

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      HyperSpeed Pro - Installation Verification             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Track status
errors=0
warnings=0

##############################################################################
# Function to check status
##############################################################################
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        ((errors++))
    fi
}

check_warning() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${YELLOW}⚠${NC} $2"
        ((warnings++))
    fi
}

##############################################################################
# 1. System Requirements
##############################################################################
echo -e "${BLUE}[1/8] Checking System Requirements...${NC}"

# Supported OS check (Ubuntu, AlmaLinux, Rocky Linux)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" && ("$VERSION_ID" == "22.04" || "$VERSION_ID" == "24.04") ]]; then
        check_status 0 "Ubuntu $VERSION_ID detected"
    elif [[ "$ID" == "almalinux" && "$VERSION_ID" =~ ^9\. ]]; then
        check_status 0 "AlmaLinux $VERSION_ID detected"
    elif [[ "$ID" == "rocky" && "$VERSION_ID" =~ ^9\. ]]; then
        check_status 0 "Rocky Linux $VERSION_ID detected"
    else
        check_status 1 "Unsupported OS: $ID $VERSION_ID (supported: Ubuntu 22.04/24.04, AlmaLinux 9, Rocky Linux 9)"
    fi
else
    check_status 1 "Cannot detect operating system"
fi

# cPanel version
if [ -f /usr/local/cpanel/version ]; then
    cpanel_version=$(cat /usr/local/cpanel/version)
    echo -e "  ${GREEN}→${NC} cPanel version: $cpanel_version"
    check_status 0 "cPanel is installed"
else
    check_status 1 "cPanel not found"
fi

echo ""

##############################################################################
# 2. WHM Plugin Files
##############################################################################
echo -e "${BLUE}[2/8] Checking WHM Plugin Installation...${NC}"

# Check WHM plugin directory
if [ -d "/usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed_pro" ]; then
    check_status 0 "WHM plugin directory exists"
else
    check_status 1 "WHM plugin directory not found (/usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed_pro)"  
fi

# Check key WHM files
files=(
    "/usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed_pro/index.cgi"
    "/usr/local/cpanel/lib/hyperspeed_pro/PerformanceEngine.php"
    "/usr/local/cpanel/lib/hyperspeed_pro/SecurityEngine.php"
    "/etc/hyperspeed_pro/hyperspeed.conf"
    "/usr/local/bin/hyperspeed"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        check_status 0 "Found: $(basename $file)"
    else
        check_status 1 "Missing: $(basename $file)"
    fi
done

echo ""

##############################################################################
# 3. cPanel Plugin Files
##############################################################################
echo -e "${BLUE}[3/8] Checking cPanel Plugin Installation...${NC}"

# Check UAPI module
if [ -f "/usr/local/cpanel/Cpanel/API/HyperSpeed.pm" ]; then
    check_status 0 "UAPI module installed"
else
    check_status 1 "UAPI module not found"
fi

# Check cPanel interface in Paper Lantern AND Jupiter themes
if [ -d "/usr/local/cpanel/base/frontend/paper_lantern/hyperspeed" ]; then
    check_status 0 "cPanel interface (Paper Lantern) installed"
else
    check_status 1 "cPanel interface (Paper Lantern) not found"
fi

if [ -d "/usr/local/cpanel/base/frontend/jupiter/hyperspeed" ]; then
    check_status 0 "cPanel interface (Jupiter theme) installed"
else
    check_status 1 "cPanel interface (Jupiter theme) not found — users may not see plugin"
fi

# Check interface files (check Jupiter primary, fall back to paper_lantern)
for theme in jupiter paper_lantern; do
    theme_dir="/usr/local/cpanel/base/frontend/${theme}/hyperspeed"
    if [ -d "$theme_dir" ]; then
        interface_files=(
            "${theme_dir}/index.html"
            "${theme_dir}/assets/dashboard.js"
            "${theme_dir}/assets/style.css"
        )
        for file in "${interface_files[@]}"; do
            if [ -f "$file" ]; then
                check_status 0 "Found: $(basename $file) [${theme}]"
            else
                check_status 1 "Missing: $(basename $file) [${theme}]"
            fi
        done
        break  # only check first found theme
    fi
done

echo ""

##############################################################################
# 4. Dependencies
##############################################################################
echo -e "${BLUE}[4/8] Checking Dependencies...${NC}"

# Redis
if systemctl is-active --quiet redis || systemctl is-active --quiet redis-server; then
    check_status 0 "Redis is running"
    redis_version=$(redis-cli --version | awk '{print $2}')
    echo -e "  ${GREEN}→${NC} Redis version: $redis_version"
else
    check_status 1 "Redis is not running"
fi

# Memcached
if systemctl is-active --quiet memcached; then
    check_status 0 "Memcached is running"
else
    check_status 1 "Memcached is not running"
fi

# Nginx
if command -v nginx &> /dev/null; then
    check_status 0 "Nginx is installed"
    nginx_version=$(nginx -v 2>&1 | awk -F/ '{print $2}')
    echo -e "  ${GREEN}→${NC} Nginx version: $nginx_version"
else
    check_status 1 "Nginx is not installed"
fi

# PHP
if command -v php &> /dev/null; then
    check_status 0 "PHP is installed"
    php_version=$(php -v | head -n 1 | awk '{print $2}')
    echo -e "  ${GREEN}→${NC} PHP version: $php_version"
else
    check_status 1 "PHP is not installed"
fi

# PHP Redis extension
if php -m | grep -q redis; then
    check_status 0 "PHP Redis extension loaded"
else
    check_status 1 "PHP Redis extension not found"
fi

# PHP Memcached extension
if php -m | grep -q memcached; then
    check_status 0 "PHP Memcached extension loaded"
else
    check_warning 1 "PHP Memcached extension not found (optional)"
fi

echo ""

##############################################################################
# 5. Services
##############################################################################
echo -e "${BLUE}[5/8] Checking System Services...${NC}"

# HyperSpeed Engine Service
if systemctl is-active --quiet hyperspeed-engine; then
    check_status 0 "HyperSpeed Engine service is running"
else
    check_status 1 "HyperSpeed Engine service is not running"
fi

# HyperSpeed cPanel Sync Service
if systemctl is-active --quiet hyperspeed-cpanel-sync; then
    check_status 0 "HyperSpeed Sync service is running"
else
    check_status 1 "HyperSpeed Sync service is not running"
fi

# Check if services are enabled
if systemctl is-enabled --quiet hyperspeed-engine; then
    check_status 0 "HyperSpeed Engine auto-start enabled"
else
    check_warning 1 "HyperSpeed Engine auto-start not enabled"
fi

if systemctl is-enabled --quiet hyperspeed-cpanel-sync; then
    check_status 0 "HyperSpeed Sync auto-start enabled"
else
    check_warning 1 "HyperSpeed Sync auto-start not enabled"
fi

echo ""

##############################################################################
# 6. Redis Connectivity
##############################################################################
echo -e "${BLUE}[6/8] Testing Redis Connectivity...${NC}"

# Test Redis connection
if redis-cli PING &> /dev/null; then
    check_status 0 "Redis connection successful"
    
    # Check for HyperSpeed keys
    key_count=$(redis-cli KEYS "hyperspeed:*" | wc -l)
    echo -e "  ${GREEN}→${NC} Found $key_count HyperSpeed keys in Redis"
    
else
    check_status 1 "Cannot connect to Redis"
fi

echo ""

##############################################################################
# 7. UAPI Functionality
##############################################################################
echo -e "${BLUE}[7/8] Testing UAPI Functionality...${NC}"

# Check UAPI module (custom modules don't appear in uapi --list, check file directly)
UAPI_MODULE="/usr/local/cpanel/Cpanel/API/HyperSpeed.pm"
if [ -f "$UAPI_MODULE" ]; then
    check_status 0 "UAPI module installed"
    # Use cPanel's own Perl (has Cpanel:: modules in @INC) for syntax check
    CPANEL_PERL="/usr/local/cpanel/3rdparty/bin/perl"
    PERL_BIN="${CPANEL_PERL}"
    [ -x "$PERL_BIN" ] || PERL_BIN="perl"
    if "$PERL_BIN" -c "$UAPI_MODULE" &>/dev/null 2>&1; then
        check_status 0 "UAPI module syntax valid"
    else
        check_status 1 "UAPI module has syntax errors"
    fi
else
    check_status 1 "UAPI module not found"
fi

echo ""

##############################################################################
# 8. File Permissions
##############################################################################
echo -e "${BLUE}[8/8] Checking File Permissions...${NC}"

# WHM CGI should be executable
if [ -x "/usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed_pro/index.cgi" ]; then
    check_status 0 "WHM CGI is executable"
else
    check_status 1 "WHM CGI not found or not executable: /usr/local/cpanel/whostmgr/docroot/cgi/hyperspeed_pro/index.cgi"
fi

# CLI tool should be executable
if [ -x "/usr/local/bin/hyperspeed" ] || [ -x "/usr/local/bin/hyperspeed_pro/hyperspeed" ]; then
    check_status 0 "CLI tool is executable"
else
    check_status 1 "CLI tool permissions incorrect"
fi

# Check log directory
if [ -d "/var/log/hyperspeed_pro" ]; then
    check_status 0 "Log directory exists"
    
    if [ -w "/var/log/hyperspeed_pro" ]; then
        check_status 0 "Log directory is writable"
    else
        check_status 1 "Log directory is not writable"
    fi
else
    check_status 1 "Log directory not found"
fi

echo ""

##############################################################################
# Summary
##############################################################################
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Summary                                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo -e "${GREEN}✓ Perfect!${NC} All checks passed successfully."
    echo -e ""
    echo -e "HyperSpeed Pro is fully installed and operational!"
    echo -e ""
    echo -e "Next steps:"
    echo -e "  1. Access WHM → Plugins → HyperSpeed Pro"
    echo -e "  2. Configure global settings"
    echo -e "  3. Notify users to access cPanel → Software → HyperSpeed Pro"
    echo -e ""
    exit 0
    
elif [ $errors -eq 0 ]; then
    echo -e "${YELLOW}⚠ Almost there!${NC} Installation complete with $warnings warning(s)."
    echo -e ""
    echo -e "HyperSpeed Pro should work, but you may want to address warnings."
    echo -e ""
    exit 0
    
else
    echo -e "${RED}✗ Issues found!${NC} $errors error(s) and $warnings warning(s) detected."
    echo -e ""
    echo -e "Please review the errors above and:"
    echo -e "  1. Ensure both WHM and cPanel plugins are installed"
    echo -e "  2. Check service status: systemctl status hyperspeed-*"
    echo -e "  3. Review logs: /var/log/hyperspeed_pro/"
    echo -e "  4. Consult documentation: README.md"
    echo -e ""
    echo -e "For support: support@hyperspeed.pro"
    echo -e ""
    exit 1
fi
