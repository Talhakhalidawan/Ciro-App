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
  bool _isTrafficActive = false;
  bool _isHeatActive = true;
  bool _isRainActive = false;
  bool _isDangerActive = true;

  // Active Map Overlay
  late final TileOverlay _weatherOverlay;

  @override
  void initState() {
    super.initState();
    _weatherOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('weather_temp_overlay'),
      tileProvider: WeatherTileProvider(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── PHASE 1: FOUNDATION & THE BASE MAP ──
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(33.6844, 73.0479), // Islamabad, Pakistan
              zoom: 12.0,
            ),
            zoomControlsEnabled: false,
            compassEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            tileOverlays: _isHeatActive ? {_weatherOverlay} : {},
            trafficEnabled: _isTrafficActive,
            mapType: MapType.normal,
          ),

          // ── PHASE 3: FLOATING WEATHER CARD (TOP) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B1F).withOpacity(0.9), // Premium dark mode glassmorphism
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: Location & Temperature Info
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
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Islamabad, Pakistan',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
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
                  // Thin elegant divider
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  const SizedBox(height: 12),
                  // Bottom Row: Sleek Weather Metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          icon: Icons.air,
                          iconColor: Colors.redAccent,
                          label: 'AQI',
                          value: '120',
                          valueColor: Colors.redAccent,
                        ),
                      ),
                      _buildMetricVerticalDivider(),
                      Expanded(
                        child: _buildMetricItem(
                          icon: Icons.water_drop,
                          iconColor: Colors.blueAccent,
                          label: 'Humidity',
                          value: '42%',
                          valueColor: Colors.white,
                        ),
                      ),
                      _buildMetricVerticalDivider(),
                      Expanded(
                        child: _buildMetricItem(
                          icon: Icons.wind_power,
                          iconColor: Colors.tealAccent,
                          label: 'Wind',
                          value: '14 km/h',
                          valueColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── PHASE 3: SIDE TOGGLES (MIDDLE RIGHT) ──
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B1F).withOpacity(0.9), // Match weather card glassmorphism
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapToggle(
                    icon: Icons.map_outlined,
                    label: 'Traffic',
                    isActive: _isTrafficActive,
                    onTap: () => setState(() => _isTrafficActive = !_isTrafficActive),
                  ),
                  const SizedBox(height: 16),
                  _buildMapToggle(
                    icon: Icons.layers,
                    label: 'Heat',
                    isActive: _isHeatActive,
                    onTap: () => setState(() => _isHeatActive = !_isHeatActive),
                  ),
                  const SizedBox(height: 16),
                  _buildMapToggle(
                    icon: Icons.cloudy_snowing,
                    label: 'Rain',
                    isActive: _isRainActive,
                    onTap: () => setState(() => _isRainActive = !_isRainActive),
                  ),
                  const SizedBox(height: 16),
                  _buildMapToggle(
                    icon: Icons.warning,
                    label: 'Dangers',
                    iconColor: Colors.redAccent,
                    isActive: _isDangerActive,
                    onTap: () => setState(() => _isDangerActive = !_isDangerActive),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 1,
                    width: 30,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  const SizedBox(height: 12),
                  Icon(Icons.layers_outlined, color: Colors.white.withOpacity(0.7), size: 28),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // ── PHASE 3: BOTTOM ALERT CARD ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isDangerActive ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_isDangerActive,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C1E1E).withOpacity(0.95), // Translucent dark crimson
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.redAccent, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Extreme Heatwave Alert',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Islamabad experienced a sharp temperature rise to 49.0°C, indicating a severe meteorological anomaly.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for Weather Card metrics
  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withOpacity(0.08),
    );
  }

  // Helper for Floating Toggles
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
              color: isActive ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? Colors.blueAccent : Colors.white.withOpacity(0.08),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor ?? (isActive ? Colors.blueAccent : Colors.white.withOpacity(0.7)),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}