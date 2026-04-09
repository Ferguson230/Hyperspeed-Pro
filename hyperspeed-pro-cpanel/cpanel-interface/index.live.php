<?php
/**
 * HyperSpeed Pro - cPanel User Interface Entry Point
 *
 * The .live.php suffix is REQUIRED by cPanel's plugin system.
 * install.json references this file as the plugin URI.
 * cPanel wraps this page with the authenticated session so
 * assets at the same relative path are served correctly.
 *
 * Access: https://server:2083/cpsessXXX/frontend/jupiter/hyperspeed/index.live.php
 */
header('Content-Type: text/html; charset=utf-8');
readfile(__DIR__ . '/index.html');
