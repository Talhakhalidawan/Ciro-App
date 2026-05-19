import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  bool _showDanger = false; // Hidden initially as requested

  // Whether the layer panel is expanded
  bool _layerPanelOpen = false;

  // Location state
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(33.6844, 73.0479); // Default: Islamabad
  bool _isLoadingLocation = true;

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

    _determineUserPosition();
  }

  /// Queries user GPS position, requests permissions FIRST to ensure dialog popup, and animates the map controller
  Future<void> _determineUserPosition() async {
    LocationPermission permission;

    // 1. Check and request location permission first to ensure popup displays
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[WeatherMapScreen] Location permissions are denied.');
        setState(() => _isLoadingLocation = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('[WeatherMapScreen] Location permissions are permanently denied.');
      setState(() => _isLoadingLocation = false);
      return;
    } 

    // 2. Once permission is verified, check if location services are toggled on
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[WeatherMapScreen] Location services are disabled.');
      setState(() => _isLoadingLocation = false);
      return;
    }

    // 3. Fast-track: check last known position first to give immediate rendering feedback
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final lastLatLng = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _currentPosition = lastLatLng;
          _isLoadingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: lastLatLng,
              zoom: 13.0,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[WeatherMapScreen] Error getting last known position: $e');
    }

    // 4. Query live high-accuracy location with AndroidSettings to force mock location capabilities
    try {
      final LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true, // Forces Android's older LocationManager API to get instant emulator simulated locks
        intervalDuration: const Duration(seconds: 5),
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(const Duration(seconds: 8));

      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = userLatLng;
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLatLng,
            zoom: 13.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[WeatherMapScreen] Error getting user location: $e');
      setState(() => _isLoadingLocation = false);
    }
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
    final double toggleBottomOffset = _showDanger
        ? bottomPad + 24 + 90 + 16 // safeArea + dangerPad + dangerHeight + gap
        : bottomPad + 16;

    return Scaffold(
      body: Stack(
        children: [
          // ── BASE MAP ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 12.0,
            ),
            zoomControlsEnabled: false,
            compassEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: true, // Shows current user location dot on map
            mapToolbarEnabled: false,
            tileOverlays: _activeTileOverlays,
            trafficEnabled: _showTraffic,
            mapType: MapType.normal, // Fixed to default normal map type
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_isLoadingLocation) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _currentPosition,
                      zoom: 13.0,
                    ),
                  ),
                );
              }
            },
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
                border: Border.all(
                  color: Colors.black.withOpacity(0.06),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000), // 12% opacity deep shadow
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x0A000000), // 4% opacity soft shadow
                    blurRadius: 8,
                    offset: Offset(0, 2),
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

          // ── EXPANDABLE WEATHER LAYER OPTIONS POPUP ──
          // Smooth Bottom-to-Top slide and fade transition
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: 16,
            bottom: _layerPanelOpen ? (toggleBottomOffset + 64 + 12) : toggleBottomOffset,
            child: IgnorePointer(
              ignoring: !_layerPanelOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _layerPanelOpen ? 1.0 : 0.0,
                child: Container(
                  width: 64, // Exact matches toggler width to avoid horizontal shifting
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.06),
                      width: 1.2,
                ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000), // Premium 12% elevation shadow
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Color(0x0A000000), // Premium 4% ambient shadow
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMapToggle(
                        icon: Icons.alt_route_rounded,
                        label: 'Traffic',
                        isActive: _showTraffic,
                        iconColor: Colors.teal,
                        onTap: () => setState(() => _showTraffic = !_showTraffic),
                      ),
                      const SizedBox(height: 18),
                      _buildMapToggle(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Heat',
                        isActive: _showHeat,
                        iconColor: Colors.deepOrange,
                        onTap: () => setState(() => _showHeat = !_showHeat),
                      ),
                      const SizedBox(height: 18),
                      _buildMapToggle(
                        icon: Icons.cloud_rounded,
                        label: 'Clouds',
                        isActive: _showClouds,
                        iconColor: Colors.blueGrey,
                        onTap: () => setState(() => _showClouds = !_showClouds),
                      ),
                      const SizedBox(height: 18),
                      _buildMapToggle(
                        icon: Icons.water_drop_rounded,
                        label: 'Rain',
                        isActive: _showRain,
                        iconColor: Colors.blue,
                        onTap: () => setState(() => _showRain = !_showRain),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── LAYERS TOGGLE BUTTON ──
          // Deeper premium double shadows for strong contrast against the light map
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: 16,
            bottom: toggleBottomOffset,
            child: GestureDetector(
              onTap: () => setState(() => _layerPanelOpen = !_layerPanelOpen),
              child: Container(
                width: 64, // Exact width matches expanded layer panel
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.06),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000), // High-definition 12% elevation shadow
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Color(0x0A000000), // 4% ambient shadow
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _layerPanelOpen ? Icons.close : Icons.layers_outlined,
                    color: _layerPanelOpen ? Colors.red : Colors.black87,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // ── BOTTOM DANGER ALERT CARD (Intact Code, Hidden by default via _showDanger = false) ──
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
    final activeColor = iconColor ?? Colors.blue;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? activeColor : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.black87,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: isActive ? activeColor : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}