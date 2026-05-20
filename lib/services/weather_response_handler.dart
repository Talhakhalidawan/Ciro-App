/// Centralized response handler for all backend weather & crisis data.
///
/// This class parses the raw JSON response from the backend and exposes
/// clean, typed properties that the UI layer can consume directly.
/// It also stores the user's resolved city name so the entire app displays
/// the correct location.
class WeatherResponseHandler {
  // ── Resolved location ───────────────────────────────────────────────
  String cityName;
  String regionAndCountry;

  // ── Core weather metrics ────────────────────────────────────────────
  double temperatureC;
  double feelsLikeC;
  int humidityPct;
  double precipitationMm;
  double windSpeedKmh;
  double windGustsKmh;
  int weatherCode;
  int aqi;
  int activeFiresNearby;

  // ── Traffic ─────────────────────────────────────────────────────────
  int trafficIncidentCount;
  List<Map<String, dynamic>> trafficIncidents;

  // ── Crisis / Alert ──────────────────────────────────────────────────
  bool hasCrisis;
  Map<String, dynamic>? alertData;

  WeatherResponseHandler({
    this.cityName = 'Unknown',
    this.regionAndCountry = 'Unknown',
    this.temperatureC = 0,
    this.feelsLikeC = 0,
    this.humidityPct = 0,
    this.precipitationMm = 0,
    this.windSpeedKmh = 0,
    this.windGustsKmh = 0,
    this.weatherCode = 0,
    this.aqi = 0,
    this.activeFiresNearby = 0,
    this.trafficIncidentCount = 0,
    this.trafficIncidents = const [],
    this.hasCrisis = false,
    this.alertData,
  });

  /// Parse a raw backend JSON map and return a fully populated handler.
  factory WeatherResponseHandler.fromResponse(Map<String, dynamic> json) {
    final env = json['environment'] as Map<String, dynamic>? ?? {};
    final traffic = json['traffic'] as Map<String, dynamic>? ?? {};
    final alert = json['alert'] as Map<String, dynamic>?;

    // ── Parse top_posts into flat list of individual items ────────────
    // Backend sends: [{platform, query, items: [{title, snippet, url}]}]
    // We flatten to: [{platform, title, snippet, url}]
    List<Map<String, dynamic>> flattenedPosts = [];
    if (alert != null) {
      final topPosts = alert['top_posts'] as List<dynamic>? ?? [];
      for (final platformGroup in topPosts) {
        if (platformGroup is Map<String, dynamic>) {
          final platform = platformGroup['platform']?.toString() ?? 'video';
          final items = platformGroup['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              flattenedPosts.add({
                'platform': platform,
                'title': item['title'] ?? 'Video Report',
                'snippet': item['snippet'] ?? '',
                'url': item['url'] ?? '',
              });
            }
          }
        }
      }

      // Replace top_posts with our flattened version
      alert['top_posts'] = flattenedPosts;
    }

    // ── Parse traffic incidents ───────────────────────────────────────
    final rawIncidents = traffic['incidents'] as List<dynamic>? ?? [];
    final parsedIncidents = rawIncidents
        .whereType<Map<String, dynamic>>()
        .toList();

    return WeatherResponseHandler(
      cityName: json['location_name']?.toString() ?? 'Unknown',
      regionAndCountry: json['region_and_country']?.toString() ?? 'Unknown',
      temperatureC: _toDouble(env['temperature_c']),
      feelsLikeC: _toDouble(env['feels_like_c']),
      humidityPct: _toInt(env['humidity_pct']),
      precipitationMm: _toDouble(env['precipitation_mm']),
      windSpeedKmh: _toDouble(env['wind_speed_kmh']),
      windGustsKmh: _toDouble(env['wind_gusts_kmh']),
      weatherCode: _toInt(env['weather_code']),
      aqi: _toInt(env['aqi']),
      activeFiresNearby: _toInt(env['active_fires_nearby']),
      trafficIncidentCount: _toInt(traffic['incident_count']),
      trafficIncidents: parsedIncidents,
      hasCrisis: alert != null && (alert['type']?.toString() ?? 'safe') != 'safe',
      alertData: alert,
    );
  }

  // ── Display-ready getters ──────────────────────────────────────────

  String get temperatureDisplay => '${temperatureC.round()}°C';
  String get feelsLikeDisplay => '${feelsLikeC.round()}°C';
  String get humidityDisplay => '$humidityPct%';
  String get windSpeedDisplay => '${windSpeedKmh.round()} km/h';
  String get aqiDisplay => '$aqi';
  String get alertTitle => alertData?['title']?.toString() ?? '';
  String get alertDetails => alertData?['details']?.toString() ?? '';

  // ── Utility helpers ────────────────────────────────────────────────

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
