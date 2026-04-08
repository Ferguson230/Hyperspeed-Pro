#!/usr/bin/env php
<?php
/**
 * HyperSpeed Pro - cPanel-WHM Sync Service
 * 
 * Synchronizes cPanel user settings with WHM master configuration
 * Ensures consistency between user-level and server-level optimizations
 * 
 * @package HyperSpeed Pro
 * @version 1.0.0
 */

require_once '/usr/local/cpanel/php/cpanel.php';

class HyperSpeedSync
{
    private $redis;
    private $whm_config;
    private $logger;
    
    const SYNC_INTERVAL = 60; // seconds
    const LOG_FILE = '/var/log/hyperspeed_pro/sync.log';
    
    public function __construct()
    {
        $this->initializeRedis();
        $this->loadWHMConfig();
        $this->initializeLogger();
    }
    
    /**
     * Initialize Redis connection
     */
    private function initializeRedis()
    {
        try {
            $this->redis = new Redis();
            $this->redis->connect('127.0.0.1', 6379);
            $this->redis->setOption(Redis::OPT_PREFIX, 'hyperspeed:');
        } catch (Exception $e) {
            $this->log("Failed to connect to Redis: " . $e->getMessage(), 'ERROR');
            exit(1);
        }
    }
    
    /**
     * Load WHM master configuration
     */
    private function loadWHMConfig()
    {
        $config_file = '/etc/hyperspeed_pro/hyperspeed.conf';
        
        if (!file_exists($config_file)) {
            $this->log("WHM configuration not found", 'ERROR');
            exit(1);
        }
        
        $this->whm_config = json_decode(file_get_contents($config_file), true);
        
        if (!$this->whm_config) {
            $this->log("Failed to parse WHM configuration", 'ERROR');
            exit(1);
        }
    }
    
    /**
     * Initialize logger
     */
    private function initializeLogger()
    {
        $log_dir = dirname(self::LOG_FILE);
        if (!is_dir($log_dir)) {
            mkdir($log_dir, 0755, true);
        }
    }
    
    /**
     * Main sync loop
     */
    public function run()
    {
        $this->log("HyperSpeed Pro Sync Service Started");
        
        while (true) {
            try {
                $this->syncAllUsers();
                $this->syncDomainSettings();
                $this->syncSecurityRules();
                $this->cleanupStaleData();
                
            } catch (Exception $e) {
                $this->log("Sync error: " . $e->getMessage(), 'ERROR');
            }
            
            sleep(self::SYNC_INTERVAL);
        }
    }
    
    /**
     * Sync all cPanel users with WHM master settings
     */
    private function syncAllUsers()
    {
        $users = $this->getCpanelUsers();
        $synced_count = 0;
        
        foreach ($users as $user) {
            if ($this->syncUser($user)) {
                $synced_count++;
            }
        }
        
        if ($synced_count > 0) {
            $this->log("Synced $synced_count users with master configuration");
        }
    }
    
    /**
     * Sync individual user settings
     */
    private function syncUser($username)
    {
        try {
            // Get user's current settings
            $user_settings_key = "user:$username:settings";
            $user_settings_json = $this->redis->get($user_settings_key);
            
            $user_settings = $user_settings_json ? 
                json_decode($user_settings_json, true) : [];
            
            // Merge with WHM master settings (WHM settings take precedence if enforced)
            $synced_settings = $this->mergeSettings($user_settings, $this->whm_config);
            
            // Save synced settings
            $this->redis->set($user_settings_key, json_encode($synced_settings));
            
            // Update user domains with synced settings
            $this->syncUserDomains($username, $synced_settings);
            
            return true;
            
        } catch (Exception $e) {
            $this->log("Failed to sync user $username: " . $e->getMessage(), 'ERROR');
            return false;
        }
    }
    
    /**
     * Merge user settings with WHM master configuration
     */
    private function mergeSettings($user_settings, $whm_config)
    {
        $merged = $user_settings;
        
        // If WHM enforces certain settings, override user settings
        if (isset($whm_config['enforce_settings']) && $whm_config['enforce_settings']) {
            $enforce_keys = ['security', 'rate_limiting', 'ddos_protection'];
            
            foreach ($enforce_keys as $key) {
                if (isset($whm_config['security'][$key])) {
                    $merged['security'][$key] = $whm_config['security'][$key];
                }
            }
        }
        
        // Ensure minimum security standards
        if (!isset($merged['security']['rate_limiting'])) {
            $merged['security']['rate_limiting'] = true;
        }
        
        if (!isset($merged['cache'])) {
            $merged['cache'] = $whm_config['cache'];
        }
        
        return $merged;
    }
    
    /**
     * Sync user domains with their settings
     */
    private function syncUserDomains($username, $settings)
    {
        $domains = $this->getUserDomains($username);
        
        foreach ($domains as $domain) {
            $domain_key = "domain:$domain:settings";
            $this->redis->set($domain_key, json_encode($settings));
            
            // Apply cache rules for the domain
            $this->applyCacheRules($domain, $settings);
        }
    }
    
    /**
     * Apply cache rules to a domain
     */
    private function applyCacheRules($domain, $settings)
    {
        // Update Nginx configuration for the domain if needed
        // This would generate domain-specific Nginx config snippets
        
        $cache_enabled = $settings['cache']['page_cache'] ?? true;
        $ttl = $settings['cache']['ttl'] ?? 3600;
        
        // Store domain cache configuration
        $cache_config = [
            'enabled' => $cache_enabled,
            'ttl' => $ttl,
            'bypass_rules' => $this->getDomainBypassRules($domain),
        ];
        
        $this->redis->set("domain:$domain:cache_config", json_encode($cache_config));
    }
    
    /**
     * Get bypass rules for a domain
     */
    private function getDomainBypassRules($domain)
    {
        $rules_key = "domain:$domain:bypass_rules";
        $rules_json = $this->redis->get($rules_key);
        return $rules_json ? json_decode($rules_json, true) : [];
    }
    
    /**
     * Sync domain settings across the server
     */
    private function syncDomainSettings()
    {
        // Get all domains and ensure consistent settings
        $domain_keys = $this->redis->keys('domain:*:settings');
        
        foreach ($domain_keys as $key) {
            $domain = explode(':', $key)[1];
            
            // Validate domain configuration
            $config = $this->redis->get($key);
            if ($config) {
                $settings = json_decode($config, true);
                
                // Ensure domain has proper cache TTL set
                if (!isset($settings['cache']['ttl'])) {
                    $settings['cache']['ttl'] = $this->whm_config['cache']['ttl'];
                    $this->redis->set($key, json_encode($settings));
                }
            }
        }
    }
    
    /**
     * Sync security rules between WHM and cPanel users
     */
    private function syncSecurityRules()
    {
        // Get WHM global security exemptions
        $global_exemptions = $this->redis->get('global:security_exemptions');
        
        if ($global_exemptions) {
            $exemptions = json_decode($global_exemptions, true);
            
            // Apply global exemptions to all users
            foreach ($exemptions as $exemption) {
                if ($exemption['type'] === 'ip') {
                    // Add to global whitelist
                    $this->redis->set("whitelist:global:{$exemption['value']}", time());
                }
            }
        }
        
        // Sync rate limiting rules
        $this->syncRateLimits();
    }
    
    /**
     * Sync rate limiting configuration
     */
    private function syncRateLimits()
    {
        // Get master rate limit settings
        $master_rate_limit = $this->whm_config['security']['rate_limiting'] ?? true;
        
        if (!$master_rate_limit) {
            // If master disables rate limiting, ensure it's disabled for all
            $this->log("Rate limiting disabled at WHM level", 'WARN');
        }
    }
    
    /**
     * Cleanup stale data from Redis
     */
    private function cleanupStaleData()
    {
        // Remove old metrics (older than 30 days)
        $cutoff = time() - (30 * 86400);
        $metric_keys = $this->redis->keys('metrics:*');
        
        $cleaned = 0;
        foreach ($metric_keys as $key) {
            // Parse timestamp from key
            if (preg_match('/metrics:.*:(\d{4}-\d{2}-\d{2})/', $key, $matches)) {
                $date = strtotime($matches[1]);
                if ($date < $cutoff) {
                    $this->redis->del($key);
                    $cleaned++;
                }
            }
        }
        
        if ($cleaned > 0) {
            $this->log("Cleaned up $cleaned stale metric entries");
        }
        
        // Remove expired blacklist entries
        $this->cleanupBlacklist();
    }
    
    /**
     * Cleanup expired blacklist entries
     */
    private function cleanupBlacklist()
    {
        $blacklist_keys = $this->redis->keys('blacklist:*');
        $removed = 0;
        
        foreach ($blacklist_keys as $key) {
            // Check if key has TTL, if not it's already expired or permanent
            $ttl = $this->redis->ttl($key);
            if ($ttl === -2) {
                // Key doesn't exist (already expired)
                $removed++;
            }
        }
        
        if ($removed > 0) {
            $this->log("Removed $removed expired blacklist entries");
        }
    }
    
    /**
     * Get all cPanel users
     */
    private function getCpanelUsers()
    {
        $users = [];
        
        // Read from /etc/trueuserdomains or use cPanel API
        if (file_exists('/etc/trueuserdomains')) {
            $lines = file('/etc/trueuserdomains', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            
            foreach ($lines as $line) {
                if (strpos($line, ':') !== false) {
                    list($domain, $user) = explode(':', $line, 2);
                    $user = trim($user);
                    if (!in_array($user, $users)) {
                        $users[] = $user;
                    }
                }
            }
        }
        
        return $users;
    }
    
    /**
     * Get domains for a specific user
     */
    private function getUserDomains($username)
    {
        $domains = [];
        
        if (file_exists('/etc/trueuserdomains')) {
            $lines = file('/etc/trueuserdomains', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            
            foreach ($lines as $line) {
                if (strpos($line, ':') !== false) {
                    list($domain, $user) = explode(':', $line, 2);
                    $user = trim($user);
                    if ($user === $username) {
                        $domains[] = trim($domain);
                    }
                }
            }
        }
        
        return $domains;
    }
    
    /**
     * Log message
     */
    private function log($message, $level = 'INFO')
    {
        $timestamp = date('Y-m-d H:i:s');
        $log_message = "[$timestamp] [$level] $message\n";
        file_put_contents(self::LOG_FILE, $log_message, FILE_APPEND);
        
        // Also log to syslog for important events
        if ($level === 'ERROR' || $level === 'CRITICAL') {
            syslog(LOG_ERR, "HyperSpeed Sync: $message");
        }
    }
}

// Run the sync service
try {
    $sync = new HyperSpeedSync();
    $sync->run();
} catch (Exception $e) {
    syslog(LOG_ERR, "HyperSpeed Sync fatal error: " . $e->getMessage());
    exit(1);
}
