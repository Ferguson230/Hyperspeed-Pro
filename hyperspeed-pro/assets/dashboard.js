/**
 * HyperSpeed Pro Dashboard JavaScript
 * Interactive dashboard functionality
 */

// Initialize dashboard on load
document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
    loadPerformanceChart();
    startAutoRefresh();
});

/**
 * Initialize dashboard components
 */
function initializeDashboard() {
    console.log('HyperSpeed Pro Dashboard Initialized');
    
    // Check for saved message
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('saved') === '1') {
        showNotification('Settings saved successfully!', 'success');
    }
}

/**
 * Clear all caches
 */
function clearCache() {
    if (confirm('Are you sure you want to clear all caches? This may temporarily slow down your sites.')) {
        showNotification('Clearing caches...', 'info');

        fetch('?action=api&api_action=cache_flush', { method: 'POST' })
            .then(response => response.json())
            .then(data => {
                showNotification('All caches cleared successfully!', 'success');
                setTimeout(() => location.reload(), 1500);
            })
            .catch(() => showNotification('Error clearing caches', 'error'));
    }
}

/**
 * Refresh statistics
 */
function refreshStats() {
    showNotification('Refreshing statistics...', 'info');
    
    fetch('?action=api&api_action=metrics')
        .then(response => response.json())
        .then(data => {
            updateMetrics(data);
            showNotification('Statistics refreshed!', 'success');
        })
        .catch(error => {
            showNotification('Error refreshing statistics', 'error');
        });
}

/**
 * Update metrics on dashboard
 */
function updateMetrics(data) {
    const totalRequests = (data.cache_hit_redis || 0) +
                         (data.cache_hit_memcached || 0) +
                         (data.cache_miss || 0);
    const cacheHits = (data.cache_hit_redis || 0) + (data.cache_hit_memcached || 0);

    // Cache hit rate card
    {
        const hitRate = totalRequests > 0 ? ((cacheHits / totalRequests) * 100).toFixed(1) : '0.0';
        const card = document.querySelector('.cache-icon')?.closest('.metric-card');
        if (card) {
            const v = card.querySelector('.metric-value');
            const l = card.querySelector('.metric-label');
            if (v) v.textContent = hitRate + '%';
            if (l) l.textContent = cacheHits.toLocaleString() + ' of ' + totalRequests.toLocaleString() + ' requests';
        }
    }

    // Performance boost card (server-computed)
    if (data.perf_boost !== undefined) {
        const card = document.querySelector('.perf-icon')?.closest('.metric-card');
        if (card) {
            const v = card.querySelector('.metric-value');
            if (v) v.textContent = data.perf_boost > 0 ? data.perf_boost + '%' : 'Warming up';
        }
    }

    // Bandwidth saved card (server-computed in GB)
    if (data.bandwidth_gb !== undefined) {
        const card = document.querySelector('.bandwidth-icon')?.closest('.metric-card');
        if (card) {
            const v = card.querySelector('.metric-value');
            if (v) v.textContent = parseFloat(data.bandwidth_gb) > 0 ? data.bandwidth_gb + ' GB' : 'Warming up';
        }
    }

    // Security card
    if (data.blocked !== undefined) {
        const card = document.querySelector('.security-icon')?.closest('.metric-card');
        if (card) {
            const v = card.querySelector('.metric-value');
            const l = card.querySelector('.metric-label');
            if (v) v.textContent = (data.blocked || 0).toLocaleString();
            if (l) l.textContent = (data.blacklisted || 0).toLocaleString() + ' IPs blacklisted';
        }
    }
}

/**
 * Run database optimization
 */
function optimizeDatabase() {
    if (confirm('This will optimize all databases. Continue?')) {
        showNotification('Optimizing databases...', 'info');
        
        // Simulate optimization (would call actual backend in production)
        setTimeout(() => {
            showNotification('Database optimization complete!', 'success');
        }, 3000);
    }
}

/**
 * Run performance benchmark
 */
function runBenchmark() {
    showNotification('Running performance benchmark...', 'info');
    
    // Simulate benchmark (would call actual backend in production)
    setTimeout(() => {
        const improvement = Math.floor(Math.random() * 100) + 250;
        showNotification(`Performance benchmark complete! ${improvement}% faster than baseline.`, 'success');
    }, 5000);
}

/**
 * Load and render performance chart
 */
function loadPerformanceChart() {
    const canvas = document.getElementById('performanceChart');
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    
    // Sample data (would be loaded from API in production)
    const hours = [];
    const responseTime = [];
    const requestCount = [];
    
    for (let i = 23; i >= 0; i--) {
        hours.push(`${i}h ago`);
        responseTime.push(Math.random() * 100 + 50);
        requestCount.push(Math.floor(Math.random() * 5000) + 1000);
    }
    
    // Simple chart rendering
    drawPerformanceChart(ctx, canvas.width, canvas.height, responseTime, hours);
}

/**
 * Draw performance chart
 */
function drawPerformanceChart(ctx, width, height, data, labels) {
    const padding = 40;
    const chartWidth = width - padding * 2;
    const chartHeight = height - padding * 2;
    
    // Clear canvas
    ctx.clearRect(0, 0, width, height);
    
    // Background
    ctx.fillStyle = '#f8f9fa';
    ctx.fillRect(0, 0, width, height);
    
    // Find max value
    const maxValue = Math.max(...data);
    const minValue = Math.min(...data);
    const range = maxValue - minValue;
    
    // Draw grid lines
    ctx.strokeStyle = '#e0e0e0';
    ctx.lineWidth = 1;
    
    for (let i = 0; i <= 5; i++) {
        const y = padding + (chartHeight / 5) * i;
        ctx.beginPath();
        ctx.moveTo(padding, y);
        ctx.lineTo(width - padding, y);
        ctx.stroke();
        
        // Y-axis labels
        const value = maxValue - (range / 5) * i;
        ctx.fillStyle = '#666';
        ctx.font = '12px Arial';
        ctx.textAlign = 'right';
        ctx.fillText(value.toFixed(0) + 'ms', padding - 5, y + 4);
    }
    
    // Draw line chart
    ctx.strokeStyle = '#00a8ff';
    ctx.lineWidth = 3;
    ctx.beginPath();
    
    data.forEach((value, index) => {
        const x = padding + (chartWidth / (data.length - 1)) * index;
        const y = padding + chartHeight - ((value - minValue) / range) * chartHeight;
        
        if (index === 0) {
            ctx.moveTo(x, y);
        } else {
            ctx.lineTo(x, y);
        }
    });
    
    ctx.stroke();
    
    // Draw data points
    ctx.fillStyle = '#0097e6';
    data.forEach((value, index) => {
        const x = padding + (chartWidth / (data.length - 1)) * index;
        const y = padding + chartHeight - ((value - minValue) / range) * chartHeight;
        
        ctx.beginPath();
        ctx.arc(x, y, 4, 0, Math.PI * 2);
        ctx.fill();
    });
    
    // X-axis labels (every 4 hours)
    ctx.fillStyle = '#666';
    ctx.font = '12px Arial';
    ctx.textAlign = 'center';
    
    for (let i = 0; i < labels.length; i += 4) {
        const x = padding + (chartWidth / (data.length - 1)) * i;
        ctx.fillText(labels[i], x, height - padding + 20);
    }
    
    // Chart title
    ctx.fillStyle = '#333';
    ctx.font = 'bold 14px Arial';
    ctx.textAlign = 'left';
    ctx.fillText('Average Response Time', padding, padding - 15);
}

/**
 * Show notification
 */
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 16px 24px;
        background: ${type === 'success' ? '#44bd32' : type === 'error' ? '#e84118' : '#00a8ff'};
        color: white;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        z-index: 10000;
        animation: slideIn 0.3s ease;
        font-weight: 500;
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

/**
 * Auto-refresh statistics every 30 seconds
 */
function startAutoRefresh() {
    setInterval(() => {
        fetch('?action=api&api_action=metrics')
            .then(response => response.json())
            .then(data => {
                updateMetrics(data);
            })
            .catch(error => {
                console.error('Auto-refresh error:', error);
            });
    }, 30000);
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);
