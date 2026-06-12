import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications — used by the trip session to nudge the tourist
/// to take photos when they arrive at a stop (BeReal style).
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Callback when the user taps the notification (payload = stop index)
  void Function(String payload)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          onNotificationTap?.call(response.payload!);
        }
      },
    );
    // Android 13+ runtime permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showStopArrivalNotification({
    required int stopIndex,
    required String stopName,
  }) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trip_stops',
        'Trip Stops',
        channelDescription: 'Photo reminders when you arrive at a stop',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      stopIndex,
      '📸 You made it to $stopName!',
      'Time to NileReal! Capture 3 photos of this moment ✨',
      details,
      payload: stopIndex.toString(),
    );
  }

  Future<void> showTripCompleteNotification() async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trip_stops',
        'Trip Stops',
        channelDescription: 'Photo reminders when you arrive at a stop',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      9999,
      '🎉 Trip complete!',
      'Your NileQuest Wrapped is ready — see your day in photos!',
      details,
      payload: 'wrapped',
    );
  }
}
