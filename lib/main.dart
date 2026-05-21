import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'screens/weather_map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/weather_service.dart';
import 'services/weather_response_handler.dart';
import 'services/community_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Startup diagnostics
  const owmKey = String.fromEnvironment('OPEN_WEATHER_API_KEY', defaultValue: '');
  debugPrint('[CIRO] Environment loaded. OWM key length: ${owmKey.length}');

  // Initialize notifications first
  await NotificationService.init();

  // Initialize and start the premium background service
  await initializeBackgroundService();

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  runApp(MyApp(onboardingCompleted: onboardingCompleted));
}

/// Configure and start the real-time background service
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'ciro_crisis_alerts', // Use high-priority channel
      initialNotificationTitle: 'CIRO Safety Guard Active',
      initialNotificationContent: 'Monitoring weather anomalies and nearby emergency incident reports in real-time.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Re-init notifications inside the isolate
  await NotificationService.init();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Background state indicators
  int lastSeenIncidentId = 0;
  DateTime lastWeatherCheck = DateTime.fromMillisecondsSinceEpoch(0);

  // Attempt to recover last seen incident ID from shared preferences
  try {
    final initialPrefs = await SharedPreferences.getInstance();
    lastSeenIncidentId = initialPrefs.getInt('bg_last_seen_incident_id') ?? 0;
  } catch (e) {
    debugPrint('[BG Service] Initial shared_preferences read failed: $e');
  }

  // Poll continuously every 10 seconds for real-time instant alerts
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('user_lat');
      final lon = prefs.getDouble('user_lon');
      final username = prefs.getString('user_name') ?? 'unknown';
      final city = prefs.getString('user_city') ?? '';

      if (lat == null || lon == null) return;

      // ── 1. COMMUNITY INCIDENTS SCAN ──
      try {
        final communityData = await CommunityService.fetchIncidents(
          latitude: lat,
          longitude: lon,
          sinceId: lastSeenIncidentId,
        );
        final List<dynamic> incidents = communityData['incidents'] ?? [];
        if (incidents.isNotEmpty) {
          int highestId = lastSeenIncidentId;
          for (final inc in incidents) {
            final id = inc['id'] as int;
            if (id > highestId) highestId = id;

            final notify = inc['notify'] as bool? ?? false;
            // Only notify for new incidents that occurred while out/active
            if (notify && id > lastSeenIncidentId) {
              final type = inc['incident_type'] as String? ?? 'other';
              await NotificationService.showCrisisNotification(
                id: 2000 + id,
                title: '📢 ${inc['title']}',
                body: '${inc['description']} (${inc['distance_km']}km away)',
                alertType: type,
                severity: 'medium',
                payload: 'community_$id',
              );
            }
          }
          if (highestId > lastSeenIncidentId) {
            lastSeenIncidentId = highestId;
            await prefs.setInt('bg_last_seen_incident_id', lastSeenIncidentId);
          }
        }
      } catch (ce) {
        debugPrint('[BG Service] Incidents check failed: $ce');
      }

      // ── 2. WEATHER ANOMALIES SCAN ──
      final now = DateTime.now();
      // Poll weather service every 15 minutes in the background
      if (now.difference(lastWeatherCheck).inMinutes >= 15) {
        lastWeatherCheck = now;
        try {
          final responseData = await WeatherService.fetchWeatherDetails(
            username: username,
            latitude: lat,
            longitude: lon,
            cityName: city,
          );
          final handler = WeatherResponseHandler.fromResponse(responseData);
          if (handler.hasCrisis) {
            await NotificationService.showCrisisNotification(
              id: 1,
              title: handler.alertTitle,
              body: handler.alertDetails,
              alertType: handler.alertData?['type']?.toString() ?? 'general',
              severity: handler.alertData?['severity']?.toString() ?? 'high',
              payload: 'crisis',
            );
          }
        } catch (we) {
          debugPrint('[BG Service] Weather check failed: $we');
        }
      }
    } catch (e) {
      debugPrint('[BG Service] Outer loop error: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  final bool onboardingCompleted;

  const MyApp({super.key, required this.onboardingCompleted});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIRO Emergency Weather Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: onboardingCompleted ? const WeatherMapScreen() : const OnboardingScreen(),
    );
  }
}
