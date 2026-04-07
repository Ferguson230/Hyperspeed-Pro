#!/usr/bin/env php
<?php
/**
 * HyperSpeed Pro - Advanced Security Module
 * 
 * Enterprise-grade security with DDoS protection, rate limiting,
 * bot detection, and threat intelligence.
 * 
 * @package HyperSpeed Pro
 * @version 1.0.0
 */

namespace HyperSpeed\Security;

class SecurityEngine
{
    private $redis;
    private $config;
    private $threatDb;
    
    const RATE_LIMIT_PREFIX = 'ratelimit:';
    const BLACKLIST_PREFIX = 'blacklist:';
    const THREAT_DB_FILE = '/etc/hyperspeed_pro/threat_db.json';
    
    public function __construct($config)
    {
        $this->config = $config;
        $this->redis = new \Redis();
        $this->redis->connect('127.0.0.1', 6379);
        $this->loadThreatDatabase();
    }
    
    /**
     * Load threat intelligence database
     */
    private function loadThreatDatabase()
    {
        if (file_exists(self::THREAT_DB_FILE)) {
            $this->threatDb = json_decode(file_get_contents(self::THREAT_DB_FILE), true);
        } else {
            $this->threatDb = [
                'malicious_ips' => [],
                'malicious_user_agents' => [],
                'attack_patterns' => []
            ];
        }
    }
    
    /**
     * Check if request should be blocked
     */
    public function checkRequest($ip, $userAgent, $uri)
    {
        // Check blacklist
        if ($this->isBlacklisted($ip)) {
            $this->logSecurity("Blocked blacklisted IP: $ip", 'BLOCK');
            return [
                'allowed' => false,
                'reason' => 'Blacklisted IP',
                'code' => 403
            ];
        }
        
        // Rate limiting
        if ($this->config['security']['rate_limiting']) {
            $rateCheck = $this->checkRateLimit($ip);
            if (!$rateCheck['allowed']) {
                return $rateCheck;
            }
        }
        
        // DDoS protection
        if ($this->config['security']['ddos_protection']) {
            $ddosCheck = $this->detectDDoS($ip);
            if (!$ddosCheck['allowed']) {
                return $ddosCheck;
            }
        }
        
        // Bot detection
        if ($this->config['security']['bot_detection']) {
            $botCheck = $this->detectBot($userAgent, $ip);
            if ($botCheck['is_bad_bot']) {
                return [
                    'allowed' => false,
                    'reason' => 'Malicious bot detected',
                    'code' => 403
                ];
            }
        }
        
        // SQL injection detection
        if ($this->detectSQLInjection($uri)) {
            $this->logSecurity("SQL injection attempt detected from $ip: $uri", 'CRITICAL');
            $this->blacklistIP($ip, 3600);
            return [
                'allowed' => false,
                'reason' => 'Security violation detected',
                'code' => 403
            ];
        }
        
        // XSS detection
        if ($this->detectXSS($uri)) {
            $this->logSecurity("XSS attempt detected from $ip: $uri", 'CRITICAL');
            return [
                'allowed' => false,
                'reason' => 'Security violation detected',
                'code' => 403
            ];
        }
        
        return [
            'allowed' => true,
            'reason' => 'OK'
        ];
    }
    
    /**
     * Advanced rate limiting with burst capability
     */
    private function checkRateLimit($ip)
    {
        $key = self::RATE_LIMIT_PREFIX . $ip;
        $now = time();
        
        // Get current request count
        $requests = $this->redis->get($key);
        
        if ($requests === false) {
            // First request in this window
            $this->redis->setex($key, 60, 1);
            return ['allowed' => true];
        }
        
        $requests = (int)$requests;
        
        // Allow burst of 100 requests per minute
        $limit = 100;
        $burstLimit = 500; // Allow 500 for short bursts
        
        // Check if this is part of a DDoS attack
        if ($requests > $burstLimit) {
            $this->blacklistIP($ip, 300); // 5 minute blacklist
            $this->logSecurity("Rate limit exceeded (burst): $ip ($requests requests)", 'WARN');
            return [
                'allowed' => false,
                'reason' => 'Rate limit exceeded',
                'code' => 429,
                'retry_after' => 60
            ];
        }
        
        if ($requests > $limit) {
            $this->logSecurity("Rate limit exceeded: $ip ($requests requests)", 'WARN');
            return [
                'allowed' => false,
                'reason' => 'Rate limit exceeded',
                'code' => 429,
                'retry_after' => 60
            ];
        }
        
        $this->redis->incr($key);
        return ['allowed' => true];
    }
    
    /**
     * DDoS detection using pattern analysis
     */
    private function detectDDoS($ip)
    {
        $key = 'ddos:' . $ip;
        $window = 10; // 10 second window
        $threshold = 200; // 200 requests in 10 seconds
        
        $count = $this->redis->get($key);
        
        if ($count === false) {
            $this->redis->setex($key, $window, 1);
            return ['allowed' => true];
        }
        
        $count = (int)$count;
        
        if ($count > $threshold) {
            $this->blacklistIP($ip, 3600); // 1 hour blacklist
            $this->logSecurity("DDoS attack detected from $ip", 'CRITICAL');
            return [
                'allowed' => false,
                'reason' => 'DDoS attack detected',
                'code' => 403
            ];
        }
        
        $this->redis->incr($key);
        return ['allowed' => true];
    }
    
    /**
     * Intelligent bot detection
     */
    private function detectBot($userAgent, $ip)
    {
        // Good bots (allow)
        $goodBots = [
            'Googlebot', 'bingbot', 'Slurp', 'DuckDuckBot',
            'Baiduspider', 'YandexBot', 'facebookexternalhit'
        ];
        
        foreach ($goodBots as $bot) {
            if (stripos($userAgent, $bot) !== false) {
                return ['is_bot' => true, 'is_bad_bot' => false, 'type' => 'good'];
            }
        }
        
        // Bad bot patterns
        $badBotPatterns = [
            'sqlmap', 'nikto', 'nmap', 'masscan', 'nessus',
            'scrapy', 'python-requests', 'curl', 'wget',
            'bot', 'crawler', 'spider', 'scraper'
        ];
        
        $lowerUA = strtolower($userAgent);
        foreach ($badBotPatterns as $pattern) {
            if (strpos($lowerUA, $pattern) !== false) {
                // Additional validation for legitimate tools
                if (!$this->isLegitimateBot($ip, $userAgent)) {
                    $this->logSecurity("Bad bot detected: $userAgent from $ip", 'WARN');
                    return ['is_bot' => true, 'is_bad_bot' => true, 'type' => 'malicious'];
                }
            }
        }
        
        // Check for missing or suspicious User-Agent
        if (empty($userAgent) || strlen($userAgent) < 10) {
            return ['is_bot' => true, 'is_bad_bot' => true, 'type' => 'suspicious'];
        }
        
        return ['is_bot' => false, 'is_bad_bot' => false];
    }
    
    /**
     * Verify legitimate bots through reverse DNS
     */
    private function isLegitimateBot($ip, $userAgent)
    {
        // Verify Googlebot
        if (stripos($userAgent, 'Googlebot') !== false) {
            $hostname = gethostbyaddr($ip);
            return (strpos($hostname, 'googlebot.com') !== false || 
                    strpos($hostname, 'google.com') !== false);
        }
        
        // Verify Bingbot
        if (stripos($userAgent, 'bingbot') !== false) {
            $hostname = gethostbyaddr($ip);
            return strpos($hostname, 'search.msn.com') !== false;
        }
        
        return false;
    }
    
    /**
     * SQL injection pattern detection
     */
    private function detectSQLInjection($input)
    {
        $sqlPatterns = [
            '/(\s|^)(union|select|insert|update|delete|drop|create|alter|exec|execute)(\s|$)/i',
            '/(\s|^)(or|and)\s*[\d\w]+\s*=\s*[\d\w]+/i',
            '/--/',
            '/\/\*.*\*\//',
            '/;.*--/',
            '/benchmark\s*\(/i',
            '/sleep\s*\(/i',
            '/waitfor\s+delay/i'
        ];
        
        foreach ($sqlPatterns as $pattern) {
            if (preg_match($pattern, $input)) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * XSS pattern detection
     */
    private function detectXSS($input)
    {
        $xssPatterns = [
            '/<script[^>]*>.*<\/script>/i',
            '/javascript:/i',
            '/on\w+\s*=/i', // Event handlers
            '/<iframe/i',
            '/<embed/i',
            '/<object/i',
            '/eval\s*\(/i',
            '/expression\s*\(/i'
        ];
        
        foreach ($xssPatterns as $pattern) {
            if (preg_match($pattern, $input)) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Add IP to blacklist
     */
    public function blacklistIP($ip, $duration = 3600)
    {
        $key = self::BLACKLIST_PREFIX . $ip;
        $this->redis->setex($key, $duration, time());
        $this->logSecurity("IP blacklisted: $ip for {$duration}s", 'WARN');
    }
    
    /**
     * Check if IP is blacklisted
     */
    public function isBlacklisted($ip)
    {
        $key = self::BLACKLIST_PREFIX . $ip;
        return $this->redis->exists($key);
    }
    
    /**
     * Remove IP from blacklist
     */
    public function whitelistIP($ip)
    {
        $key = self::BLACKLIST_PREFIX . $ip;
        $this->redis->del($key);
        $this->logSecurity("IP whitelisted: $ip", 'INFO');
    }
    
    /**
     * Get security headers
     */
    public function getSecurityHeaders()
    {
        $headers = [];
        
        if (isset($this->config['security']['headers'])) {
            $cfg = $this->config['security']['headers'];
            
            if (isset($cfg['x_frame_options'])) {
                $headers['X-Frame-Options'] = $cfg['x_frame_options'];
            }
            
            if (isset($cfg['x_content_type_options'])) {
                $headers['X-Content-Type-Options'] = $cfg['x_content_type_options'];
            }
            
            if (isset($cfg['x_xss_protection'])) {
                $headers['X-XSS-Protection'] = $cfg['x_xss_protection'];
            }
            
            // Additional security headers
            $headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload';
            $headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';";
            $headers['Referrer-Policy'] = 'strict-origin-when-cross-origin';
            $headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()';
        }
        
        return $headers;
    }
    
    /**
     * Log security event
     */
    private function logSecurity($message, $level = 'INFO')
    {
        $timestamp = date('Y-m-d H:i:s');
        $logFile = '/var/log/hyperspeed_pro/security.log';
        $logMessage = "[$timestamp] [$level] $message\n";
        file_put_contents($logFile, $logMessage, FILE_APPEND);
        
        // Also increment security metrics
        $key = "security:events:$level:" . date('Y-m-d');
        $this->redis->incr($key);
        $this->redis->expire($key, 86400 * 30); // 30 days retention
    }
    
    /**
     * Get security statistics
     */
    public function getSecurityStats()
    {
        $stats = [
            'blocked_requests' => 0,
            'rate_limited' => 0,
            'blacklisted_ips' => 0,
            'ddos_attacks' => 0
        ];
        
        // Count blacklisted IPs
        $blacklistedKeys = $this->redis->keys(self::BLACKLIST_PREFIX . '*');
        $stats['blacklisted_ips'] = count($blacklistedKeys);
        
        // Get event counts from last 24 hours
        $eventKeys = $this->redis->keys('security:events:*:' . date('Y-m-d'));
        foreach ($eventKeys as $key) {
            $stats['blocked_requests'] += (int)$this->redis->get($key);
        }
        
        return $stats;
    }
}
