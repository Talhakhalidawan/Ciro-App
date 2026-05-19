import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Supported OpenWeatherMap tile layer types.
enum OWMLayer {
  temperature('temp_new'),
  clouds('clouds_new'),
  precipitation('precipitation_new');

  final String endpoint;
  const OWMLayer(this.endpoint);
}

/// A reusable [TileProvider] that fetches OpenWeatherMap Weather Maps 1.0 tiles.
class OWMTileProvider implements TileProvider {
  final OWMLayer layer;
  final String _apiKey;
  final HttpClient _httpClient = HttpClient();

  OWMTileProvider({required this.layer})
      : _apiKey = _resolveApiKey() {
    debugPrint('[OWMTileProvider] Initialized ${layer.endpoint} with key length: ${_resolveApiKey().length}');
  }

  static String _resolveApiKey() {
    final key = dotenv.env['OPEN_WEATHER_API_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint('[OWMTileProvider] WARNING: OPEN_WEATHER_API_KEY not found in .env!');
    }
    return key;
  }

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null || _apiKey.isEmpty) return TileProvider.noTile;

    final url =
        'https://tile.openweathermap.org/map/${layer.endpoint}/$zoom/$x/$y.png?appid=$_apiKey';

    try {
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytesBuilder = BytesBuilder();
        await for (var chunk in response) {
          bytesBuilder.add(chunk);
        }
        final Uint8List bytes = bytesBuilder.toBytes();
        return Tile(256, 256, bytes);
      } else {
        debugPrint(
            '[OWMTileProvider] HTTP ${response.statusCode} for ${layer.endpoint} tile z=$zoom x=$x y=$y | key=${_apiKey.substring(0, 8)}...');
      }
    } catch (e) {
      debugPrint('[OWMTileProvider] Error fetching ${layer.endpoint} tile: $e');
    }
    return TileProvider.noTile;
  }
}
