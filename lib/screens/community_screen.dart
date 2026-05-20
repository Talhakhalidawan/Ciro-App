import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/ciro_theme.dart';
import '../utils/config.dart';
import '../services/community_service.dart';
import '../services/notification_service.dart';
import 'report_incident_screen.dart';

/// Live community feed showing nearby incident reports.
/// Polls the backend every N seconds for near-real-time updates.
class CommunityScreen extends StatefulWidget {
  final String userId;
  final LatLng userLocation;

  const CommunityScreen({
    super.key,
    required this.userId,
    required this.userLocation,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Map<String, dynamic>> _incidents = [];
  int _lastSeenId = 0;
  bool _isLoading = true;
  Timer? _pollTimer;
  final Set<int> _notifiedIds = {};

  static const Map<String, IconData> typeIcons = {
    'accident': Icons.car_crash_rounded,
    'fire': Icons.local_fire_department_rounded,
    'flood': Icons.water_rounded,
    'road_closure': Icons.block_rounded,
    'power_outage': Icons.power_off_rounded,
    'gas_leak': Icons.warning_amber_rounded,
    'protest': Icons.groups_rounded,
    'crime': Icons.gavel_rounded,
    'medical': Icons.local_hospital_rounded,
    'other': Icons.report_problem_rounded,
  };

  static const Map<String, Color> typeColors = {
    'accident': Color(0xFFEF4444),
    'fire': Color(0xFFF97316),
    'flood': Color(0xFF3B82F6),
    'road_closure': Color(0xFF8B5CF6),
    'power_outage': Color(0xFF6B7280),
    'gas_leak': Color(0xFFEAB308),
    'protest': Color(0xFF14B8A6),
    'crime': Color(0xFFDC2626),
    'medical': Color(0xFFEC4899),
    'other': Color(0xFF9CA3AF),
  };

  @override
  void initState() {
    super.initState();
    _fetchIncidents(initial: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConfig.communityPollIntervalSeconds),
      (_) => _fetchIncidents(),
    );
  }

  Future<void> _fetchIncidents({bool initial = false}) async {
    try {
      final data = await CommunityService.fetchIncidents(
        latitude: widget.userLocation.latitude,
        longitude: widget.userLocation.longitude,
        sinceId: initial ? 0 : _lastSeenId,
      );

      final List<dynamic> fetched = data['incidents'] ?? [];
      final newIncidents = fetched.cast<Map<String, dynamic>>();

      if (initial) {
        setState(() {
          _incidents = newIncidents;
          _isLoading = false;
          if (_incidents.isNotEmpty) {
            _lastSeenId = _incidents.first['id'] as int;
          }
        });
      } else if (newIncidents.isNotEmpty) {
        // Prepend new incidents
        for (final inc in newIncidents) {
          _incidents.insert(0, inc);

          // Send notification for incidents within 20km that haven't been notified yet
          final id = inc['id'] as int;
          final notify = inc['notify'] as bool? ?? false;
          if (notify && !_notifiedIds.contains(id)) {
            _notifiedIds.add(id);
            final type = inc['incident_type'] as String? ?? 'other';
            NotificationService.showCrisisNotification(
              id: 1000 + id,
              title: '📢 ${inc['title']}',
              body: '${inc['description']} (${inc['distance_km']}km away)',
              alertType: type,
              severity: 'medium',
              payload: 'community_$id',
            );
          }
        }
        setState(() {
          _lastSeenId = _incidents.first['id'] as int;
        });
      }
    } catch (e) {
      debugPrint('[Community] Fetch error: $e');
      if (initial && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openReportScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportIncidentScreen(
          userId: widget.userId,
          userLocation: widget.userLocation,
        ),
      ),
    );
    if (result == true) {
      // Refresh immediately after posting
      _fetchIncidents(initial: true);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Incident reported successfully!', style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _openFullScreen(Map<String, dynamic> incident) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenIncident(incident: incident),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 16, top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Community Feed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: CiroTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time incidents within 70 km',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // ── Report Button ──
              GestureDetector(
                onTap: _openReportScreen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: CiroTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Report',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Feed ──
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: CiroTheme.primary))
              : _incidents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No incidents reported nearby',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your area looks safe right now',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: CiroTheme.primary,
                      onRefresh: () => _fetchIncidents(initial: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 4),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        itemCount: _incidents.length,
                        itemBuilder: (context, index) {
                          return _buildIncidentCard(_incidents[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final type = incident['incident_type'] as String? ?? 'other';
    final color = typeColors[type] ?? Colors.grey;
    final icon = typeIcons[type] ?? Icons.report_problem_rounded;
    final title = incident['title'] as String? ?? '';
    final desc = incident['description'] as String? ?? '';
    final distance = incident['distance_km'] ?? 0;
    final createdAt = incident['created_at'] as String? ?? '';
    final lat = incident['latitude'] as double? ?? 0;
    final lon = incident['longitude'] as double? ?? 0;
    final radiusKm = (incident['radius_km'] as num?)?.toDouble() ?? 1.0;

    // Parse time ago
    String timeAgo = '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => _openFullScreen(incident),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: CiroTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$timeAgo • ${distance}km away',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      type.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Description ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                desc,
                style: const TextStyle(fontSize: 13, color: CiroTheme.textPrimary, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 10),

            // ── Mini Map ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: SizedBox(
                height: 120,
                child: IgnorePointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lon),
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId('incident_${incident['id']}'),
                        position: LatLng(lat, lon),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          type == 'fire' ? BitmapDescriptor.hueOrange :
                          type == 'flood' ? BitmapDescriptor.hueAzure :
                          type == 'crime' ? BitmapDescriptor.hueViolet :
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: CircleId('radius_${incident['id']}'),
                        center: LatLng(lat, lon),
                        radius: radiusKm * 1000,
                        fillColor: color.withValues(alpha: 0.08),
                        strokeColor: color.withValues(alpha: 0.25),
                        strokeWidth: 1,
                      ),
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    scrollGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    liteModeEnabled: true,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full Screen Incident Viewer ────────────────────────────────────────

class _FullScreenIncident extends StatelessWidget {
  final Map<String, dynamic> incident;

  const _FullScreenIncident({required this.incident});

  @override
  Widget build(BuildContext context) {
    final type = incident['incident_type'] as String? ?? 'other';
    final color = _CommunityScreenState.typeColors[type] ?? Colors.grey;
    final icon = _CommunityScreenState.typeIcons[type] ?? Icons.report_problem_rounded;
    final title = incident['title'] as String? ?? '';
    final desc = incident['description'] as String? ?? '';
    final distance = incident['distance_km'] ?? 0;
    final userId = incident['user_id'] as String? ?? 'Anonymous';
    final lat = incident['latitude'] as double? ?? 0;
    final lon = incident['longitude'] as double? ?? 0;
    final radiusKm = (incident['radius_km'] as num?)?.toDouble() ?? 1.0;
    final createdAt = incident['created_at'] as String? ?? '';

    String timeAgo = '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes} minutes ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours} hours ago';
      } else {
        timeAgo = '${diff.inDays} days ago';
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: CiroTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: CiroTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          type.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Map ──
            SizedBox(
              height: 280,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lon),
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('full_${incident['id']}'),
                    position: LatLng(lat, lon),
                  ),
                },
                circles: {
                  Circle(
                    circleId: CircleId('full_radius_${incident['id']}'),
                    center: LatLng(lat, lon),
                    radius: radiusKm * 1000,
                    fillColor: color.withValues(alpha: 0.1),
                    strokeColor: color.withValues(alpha: 0.35),
                    strokeWidth: 2,
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Icon + Title ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: CiroTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Meta Info ──
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(timeAgo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(width: 16),
                      Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(userId, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(width: 16),
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('${distance}km away', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // ── Description ──
                  const Text('Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CiroTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 15,
                      color: CiroTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Area Info ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.radar_rounded, color: color, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Affected Area',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
                              ),
                              Text(
                                '${radiusKm.toStringAsFixed(1)} km radius from the incident point',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
