import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/weather_map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/weather_service.dart';
import 'services/weather_response_handler.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await NotificationService.init(); // Initialize without tap callback for background

      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('user_lat');
      final lon = prefs.getDouble('user_lon');
      final city = prefs.getString('user_city');
      final username = prefs.getString('user_name');

      if (lat != null && lon != null) {
        final responseData = await WeatherService.fetchWeatherDetails(
          username: username ?? 'unknown',
          latitude: lat,
          longitude: lon,
          cityName: city ?? '',
        );

        final handler = WeatherResponseHandler.fromResponse(responseData);

        if (handler.hasCrisis) {
          NotificationService.showCrisisNotification(
            id: 1,
            title: handler.alertTitle,
            body: handler.alertDetails,
            alertType: handler.alertData?['type']?.toString() ?? 'general',
            severity: handler.alertData?['severity']?.toString() ?? 'high',
            payload: 'crisis',
          );
        }
      }
    } catch (e) {
      debugPrint('[Workmanager] Background task failed: $e');
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().initialize(callbackDispatcher);

  // Startup diagnostics
  const owmKey = String.fromEnvironment('OPEN_WEATHER_API_KEY', defaultValue: '');
  debugPrint('[CIRO] Environment loaded. OWM key length: ${owmKey.length}, '
      'first 8 chars: ${owmKey.length >= 8 ? owmKey.substring(0, 8) : owmKey}...');

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  runApp(MyApp(onboardingCompleted: onboardingCompleted));
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
