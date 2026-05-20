import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/weather_map_screen.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Startup diagnostics
  final owmKey = dotenv.env['OPEN_WEATHER_API_KEY'] ?? '';
  debugPrint('[CIRO] .env loaded. OWM key length: ${owmKey.length}, '
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
