import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/weather_tile_provider.dart';
import '../utils/ciro_theme.dart';
import '../widgets/weather_info_card.dart';
import '../widgets/location_dialogs.dart';
import '../widgets/ciro_bottom_nav_bar.dart';
import '../services/weather_service.dart';
import '../services/weather_response_handler.dart';
import '../services/notification_service.dart';
import 'crisis_details_screen.dart';
import 'community_screen.dart';

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
  bool _showDanger = false;

  // Location state
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(33.6844, 73.0479);
  bool _isLoadingLocation = true;
  bool _isCameraCenteredOnUser = true;

  bool _isLocationDialogOpen = false;
  bool _isPermissionDialogOpen = false;
  BuildContext? _locationDialogContext;
  BuildContext? _permissionDialogContext;

  double _optimalZoom = 12.0;

  // Testing variables
  bool _isRequestingBackend = false;
  bool _isMapOptionsExpanded = false;

  // Re-loadable weather state via centralized handler
  final String _username = "talha_ciro";
  String _cityName = "Gujrat"; // Will be overwritten by backend response
  WeatherResponseHandler _weather = WeatherResponseHandler(
    cityName: 'Gujrat',
    regionAndCountry: 'Gujrat, Pakistan',
  );

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAndApplyOptimalZoom();
    });

    NotificationService.init(
      onNotificationTapped: (payload) {
        if (mounted) {
          setState(() {
            _currentTabIndex = 2; // Route to the Crisis Page
          });
        }
      },
    );

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
      _checkLocationOnResume();
    }
  }

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
        _determineUserPosition();
      }
    }
  }

  Future<void> _determineUserPosition() async {
    LocationPermission permission;

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

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[WeatherMapScreen] Location services are disabled.');
      _showLocationServiceDialog();
      setState(() => _isLoadingLocation = false);
      return;
    }

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
            CameraPosition(target: lastLatLng, zoom: _optimalZoom),
          ),
        );
        _updateWeatherStats();
      }
    } catch (e) {
      debugPrint('[WeatherMapScreen] Error getting last known position: $e');
    }

    try {
      final LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
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
          CameraPosition(target: userLatLng, zoom: _optimalZoom),
        ),
      );
      _updateWeatherStats();
    } catch (e) {
      debugPrint('[WeatherMapScreen] Error getting user location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  CameraTargetBounds get _limitTargetBounds {
    const double latDelta = 70.0 / 111.12;
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
        setState(() {});
      }
    }
  }

  Future<void> _updateWeatherStats() async {
    try {
      final Map<String, dynamic> responseData = await WeatherService.fetchWeatherDetails(
        username: _username,
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        cityName: _cityName,
      );

      final handler = WeatherResponseHandler.fromResponse(responseData);

      setState(() {
        _weather = handler;
        _cityName = handler.cityName;
        _showDanger = handler.hasCrisis;
      });

      if (handler.hasCrisis) {
        NotificationService.showCrisisNotification(
          id: 1,
          title: handler.alertTitle,
          body: handler.alertDetails,
          payload: 'crisis',
        );
      }
    } catch (e) {
      debugPrint('[WeatherMapScreen] Failed to auto-update weather: $e');
    }
  }

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
        cityName: _cityName,
      );

      final handler = WeatherResponseHandler.fromResponse(responseData);

      setState(() {
        _weather = handler;
        _cityName = handler.cityName;
        _showDanger = handler.hasCrisis;
      });

      if (handler.hasCrisis) {
        NotificationService.showCrisisNotification(
          id: 1,
          title: handler.alertTitle,
          body: handler.alertDetails,
          payload: 'crisis',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                handler.hasCrisis ? "Alert Received!" : "Weather Updated!",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: handler.hasCrisis ? Colors.orangeAccent : Colors.teal,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[WeatherMapScreen] Backend request failed: $e');
      if (!mounted) return;
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
        currentBody = const CommunityScreen();
        break;
      case 2:
        if (_showDanger && _weather.alertData != null) {
          currentBody = CrisisDetailsScreen(alertData: _weather.alertData!);
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
      backgroundColor: CiroTheme.scaffoldBackground,
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: currentBody),
          ],
        ),
      ),
      bottomNavigationBar: CiroBottomNavBar(
        currentIndex: _currentTabIndex,
        onTabChanged: (index) => setState(() => _currentTabIndex = index),
        showCrisisTab: _showDanger,
        onSyncTapped: _triggerBackendRequest,
        isSyncing: _isRequestingBackend,
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
            locationName: _weather.cityName,
            regionAndCountry: _weather.regionAndCountry,
            temperature: _weather.temperatureDisplay,
            aqi: _weather.aqiDisplay,
            humidity: _weather.humidityDisplay,
            windSpeed: _weather.windSpeedDisplay,
          ),
        ),

        // 2. Central Premium Rounded Map Container
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 16), // No overlap issues with extendBody: false
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32), // High-end rounded corners
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06), // Improved contrast border
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(31), 
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition,
                      zoom: _optimalZoom,
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

                  if (_showDanger)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _buildUrgentCrisisBanner(context),
                    ),

                  // Map Options rigidly anchored, preventing layout shifts
                  Positioned(
                    bottom: 20,
                    left: 16,
                    child: _buildHorizontalLayerFilters(),
                  ),

                  // Location Option rigidly anchored, matching exactly in size
                  Positioned(
                    bottom: 20,
                    right: 16,
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
            opacity: value.clamp(0.0, 1.0), // Clamped to prevent overshoot crash
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
                      _weather.alertTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _weather.alertDetails,
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

  Widget _buildMiniLocationToggle() {
    return GestureDetector(
      onTap: _determineUserPosition,
      child: Container(
        width: 50, // Perfectly matched fixed size to toggle button
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          _isCameraCenteredOnUser ? Icons.my_location_rounded : Icons.location_searching_rounded,
          color: _isCameraCenteredOnUser ? const Color(0xFF1C1C1E) : Colors.grey.shade400,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildHorizontalLayerFilters() {
    return Container(
      height: 50, // Strict height to prevent any vertical layout shifts when animating
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The Toggle Button - Exactly 50x50
          GestureDetector(
            onTap: () => setState(() => _isMapOptionsExpanded = !_isMapOptionsExpanded),
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
              child: Icon(
                _isMapOptionsExpanded ? Icons.close_rounded : Icons.layers_rounded,
                color: const Color(0xFF1C1C1E),
                size: 24,
              ),
            ),
          ),
          
          // Expanded horizontal options
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft, // Crucial for stopping vertical shifts
            child: _isMapOptionsExpanded
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterItem(
                        icon: _showTraffic ? Icons.directions_car_rounded : Icons.directions_car_outlined,
                        isActive: _showTraffic,
                        onTap: () => setState(() => _showTraffic = !_showTraffic),
                      ),
                      _buildFilterItem(
                        icon: _showHeat ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                        isActive: _showHeat,
                        onTap: () => setState(() => _showHeat = !_showHeat),
                      ),
                      _buildFilterItem(
                        icon: _showClouds ? Icons.cloud_rounded : Icons.cloud_outlined,
                        isActive: _showClouds,
                        onTap: () => setState(() => _showClouds = !_showClouds),
                      ),
                      _buildFilterItem(
                        icon: _showRain ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                        isActive: _showRain,
                        onTap: () => setState(() => _showRain = !_showRain),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterItem({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? CiroTheme.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey.shade400,
          size: 20,
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