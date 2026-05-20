import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/ciro_theme.dart';
import '../services/community_service.dart';

/// A clean, minimal screen to report a new community incident.
/// The user selects the type, enters details, and picks a location on the map.
class ReportIncidentScreen extends StatefulWidget {
  final String userId;
  final LatLng userLocation;

  const ReportIncidentScreen({
    super.key,
    required this.userId,
    required this.userLocation,
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'accident';
  late LatLng _incidentLocation;
  double _radiusKm = 1.0;
  bool _isSubmitting = false;

  static const Map<String, IconData> _typeIcons = {
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

  static const Map<String, String> _typeLabels = {
    'accident': 'Accident',
    'fire': 'Fire',
    'flood': 'Flooding',
    'road_closure': 'Road Closure',
    'power_outage': 'Power Outage',
    'gas_leak': 'Gas Leak',
    'protest': 'Protest',
    'crime': 'Crime',
    'medical': 'Medical',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _incidentLocation = widget.userLocation;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      _showSnackBar('Please enter a title for the incident');
      return;
    }
    if (description.isEmpty) {
      _showSnackBar('Please describe the incident');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await CommunityService.createIncident(
        userId: widget.userId,
        title: title,
        description: description,
        incidentType: _selectedType,
        latitude: _incidentLocation.latitude,
        longitude: _incidentLocation.longitude,
        userLatitude: widget.userLocation.latitude,
        userLongitude: widget.userLocation.longitude,
        radiusKm: _radiusKm,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to signal success
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: CiroTheme.crisisRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Report Incident',
          style: TextStyle(
            color: CiroTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Incident Type Selector ──
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CiroTheme.textPrimary)),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _typeIcons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final type = _typeIcons.keys.elementAt(index);
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        decoration: BoxDecoration(
                          color: isSelected ? CiroTheme.primary.withValues(alpha: 0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? CiroTheme.primary : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _typeIcons[type],
                              color: isSelected ? CiroTheme.primary : Colors.grey.shade500,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _typeLabels[type]!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? CiroTheme.primary : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Title Field ──
              const Text('Title', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CiroTheme.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 15, color: CiroTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Major accident on GT Road',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CiroTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 20),

              // ── Description Field ──
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CiroTheme.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(fontSize: 15, color: CiroTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Describe what happened, what you saw...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CiroTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 20),

              // ── Location Map ──
              const Text('Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CiroTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Tap to move the marker to the incident location',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: widget.userLocation,
                      zoom: 14,
                    ),
                    onTap: (latLng) {
                      setState(() => _incidentLocation = latLng);
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('incident_pin'),
                        position: _incidentLocation,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        draggable: true,
                        onDragEnd: (newPos) {
                          setState(() => _incidentLocation = newPos);
                        },
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('radius'),
                        center: _incidentLocation,
                        radius: _radiusKm * 1000,
                        fillColor: CiroTheme.crisisRed.withValues(alpha: 0.08),
                        strokeColor: CiroTheme.crisisRed.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      ),
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Radius Slider ──
              Row(
                children: [
                  const Text('Area Radius', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CiroTheme.textPrimary)),
                  const Spacer(),
                  Text(
                    '${_radiusKm.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CiroTheme.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radiusKm,
                min: 0.5,
                max: 10.0,
                divisions: 19,
                activeColor: CiroTheme.primary,
                inactiveColor: Colors.grey.shade200,
                onChanged: (v) => setState(() => _radiusKm = v),
              ),

              const SizedBox(height: 20),

              // ── Submit Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CiroTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
