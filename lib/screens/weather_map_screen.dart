import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/weather_tile_provider.dart';

class WeatherMapScreen extends StatefulWidget {
  const WeatherMapScreen({super.key});

  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> {
  // Map toggles
  bool _showTraffic = false;
  bool _showHeat = false;
  bool _showClouds = false;
  bool _showRain = false;
  bool _showDanger = true;

  // Whether the layer panel is expanded
  bool _layerPanelOpen = false;

  // OWM Tile Overlays
  late final TileOverlay _heatOverlay;
  late final TileOverlay _cloudsOverlay;
  late final TileOverlay _rainOverlay;

  @override
  void initState() {
    super.initState();
    _heatOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('owm_heat'),
      tileProvider: OWMTileProvider(layer: OWMLayer.temperature),
    );
    _cloudsOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('owm_clouds'),
      tileProvider: OWMTileProvider(layer: OWMLayer.clouds),
    );
    _rainOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('owm_rain'),
      tileProvider: OWMTileProvider(layer: OWMLayer.precipitation),
    );
  }

  Set<TileOverlay> get _activeTileOverlays {
    final Set<TileOverlay> overlays = {};
    if (_showHeat) overlays.add(_heatOverlay);
    if (_showClouds) overlays.add(_cloudsOverlay);
    if (_showRain) overlays.add(_rainOverlay);
    return overlays;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // When danger card is visible, toggles sit above it; otherwise at the bottom
    final double toggleBottomOffset = _showDanger
        ? bottomPad + 24 + 90 + 16 // safeArea + dangerPad + dangerHeight + gap
        : bottomPad + 16;

    return Scaffold(
      body: Stack(
        children: [
          // ── BASE MAP ──
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(33.6844, 73.0479),
              zoom: 12.0,
            ),
            zoomControlsEnabled: false,
            compassEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            tileOverlays: _activeTileOverlays,
            trafficEnabled: _showTraffic,
            mapType: MapType.normal,
          ),

          // ── TOP WEATHER CARD ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sector G-10',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Islamabad, Pakistan',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wb_sunny, color: Colors.orange, size: 18),
                            SizedBox(width: 6),
                            Text(
                              '49°C',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildMetricItem(Icons.air, Colors.red, 'AQI', '120', Colors.red)),
                      _buildMetricDivider(),
                      Expanded(child: _buildMetricItem(Icons.water_drop, Colors.blue, 'Humidity', '42%', Colors.black87)),
                      _buildMetricDivider(),
                      Expanded(child: _buildMetricItem(Icons.wind_power, Colors.teal, 'Wind', '14 km/h', Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── SIDE LAYER PANEL + TOGGLE BUTTON ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: 16,
            bottom: toggleBottomOffset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Expandable layer options
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _layerPanelOpen
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMapToggle(
                                icon: Icons.traffic,
                                label: 'Traffic',
                                isActive: _showTraffic,
                                onTap: () => setState(() => _showTraffic = !_showTraffic),
                              ),
                              const SizedBox(height: 16),
                              _buildMapToggle(
                                icon: Icons.thermostat,
                                label: 'Heat',
                                isActive: _showHeat,
                                iconColor: Colors.deepOrange,
                                onTap: () => setState(() => _showHeat = !_showHeat),
                              ),
                              const SizedBox(height: 16),
                              _buildMapToggle(
                                icon: Icons.cloud,
                                label: 'Clouds',
                                isActive: _showClouds,
                                onTap: () => setState(() => _showClouds = !_showClouds),
                              ),
                              const SizedBox(height: 16),
                              _buildMapToggle(
                                icon: Icons.water_drop,
                                label: 'Rain',
                                isActive: _showRain,
                                iconColor: Colors.blue,
                                onTap: () => setState(() => _showRain = !_showRain),
                              ),
                              const SizedBox(height: 8),
                              Container(height: 1, width: 30, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              _buildMapToggle(
                                icon: Icons.warning_amber_rounded,
                                label: 'Danger',
                                isActive: _showDanger,
                                iconColor: Colors.red,
                                onTap: () => setState(() => _showDanger = !_showDanger),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Layers toggle button (always visible)
                GestureDetector(
                  onTap: () => setState(() => _layerPanelOpen = !_layerPanelOpen),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _layerPanelOpen ? Icons.close : Icons.layers_outlined,
                      color: _layerPanelOpen ? Colors.red : Colors.black87,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM DANGER ALERT CARD ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _showDanger ? bottomPad + 24 : -100.0,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.red.withOpacity(0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Extreme Heatwave Alert',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Islamabad experienced a sharp temperature rise to 49.0°C, indicating a severe meteorological anomaly.',
                          style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.black54),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildMetricItem(IconData icon, Color iconColor, String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildMetricDivider() => Container(width: 1, height: 28, color: Colors.grey.shade200);

  Widget _buildMapToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? Colors.blue.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? Colors.blue : Colors.grey.shade300,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor ?? (isActive ? Colors.blue : Colors.black87),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black),
          ),
        ],
      ),
    );
  }
}