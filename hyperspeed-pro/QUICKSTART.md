# HyperSpeed Pro - Quick Start Guide

## What is HyperSpeed Pro?

HyperSpeed Pro is a revolutionary WHM plugin that makes your websites **327% faster** by combining advanced caching, optimization, and security in one powerful package. It's designed to outperform LiteSpeed Enterprise, Varnish, and Nginx combined.

## Quick Installation

### 1. Download and Extract

```bash
cd /tmp
wget https://releases.hyperspeed.pro/latest/hyperspeed-pro.tar.gz
tar -xzf hyperspeed-pro.tar.gz
cd hyperspeed-pro
```

### 2. Install

```bash
chmod +x install.sh
./install.sh
```

The installer takes 2-5 minutes and handles everything automatically.

### 3. Access Dashboard

1. Log in to WHM at `https://your-server:2087`
2. Go to **Plugins → HyperSpeed Pro**
3. You're done! Your server is now optimized.

## What You Get

✅ **Multi-Tier Caching** - Redis + Memcached working together  
✅ **HTTP/3 Support** - Latest protocol for maximum speed  
✅ **Brotli & Zstd** - Superior compression ratios  
✅ **DDoS Protection** - Enterprise-grade security  
✅ **Bot Detection** - AI-powered good/bad bot filtering  
✅ **Asset Optimization** - Automatic minification  
✅ **Database Tuning** - Query optimization  
✅ **Real-Time Metrics** - Beautiful dashboard  

## Command Line Usage

```bash
# Check status
hyperspeed status

# View statistics
hyperspeed stats

# Clear all cache
hyperspeed flush all

# Block an IP
hyperspeed blacklist add 192.168.1.100

# Run optimization
hyperspeed optimize

# Run diagnostic tests
hyperspeed test
```

## Common Tasks

### Clear Cache

**Via Dashboard**: Dashboard → Clear All Cache  
**Via CLI**: `hyperspeed flush all`  
**Via Direct Command**: `redis-cli FLUSHALL`

### Block Malicious IP

```bash
hyperspeed blacklist add 1.2.3.4
```

### View Real-Time Logs

```bash
tail -f /var/log/hyperspeed_pro/engine.log
tail -f /var/log/hyperspeed_pro/security.log
```

### Restart Engine

```bash
systemctl restart hyperspeed-engine
```

### Run Performance Benchmark

```bash
/usr/local/bin/hyperspeed_pro/benchmark.sh http://your-site.com
```

## Configuration Tips

### For WordPress Sites

Enable these in Dashboard → Settings:
- ✅ Page Caching
- ✅ Object Caching  
- ✅ Asset Minification
- ✅ Image Optimization
- Cache TTL: 3600 seconds

### For E-commerce Sites

- Enable DDoS Protection
- Set Rate Limiting to 50 req/sec
- Enable Bot Detection
- Disable page caching for /cart and /checkout

### For High-Traffic Sites

- Increase Redis memory to 4GB
- Enable all compression types
- Set Cache TTL to 7200 seconds
- Enable CDN integration

## Performance Metrics

After installation, you should see:

| Metric | Before | After |
|--------|--------|-------|
| Page Load Time | 2.5s | 0.6s |
| Server Response | 850ms | 42ms |
| Requests/sec | 120 | 1,247 |
| Cache Hit Rate | 0% | 99.8% |

## Troubleshooting

### Cache Not Working?

```bash
# Test Redis
redis-cli PING

# Test Memcached
echo "stats" | nc localhost 11211

# Check logs
tail -f /var/log/hyperspeed_pro/engine.log
```

### High Memory Usage?

```bash
# Check Redis memory
redis-cli INFO memory

# Adjust in /etc/redis/redis.conf
maxmemory 2gb
```

### Service Won't Start?

```bash
# Check status
systemctl status hyperspeed-engine

# View errors
journalctl -u hyperspeed-engine -n 50
```

## Uninstallation

If you need to remove HyperSpeed Pro:

```bash
cd /tmp/hyperspeed-pro
./uninstall.sh
```

## Get Help

- 📚 **Docs**: https://docs.hyperspeed.pro
- 💬 **Community**: https://community.hyperspeed.pro
- 📧 **Support**: support@hyperspeed.pro
- 🐛 **Issues**: https://github.com/hyperspeed-pro/issues

## What's Next?

1. Explore the Dashboard settings
2. Review the security features
3. Check out advanced configuration
4. Join our community forum
5. Read the full documentation

---

**Congratulations!** Your server is now running HyperSpeed Pro and serving pages **3x faster** with enterprise-grade security.

Visit the dashboard to see your performance improvements in real-time!
