/// Professional API Configuration and Connectivity Hub for CIRO.
/// This file acts as the single source of truth for all network routing, domains, and endpoint declarations.
class ApiConfig {
  /// Base API Domain/URL configuration.
  /// Simply update this domain path, and all endpoints across the entire application will synchronize instantly.
  static const String baseUrl = "http://192.168.43.33:8000"; // Loopback address for standard Android emulator debug runs

  /// Endpoint Path Paths
  static const String _weatherEndpoint = "/api/weather/";

  /// Dynamic URL Getter
  static Uri get weatherUri => Uri.parse("$baseUrl$_weatherEndpoint");

  /// Global Network Configurations
  static const Duration requestTimeout = Duration(seconds: 8);
}
