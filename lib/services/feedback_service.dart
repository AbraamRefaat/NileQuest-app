import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback.dart';

/// Sends user feedback to the trip backend with an offline queue.
///
/// Fire-and-forget by design: never throws, never blocks UX. Anything that
/// can't be delivered (no network, endpoint not deployed yet) is queued in
/// SharedPreferences and flushed on the next submission or app start.
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  static const String _baseUrl = 'https://trip-backend-iota.vercel.app';
  static String get _feedbackUrl => '$_baseUrl/api/feedback';
  static const String _queueKey = 'feedback_queue_v1';
  static const int _maxQueue = 50;
  static const Duration _timeout = Duration(seconds: 8);

  /// Lazily created so the singleton can be constructed in tests before a
  /// mock client is injected. Swappable for tests.
  http.Client? _httpClient;
  http.Client get httpClient => _httpClient ??= http.Client();
  set httpClient(http.Client client) => _httpClient = client;

  Future<void> submitStopFeedback(StopFeedback feedback) =>
      _submit({'type': 'stop', 'data': feedback.toJson()});

  Future<void> submitTripFeedback(TripFeedback feedback) =>
      _submit({'type': 'trip', 'data': feedback.toJson()});

  Future<void> _submit(Map<String, dynamic> payload) async {
    await flushQueue();
    final delivered = await _post(payload);
    if (!delivered) {
      await _enqueue(payload);
    }
  }

  /// Drains the queue front-to-back, stopping at the first failure.
  Future<void> flushQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? [];
      if (queue.isEmpty) return;

      var delivered = 0;
      for (final raw in queue) {
        final ok = await _post(jsonDecode(raw) as Map<String, dynamic>);
        if (!ok) break;
        delivered++;
      }
      if (delivered > 0) {
        await prefs.setStringList(_queueKey, queue.sublist(delivered));
        print('📨 [FeedbackService] Flushed $delivered queued feedback item(s).');
      }
    } catch (e) {
      print('⚠️ [FeedbackService] flushQueue error: $e');
    }
  }

  Future<bool> _post(Map<String, dynamic> payload) async {
    try {
      final response = await httpClient
          .post(
            Uri.parse(_feedbackUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? [];
      queue.add(jsonEncode(payload));
      // Cap the queue; drop oldest first.
      while (queue.length > _maxQueue) {
        queue.removeAt(0);
      }
      await prefs.setStringList(_queueKey, queue);
      print('📥 [FeedbackService] Feedback queued (${queue.length} pending).');
    } catch (e) {
      print('⚠️ [FeedbackService] enqueue error: $e');
    }
  }

  /// Pending queue size (for tests/diagnostics).
  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? []).length;
  }
}
