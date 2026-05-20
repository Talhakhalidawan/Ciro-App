/// Professional API Configuration and Connectivity Hub for CIRO.
/// This file acts as the single source of truth for all network routing, domains, and endpoint declarations.
class ApiConfig {
  /// Base API Domain/URL configuration.
  /// Automatically uses the production URL during GitHub Actions build, and defaults to your local IP for debug runs.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://192.168.43.33:8000');

  /// Endpoint Path Paths
  static const String _weatherEndpoint = "/api/weather/";

  /// Dynamic URL Getter
  static Uri get weatherUri => Uri.parse("$baseUrl$_weatherEndpoint");

  /// Global Network Configurations
  static const Duration requestTimeout = Duration(seconds: 60);
}
