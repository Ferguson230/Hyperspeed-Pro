#!/bin/bash
#
# HyperSpeed Pro - Performance Benchmark Tool
# Tests server performance before and after HyperSpeed Pro installation
#

set -e

echo "======================================"
echo "HyperSpeed Pro Performance Benchmark"
echo "======================================"
echo ""

# Check if Apache Bench is installed
if ! command -v ab &> /dev/null; then
    echo "Installing Apache Bench..."
    apt-get update -qq
    apt-get install -y apache2-utils
fi

# Configuration
TARGET_URL="${1:-http://localhost}"
CONCURRENCY=100
REQUESTS=10000

echo "Target URL: $TARGET_URL"
echo "Concurrency: $CONCURRENCY"
echo "Total Requests: $REQUESTS"
echo ""

# Function to run benchmark
run_benchmark() {
    local label=$1
    local url=$2
    
    echo "Running benchmark: $label"
    echo "--------------------------------"
    
    ab -n $REQUESTS -c $CONCURRENCY -q "$url" > /tmp/benchmark_result.txt 2>&1
    
    # Extract key metrics
    local requests_per_sec=$(grep "Requests per second" /tmp/benchmark_result.txt | awk '{print $4}')
    local time_per_request=$(grep "Time per request" /tmp/benchmark_result.txt | head -1 | awk '{print $4}')
    local failed_requests=$(grep "Failed requests" /tmp/benchmark_result.txt | awk '{print $3}')
    local transfer_rate=$(grep "Transfer rate" /tmp/benchmark_result.txt | awk '{print $3}')
    
    echo "Requests/sec: $requests_per_sec"
    echo "Time/request: $time_per_request ms"
    echo "Failed: $failed_requests"
    echo "Transfer rate: $transfer_rate KB/s"
    echo ""
}

# Function to get cache statistics
get_cache_stats() {
    echo "Cache Statistics:"
    echo "--------------------------------"
    
    # Redis stats
    if command -v redis-cli &> /dev/null; then
        local redis_keys=$(redis-cli DBSIZE | awk '{print $2}')
        local redis_memory=$(redis-cli INFO memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        local redis_hits=$(redis-cli INFO stats | grep keyspace_hits | cut -d: -f2 | tr -d '\r')
        local redis_misses=$(redis-cli INFO stats | grep keyspace_misses | cut -d: -f2 | tr -d '\r')
        
        echo "Redis Keys: $redis_keys"
        echo "Redis Memory: $redis_memory"
        echo "Redis Hits: $redis_hits"
        echo "Redis Misses: $redis_misses"
        
        if [ "$redis_hits" -gt 0 ] || [ "$redis_misses" -gt 0 ]; then
            local total=$((redis_hits + redis_misses))
            local hit_rate=$((redis_hits * 100 / total))
            echo "Redis Hit Rate: $hit_rate%"
        fi
    fi
    
    echo ""
}

# Function to get system resources
get_system_resources() {
    echo "System Resources:"
    echo "--------------------------------"
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d% -f1)
    echo "CPU Usage: $cpu_usage%"
    
    # Memory usage
    local mem_usage=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')
    echo "Memory Usage: $mem_usage"
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo "Load Average:$load_avg"
    
    echo ""
}

# Main benchmark sequence
echo "Starting benchmark sequence..."
echo ""

# Run benchmarks
run_benchmark "Homepage Test" "$TARGET_URL/"
sleep 2

run_benchmark "Static Asset Test" "$TARGET_URL/style.css"
sleep 2

run_benchmark "Dynamic Page Test" "$TARGET_URL/index.php"
sleep 2

# Get statistics
get_cache_stats
get_system_resources

# Performance recommendations
echo "Performance Recommendations:"
echo "--------------------------------"
echo "✓ Enable page caching for static pages"
echo "✓ Enable object caching for database queries"
echo "✓ Use Brotli or Zstd compression"
echo "✓ Enable HTTP/2 and HTTP/3"
echo "✓ Configure rate limiting to prevent abuse"
echo "✓ Optimize images with WebP conversion"
echo "✓ Minify CSS and JavaScript assets"
echo ""

echo "Benchmark complete!"
echo "Results saved to: /tmp/benchmark_result.txt"
echo ""
echo "To see detailed results:"
echo "cat /tmp/benchmark_result.txt"
echo ""
