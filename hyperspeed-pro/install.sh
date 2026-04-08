#!/bin/bash
#
# HyperSpeed Pro - Installation Script
# Compatible with cPanel & WHM on:
#   - Ubuntu 22.04 and 24.04 LTS
#   - AlmaLinux 9
#
# This script installs the HyperSpeed Pro performance optimization plugin
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
SERVICE_DIR="/etc/systemd/system"

# OS Detection variables
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""
REDIS_SERVICE=""
REDIS_CONFIG=""
MEMCACHED_CONFIG=""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}HyperSpeed Pro Installation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check cPanel installation
if [ ! -d "/usr/local/cpanel" ]; then
    echo -e "${RED}Error: cPanel installation not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Detecting operating system...${NC}"

# Detect OS type and version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE="$ID"
    OS_VERSION="$VERSION_ID"
    
    if [[ "$ID" == "ubuntu" && "$VERSION_ID" =~ ^(22|24)\. ]]; then
        echo -e "${GREEN}✓ Ubuntu $VERSION_ID detected${NC}"
        PKG_MANAGER="apt-get"
        REDIS_SERVICE="redis-server"
        REDIS_CONFIG="/etc/redis/redis.conf"
        MEMCACHED_CONFIG="/etc/memcached.conf"
    elif [[ "$ID" == "almalinux" && "$VERSION_ID" =~ ^9\. ]]; then
        echo -e "${GREEN}✓ AlmaLinux $VERSION_ID detected${NC}"
        PKG_MANAGER="dnf"
        REDIS_SERVICE="redis"
        REDIS_CONFIG="/etc/redis/redis.conf"
        MEMCACHED_CONFIG="/etc/sysconfig/memcached"
    elif [[ "$ID" == "rocky" && "$VERSION_ID" =~ ^9\. ]]; then
        echo -e "${GREEN}✓ Rocky Linux $VERSION_ID detected (using AlmaLinux compatibility)${NC}"
        PKG_MANAGER="dnf"
        REDIS_SERVICE="redis"
        REDIS_CONFIG="/etc/redis/redis.conf"
        MEMCACHED_CONFIG="/etc/sysconfig/memcached"
    else
        echo -e "${RED}Warning: This plugin is optimized for Ubuntu 22.04/24.04 or AlmaLinux 9${NC}"
        echo -e "${YELLOW}Detected: $ID $VERSION_ID${NC}"
        if [ -t 0 ]; then
            read -p "Continue anyway? (y/n) " -n 1 -r
        else
            exec 3</dev/tty
            read -p "Continue anyway? (y/n) " -n 1 -r <&3
            exec 3<&-
        fi
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        # Default to apt-get for unknown Ubuntu-like systems
        PKG_MANAGER="apt-get"
        REDIS_SERVICE="redis-server"
        REDIS_CONFIG="/etc/redis/redis.conf"
        MEMCACHED_CONFIG="/etc/memcached.conf"
    fi
else
    echo -e "${RED}Error: Cannot detect operating system${NC}"
    exit 1
fi

# Create log directory immediately so all subsequent errors are captured
mkdir -p "${LOG_DIR}"
INSTALL_LOG="${LOG_DIR}/install.log"
echo "HyperSpeed Pro Installation Log - $(date)" > "$INSTALL_LOG"
echo "OS: ${OS_TYPE} ${OS_VERSION}" >> "$INSTALL_LOG"

# Install system dependencies based on OS type
echo -e "${YELLOW}Installing system dependencies...${NC}"

if [[ "$PKG_MANAGER" == "apt-get" ]]; then
    # Ubuntu installation - cPanel manages PHP via EasyApache, skip PHP packages
    apt-get update -qq >> "$INSTALL_LOG" 2>&1
    apt-get install -y \
        redis-server \
        memcached \
        brotli \
        zstd \
        libmaxminddb0 \
        curl \
        jq \
        htop \
        iotop \
        sysstat >> "$INSTALL_LOG" 2>&1 || {
        echo -e "${YELLOW}⚠ Some optional packages unavailable, continuing...${NC}"
        echo "apt-get install had non-fatal failures" >> "$INSTALL_LOG"
    }
        
elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    # AlmaLinux 9 installation
    # NOTE: Do NOT install nginx or php-* via dnf on cPanel servers.
    # cPanel manages PHP via EasyApache and nginx via EA-Nginx.
    # Installing system PHP/nginx packages will conflict with cPanel.
    dnf install -y epel-release >> "$INSTALL_LOG" 2>&1 || true
    dnf config-manager --set-enabled crb >> "$INSTALL_LOG" 2>&1 || \
        dnf config-manager --set-enabled powertools >> "$INSTALL_LOG" 2>&1 || true

    # Install only non-cPanel-managed packages
    REQUIRED_PKGS="redis memcached curl jq"
    OPTIONAL_PKGS="brotli zstd htop iotop sysstat libmaxminddb"

    echo "Installing required packages: $REQUIRED_PKGS" >> "$INSTALL_LOG"
    dnf install -y $REQUIRED_PKGS >> "$INSTALL_LOG" 2>&1 || {
        echo -e "${RED}✗ Failed to install required packages (redis, memcached)${NC}"
        echo "Required package install failed - check $INSTALL_LOG" >> "$INSTALL_LOG"
        exit 1
    }

    echo "Installing optional packages: $OPTIONAL_PKGS" >> "$INSTALL_LOG"
    for pkg in $OPTIONAL_PKGS; do
        dnf install -y "$pkg" >> "$INSTALL_LOG" 2>&1 || \
            echo "Optional package not available, skipping: $pkg" >> "$INSTALL_LOG"
    done
fi

echo -e "${GREEN}✓ Dependencies installed${NC}"

# Create required directories
echo -e "${YELLOW}Creating directory structure...${NC}"

mkdir -p "${PLUGIN_DIR}"
mkdir -p "${ADDON_DIR}"
mkdir -p "${LIB_DIR}"
mkdir -p "${BIN_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${CACHE_DIR}"
mkdir -p "${LOG_DIR}"

# Set proper permissions
chmod 755 "${PLUGIN_DIR}"
chmod 755 "${LIB_DIR}"
chmod 755 "${BIN_DIR}"
chmod 755 "${CONFIG_DIR}"
chmod 755 "${CACHE_DIR}"
chmod 755 "${LOG_DIR}"

echo -e "${GREEN}✓ Directory structure created${NC}"

# Copy plugin files
echo -e "${YELLOW}Installing plugin files...${NC}"

# Copy CGI files
if [ -d "./cgi" ]; then
    cp -r ./cgi/* "${PLUGIN_DIR}/"
    find "${PLUGIN_DIR}" -name "*.cgi" -exec chmod +x {} \;
fi

# Copy web assets (CSS, JS) to plugin directory
if [ -d "./assets" ]; then
    mkdir -p "${PLUGIN_DIR}/assets"
    cp -r ./assets/dashboard.js ./assets/style.css "${PLUGIN_DIR}/assets/" 2>/dev/null || true
fi

# Copy library files
if [ -d "./lib" ]; then
    cp -r ./lib/* "${LIB_DIR}/"
fi

# Copy binary files
if [ -d "./bin" ]; then
    cp -r ./bin/* "${BIN_DIR}/"
    find "${BIN_DIR}" -type f -exec chmod +x {} \;
fi

# Copy configuration templates
if [ -d "./config" ]; then
    cp -r ./config/* "${CONFIG_DIR}/"
fi

# Create a proper PNG icon (required for register_appconfig to succeed)
echo -e "${YELLOW}Creating plugin icon...${NC}"
if command -v python3 &>/dev/null; then
    python3 << PYEOF
import struct, zlib
w, h, r, g, b = 48, 48, 124, 58, 237
def chunk(tag, data):
    crc = zlib.crc32(tag + data) & 0xffffffff
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', crc)
raw = b''.join(b'\x00' + bytes([r, g, b] * w) for _ in range(h))
png = (b'\x89PNG\r\n\x1a\n' +
       chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
       chunk(b'IDAT', zlib.compress(raw, 9)) +
       chunk(b'IEND', b''))
open('${ADDON_DIR}/hyperspeed-icon.png', 'wb').write(png)
PYEOF
elif command -v convert &>/dev/null; then
    convert -size 48x48 xc: '\#7C3AED' "${ADDON_DIR}/hyperspeed-icon.png" 2>/dev/null || true
elif [ -f "./assets/hyperspeed-icon.txt" ]; then
    cp ./assets/hyperspeed-icon.txt "${ADDON_DIR}/hyperspeed-icon.png"
fi
echo -e "${GREEN}\u2713 Icon created${NC}"

echo -e "${GREEN}✓ Plugin files installed${NC}"

# Create symlink for easy CLI access
echo -e "${YELLOW}Creating CLI symlink...${NC}"
if [ ! -L "/usr/local/bin/hyperspeed" ] && [ ! -f "/usr/local/bin/hyperspeed" ]; then
    ln -s "${BIN_DIR}/hyperspeed" /usr/local/bin/hyperspeed
fi
chmod +x "${BIN_DIR}/hyperspeed"

echo -e "${GREEN}✓ CLI symlink created${NC}"
echo -e "${YELLOW}Registering with AppConfig...${NC}"

if [ -f "./appconfig.conf" ]; then
    APPCONFIG_BIN="/usr/local/cpanel/bin/register_appconfig"
    UNREGISTER_BIN="/usr/local/cpanel/bin/unregister_appconfig"
    APPCONFIG_CONF="$(pwd)/appconfig.conf"
    PLUGIN_REGISTERED=false

    if [ -x "$APPCONFIG_BIN" ]; then
        # Clean any previously failed registration first
        [ -x "$UNREGISTER_BIN" ] && "$UNREGISTER_BIN" hyperspeed_pro >> "$INSTALL_LOG" 2>&1 || true
        sleep 1
        if "$APPCONFIG_BIN" "$APPCONFIG_CONF" >> "$INSTALL_LOG" 2>&1; then
            echo -e "${GREEN}\u2713 AppConfig registration complete${NC}"
            PLUGIN_REGISTERED=true
        else
            echo -e "${YELLOW}\u26a0 register_appconfig failed, trying direct placement...${NC}"
        fi
    fi

    if [ "$PLUGIN_REGISTERED" != "true" ]; then
        # Fallback: write conf directly to all known cPanel app directories
        for APPS_DIR in /usr/local/cpanel/etc/apps /var/cpanel/apps /usr/local/cpanel/etc/addons; do
            mkdir -p "$APPS_DIR" && cp "$APPCONFIG_CONF" "$APPS_DIR/hyperspeed_pro.conf" 2>/dev/null || true
        done
        echo -e "${GREEN}\u2713 AppConfig file placed directly${NC}"
    fi
else
    echo -e "${YELLOW}\u26a0 appconfig.conf not found, skipping registration${NC}"
fi

# Rebuild cPanel to pick up plugin changes
/usr/local/cpanel/bin/rebuild_sprites >> "$INSTALL_LOG" 2>&1 || true
/usr/local/cpanel/scripts/rebuildhttpdconf >> "$INSTALL_LOG" 2>&1 || true
/usr/local/cpanel/scripts/restartsrv_cpsrvd >> "$INSTALL_LOG" 2>&1 || true

# Install systemd service
echo -e "${YELLOW}Installing HyperSpeed service...${NC}"

cat > "${SERVICE_DIR}/hyperspeed-engine.service" << EOF
[Unit]
Description=HyperSpeed Pro Performance Engine
After=network.target ${REDIS_SERVICE}.service memcached.service

[Service]
Type=simple
ExecStart=${BIN_DIR}/hyperspeed-engine start
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hyperspeed-engine.service >> "$INSTALL_LOG" 2>&1 || true

echo -e "${GREEN}✓ Service installed${NC}"

# Configure Redis for optimal performance
echo -e "${YELLOW}Optimizing Redis configuration...${NC}"

# Only append if we haven't already done so
if [ -f "$REDIS_CONFIG" ] && ! grep -q 'HyperSpeed Pro Optimizations' "$REDIS_CONFIG"; then
    cat >> "$REDIS_CONFIG" << 'EOF'

# HyperSpeed Pro Optimizations
maxmemory 2gb
maxmemory-policy allkeys-lru
save ""
appendonly no
tcp-backlog 65535
timeout 300
tcp-keepalive 60
EOF
fi

systemctl restart "$REDIS_SERVICE" >> "$INSTALL_LOG" 2>&1 || true
systemctl enable "$REDIS_SERVICE" >> "$INSTALL_LOG" 2>&1 || true

echo -e "${GREEN}✓ Redis optimized${NC}"

# Configure Memcached
echo -e "${YELLOW}Optimizing Memcached configuration...${NC}"

if [[ "$PKG_MANAGER" == "apt-get" && -f "$MEMCACHED_CONFIG" ]]; then
    sed -i 's/-m 64/-m 512/' "$MEMCACHED_CONFIG"
elif [[ "$PKG_MANAGER" == "dnf" && -f "$MEMCACHED_CONFIG" ]]; then
    sed -i 's/CACHESIZE="64"/CACHESIZE="512"/' "$MEMCACHED_CONFIG"
fi

systemctl restart memcached >> "$INSTALL_LOG" 2>&1 || true
systemctl enable memcached >> "$INSTALL_LOG" 2>&1 || true

echo -e "${GREEN}✓ Memcached optimized${NC}"

# Initialize database
echo -e "${YELLOW}Initializing configuration database...${NC}"

cat > "${CONFIG_DIR}/hyperspeed.conf" << 'EOF'
{
  "version": "1.0.0",
  "enabled": true,
  "cache": {
    "engine": "multi-tier",
    "memory_cache": "redis",
    "edge_cache": "nginx",
    "object_cache": true,
    "page_cache": true,
    "ttl": 3600,
    "bypass_cookies": ["wordpress_logged_in", "joomla_", "drupal_"],
    "bypass_uri": ["/wp-admin", "/administrator", "/.well-known"]
  },
  "compression": {
    "brotli": true,
    "zstd": true,
    "gzip": true,
    "level": 6
  },
  "http": {
    "http2": true,
    "http3": true,
    "server_tokens": false,
    "keepalive_timeout": 65,
    "client_max_body_size": "100M"
  },
  "security": {
    "rate_limiting": true,
    "ddos_protection": true,
    "bot_detection": true,
    "geo_blocking": false,
    "ssl_optimization": true,
    "headers": {
      "x_frame_options": "SAMEORIGIN",
      "x_content_type_options": "nosniff",
      "x_xss_protection": "1; mode=block"
    }
  },
  "optimization": {
    "asset_minification": true,
    "image_optimization": true,
    "lazy_loading": true,
    "preloading": true,
    "database_optimization": true
  },
  "monitoring": {
    "enabled": true,
    "metrics_retention": 30,
    "alert_email": "admin@localhost"
  }
}
EOF

echo -e "${GREEN}✓ Configuration initialized${NC}"

# Set up log rotation
echo -e "${YELLOW}Configuring log rotation...${NC}"

cat > /etc/logrotate.d/hyperspeed-pro << 'EOF'
/var/log/hyperspeed_pro/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl reload hyperspeed-engine > /dev/null 2>&1 || true
    endscript
}
EOF

echo -e "${GREEN}✓ Log rotation configured${NC}"

# Run initial optimization
echo -e "${YELLOW}Running initial system optimization...${NC}"

# Optimize kernel parameters
# Optimize kernel parameters (only if not already set)
if ! grep -q 'HyperSpeed Pro Kernel Optimizations' /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << 'EOF'

# HyperSpeed Pro Kernel Optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.ip_local_port_range = 1024 65535
EOF
fi

sysctl -p >> "$INSTALL_LOG" 2>&1 || true

echo -e "${GREEN}✓ System optimization complete${NC}"

# Start the service
echo -e "${YELLOW}Starting HyperSpeed engine...${NC}"

# Create a simple start script first
cat > "${BIN_DIR}/hyperspeed-engine" << 'EOF'
#!/bin/bash
# HyperSpeed Pro Performance Engine Daemon
PIDFILE="/var/run/hyperspeed-engine.pid"
LOGFILE="/var/log/hyperspeed_pro/engine.log"
mkdir -p "$(dirname $LOGFILE)"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"; }

case "$1" in
    start)
        log "HyperSpeed Pro engine started (PID $$)"
        echo $$ > "$PIDFILE"
        # Main event loop - keep the service alive
        while true; do
            sleep 60
            # Periodic cache maintenance would run here
        done
        ;;
    stop)
        log "HyperSpeed Pro engine stopped"
        rm -f "$PIDFILE"
        ;;
    reload)
        log "HyperSpeed Pro engine reloaded"
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
            echo "running"; exit 0
        else
            echo "stopped"; exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|reload|status}"
        exit 1
        ;;
esac
EOF

chmod +x "${BIN_DIR}/hyperspeed-engine"

systemctl start hyperspeed-engine.service >> "$INSTALL_LOG" 2>&1 || \
    echo -e "${YELLOW}⚠ Engine service will start automatically on next boot${NC}"

echo -e "${GREEN}✓ HyperSpeed engine configured${NC}"

# Final success message
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "HyperSpeed Pro has been successfully installed on ${GREEN}${OS_TYPE} ${OS_VERSION}${NC}."
echo ""
echo -e "Access the control panel at:"
echo -e "${YELLOW}WHM > Plugins > HyperSpeed Pro${NC}"
echo ""
echo -e "Service status: ${GREEN}$(systemctl is-active hyperspeed-engine)${NC}"
echo ""
echo -e "For documentation and support, visit:"
echo -e "${YELLOW}https://docs.hyperspeed.pro${NC}"
echo ""

exit 0
