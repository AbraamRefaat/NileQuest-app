import 'dart:async';
import 'package:http/http.dart' as http;
import 'server_config.dart';

/// Keeps the Railway server warm by pinging it periodically
/// This prevents cold start delays when users make requests
class ServerWarmer {
  static Timer? _warmupTimer;
  static bool _isWarming = false;
  
  /// Start periodic server warming (every 10 minutes)
  static void startWarming() {
    if (_isWarming) return;
    
    _isWarming = true;
    print('🔥 Server warmer started - keeping Railway server alive');
    
    // Warm immediately on start
    _warmServer();
    
    // Then warm every 10 minutes (Railway sleeps after 15 min of inactivity)
    _warmupTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _warmServer(),
    );
  }
  
  /// Stop the warming service
  static void stopWarming() {
    _warmupTimer?.cancel();
    _warmupTimer = null;
    _isWarming = false;
    print('❄️ Server warmer stopped');
  }
  
  /// Ping the server health endpoint to keep it alive
  static Future<void> _warmServer() async {
    try {
      final baseUrl = await ServerConfig.getServerUrl();
      final uri = Uri.parse('$baseUrl/health');
      
      print('🔥 Warming server at $baseUrl...');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      
      if (response.statusCode == 200) {
        print('✅ Server is warm and ready');
      } else {
        print('⚠️ Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Server warming failed (this is OK): $e');
    }
  }
}
