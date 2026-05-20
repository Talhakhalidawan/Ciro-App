/// Central Configuration Hub for CIRO.
/// This file acts as the single source of truth for all network routing, domains, endpoint declarations, and app settings.
class AppConfig {
  /// Base API Domain/URL configuration.
  /// Automatically uses the production URL during GitHub Actions build, and defaults to your local IP for debug runs.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://192.168.43.33:8000');

  /// Endpoint Path Paths
  static const String _weatherEndpoint = "/api/weather/";
  static const String _communityListEndpoint = "/api/community/incidents/";
  static const String _communityCreateEndpoint = "/api/community/incidents/create/";

  /// Dynamic URL Getters
  static Uri get weatherUri => Uri.parse("$baseUrl$_weatherEndpoint");
  static Uri get communityListUri => Uri.parse("$baseUrl$_communityListEndpoint");
  static Uri get communityCreateUri => Uri.parse("$baseUrl$_communityCreateEndpoint");

  /// Global Network Configurations
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Weather check interval in minutes.
  /// Change this value for debugging (e.g. set to 1 for quick testing).
  /// The backend can also override this dynamically via the 'interval_minutes' response field.
  static const int checkIntervalMinutes = 1;

  /// Community feed polling interval in seconds (for near-real-time updates)
  static const int communityPollIntervalSeconds = 15;
}
