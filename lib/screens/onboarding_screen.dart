import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ciro_theme.dart';
import 'weather_map_screen.dart';

/// Premium, beautifully-designed Onboarding screen for Ciro App.
///
/// Asks for User Name, City Name, requests native Location Permission,
/// resolves dynamic IP address, and saves details to SharedPreferences.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isRequestingPermission = false;
  bool _isSaving = false;
  String? _resolvedIp;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchPublicIp();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Automatically fetch user's public IP address at startup
  Future<void> _fetchPublicIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _resolvedIp = data['ip'];
        });
      }
    } catch (e) {
      debugPrint('[Onboarding] IP fetch failed: $e');
      setState(() {
        _resolvedIp = "127.0.0.1"; // Localhost fallback
      });
    }
  }

  /// Request dynamic location permissions natively
  Future<void> _requestLocationPermission() async {
    if (_isRequestingPermission) return;
    setState(() {
      _isRequestingPermission = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 6));

        setState(() {
          _currentPosition = position;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Location verified successfully!'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.teal.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) {
          _showPermissionErrorDialog();
        }
      }
    } catch (e) {
      debugPrint('[Onboarding] Error requesting location: $e');
    } finally {
      setState(() {
        _isRequestingPermission = false;
      });
    }
  }

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('Permission Needed'),
          ],
        ),
        content: const Text(
          'CIRO requires location access to monitor severe weather anomalies in your vicinity. Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Complete onboarding: save state and redirect to main screen
  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Please verify your location permission before continuing.')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameController.text.trim());
      await prefs.setString('user_city', _cityController.text.trim());
      await prefs.setString('user_ip', _resolvedIp ?? '127.0.0.1');
      await prefs.setDouble('user_lat', _currentPosition!.latitude);
      await prefs.setDouble('user_lon', _currentPosition!.longitude);
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WeatherMapScreen()),
      );
    } catch (e) {
      debugPrint('[Onboarding] Saving onboarding failed: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: CiroTheme.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 40.0,
            bottom: bottomPadding + 24.0,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header area
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CiroTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.thunderstorm_rounded,
                      color: CiroTheme.primary,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to CIRO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: CiroTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time emergency tracking and smart weather anomalies',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),

                // Onboarding Card Box
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name field
                      const Text(
                        'Your Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: CiroTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: CiroTheme.primary, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // City field
                      const Text(
                        'Home City',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: CiroTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cityController,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Gujrat',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: CiroTheme.primary, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your home city';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Location permission btn
                      ElevatedButton(
                        onPressed: _isRequestingPermission ? null : _requestLocationPermission,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _currentPosition != null
                              ? Colors.teal.shade50
                              : CiroTheme.primary.withValues(alpha: 0.1),
                          foregroundColor: _currentPosition != null
                              ? Colors.teal.shade700
                              : CiroTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isRequestingPermission
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _currentPosition != null
                                        ? Icons.gps_fixed_rounded
                                        : Icons.location_on_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _currentPosition != null
                                        ? 'Permission Granted'
                                        : 'Grant Location Permission',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Submit/Continue onboarding button
                ElevatedButton(
                  onPressed: _isSaving ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: CiroTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text(
                          'Get Started',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
