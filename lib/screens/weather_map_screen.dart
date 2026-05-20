import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/weather_tile_provider.dart';
import '../widgets/weather_info_card.dart';
import '../widgets/location_dialogs.dart';
import '../services/weather_service.dart';
import 'crisis_details_screen.dart';

class WeatherMapScreen extends StatefulWidget {
  const WeatherMapScreen({super.key});

  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> with WidgetsBindingObserver {
  // Navigation Tab Index
  int _currentTabIndex = 0;

  // Map toggles
  bool _showTraffic = false;
  bool _showHeat = false;
  bool _showClouds = false;
  bool _showRain = false;
  bool _showDanger = false; // Hidden initially as requested



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
  Map<String, dynamic>? _activeAlertData;

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
    // The central map container has a beautiful static height of 380 logical pixels
    const double mapHeightLogical = 380.0;
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
      final Map<String, dynamic> responseData = await WeatherService.fetchWeatherDetails(
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
          final alert = responseData['alert'] as Map<String, dynamic>;
          _activeAlertData = alert;
          _dangerTitle = alert['title'] ?? "Extreme Heatwave Alert";
          _dangerDetails = alert['details'] ?? "";
          _showDanger = true;
        } else {
          _activeAlertData = null;
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
    Widget currentBody;
    switch (_currentTabIndex) {
      case 1:
        currentBody = _buildCommunityTab();
        break;
      case 2:
        if (_showDanger) {
          final alertData = _activeAlertData ?? {
            'type': 'heatwave',
            'severity': 'extreme',
            'confidence': 0.95,
            'title': _dangerTitle,
            'details': _dangerDetails,
            'safety_advises': [
              'Stay indoors during peak sunlight hours (11:00 AM - 4:00 PM).',
              'Consume sufficient fluids and wear loose, light-colored clothing.',
              'Avoid strenuous physical activities outdoors.'
            ],
            'help_resources': [
              {'name': 'Rescue 1122', 'contact': '1122'},
              {'name': 'Police Emergency', 'contact': '15'},
              {'name': 'Edhi Ambulance', 'contact': '115'}
            ],
            'top_posts': [
              {
                'platform': 'x',
                'title': 'Heatwave peak temperature hits extreme record in Gujrat!',
                'url': 'https://x.com/ProPakistaniPK/status/2056697796573446447/photo/1'
              }
            ]
          };
          currentBody = CrisisDetailsScreen(alertData: alertData);
        } else {
          currentBody = _buildHomeTab();
        }
        break;
      case 0:
      default:
        currentBody = _buildHomeTab();
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Sleek, modern premium light backdrop
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: currentBody),
            _buildCustomBottomNavBar(),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildHomeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sleek Weather Snapshot Panel (at the top)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: WeatherInfoCard(
            locationName: _locationName,
            regionAndCountry: _regionAndCountry,
            temperature: _temperature,
            aqi: _aqi,
            humidity: _humidity,
            windSpeed: _windSpeed,
          ),
        ),

        // 2. Central Premium Rounded Map Container (Takes all remaining space)
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22), // Prevents map canvas from bleeding outside card border
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition,
                      zoom: _optimalZoom, // Automatically calculated vertical zoom
                    ),
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: true,
                    mapToolbarEnabled: false,
                    tileOverlays: _activeTileOverlays,
                    trafficEnabled: _showTraffic,
                    mapType: MapType.normal,
                    cameraTargetBounds: _limitTargetBounds,
                    minMaxZoomPreference: MinMaxZoomPreference(_optimalZoom, null),
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

                  // Smart sized Floating Crisis Banner at the top inside the Map stack
                  if (_showDanger)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _buildUrgentCrisisBanner(context),
                    ),

                  // Weather Layers Toggler on the left inside the Map
                  Positioned(
                    top: _showDanger ? 80 : 12,
                    left: 12,
                    child: _buildVerticalLayerFilters(),
                  ),

                  // 70km Limited indicator
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _buildMiniLayerToggle(),
                  ),

                  // My Location indicator inside bottom-right inside the map
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _buildMiniLocationToggle(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentCrisisBanner(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (value * 0.05),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = 2; // Jump to Crisis Details tab
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1F1), Color(0xFFFFE4E4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Filled critical warning icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dangerTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _dangerDetails,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.redAccent.withValues(alpha: 0.6),
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniLayerToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_rounded, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            "70km Limited",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.blue.shade800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniLocationToggle() {
    return GestureDetector(
      onTap: _determineUserPosition,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.my_location_rounded,
          color: _isCameraCenteredOnUser ? Colors.blue : Colors.black87,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildVerticalLayerFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVerticalFilterItem(
            icon: Icons.alt_route_rounded,
            isActive: _showTraffic,
            color: Colors.teal,
            onTap: () => setState(() => _showTraffic = !_showTraffic),
          ),
          const SizedBox(height: 8),
          _buildVerticalFilterItem(
            icon: Icons.local_fire_department_rounded,
            isActive: _showHeat,
            color: Colors.deepOrange,
            onTap: () => setState(() => _showHeat = !_showHeat),
          ),
          const SizedBox(height: 8),
          _buildVerticalFilterItem(
            icon: Icons.cloud_rounded,
            isActive: _showClouds,
            color: Colors.blueGrey,
            onTap: () => setState(() => _showClouds = !_showClouds),
          ),
          const SizedBox(height: 8),
          _buildVerticalFilterItem(
            icon: Icons.water_drop_rounded,
            isActive: _showRain,
            color: Colors.blue,
            onTap: () => setState(() => _showRain = !_showRain),
          ),
          const SizedBox(height: 12),
          // Diagnostics Button
          GestureDetector(
            onTap: _triggerBackendRequest,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isRequestingBackend ? Colors.blue.withValues(alpha: 0.12) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: _isRequestingBackend
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: Padding(
                        padding: EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                      ),
                    )
                  : const Icon(Icons.science_rounded, color: Colors.blue, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalFilterItem({
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? color : Colors.black54,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildCommunityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "COMMUNITY HUB",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Real-time safety reports and community discussions",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildCommunityPost(
                username: "ali_guajrat",
                timeAgo: "12m ago",
                content: "Very high temperatures near the city center today. Staying indoors. Power outages are being reported in Sector B.",
                upvotes: 24,
                comments: 5,
                tag: "Weather Advisory",
                tagColor: Colors.orange,
              ),
              _buildCommunityPost(
                username: "zainab_ciro",
                timeAgo: "45m ago",
                content: "Is anyone else seeing heavy smoke near the industrial park? The air quality is feeling extremely thick and dusty.",
                upvotes: 42,
                comments: 18,
                tag: "Air Quality",
                tagColor: Colors.redAccent,
              ),
              _buildCommunityPost(
                username: "doctor_hamza",
                timeAgo: "2h ago",
                content: "Health tip: Please drink at least 4-5 liters of water today to avoid heat exhaustion. Avoid sugary drinks which cause dehydration.",
                upvotes: 112,
                comments: 29,
                tag: "Safety Tip",
                tagColor: Colors.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityPost({
    required String username,
    required String timeAgo,
    required String content,
    required int upvotes,
    required int comments,
    required String tag,
    required Color tagColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tagColor.withValues(alpha: 0.1),
                radius: 18,
                child: Text(
                  username[0].toUpperCase(),
                  style: TextStyle(color: tagColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "@$username",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tag,
                  style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                "$upvotes",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 20),
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                "$comments",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBottomNavBar() {
    final showCrisisTab = _showDanger;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavBarItem(
            index: 0,
            icon: Icons.home_rounded,
            label: "Home",
          ),
          _buildNavBarItem(
            index: 1,
            icon: Icons.people_rounded,
            label: "Community",
          ),
          if (showCrisisTab)
            _buildNavBarItem(
              index: 2,
              icon: Icons.warning_amber_rounded,
              label: "Crisis",
              color: Colors.redAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildNavBarItem({
    required int index,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final isSelected = _currentTabIndex == index;
    final activeColor = color ?? Colors.blue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : Colors.black54,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
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