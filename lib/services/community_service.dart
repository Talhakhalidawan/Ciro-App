import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

/// Service for Community Incident API calls.
class CommunityService {
  /// Fetch incidents near the user's location.
  /// [sinceId] enables incremental fetching (only new incidents).
  static Future<Map<String, dynamic>> fetchIncidents({
    required double latitude,
    required double longitude,
    int sinceId = 0,
  }) async {
    final uri = AppConfig.communityListUri.replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      if (sinceId > 0) 'since_id': sinceId.toString(),
    });

    final response = await http.get(uri).timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to fetch incidents: ${response.statusCode}");
    }
  }

  /// Create a new community incident report.
  static Future<Map<String, dynamic>> createIncident({
    required String userId,
    required String title,
    required String description,
    required String incidentType,
    required double latitude,
    required double longitude,
    required double userLatitude,
    required double userLongitude,
    double radiusKm = 1.0,
    List<Map<String, double>>? customBoundary,
  }) async {
    final response = await http.post(
      AppConfig.communityCreateUri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "title": title,
        "description": description,
        "incident_type": incidentType,
        "latitude": latitude,
        "longitude": longitude,
        "radius_km": radiusKm,
        "user_latitude": userLatitude,
        "user_longitude": userLongitude,
        if (customBoundary != null) "custom_boundary": customBoundary,
      }),
    ).timeout(AppConfig.requestTimeout);

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? "Failed to create incident");
    }
  }
}
