import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

/// Dedicated Weather API Service to handle environmental, traffic, and emergency hazard POST queries.
class WeatherService {
  /// Submits the current coordinates and user payload metadata to the local sentinel server.
  /// Bypasses active database persistent entries or anomaly checking runs via `use_mock: true`.
  static Future<Map<String, dynamic>> fetchMockWeatherDetails({
    required String username,
    required double latitude,
    required double longitude,
    required String cityName,
    bool forceCrisis = false,
  }) async {
    final response = await http.post(
      ApiConfig.weatherUri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": username,
        "latitude": latitude,
        "longitude": longitude,
        "time": DateTime.now().toIso8601String(),
        "city_name": cityName,
        "use_mock": true,
        "force_crisis": forceCrisis,
      }),
    ).timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Server failed with status code: ${response.statusCode}");
    }
  }
}
