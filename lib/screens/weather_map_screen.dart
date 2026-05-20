import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/weather_tile_provider.dart';
import '../utils/ciro_theme.dart';
import '../utils/config.dart';
import '../widgets/weather_info_card.dart';
import '../widgets/location_dialogs.dart';
import '../widgets/ciro_bottom_nav_bar.dart';
import '../services/weather_service.dart';
import '../services/weather_response_handler.dart';
import '../services/notification_service.dart';
import 'crisis_details_screen.dart';
import 'community_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

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
  bool _showCrisisTab = false;
  bool _showDangerBanner = false;

  bool _evaluateDangerBanner(WeatherResponseHandler handler, SharedPreferences prefs) {
    if (!handler.hasCrisis) return false;
    final title = handler.alertTitle;
    if (title.isEmpty) return false;
    
    final dismissed = prefs.getStringList('dismissed_banners') ?? [];
    if (dismissed.contains(title)) return false;
    
    final firstSeenKey = 'banner_first_seen_$title';
    final firstSeen = prefs.getInt(firstSeenKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (firstSeen == null) {
      prefs.setInt(firstSeenKey, now);
      return true;
    }
    
    // Check if 10 hours have passed
    if (now - firstSeen > 10 * 3600 * 1000) {
      return false;
    }
    return true;
  }

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

  // Caching and Rate-limiting/Throttling variables
  DateTime? _lastSuccessfulFetchTime;
  int _checkIntervalMinutes = AppConfig.checkIntervalMinutes;
  Timer? _autoRefreshTimer;
  // Offline retry mechanism state
  bool _isOffline = false;
  bool _isWaitingForInternet = false;
  Timer? _offlineRetryTimer;

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

    _loadCachedWeatherData();
    _loadOnboardingStateAndCheckPermissions();
    _startAutoRefreshTimer();
  }

  Future<void> _loadOnboardingStateAndCheckPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLat = prefs.getDouble('user_lat');
      final savedLon = prefs.getDouble('user_lon');
      final savedCity = prefs.getString('user_city');

      if (savedLat != null && savedLon != null) {
        setState(() {
          _currentPosition = LatLng(savedLat, savedLon);
        });
      }
      if (savedCity != null) {
        setState(() {
          _cityName = savedCity;
        });
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        // We already have permission, update user location to keep track of their latest coordinates
        _determineUserPosition();
      } else {
        // No permission or denied, prompt the user with a dismissible dialog
        _showLocationRequestPrompt();
      }
    } catch (e) {
      debugPrint('[WeatherMapScreen] Failed loading onboarding state: $e');
      _determineUserPosition();
    }
  }

  void _showLocationRequestPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CiroTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on_rounded, color: CiroTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Location Access',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'CIRO works best when we have your latest coordinates. Allow location permission to sync real-time weather anomalies in your vicinity.',
          style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateWeatherStats();
              _registerBackgroundSync();
              setState(() {
                _isLoadingLocation = false;
              });
            },
            child: Text(
              'Not Now',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              LocationPermission perm = await Geolocator.requestPermission();
              if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
                _determineUserPosition();
              } else {
                _updateWeatherStats();
                _registerBackgroundSync();
                setState(() {
                  _isLoadingLocation = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CiroTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Allow Access',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopOfflineRetryTimer();
    _autoRefreshTimer?.cancel();
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

  Future<void> _registerBackgroundSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        "ciro_weather_check_task",
        "ciro_weather_check",
        frequency: Duration(minutes: AppConfig.checkIntervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      debugPrint('[WeatherMapScreen] Background task successfully registered.');
    } catch (e) {
      debugPrint('[WeatherMapScreen] Failed to register background task: $e');
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
        _updateWeatherStats();
        _registerBackgroundSync();
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('[WeatherMapScreen] Location permissions are permanently denied.');
      _showAppSettingsDialog();
      setState(() => _isLoadingLocation = false);
      _updateWeatherStats();
      _registerBackgroundSync();
      return;
    } 

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[WeatherMapScreen] Location services are disabled.');
      _showLocationServiceDialog();
      setState(() => _isLoadingLocation = false);
      _updateWeatherStats();
      _registerBackgroundSync();
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

      // Keep track of user's latest location in SharedPreferences!
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('user_lat', position.latitude);
      await prefs.setDouble('user_lon', position.longitude);

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: _optimalZoom),
        ),
      );
      _updateWeatherStats();
      _registerBackgroundSync();
    } catch (e) {
      debugPrint('[WeatherMapScreen] Error getting user location: $e');
      setState(() => _isLoadingLocation = false);
      _updateWeatherStats();
      _registerBackgroundSync();
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

  Future<void> _loadCachedWeatherData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load last successful fetch time
      final lastSuccessfulFetchMs = prefs.getInt('last_successful_fetch_time');
      if (lastSuccessfulFetchMs != null) {
        _lastSuccessfulFetchTime = DateTime.fromMillisecondsSinceEpoch(lastSuccessfulFetchMs);
      }
      
      // Enforce the interval strictly from AppConfig (ignoring cache)
      _checkIntervalMinutes = AppConfig.checkIntervalMinutes;
      
      // Load cached response
      final cachedJsonStr = prefs.getString('cached_weather_response');
      if (cachedJsonStr != null) {
        final decodedJson = json.decode(cachedJsonStr) as Map<String, dynamic>;
        final handler = WeatherResponseHandler.fromResponse(decodedJson);
        final showBanner = _evaluateDangerBanner(handler, prefs);
        setState(() {
          _weather = handler;
          _cityName = handler.cityName;
          _showCrisisTab = handler.hasCrisis;
          _showDangerBanner = showBanner;
        });
        debugPrint('[WeatherMapScreen] Cached weather data loaded successfully on startup.');
      }
    } catch (e) {
      debugPrint('[WeatherMapScreen] Error loading cached weather data: $e');
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _startOfflineRetryTimer() {
    if (_offlineRetryTimer != null && _offlineRetryTimer!.isActive) return;
    
    debugPrint('[OfflineRetry] Starting periodic connectivity check every 15s...');
    _offlineRetryTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final hasInternet = await _hasInternetConnection();
      if (hasInternet) {
        debugPrint('[OfflineRetry] Internet connection restored! Retrying pending weather fetch...');
        _stopOfflineRetryTimer();
        if (mounted) {
          setState(() {
            _isOffline = false;
            _isWaitingForInternet = false;
          });
          _triggerBackendRequest(isAutoUpdate: true);
        }
      }
    });
  }

  void _stopOfflineRetryTimer() {
    if (_offlineRetryTimer != null) {
      debugPrint('[OfflineRetry] Stopping connectivity checks.');
      _offlineRetryTimer!.cancel();
      _offlineRetryTimer = null;
    }
  }

  /// Starts a periodic timer that automatically triggers a weather fetch
  /// at the configured interval (from AppConfig.checkIntervalMinutes).
  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    final interval = Duration(minutes: _checkIntervalMinutes);
    debugPrint('[AutoRefresh] Starting auto-refresh timer: every $_checkIntervalMinutes min(s).');
    _autoRefreshTimer = Timer.periodic(interval, (_) {
      debugPrint('[AutoRefresh] Timer fired — triggering auto weather update.');
      _triggerBackendRequest(isAutoUpdate: true);
    });
  }

  Future<void> _updateWeatherStats() async {
    // Simply delegate to _triggerBackendRequest with isAutoUpdate=true
    // to reuse the 30-minute interval check, local caching, and offline-resume flows!
    await _triggerBackendRequest(isAutoUpdate: true);
  }

  Future<void> _triggerBackendRequest({bool isAutoUpdate = false}) async {
    if (_isRequestingBackend) return;

    final now = DateTime.now();

    // Enforce the 30-minute interval (only block if we have a successful previous fetch and it is within interval)
    if (_lastSuccessfulFetchTime != null) {
      final difference = now.difference(_lastSuccessfulFetchTime!);
      if (difference.inMinutes < _checkIntervalMinutes) {
        final remainingMinutes = _checkIntervalMinutes - difference.inMinutes;
        debugPrint('[WeatherMapScreen] Request skipped: local cooldown is active ($remainingMinutes min(s) remaining).');
        
        // If the user manually clicked the button, show an informative alert
        if (!isAutoUpdate && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Weather alerts are already up to date. Next update in $remainingMinutes min(s).',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: CiroTheme.primary,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
    }



    // Proceed with online request
    setState(() {
      _isRequestingBackend = true;
      _isOffline = false;
    });

    try {
      final Map<String, dynamic> responseData = await WeatherService.fetchWeatherDetails(
        username: _username,
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        cityName: _cityName,
      );

      final handler = WeatherResponseHandler.fromResponse(responseData);
      debugPrint('[DEBUG] RAW BACKEND ALERT: ${jsonEncode(responseData['alert'])}');

      // Save success state & serialize to SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_weather_response', json.encode(responseData));
      
      // Note: We strictly honor AppConfig.checkIntervalMinutes for the foreground timer.
      // However, for background tasks (Workmanager), Android enforces a minimum of 15 minutes.
      
      _lastSuccessfulFetchTime = DateTime.now();
      await prefs.setInt('last_successful_fetch_time', _lastSuccessfulFetchTime!.millisecondsSinceEpoch);

      final showBanner = _evaluateDangerBanner(handler, prefs);

      if (mounted) {
        setState(() {
          _weather = handler;
          _cityName = handler.cityName;
          _showCrisisTab = handler.hasCrisis;
          _showDangerBanner = showBanner;
          _isWaitingForInternet = false;
        });

        _stopOfflineRetryTimer();

        if (!isAutoUpdate) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Weather and alerts successfully synchronized.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFF34C759),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }

      if (handler.hasCrisis) {
        final title = handler.alertTitle;
        final notified = prefs.getStringList('notified_events') ?? [];
        if (!notified.contains(title) && title.isNotEmpty) {
          notified.add(title);
          await prefs.setStringList('notified_events', notified);
          NotificationService.showCrisisNotification(
            id: 1,
            title: handler.notificationTitle,
            body: handler.notificationBody,
            alertType: handler.alertData?['type']?.toString() ?? 'general',
            severity: handler.alertData?['severity']?.toString() ?? 'high',
            payload: 'crisis',
          );
        }
      }
    } catch (e) {
      debugPrint('[WeatherMapScreen] Backend request failed: $e');
      if (e is SocketException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        _isWaitingForInternet = true;
        _startOfflineRetryTimer();
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingBackend = false);
      }
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
        currentBody = CommunityScreen(
          userId: _username,
          userLocation: _currentPosition,
        );
        break;
      case 2:
        if (_showCrisisTab && _weather.alertData != null) {
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
        showCrisisTab: _showCrisisTab,
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
            isOffline: _isOffline || _isWaitingForInternet,
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

                  if (_showDangerBanner)
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
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final title = _weather.alertTitle;
          if (title.isNotEmpty) {
            final dismissed = prefs.getStringList('dismissed_banners') ?? [];
            if (!dismissed.contains(title)) {
              dismissed.add(title);
              await prefs.setStringList('dismissed_banners', dismissed);
            }
          }
          if (mounted) {
            setState(() {
              _showDangerBanner = false;
              _currentTabIndex = 2; // Jump to Crisis Details tab
            });
          }
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