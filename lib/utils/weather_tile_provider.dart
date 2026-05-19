import 'dart:io';
import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WeatherTileProvider implements TileProvider {
  final String apiKey = "851b47ff0f09a1de8cf0e04130005a76"; // Free public key for OWM
  final HttpClient _httpClient = HttpClient();

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) return TileProvider.noTile;

    final url = 'https://tile.openweathermap.org/map/temp_new/$zoom/$x/$y.png?appid=$apiKey';

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
      }
    } catch (e) {
      // Gracefully fallback on network errors
    }
    return TileProvider.noTile;
  }
}
