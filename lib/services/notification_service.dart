import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Centralized service to manage real native Android & iOS notifications.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static ValueChanged<String?>? _onNotificationTapped;

  /// Initialize the notification service and request permissions on Android/iOS.
  static Future<void> init({ValueChanged<String?>? onNotificationTapped}) async {
    _onNotificationTapped = onNotificationTapped;

    // Android Settings: using standard app icon (ic_launcher or ic_stat_name)
    // On Flutter, @mipmap/ic_launcher is always available.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (_onNotificationTapped != null) {
          _onNotificationTapped!(response.payload);
        }
      },
    );

    // Request permissions on Android 13+
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Show a high-importance native notification that pops up on the screen (Heads-up).
  static Future<void> showCrisisNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ciro_crisis_alerts', // Channel ID
      'Crisis Alerts', // Channel Name
      channelDescription: 'Real-time emergency and anomaly alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }
}
