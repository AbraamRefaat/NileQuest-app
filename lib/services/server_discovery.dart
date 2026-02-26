import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:udp/udp.dart';

/// Automatic server discovery - finds the Python API on the network
class ServerDiscovery {
  static const int serverPort = 8000;
  static const String healthEndpoint = '/health';
  static const int broadcastPort = 37020;
  
  /// Automatically discover the server on the network
  static Future<String?> discoverServer() async {
    print('🔍 Starting automatic server discovery...');
    
    // Try localhost/emulator addresses first (fastest)
    final quickTests = await _tryQuickAddresses();
    if (quickTests != null) {
      print('✅ Found server at: $quickTests');
      return quickTests;
    }
    
    // Try UDP broadcast discovery (NEW - most reliable)
    print('📡 Listening for server broadcasts...');
    final broadcast = await _listenForBroadcast();
    if (broadcast != null) {
      print('✅ Found server via broadcast: $broadcast');
      return broadcast;
    }
    
    // Then try network discovery for physical devices
    final discovered = await _scanNetwork();
    if (discovered != null) {
      print('✅ Found server at: $discovered');
      return discovered;
    }
    
    print('❌ Could not find server automatically');
    return null;
  }
  
  /// Listen for UDP broadcasts from server
  static Future<String?> _listenForBroadcast() async {
    try {
      final receiver = await UDP.bind(Endpoint.any(port: Port(broadcastPort)));
      
      print('🎧 Listening for broadcasts on port $broadcastPort...');
      
      // Listen for 5 seconds
      final completer = Completer<String?>();
      
      StreamSubscription? subscription;
      subscription = receiver.asStream(timeout: const Duration(seconds: 5)).listen(
        (datagram) {
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            print('📨 Received: $message');
            
            // Expected format: "NILEQUEST_SERVER:192.168.1.100:8000"
            if (message.startsWith('NILEQUEST_SERVER:')) {
              final parts = message.split(':');
              if (parts.length >= 3) {
                final ip = parts[1];
                final port = parts[2];
                final url = 'http://$ip:$port';
                print('✅ Discovered server: $url');
                
                if (!completer.isCompleted) {
                  completer.complete(url);
                  subscription?.cancel();
                  receiver.close();
                }
              }
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          receiver.close();
        },
        onError: (error) {
          print('❌ Broadcast listen error: $error');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          receiver.close();
        },
      );
      
      return await completer.future;
    } catch (e) {
      print('❌ Broadcast discovery error: $e');
      return null;
    }
  }
  
  /// Try common addresses first (emulator, localhost)
  static Future<String?> _tryQuickAddresses() async {
    final addresses = [
      'http://10.0.2.2:$serverPort',    // Android Emulator
      'http://127.0.0.1:$serverPort',   // iOS Simulator / Desktop
      'http://localhost:$serverPort',   // Desktop
    ];
    
    for (final url in addresses) {
      if (await _testUrl(url)) {
        return url;
      }
    }
    return null;
  }
  
  /// Scan local network to find the server
  static Future<String?> _scanNetwork() async {
    try {
      // Get device's IP address
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP == null) {
        print('📱 Not connected to WiFi, cannot scan network');
        return null;
      }
      
      print('📱 Device IP: $wifiIP');
      
      // Extract network prefix (e.g., "192.168.1" from "192.168.1.45")
      final parts = wifiIP.split('.');
      if (parts.length != 4) return null;
      
      final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      print('🌐 Scanning network: $networkPrefix.0/24');
      
      // Comprehensive IP list - scan full subnet in batches
      final ipsToScan = <int>[];
      
      // Start with most common IPs
      ipsToScan.addAll([1, 2, 3, 4, 5, 10, 100, 101, 102, 103, 104, 105]);
      
      // Add all IPs from 1-254 (full subnet)
      for (int i = 1; i <= 254; i++) {
        if (!ipsToScan.contains(i)) {
          ipsToScan.add(i);
        }
      }
      
      print('🔍 Scanning ${ipsToScan.length} possible IPs...');
      
      // Scan in batches of 50 for better performance
      for (int batch = 0; batch < ipsToScan.length; batch += 50) {
        final batchEnd = (batch + 50).clamp(0, ipsToScan.length);
        final batchIPs = ipsToScan.sublist(batch, batchEnd);
        
        print('   Batch ${(batch ~/ 50) + 1}: Testing IPs ${batchIPs.first}-${batchIPs.last}...');
        
        // Test batch in parallel
        final futures = <Future<String?>>[];
        for (final ip in batchIPs) {
          final url = 'http://$networkPrefix.$ip:$serverPort';
          futures.add(_testUrlWithResult(url));
        }
        
        // Wait for batch to complete
        final results = await Future.wait(futures);
        
        // Return first successful result
        for (final result in results) {
          if (result != null) {
            print('✅ Server found at: $result');
            return result;
          }
        }
      }
      
      print('❌ Scanned entire network, server not found');
      return null;
    } catch (e) {
      print('❌ Network scan error: $e');
      return null;
    }
  }
  
  /// Test if URL is accessible
  static Future<bool> _testUrl(String url) async {
    try {
      final uri = Uri.parse('$url$healthEndpoint');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 2),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Test URL and return it if successful
  static Future<String?> _testUrlWithResult(String url) async {
    try {
      final uri = Uri.parse('$url$healthEndpoint');
      final response = await http.get(uri).timeout(
        const Duration(milliseconds: 2000), // Increased timeout
      );
      if (response.statusCode == 200) {
        print('   ✓ Found server: $url');
        return url;
      }
    } catch (e) {
      // Silent fail for parallel testing
    }
    return null;
  }
}
