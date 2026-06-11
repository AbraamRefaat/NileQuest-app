import 'package:shared_preferences/shared_preferences.dart';

/// Dynamic server configuration manager with automatic discovery
class ServerConfig {
  static const String _keyServerUrl = 'discovered_server_url';
  static const String _keyLastDiscovery = 'last_discovery_time';

  /// Get the current server URL (using Railway production URL)
  static Future<String> getServerUrl() async {
    print('📍 Using production recommendation server');
    return _getDefaultUrl();
  }
  
  /// Get default URL based on platform
  static String _getDefaultUrl() {
    return 'http://15.228.191.11:8000';
  }
  
  /// Force re-discovery of server (clears cache)
  static Future<String> rediscoverServer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    await prefs.remove(_keyLastDiscovery);
    return await getServerUrl();
  }
  
  /// Clear all cached data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    await prefs.remove(_keyLastDiscovery);
  }
}
