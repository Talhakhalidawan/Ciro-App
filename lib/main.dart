import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/weather_map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Startup diagnostics
  final owmKey = dotenv.env['OPEN_WEATHER_API_KEY'] ?? '';
  debugPrint('[CIRO] .env loaded. OWM key length: ${owmKey.length}, '
      'first 8 chars: ${owmKey.length >= 8 ? owmKey.substring(0, 8) : owmKey}...');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const WeatherMapScreen(),
    );
  }
}
