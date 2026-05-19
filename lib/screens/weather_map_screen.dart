import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/weather_tile_provider.dart';
import '../widgets/weather_info_card.dart';
import '../widgets/location_dialogs.dart';
import '../utils/api_config.dart';
import '../services/weather_service.dart';

class WeatherMapScreen extends StatefulWidget {
  const WeatherMapScreen({super.key});

  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> with WidgetsBindingObserver {
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
  LatLng _currentPosition = const LatLng(33.6844, 73.0479); // Default: Gujrat
  bool _isLoadingLocation = true;
  bool _isCameraCenteredOnUser = true; // Tracks whether map is currently centered on user location

  // Dialog open tracking to prevent stacking multiple prompts
  bool _isLocationDialogOpen = false;
  bool _isPermissionDialogOpen = false;

  // Dialog contexts for 100% reliable direct programmatic dismissal
  BuildContext? _locationDialogContext;
  BuildContext? _permissionDialogContext;

  // Optimal zoom to fit 70 km vertically
  double _optimalZoom = 12.0; // fallback until calculated

  // Testing variables
  bool _isRequestingBackend = false;

  // Re-loadable weather properties initialized with dummy defaults
  String _username = "talha_ciro";
  String _locationName = "Gujrat";
  String _regionAndCountry = "Gujrat, Pakistan";
  String _temperature = "49°C";
  String _aqi = "120";
  String _humidity = "42%";
  String _windSpeed = "14 km/h";

  // Alert card details
  String _dangerTitle = "Extreme Heatwave Alert";
  String _dangerDetails = "Gujrat experienced a sharp temperature rise to 49.0°C, indicating a severe meteorological anomaly.";

  // OWM Tile Overlays
  late final TileOverlay _heatOverlay;
  late final TileOverlay _cloudsOverlay;
  late final TileOverlay _rainOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    // Compute the optimal zoom after the first frame is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAndApplyOptimalZoom();
    });

    _determineUserPosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check and automatically close location dialogue if they enabled GPS while away
      _checkLocationOnResume();
    }
  }

  /// Automatically synchronizes GPS toggle state and permissions when returning from device settings
  Future<void> _checkLocationOnResume() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      if (_isPermissionDialogOpen && _permissionDialogContext != null && mounted) {
        Navigator.of(_permissionDialogContext!).pop();
        _permissionDialogContext = null;
        _isPermissionDialogOpen = false;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        if (_isLocationDialogOpen && _locationDialogContext != null && mounted) {
          Navigator.of(_locationDialogContext!).pop();
          _locationDialogContext = null;
          _isLocationDialogOpen = false;
        }
        // Location enabled, re-trigger user coordinate lock
        _determineUserPosition();
      }
    }
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
      _showAppSettingsDialog();
      setState(() => _isLoadingLocation = false);
      return;
    } 

    // 2. Once permission is verified, check if location services are toggled on
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[WeatherMapScreen] Location services are disabled.');
      _showLocationServiceDialog();
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
          _isCameraCenteredOnUser = true;
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: lastLatLng,
              zoom: _optimalZoom,   // use the computed optimal zoom
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
        _isCameraCenteredOnUser = true;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLatLng,
            zoom: _optimalZoom,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[WeatherMapScreen] Error getting user location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  /// Strict 70 km square around the user's position
  CameraTargetBounds get _limitTargetBounds {
    const double latDelta = 70.0 / 111.12;   // 1° lat ≈ 111.12 km

    final double radLat = _currentPosition.latitude * (math.pi / 180.0);
    final double cosLat = math.cos(radLat);
    final double lngDelta = 70.0 / (111.12 * (cosLat > 0.0 ? cosLat : 1.0));

    final LatLng southwest = LatLng(
      _currentPosition.latitude - latDelta,
      _currentPosition.longitude - lngDelta,
    );
    final LatLng northeast = LatLng(
      _currentPosition.latitude + latDelta,
      _currentPosition.longitude + lngDelta,
    );

    return CameraTargetBounds(
      LatLngBounds(southwest: southwest, northeast: northeast),
    );
  }

  /// Calculate the zoom level so that exactly 70 km fits vertically in the map
  double _calculateOptimalZoom(double mapHeightLogical, double devicePixelRatio) {
    const double targetDistanceMeters = 70000.0;
    final double mapHeightPhysical = mapHeightLogical * devicePixelRatio;
    const double metresPerPixelAtZoom0 = 156543.03392;
    final double radLat = _currentPosition.latitude * (math.pi / 180.0);
    final double cosLat = math.cos(radLat);

    final double numerator = metresPerPixelAtZoom0 * cosLat * mapHeightPhysical;
    final double zoomFactor = numerator / targetDistanceMeters;
    return math.log(zoomFactor) / math.log(2.0);
  }

  void _calculateAndApplyOptimalZoom() {
    final size = MediaQuery.of(context).size;
    final double topPad = MediaQuery.of(context).padding.top;
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    // The map fills the whole Scaffold body; subtract system UI areas for accurate visible height
    final double mapHeightLogical = size.height - topPad - bottomPad;
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final double zoom = _calculateOptimalZoom(mapHeightLogical, pixelRatio);
    if (zoom > 0) {
      _optimalZoom = zoom;

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentPosition, zoom: _optimalZoom),
          ),
        );
      } else {
        // If map not yet created, trigger rebuild so initialCameraPosition uses new zoom
        setState(() {});
      }
    }
  }

  /// Trigger HTTP request to Django local backend server with testing mock overlays
  Future<void> _triggerBackendRequest() async {
    if (_isRequestingBackend) return;
    setState(() {
      _isRequestingBackend = true;
    });

    try {
      final Map<String, dynamic> responseData = await WeatherService.fetchMockWeatherDetails(
        username: _username,
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        cityName: "Gujrat",
      );

      final env = responseData['environment'] ?? {};
      final bool receivedAlert = responseData.containsKey('alert');

      setState(() {
        // Update presentation variables dynamically from response
        _temperature = "${env['temperature_c'] ?? 49.0}°C";
        _aqi = "${env['aqi'] ?? 120}";
        _humidity = "${env['humidity_pct'] ?? 42}%";
        _windSpeed = "${env['wind_speed_kmh'] ?? 14} km/h";

        if (receivedAlert) {
          final alert = responseData['alert'];
          _dangerTitle = alert['title'] ?? "Extreme Heatwave Alert";
          _dangerDetails = alert['details'] ?? "";
          _showDanger = true;
        } else {
          _showDanger = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                receivedAlert ? "Simulated Alert Received!" : "Weather Stats Updated!",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: receivedAlert ? Colors.orangeAccent : Colors.teal,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[WeatherMapScreen] Backend request failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Backend Server Unreachable: $e",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isRequestingBackend = false;
      });
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
              zoom: _optimalZoom,               // ← dynamically computed to fit 70 km vertically
            ),
            zoomControlsEnabled: false,
            compassEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: true, // Shows current user location dot on map
            mapToolbarEnabled: false,
            tileOverlays: _activeTileOverlays,
            trafficEnabled: _showTraffic,
            mapType: MapType.normal, // Fixed to default normal map type
            cameraTargetBounds: _limitTargetBounds,   // Restricts panning strictly to a 70 km square
            minMaxZoomPreference: MinMaxZoomPreference(_optimalZoom, null), // Cannot zoom out beyond the 70 km view
            onCameraMove: (position) {
              final latDiff = (position.target.latitude - _currentPosition.latitude).abs();
              final lngDiff = (position.target.longitude - _currentPosition.longitude).abs();
              final isCentered = latDiff < 0.0008 && lngDiff < 0.0008;
              if (isCentered != _isCameraCenteredOnUser) {
                setState(() {
                  _isCameraCenteredOnUser = isCentered;
                });
              }
            },
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_isLoadingLocation) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _currentPosition,
                      zoom: _optimalZoom,
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
            child: WeatherInfoCard(
              locationName: _locationName,
              regionAndCountry: _regionAndCountry,
              temperature: _temperature,
              aqi: _aqi,
              humidity: _humidity,
              windSpeed: _windSpeed,
            ),
          ),

          // ── EXPANDABLE WEATHER LAYER OPTIONS POPUP (LEFT SIDE) ──
          // Smooth Bottom-to-Top slide and fade transition
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 16,
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

          // ── LAYERS TOGGLE BUTTON (LEFT SIDE) ──
          // Deeper premium double shadows for strong contrast against the light map
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 16,
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

          // ── TEMPORARY TESTING TRIGGER BUTTON (RIGHT SIDE, POSITIONED ABOVE MY LOCATION) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: 16,
            bottom: toggleBottomOffset + 128 + 24, // Positioned exactly above My Location
            child: GestureDetector(
              onTap: _triggerBackendRequest,
              child: Container(
                width: 64,
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
                  child: _isRequestingBackend
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        )
                      : const Icon(
                          Icons.science_rounded,
                          color: Colors.blue,
                          size: 28,
                        ),
                ),
              ),
            ),
          ),

          // ── MY LOCATION TARGET BUTTON (RIGHT SIDE, POSITIONED ABOVE +REPORT) ──
          // Smooth glide/panning camera movement to focus directly on current GPS coordinates
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: 16, 
            bottom: toggleBottomOffset + 64 + 12, // Stacked perfectly above report button
            child: GestureDetector(
              onTap: _determineUserPosition,
              child: Container(
                width: 64,
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
                    Icons.my_location_rounded, // Restored original crosshairs icon with small outside tick lines
                    color: _isCameraCenteredOnUser ? Colors.blue : Colors.black87, // Turns back black when map dragged away
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // ── STATIC +REPORT BUTTON (RIGHT SIDE, BOTTOM-MOST WIDGET) ──
          // Premium white alert box styled matching design specifications
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: 16,
            bottom: toggleBottomOffset,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Reporting feature is coming soon!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: Colors.black87,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: 64,
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
                      color: Color(0x1F000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_location_alt_rounded, // Clean map pin plus icon to represent location-based reports
                      color: Colors.black87, // Clean dark charcoal color, no longer red
                      size: 22,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'REPORT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87, // Matching clean charcoal color
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
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
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dangerTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dangerDetails,
                          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.black54),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──

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

  // ── Location Services and Permission Helper Prompts ──

  void _showLocationServiceDialog() {
    if (_isLocationDialogOpen || !mounted) return;
    _isLocationDialogOpen = true;
    showLocationServiceDialog(
      context,
      onCreated: (dialogContext) => _locationDialogContext = dialogContext,
      onCancel: () {
        setState(() {
          _isLocationDialogOpen = false;
          _locationDialogContext = null;
        });
      },
    );
  }

  void _showAppSettingsDialog() {
    if (_isPermissionDialogOpen || !mounted) return;
    _isPermissionDialogOpen = true;
    showAppSettingsDialog(
      context,
      onCreated: (dialogContext) => _permissionDialogContext = dialogContext,
      onCancel: () {
        setState(() {
          _isPermissionDialogOpen = false;
          _permissionDialogContext = null;
        });
      },
    );
  }
}