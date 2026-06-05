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

    // Android Settings: using the default app launcher icon for notifications
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

    // Request permissions and create channel on Android
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();

      // Explicitly create the high-priority channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'ciro_crisis_alerts',
        'Crisis Alerts',
        description: 'Emergency notifications for severe weather events',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidImplementation.createNotificationChannel(channel);
    }
  }

  /// Show a high-importance native notification that pops up on the screen (Heads-up).
  static Future<void> showCrisisNotification({
    required int id,
    required String title,
    required String body,
    required String alertType,
    required String severity,
    String? payload,
  }) async {
    final severityLower = severity.toLowerCase();

    Color themeColor;
    if (severityLower.contains('extreme') || severityLower.contains('high') || severityLower.contains('danger')) {
      themeColor = const Color(0xFFDC2626); // Red
    } else if (severityLower.contains('severe') || severityLower.contains('warning') || severityLower.contains('medium')) {
      themeColor = const Color(0xFFF59E0B); // Amber
    } else if (severityLower.contains('advisory') || severityLower.contains('low') || severityLower.contains('info')) {
      themeColor = const Color(0xFF3B82F6); // Blue
    } else {
      themeColor = const Color(0xFFDC2626); // Default Red
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ciro_crisis_alerts',
      'Crisis Alerts',
      channelDescription: 'Emergency notifications for severe weather events',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: themeColor, // This tints the background circle of the notification icon
      ledColor: themeColor,
      ledOnMs: 1000,
      ledOffMs: 500,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '🚨 $title',
        summaryText: 'Emergency Alert',
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'open_resources',
          'Open Emergency Resources',
          showsUserInterface: true,
        ),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(
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
