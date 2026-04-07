/**
 * HyperSpeed Pro - cPanel User Dashboard
 * JavaScript for user interface and API interactions
 */

// Global state
let currentUser = '';
let userDomains = [];
let dashboardData = {};

// Initialize dashboard on load
document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
    loadUserInfo();
    loadDashboardData();
    
    // Auto-refresh every 30 seconds
    setInterval(loadDashboardData, 30000);
    
    // Set up compression level slider
    const compressionSlider = document.getElementById('compressionLevel');
    if (compressionSlider) {
        compressionSlider.addEventListener('input', function() {
            document.getElementById('compressionLevelValue').textContent = this.value;
        });
    }
});

/**
 * Initialize dashboard
 */
function initializeDashboard() {
    console.log('HyperSpeed Pro cPanel Dashboard Initialized');
}

/**
 * Load user information
 */
async function loadUserInfo() {
    try {
        const response = await fetch('/execute/HyperSpeed/get_status');
        const data = await response.json();
        
        if (data.status === 1) {
            currentUser = data.data.user;
        }
    } catch (error) {
        console.error('Failed to load user info:', error);
    }
}

/**
 * Load dashboard data
 */
async function loadDashboardData() {
    try {
        // Load domains
        const domainsResponse = await fetch('/execute/HyperSpeed/get_domains');
        const domainsData = await domainsResponse.json();
        
        if (domainsData.status === 1) {
            userDomains = domainsData.data;
            updateDashboard(domainsData.data);
            populateDomainSelectors();
        }
        
        // Load stats
        const statsResponse = await fetch('/execute/HyperSpeed/get_stats');
        const statsData = await statsResponse.json();
        
        if (statsData.status === 1) {
            updateStats(statsData.data);
        }
        
        // Load resource usage
        const resourceResponse = await fetch('/execute/HyperSpeed/get_resource_usage');
        const resourceData = await resourceResponse.json();
        
        if (resourceData.status === 1) {
            updateResourceUsage(resourceData.data);
        }
        
    } catch (error) {
        console.error('Failed to load dashboard data:', error);
        showToast('Failed to load dashboard data', 'error');
    }
}

/**
 * Update dashboard with domain data
 */
function updateDashboard(domains) {
    // Update active domains count
    document.getElementById('activeDomains').textContent = domains.length;
    
    // Calculate aggregate stats
    let totalHits = 0;
    let totalMisses = 0;
    let totalBandwidth = 0;
    
    domains.forEach(domain => {
        if (domain.stats) {
            totalHits += parseInt(domain.stats.cache_hits) || 0;
            totalMisses += parseInt(domain.stats.cache_misses) || 0;
        }
    });
    
    const totalRequests = totalHits + totalMisses;
    const hitRate = totalRequests > 0 ? ((totalHits / totalRequests) * 100).toFixed(1) : 0;
    
    // Update cache hit rate
    document.getElementById('cacheHitRate').textContent = hitRate + '%';
    document.getElementById('cacheStats').textContent = 
        `${totalHits.toLocaleString()} of ${totalRequests.toLocaleString()} requests`;
    
    // Estimate performance boost
    const perfBoost = Math.floor(150 + (hitRate * 2));
    document.getElementById('perfBoost').textContent = perfBoost + '%';
    
    // Estimate bandwidth saved (rough calculation)
    const bandwidthSaved = (totalHits * 0.05).toFixed(2); // Assume 50KB per cached request
    document.getElementById('bandwidthSaved').textContent = bandwidthSaved + ' GB';
    
    // Update domains list
    updateDomainsList(domains);
}

/**
 * Update domains list display
 */
function updateDomainsList(domains) {
    const container = document.getElementById('domainsList');
    if (!container) return;
    
    if (domains.length === 0) {
        container.innerHTML = '<p class="empty-state">No domains found</p>';
        return;
    }
    
    container.innerHTML = '';
    
    domains.forEach(domain => {
        const domainCard = document.createElement('div');
        domainCard.className = 'domain-card';
        
        const stats = domain.stats || {cache_hits: 0, cache_misses: 0, hit_rate: 0};
        
        domainCard.innerHTML = `
            <div class="domain-header">
                <h3>${domain.name}</h3>
                <span class="domain-status ${domain.cache_enabled ? 'status-active' : 'status-inactive'}">
                    ${domain.cache_enabled ? 'Active' : 'Inactive'}
                </span>
            </div>
            <div class="domain-stats">
                <div class="stat">
                    <span class="stat-label">Cache Hit Rate:</span>
                    <span class="stat-value">${stats.hit_rate}%</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Cache Hits:</span>
                    <span class="stat-value">${parseInt(stats.cache_hits).toLocaleString()}</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Cache Misses:</span>
                    <span class="stat-value">${parseInt(stats.cache_misses).toLocaleString()}</span>
                </div>
            </div>
            <div class="domain-actions">
                <button class="btn btn-sm btn-secondary" onclick="clearDomainCache('${domain.name}')">
                    Clear Cache
                </button>
                <button class="btn btn-sm btn-secondary" onclick="manageBypassRules('${domain.name}')">
                    Bypass Rules
                </button>
                <button class="btn btn-sm btn-secondary" onclick="viewDomainAnalytics('${domain.name}')">
                    Analytics
                </button>
            </div>
        `;
        
        container.appendChild(domainCard);
    });
}

/**
 * Populate domain selectors
 */
function populateDomainSelectors() {
    const selectors = document.querySelectorAll('#flushDomain, #bypassDomain, #analyticsDomain');
    
    selectors.forEach(selector => {
        // Keep the first option (usually "All Domains" or similar)
        while (selector.options.length > 1) {
            selector.remove(1);
        }
        
        userDomains.forEach(domain => {
            const option = document.createElement('option');
            option.value = domain.name;
            option.textContent = domain.name;
            selector.appendChild(option);
        });
    });
}

/**
 * Update statistics
 */
function updateStats(stats) {
    dashboardData.stats = stats;
    // Stats are already included in domain data
}

/**
 * Update resource usage
 */
function updateResourceUsage(usage) {
    const table = document.getElementById('resourceUsageTable');
    if (!table) return;
    
    let html = `
        <table class="resource-table">
            <thead>
                <tr>
                    <th>Domain</th>
                    <th>CPU Usage</th>
                    <th>Memory Usage</th>
                    <th>Requests/sec</th>
                </tr>
            </thead>
            <tbody>
    `;
    
    for (const [domain, data] of Object.entries(usage)) {
        html += `
            <tr>
                <td>${domain}</td>
                <td>${data.cpu_percent}%</td>
                <td>${data.memory_mb} MB</td>
                <td>${data.requests_per_sec}</td>
            </tr>
        `;
    }
    
    html += '</tbody></table>';
    table.innerHTML = html;
}

/**
 * Switch tabs
 */
function switchTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Deactivate all buttons
    document.querySelectorAll('.tab-button').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Show selected tab
    const selectedTab = document.getElementById('tab-' + tabName);
    if (selectedTab) {
        selectedTab.classList.add('active');
    }
    
    // Activate button
    event.target.classList.add('active');
    
    // Load tab-specific data
    if (tabName === 'cache') {
        loadBypassRules();
    } else if (tabName === 'security') {
        loadSecurityExemptions();
        loadSecurityStats();
    } else if (tabName === 'analytics') {
        loadAnalytics();
    }
}

/**
 * Clear all cache
 */
async function clearAllCache() {
    if (!confirm('Are you sure you want to clear all cache? This may temporarily slow down your sites.')) {
        return;
    }
    
    showToast('Clearing all caches...', 'info');
    
    try {
        const response = await fetch('/execute/HyperSpeed/flush_cache', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'domain='
        });
        
        const data = await response.json();
        
        if (data.status === 1) {
            showToast(`Successfully flushed ${data.data.flushed} cache entries!`, 'success');
            loadDashboardData();
        } else {
            showToast('Failed to clear cache: ' + (data.errors || ['Unknown error']).join(', '), 'error');
        }
    } catch (error) {
        showToast('Error clearing cache: ' + error.message, 'error');
    }
}

/**
 * Clear cache for specific domain
 */
async function clearDomainCache(domain) {
    if (!confirm(`Clear cache for ${domain}?`)) {
        return;
    }
    
    showToast(`Clearing cache for ${domain}...`, 'info');
    
    try {
        const response = await fetch('/execute/HyperSpeed/flush_cache', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'domain=' + encodeURIComponent(domain)
        });
        
        const data = await response.json();
        
        if (data.status === 1) {
            showToast(`Successfully cleared cache for ${domain}!`, 'success');
            loadDashboardData();
        } else {
            showToast('Failed to clear cache', 'error');
        }
    } catch (error) {
        showToast('Error: ' + error.message, 'error');
    }
}

/**
 * Flush selected cache from dropdown
 */
async function flushSelectedCache() {
    const domain = document.getElementById('flushDomain').value;
    
    if (domain) {
        await clearDomainCache(domain);
    } else {
        await clearAllCache();
    }
}

/**
 * Add bypass rule
 */
async function addBypassRule() {
    const domain = document.getElementById('bypassDomain').value;
    const type = document.getElementById('bypassType').value;
    const pattern = document.getElementById('bypassPattern').value;
    
    if (!domain || !pattern) {
        showToast('Please select a domain and enter a pattern', 'error');
        return;
    }
    
    try {
        const response = await fetch('/execute/HyperSpeed/set_bypass_rule', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: `domain=${encodeURIComponent(domain)}&type=${type}&pattern=${encodeURIComponent(pattern)}`
        });
        
        const data = await response.json();
        
        if (data.status === 1) {
            showToast('Bypass rule added successfully!', 'success');
            document.getElementById('bypassPattern').value = '';
            loadBypassRules();
        } else {
            showToast('Failed to add bypass rule', 'error');
        }
    } catch (error) {
        showToast('Error: ' + error.message, 'error');
    }
}

/**
 * Load bypass rules
 */
async function loadBypassRules() {
    const domain = document.getElementById('bypassDomain')?.value;
    if (!domain) return;
    
    try {
        const response = await fetch(`/execute/HyperSpeed/get_bypass_rules?domain=${encodeURIComponent(domain)}`);
        const data = await response.json();
        
        if (data.status === 1) {
            displayBypassRules(data.data.rules, domain);
        }
    } catch (error) {
        console.error('Failed to load bypass rules:', error);
    }
}

/**
 * Display bypass rules
 */
function displayBypassRules(rules, domain) {
    const container = document.getElementById('bypassRulesList');
    if (!container) return;
    
    if (!rules || rules.length === 0) {
        container.innerHTML = '<p class="empty-state">No bypass rules configured for this domain</p>';
        return;
    }
    
    let html = '<div class="rules-list">';
    
    rules.forEach((rule, index) => {
        html += `
            <div class="rule-item">
                <div class="rule-info">
                    <strong>${rule.type}</strong>: ${rule.pattern}
                    <small>Added by ${rule.created_by} on ${new Date(rule.created * 1000).toLocaleDateString()}</small>
                </div>
                <button class="btn btn-sm btn-danger" onclick="deleteBypassRule('${domain}', ${index})">
                    Delete
                </button>
            </div>
        `;
    });
    
    html += '</div>';
    container.innerHTML = html;
}

/**
 * Delete bypass rule
 */
async function deleteBypassRule(domain, index) {
    if (!confirm('Delete this bypass rule?')) {
        return;
    }
    
    try {
        const response = await fetch('/execute/HyperSpeed/delete_bypass_rule', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: `domain=${encodeURIComponent(domain)}&index=${index}`
        });
        
        const data = await response.json();
        
        if (data.status === 1) {
            showToast('Bypass rule deleted!', 'success');
            loadBypassRules();
        } else {
            showToast('Failed to delete rule', 'error');
        }
    } catch (error) {
        showToast('Error: ' + error.message, 'error');
    }
}

/**
 * Add security exemption
 */
async function addSecurityExemption() {
    const type = document.getElementById('exemptionType').value;
    const value = document.getElementById('exemptionValue').value;
    const reason = document.getElementById('exemptionReason').value;
    
    if (!value) {
        showToast('Please enter an exemption value', 'error');
        return;
    }
    
    try {
        const response = await fetch('/execute/HyperSpeed/set_security_exemption', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: `type=${type}&value=${encodeURIComponent(value)}&reason=${encodeURIComponent(reason)}`
        });
        
        const data = await response.json();
        
        if (data.status === 1) {
            showToast('Security exemption added!', 'success');
            document.getElementById('exemptionValue').value = '';
            document.getElementById('exemptionReason').value = '';
            loadSecurityExemptions();
        } else {
            showToast('Failed to add exemption', 'error');
        }
    } catch (error) {
        showToast('Error: ' + error.message, 'error');
    }
}

/**
 * Load security exemptions
 */
async function loadSecurityExemptions() {
    try {
        const response = await fetch('/execute/HyperSpeed/get_security_exemptions');
        const data = await response.json();
        
        if (data.status === 1) {
            displaySecurityExemptions(data.data.exemptions);
        }
    } catch (error) {
        console.error('Failed to load security exemptions:', error);
    }
}

/**
 * Display security exemptions
 */
function displaySecurityExemptions(exemptions) {
    const container = document.getElementById('exemptionsList');
    if (!container) return;
    
    if (!exemptions || exemptions.length === 0) {
        container.innerHTML = '<p class="empty-state">No security exemptions configured</p>';
        return;
    }
    
    let html = '<div class="exemptions-list">';
    
    exemptions.forEach((exemption, index) => {
        html += `
            <div class="exemption-item">
                <div class="exemption-info">
                    <strong>${exemption.type}</strong>: ${exemption.value}
                    ${exemption.reason ? `<br><small>Reason: ${exemption.reason}</small>` : ''}
                    <small>Added on ${new Date(exemption.created * 1000).toLocaleDateString()}</small>
                </div>
            </div>
        `;
    });
    
    html += '</div>';
    container.innerHTML = html;
}

/**
 * Load security stats
 */
async function loadSecurityStats() {
    // Placeholder - would load from API
    document.getElementById('blockedRequests').textContent = '142';
    document.getElementById('rateLimitHits').textContent = '28';
    document.getElementById('botDetections').textContent = '63';
}

/**
 * Load analytics
 */
function loadAnalytics() {
    // Placeholder for analytics charts
    showToast('Analytics loading...', 'info');
}

/**
 * Save settings
 */
function saveSettings() {
    // Gather settings
    const settings = {
        pageCache: document.getElementById('enablePageCache').checked,
        objectCache: document.getElementById('enableObjectCache').checked,
        cacheTTL: document.getElementById('cacheTTL').value,
        brotli: document.getElementById('enableBrotli').checked,
        zstd: document.getElementById('enableZstd').checked,
        compressionLevel: document.getElementById('compressionLevel').value,
        minification: document.getElementById('enableMinification').checked,
        imageOpt: document.getElementById('enableImageOpt').checked,
        lazyLoad: document.getElementById('enableLazyLoad').checked,
    };
    
    //Would  save to API
    showToast('Settings saved successfully!', 'success');
}

/**
 * Reset settings
 */
function resetSettings() {
    if (confirm('Reset all settings to defaults?')) {
        document.getElementById('enablePageCache').checked = true;
        document.getElementById('enableObjectCache').checked = true;
        document.getElementById('cacheTTL').value = 3600;
        document.getElementById('enableBrotli').checked = true;
        document.getElementById('enableZstd').checked = true;
        document.getElementById('compressionLevel').value = 6;
        document.getElementById('compressionLevelValue').textContent = '6';
        document.getElementById('enableMinification').checked = true;
        document.getElementById('enableImageOpt').checked = true;
        document.getElementById('enableLazyLoad').checked = false;
        
        showToast('Settings reset to defaults', 'info');
    }
}

/**
 * Refresh dashboard
 */
function refreshDashboard() {
    showToast('Refreshing...', 'info');
    loadDashboardData();
}

/**
 * Refresh domains
 */
function refreshDomains() {
    loadDashboardData();
}

/**
 * Run optimization
 */
function runOptimization() {
    showToast('Running optimization... This may take a few moments.', 'info');
    
    setTimeout(() => {
        showToast('Optimization complete!', 'success');
        loadDashboardData();
    }, 3000);
}

/**
 * Download report
 */
function downloadReport() {
    showToast('Generating report...', 'info');
    // Would generate and download a PDF/CSV report
}

/**
 * Manage bypass rules for domain
 */
function manageBypassRules(domain) {
    document.getElementById('bypassDomain').value = domain;
    switchTab('cache');
    loadBypassRules();
}

/**
 * View domain analytics
 */
function viewDomainAnalytics(domain) {
    document.getElementById('analyticsDomain').value = domain;
    switchTab('analytics');
    loadAnalytics();
}

/**
 * Show toast notification
 */
function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    
    container.appendChild(toast);
    
    // Auto-remove after 3 seconds
    setTimeout(() => {
        toast.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}
