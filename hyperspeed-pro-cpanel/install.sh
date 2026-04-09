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
PLUGIN_DIR_PL="${CPANEL_BASE}/base/frontend/paper_lantern/hyperspeed"
PLUGIN_DIR_JP="${CPANEL_BASE}/base/frontend/jupiter/hyperspeed"
PLUGIN_DIR="${PLUGIN_DIR_PL}"  # keep alias for legacy references below
API_DIR="${CPANEL_BASE}/Cpanel/API/HyperSpeed"
UAPI_DIR="${CPANEL_BASE}/Cpanel/API"
SCRIPTS_DIR="${CPANEL_BASE}/scripts"

# Create directories for both Paper Lantern and Jupiter themes
mkdir -p "${PLUGIN_DIR_PL}"
mkdir -p "${PLUGIN_DIR_PL}/assets"
mkdir -p "${PLUGIN_DIR_JP}"
mkdir -p "${PLUGIN_DIR_JP}/assets"
mkdir -p "${API_DIR}"
mkdir -p /var/log/hyperspeed_pro

echo -e "${YELLOW}Copying plugin files...${NC}"

# Copy interface files to both themes
if [ -d "./cpanel-interface" ]; then
    cp -r ./cpanel-interface/* "${PLUGIN_DIR_PL}/"
    cp -r ./cpanel-interface/* "${PLUGIN_DIR_JP}/"
fi

# Copy API modules
if [ -d "./cpanel-api" ]; then
    cp -r ./cpanel-api/* "${API_DIR}/"
fi

# Copy UAPI module
if [ -f "./uapi/HyperSpeed.pm" ]; then
    cp ./uapi/HyperSpeed.pm "${UAPI_DIR}/"
fi

# Copy sync service PHP worker into the shared HyperSpeed lib dir created by the WHM install
if [ -f "./lib/sync-users.php" ]; then
    cp ./lib/sync-users.php "/usr/local/cpanel/lib/hyperspeed_pro/"
fi

# Set permissions for both themes
for PDIR in "${PLUGIN_DIR_PL}" "${PLUGIN_DIR_JP}"; do
    chmod 755 "${PDIR}" 2>/dev/null || true
    find "${PDIR}" -name "*.html" -exec chmod 644 {} \; 2>/dev/null || true
    find "${PDIR}/assets" -type f -exec chmod 644 {} \; 2>/dev/null || true
done
chmod 755 "${API_DIR}"
find "${API_DIR}" -name "*.pm" -exec chmod 644 {} \; 2>/dev/null || true
if [ -f "${UAPI_DIR}/HyperSpeed.pm" ]; then
    chmod 644 "${UAPI_DIR}/HyperSpeed.pm"
fi
if [ -f "/usr/local/cpanel/lib/hyperspeed_pro/sync-users.php" ]; then
    chmod 755 "/usr/local/cpanel/lib/hyperspeed_pro/sync-users.php"
fi

echo -e "${GREEN}✓ Plugin files installed${NC}"

# Best-effort install of the Redis Perl module for cPanel's managed Perl.
# The UAPI works without it via redis-cli fallbacks, but bypass-rule writes
# and user settings are better when the module is available.
echo -e "${YELLOW}Checking cPanel Perl Redis module...${NC}"
if [ -x "${SCRIPTS_DIR}/perlinstaller" ]; then
    "${SCRIPTS_DIR}/perlinstaller" Redis >> /var/log/hyperspeed_pro/install.log 2>&1 || true
elif [ -x "${SCRIPTS_DIR}/checkperlmodules" ]; then
    "${SCRIPTS_DIR}/checkperlmodules" --install Redis >> /var/log/hyperspeed_pro/install.log 2>&1 || true
fi
echo -e "${GREEN}✓ Perl module check complete${NC}"

# Copy index.live.php to both themes (the .live.php suffix is required by cPanel)
if [ -f "./cpanel-interface/index.live.php" ]; then
    cp ./cpanel-interface/index.live.php "${PLUGIN_DIR_JP}/"
    cp ./cpanel-interface/index.live.php "${PLUGIN_DIR_PL}/"
fi

# Generate a simple PNG icon for the cPanel menu
echo -e "${YELLOW}Creating cPanel plugin icon...${NC}"
if command -v python3 &>/dev/null; then
    python3 << PYEOF
import struct, zlib
w, h, r, g, b = 48, 48, 102, 126, 234
def chunk(tag, data):
    crc = zlib.crc32(tag + data) & 0xffffffff
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', crc)
raw = b''.join(b'\x00' + bytes([r, g, b] * w) for _ in range(h))
png = (b'\x89PNG\r\n\x1a\n' +
       chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
       chunk(b'IDAT', zlib.compress(raw, 9)) +
       chunk(b'IEND', b''))
for d in ['${PLUGIN_DIR_JP}', '${PLUGIN_DIR_PL}']:
    try: open(d + '/hyperspeed-icon.png', 'wb').write(png)
    except: pass
PYEOF
fi

# Register with cPanel
echo -e "${YELLOW}Registering with cPanel...${NC}"

# install_plugin expects the source directory to contain install.json AND the plugin
# files in a subdirectory whose name matches the uri prefix in install.json.
# Our install.json says uri=hyperspeed/index.live.php, so we need hyperspeed/ inside
# the source directory.  Build a clean temp dir with the right layout.
INSTALL_PLUGIN="/usr/local/cpanel/scripts/install_plugin"
REGISTERED_CPANEL=false
if [ -x "$INSTALL_PLUGIN" ] && [ -f "./install.json" ]; then
    TEMP_PLUGIN_SRC=$(mktemp -d)
    mkdir -p "${TEMP_PLUGIN_SRC}/hyperspeed"
    if [ -d "./cpanel-interface" ]; then
        cp -r ./cpanel-interface/* "${TEMP_PLUGIN_SRC}/hyperspeed/"
    fi
    cp ./install.json "${TEMP_PLUGIN_SRC}/"
    # install_plugin may validate the icon - copy it into the temp dir
    for iconpath in "${PLUGIN_DIR_JP}/hyperspeed-icon.png" "${PLUGIN_DIR_PL}/hyperspeed-icon.png"; do
        [ -f "$iconpath" ] && cp "$iconpath" "${TEMP_PLUGIN_SRC}/" && break
    done

    INSTALL_OK=false
    if "$INSTALL_PLUGIN" "${TEMP_PLUGIN_SRC}" --theme=jupiter >> /var/log/hyperspeed_pro/install.log 2>&1; then
        INSTALL_OK=true
    fi
    # Also install to paper_lantern if it exists
    if [ -d "/usr/local/cpanel/base/frontend/paper_lantern" ]; then
        "$INSTALL_PLUGIN" "${TEMP_PLUGIN_SRC}" --theme=paper_lantern >> /var/log/hyperspeed_pro/install.log 2>&1 || true
    fi

    rm -rf "${TEMP_PLUGIN_SRC}"
    if [ "$INSTALL_OK" = "true" ]; then
        echo -e "${GREEN}\u2713 Registered with cPanel via install_plugin${NC}"
        REGISTERED_CPANEL=true
    else
        echo -e "${YELLOW}\u26a0 install_plugin returned non-zero (see /var/log/hyperspeed_pro/install.log)${NC}"
    fi
fi

if [ "$REGISTERED_CPANEL" != "true" ]; then
    # Fallback: write dynamicui conf directly.
    # Omit feature=/featuremanager= so the link appears for ALL cPanel users
    # without needing a Feature Manager entry (server-wide optimization tool).
    echo -e "${YELLOW}\u26a0 Writing dynamicui entry directly as fallback...${NC}"
    for THEME in jupiter paper_lantern; do
        DUI_DIR="${CPANEL_BASE}/base/frontend/${THEME}/dynamicui"
        if [ -d "$(dirname $DUI_DIR)" ]; then
            mkdir -p "$DUI_DIR"
            cat > "${DUI_DIR}/dynamicui_hyperspeed.conf" << 'DUICONF'
file=hyperspeed-icon.png
group=software
itemdesc=HyperSpeed Pro
itemorder=100
url=hyperspeed/index.live.php
DUICONF
        fi
    done
    echo -e "${GREEN}\u2713 Registered with cPanel (dynamicui fallback)${NC}"
fi

# Create user data directory structure
echo -e "${YELLOW}Creating user data structure...${NC}"

mkdir -p /var/cpanel/hyperspeed_pro
chmod 755 /var/cpanel/hyperspeed_pro

echo -e "${GREEN}✓ Data structure created${NC}"

# Rebuild cPanel themes
echo -e "${YELLOW}Rebuilding cPanel themes...${NC}"

/usr/local/cpanel/bin/rebuild_sprites > /dev/null 2>&1 || true
/usr/local/cpanel/scripts/rebuildhttpdconf > /dev/null 2>&1 || true
/usr/local/cpanel/scripts/restartsrv_cpsrvd > /dev/null 2>&1 || true

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
# Prefer a PHP binary that actually has the Redis extension loaded.
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
    echo "No PHP binary found" >> /var/log/hyperspeed_pro/sync.log
    exit 1
fi

if ! "$PHP_BIN" -r 'exit(class_exists("Redis") ? 0 : 1);' >/dev/null 2>&1; then
    echo "No PHP binary with Redis extension found; sync worker cannot start cleanly" >> /var/log/hyperspeed_pro/sync.log
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
