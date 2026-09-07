import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../models/sos_alert.dart';
import '../models/nearby_place.dart';
import '../services/location_service.dart';
import '../services/alert_service.dart';
import '../services/contact_service.dart';
import '../services/nearby_places_service.dart';
import 'emergency_contacts_screen.dart';
import 'alert_history_screen.dart';
import 'accident_alert_dialog.dart';
import '../services/accident_detection_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _HomeBody(),
          EmergencyContactsScreen(),
          AlertHistoryScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: AppTheme.glassBorder, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryCyan.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.contacts_outlined,
                activeIcon: Icons.contacts,
                label: 'Contacts',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'History',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryCyan.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: AppTheme.primaryCyan.withOpacity(0.2))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.primaryCyan : AppTheme.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isActive ? AppTheme.primaryCyan : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
// HOME BODY ΓÇö The original home screen content, unchanged visually,
// but with real SOS logic wired in.
// ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> with TickerProviderStateMixin {
  late AnimationController _sosController;
  late Animation<double> _sosPulse;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  late AnimationController _particleController;
  late AnimationController _statusController;
  late Animation<double> _statusPulse;

  bool _sosPressed = false;
  bool _isSending = false;
  String _locationText = 'Location services enabled';
  String _gpsCoords = 'GPS Active';
  double? _currentLat;
  double? _currentLng;
  final MapController _mapController = MapController();

  // Nearby emergency places
  List<NearbyPlace> _nearbyPlaces = [];
  bool _loadingPlaces = false;
  NearbyPlace? _selectedPlace;
  bool _refreshingLocation = false;
  PlaceType? _placeFilter;

  // Accident detection
  late final AccidentDetectionService _accidentService;
  bool _accidentDialogShowing = false;

  @override
  void initState() {
    super.initState();

    // SOS button pulse
    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _sosPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _sosController, curve: Curves.easeInOut),
    );

    // Ripple ring expansion
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    );

    // Background particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    // Status dot pulse
    _statusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _statusPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _statusController, curve: Curves.easeInOut),
    );

    // Fetch initial location
    _fetchLocation();

    // Start accident detection
    _accidentService = AccidentDetectionService();
    _accidentService.startListening(
      onAccidentDetected: _onAccidentDetected,
    );
  }

  void _onAccidentDetected() {
    if (!mounted || _accidentDialogShowing) return;
    _accidentDialogShowing = true;
    AccidentAlertDialog.show(context, onSendSOS: _triggerSOS).then((_) {
      _accidentDialogShowing = false;
      _accidentService.resetCooldown();
    });
  }

  @override
  void dispose() {
    _accidentService.stopListening();
    _sosController.dispose();
    _rippleController.dispose();
    _particleController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final data = await LocationService.getLocationData();
      if (mounted) {
        setState(() {
          _gpsCoords =
              '${data.latitude.toStringAsFixed(4)}┬░, ${data.longitude.toStringAsFixed(4)}┬░';
          _locationText = 'Live location active';
          _currentLat = data.latitude;
          _currentLng = data.longitude;
        });

        // Move map camera to user's current location
        try {
          _mapController.move(
            LatLng(data.latitude, data.longitude),
            15.0,
          );
        } catch (_) {
          // MapController may not be ready yet on first build
        }

        // Fetch nearby emergency places
        _fetchNearbyPlaces(data.latitude, data.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsCoords = 'GPS Active';
          _locationText = e.toString();
        });
      }
    }
  }

  Future<void> _fetchNearbyPlaces(double lat, double lng) async {
    if (_loadingPlaces) return;
    setState(() {
      _loadingPlaces = true;
      _nearbyPlaces = [];
    });

    try {
      debugPrint('[SOS] Fetching nearby places at $lat, $lng ...');
      final places = await NearbyPlacesService.fetchNearbyPlaces(lat, lng);
      debugPrint('[SOS] Found ${places.length} nearby places');
      if (mounted) {
        setState(() {
          _nearbyPlaces = places;
          _loadingPlaces = false;
        });
      }
    } catch (e) {
      debugPrint('[SOS] Error fetching nearby places: $e');
      if (mounted) {
        setState(() => _loadingPlaces = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not load nearby places. Tap refresh to retry.',
              style: AppTheme.bodySmall.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.warningAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () => _fetchNearbyPlaces(lat, lng),
            ),
          ),
        );
      }
    }
  }

  Future<void> _triggerSOS() async {
    if (_isSending) return;

    if (_sosPressed) {
      // Cancel
      setState(() => _sosPressed = false);
      return;
    }

    setState(() {
      _sosPressed = true;
      _isSending = true;
    });

    try {
      final data = await LocationService.getLocationData();
      final contacts = await ContactService.getContacts();

      // Save alert to history
      final alert = SosAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        latitude: data.latitude,
        longitude: data.longitude,
        googleMapsLink: data.googleMapsLink,
        alertType: 'SOS',
      );
      await AlertService.saveAlert(alert);

      // Update location display
      setState(() {
        _gpsCoords =
            '${data.latitude.toStringAsFixed(4)}┬░, ${data.longitude.toStringAsFixed(4)}┬░';
        _locationText = 'Live location active';
      });

      if (mounted) {
        _showSOSConfirmation(data, contacts.length);
      }
    } on LocationException catch (e) {
      if (mounted) {
        _showErrorSnackbar(e.message);
        setState(() => _sosPressed = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to get location: $e');
        setState(() => _sosPressed = false);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _triggerQuickAction(String type) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final data = await LocationService.getLocationData();

      final alert = SosAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        latitude: data.latitude,
        longitude: data.longitude,
        googleMapsLink: data.googleMapsLink,
        alertType: type,
      );
      await AlertService.saveAlert(alert);

      setState(() {
        _gpsCoords =
            '${data.latitude.toStringAsFixed(4)}┬░, ${data.longitude.toStringAsFixed(4)}┬░';
      });

      if (mounted) {
        final message = '≡ƒÜ¿ $type EMERGENCY!\n\n'
            'I need immediate $type assistance!\n\n'
            '≡ƒôì My live location:\n${data.googleMapsLink}\n\n'
            'Coordinates: ${data.latitude.toStringAsFixed(6)}, ${data.longitude.toStringAsFixed(6)}\n\n'
            'ΓÅ░ Time: ${DateTime.now().toString().substring(0, 19)}\n\n'
            'Sent via AI Smart SOS';

        await Share.share(message);
      }
    } on LocationException catch (e) {
      if (mounted) _showErrorSnackbar(e.message);
    } catch (e) {
      if (mounted) _showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSOSConfirmation(LocationData data, int contactCount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppTheme.glassBorder),
              left: BorderSide(color: AppTheme.glassBorder),
              right: BorderSide(color: AppTheme.glassBorder),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Success icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.emergencyRed.withOpacity(0.12),
                  boxShadow:
                      AppTheme.neonGlow(AppTheme.emergencyRed, intensity: 0.4),
                ),
                child:
                    const Icon(Icons.sos, color: AppTheme.emergencyRed, size: 32),
              ),
              const SizedBox(height: 16),
              Text('SOS ALERT LOGGED', style: AppTheme.headingSmall),
              const SizedBox(height: 8),
              Text(
                'Your location has been captured',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Location info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration(
                  borderRadius: 14,
                  opacity: 0.06,
                  borderColor: AppTheme.primaryCyan.withOpacity(0.15),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: AppTheme.primaryCyan, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${data.latitude.toStringAsFixed(6)}, ${data.longitude.toStringAsFixed(6)}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            color: AppTheme.textMuted, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$contactCount emergency contact${contactCount == 1 ? '' : 's'} saved',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Share button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.redGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emergencyRed.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: MaterialButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final message = '≡ƒåÿ EMERGENCY SOS!\n\n'
                        'I need help urgently!\n\n'
                        '≡ƒôì My live location:\n${data.googleMapsLink}\n\n'
                        'Coordinates: ${data.latitude.toStringAsFixed(6)}, ${data.longitude.toStringAsFixed(6)}\n\n'
                        'ΓÅ░ Time: ${DateTime.now().toString().substring(0, 19)}\n\n'
                        'Sent via AI Smart SOS';

                    await Share.share(message);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.share, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('SHARE LOCATION NOW', style: AppTheme.buttonText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel button
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _sosPressed = false);
                },
                child: Text(
                  'Dismiss',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.emergencyRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Stack(
        children: [
          // Particle background
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) {
              return CustomPaint(
                painter: _ParticlePainter(_particleController.value),
                size: Size.infinite,
              );
            },
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildStatusBar(),
                  const SizedBox(height: 16),
                  _buildMapCard(),
                  const SizedBox(height: 8),
                  _buildMapLegend(),
                  const SizedBox(height: 12),
                  _buildPlaceFilterChips(),
                  _buildPlaceCardsList(),
                  const SizedBox(height: 16),
                  _buildSOSButton(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 12),
                  _buildLocationBar(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ΓöÇΓöÇ Top Bar ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // App logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withOpacity(0.1),
              border:
                  Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
            ),
            child: const Icon(Icons.public, color: AppTheme.primaryCyan, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI SMART SOS',
                style: AppTheme.headingSmall.copyWith(fontSize: 14),
              ),
              Text(
                'Emergency Response',
                style: AppTheme.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          // Profile avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.cyanGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryCyan.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  // ΓöÇΓöÇ System Status Bar ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: AppTheme.glassDecoration(
          borderRadius: 16,
          opacity: 0.06,
          borderColor: AppTheme.successGreen.withOpacity(0.15),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _statusPulse,
              builder: (context, _) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successGreen,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successGreen
                            .withOpacity(_statusPulse.value * 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              'SYSTEM ACTIVE',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.successGreen,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.shield_outlined,
                color: AppTheme.successGreen.withOpacity(0.6), size: 18),
            const SizedBox(width: 6),
            Text(
              'Protected',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.successGreen.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ΓöÇΓöÇ SOS Button ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildSOSButton() {
    return Column(
      children: [
        Text(
          _sosPressed ? 'ALERT TRIGGERED' : 'PRESS FOR EMERGENCY',
          style: AppTheme.bodySmall.copyWith(
            letterSpacing: 3,
            color: _sosPressed ? AppTheme.emergencyRed : AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings
              AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _RipplePainter(
                      progress: _rippleAnimation.value,
                      color: _sosPressed
                          ? AppTheme.emergencyRed
                          : AppTheme.emergencyRed.withOpacity(0.4),
                    ),
                    size: const Size(220, 220),
                  );
                },
              ),
              // Main button
              AnimatedBuilder(
                animation: _sosPulse,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _sosPulse.value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: _triggerSOS,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.redGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.emergencyRed.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: AppTheme.emergencyRed.withOpacity(0.2),
                          blurRadius: 60,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: _isSending
                        ? const Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sos,
                                  color: Colors.white, size: 42),
                              const SizedBox(height: 4),
                              Text(
                                'SOS',
                                style: AppTheme.headingSmall.copyWith(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _sosPressed ? 'Tap again to cancel' : 'Tap to send emergency alert',
          style: AppTheme.bodySmall,
        ),
      ],
    );
  }

  // ΓöÇΓöÇ Quick Actions ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              'QUICK ACTIONS',
              style: AppTheme.bodySmall.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              _buildActionCard(
                icon: Icons.local_police_outlined,
                label: 'Police',
                color: const Color(0xFF448AFF),
                onTap: () => _triggerQuickAction('Police'),
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.local_hospital_outlined,
                label: 'Ambulance',
                color: AppTheme.emergencyRed,
                onTap: () => _triggerQuickAction('Ambulance'),
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Fire',
                color: AppTheme.warningAmber,
                onTap: () => _triggerQuickAction('Fire'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: AppTheme.glassDecoration(
            borderRadius: 18,
            opacity: 0.06,
            borderColor: color.withOpacity(0.2),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Map Card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildMapCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryCyan.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    _currentLat ?? 20.5937,
                    _currentLng ?? 78.9629,
                  ),
                  initialZoom: _currentLat != null ? 15.0 : 4.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (_, __) {
                    // Dismiss selected place popup when tapping the map
                    if (_selectedPlace != null) {
                      setState(() => _selectedPlace = null);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ai_smart_sos',
                  ),
                  // Nearby places markers
                  if (_nearbyPlaces.isNotEmpty)
                    MarkerLayer(
                      markers: _nearbyPlaces.map((place) {
                        return Marker(
                          point: LatLng(place.latitude, place.longitude),
                          width: 36,
                          height: 36,
                          child: _buildPlaceMarker(place),
                        );
                      }).toList(),
                    ),
                  // User location marker (on top)
                  if (_currentLat != null && _currentLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_currentLat!, _currentLng!),
                          width: 50,
                          height: 50,
                          child: _buildLocationMarker(),
                        ),
                      ],
                    ),
                ],
              ),

              // Gradient overlay at the top for the label
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.background.withOpacity(0.85),
                        AppTheme.background.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined,
                          color: AppTheme.primaryCyan, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE LOCATION',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      // Loading indicator for nearby places
                      if (_loadingPlaces)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppTheme.primaryCyan.withOpacity(0.6),
                            ),
                          ),
                        ),
                      if (_currentLat != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.successGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'LIVE',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.successGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Selected place info card
              if (_selectedPlace != null)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 50,
                  child: _buildPlaceInfoCard(_selectedPlace!),
                ),

              // Refresh location button
              Positioned(
                bottom: 50,
                right: 10,
                child: GestureDetector(
                  onTap: _refreshingLocation ? null : () async {
                    setState(() => _refreshingLocation = true);
                    await _fetchLocation();
                    setState(() => _refreshingLocation = false);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.successGreen.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successGreen.withOpacity(0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: _refreshingLocation
                        ? Padding(
                            padding: const EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.successGreen,
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            color: AppTheme.successGreen,
                            size: 18,
                          ),
                  ),
                ),
              ),

              // Re-center button
              if (_currentLat != null && _currentLng != null)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      _mapController.move(
                        LatLng(_currentLat!, _currentLng!),
                        15.0,
                      );
                      setState(() => _selectedPlace = null);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryCyan.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryCyan.withOpacity(0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: AppTheme.primaryCyan,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Place Marker ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildPlaceMarker(NearbyPlace place) {
    final color = _placeColor(place.type);
    final icon = _placeIcon(place.type);

    return GestureDetector(
      onTap: () => setState(() => _selectedPlace = place),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.92),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  // ΓöÇΓöÇ Place Info Card (shown on marker tap) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildPlaceInfoCard(NearbyPlace place) {
    final color = _placeColor(place.type);
    final icon = _placeIcon(place.type);
    final typeLabel = _placeLabel(place.type);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.name,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          typeLabel,
                          style: AppTheme.bodySmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.textMuted.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          place.distanceText,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedPlace = null),
                child: Icon(
                  Icons.close,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Navigate button
          GestureDetector(
            onTap: () {
              final url = Uri.parse(
                'https://www.google.com/maps/dir/?api=1'
                '&origin=${_currentLat ?? ''},${_currentLng ?? ''}'
                '&destination=${place.latitude},${place.longitude}'
                '&travelmode=driving',
              );
              launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Navigate',
                    style: AppTheme.bodySmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ΓöÇΓöÇ Map Legend (below map card) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildMapLegend() {
    // Only show legend when loading or when real data is available
    if (!_loadingPlaces && _nearbyPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    final hospitalCount = _nearbyPlaces.where((p) => p.type == PlaceType.hospital).length;
    final policeCount = _nearbyPlaces.where((p) => p.type == PlaceType.police).length;
    final ambulanceCount = _nearbyPlaces.where((p) => p.type == PlaceType.ambulance).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (hospitalCount > 0 || _loadingPlaces)
            _buildLegendItem(
              color: const Color(0xFFFF5252),
              label: 'Hospital',
              count: hospitalCount,
            ),
          if (hospitalCount > 0 || _loadingPlaces)
            const SizedBox(width: 16),
          if (policeCount > 0 || _loadingPlaces)
            _buildLegendItem(
              color: const Color(0xFF448AFF),
              label: 'Police',
              count: policeCount,
            ),
          if (policeCount > 0 || _loadingPlaces)
            const SizedBox(width: 16),
          if (ambulanceCount > 0 || _loadingPlaces)
            _buildLegendItem(
              color: AppTheme.warningAmber,
              label: 'Ambulance',
              count: ambulanceCount,
            ),
          const Spacer(),
          if (_loadingPlaces)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppTheme.primaryCyan.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Searching...',
                  style: AppTheme.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            )
          else if (_nearbyPlaces.isNotEmpty)
            Text(
              '${_nearbyPlaces.length} places found',
              style: AppTheme.bodySmall.copyWith(
                fontSize: 11,
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label${count > 0 ? ' ($count)' : ''}',
          style: AppTheme.bodySmall.copyWith(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ΓöÇΓöÇ Place Filter Chips ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildPlaceFilterChips() {
    if (_nearbyPlaces.isEmpty && !_loadingPlaces) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip(label: 'All', type: null),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Hospital',
            type: PlaceType.hospital,
            icon: Icons.local_hospital,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Police',
            type: PlaceType.police,
            icon: Icons.local_police,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Ambulance',
            type: PlaceType.ambulance,
            icon: Icons.emergency,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required PlaceType? type,
    IconData? icon,
  }) {
    final isActive = _placeFilter == type;
    final color = type != null ? _placeColor(type) : AppTheme.primaryCyan;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _placeFilter = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color.withOpacity(0.5) : AppTheme.glassBorder,
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isActive ? color : AppTheme.textMuted,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Place Cards List ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildPlaceCardsList() {
    if (_nearbyPlaces.isEmpty && !_loadingPlaces) {
      return const SizedBox.shrink();
    }

    final filtered = _placeFilter == null
        ? _nearbyPlaces
        : _nearbyPlaces.where((p) => p.type == _placeFilter).toList();

    if (_loadingPlaces) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryCyan.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Finding nearby places...',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Center(
          child: Text(
            'No ${_placeFilter != null ? _placeLabel(_placeFilter!).toLowerCase() + "s" : "places"} found nearby',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'NEARBY EMERGENCY SERVICES',
              style: AppTheme.bodySmall.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...filtered.take(10).map((place) => _buildPlaceCard(place)),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(NearbyPlace place) {
    final color = _placeColor(place.type);
    final icon = _placeIcon(place.type);
    final typeLabel = _placeLabel(place.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassDecoration(
          borderRadius: 16,
          opacity: 0.06,
          borderColor: color.withOpacity(0.15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + name + status badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        typeLabel,
                        style: AppTheme.bodySmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: place.isNearby
                        ? AppTheme.successGreen.withOpacity(0.12)
                        : AppTheme.primaryCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: place.isNearby
                          ? AppTheme.successGreen.withOpacity(0.3)
                          : AppTheme.primaryCyan.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    place.statusLabel,
                    style: AppTheme.bodySmall.copyWith(
                      color: place.isNearby
                          ? AppTheme.successGreen
                          : AppTheme.primaryCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            // Address
            if (place.address != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      place.address!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Distance + Travel time row
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.straighten,
                    color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 6),
                Text(
                  place.distanceText,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time,
                    color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 6),
                Text(
                  '~${place.estimatedTravelTime}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Action buttons
            const SizedBox(height: 12),
            Row(
              children: [
                // Navigate button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final url = Uri.parse(
                        'https://www.google.com/maps/dir/?api=1'
                        '&origin=${_currentLat ?? ''},${_currentLng ?? ''}'
                        '&destination=${place.latitude},${place.longitude}'
                        '&travelmode=driving',
                      );
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions, color: color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Navigate',
                            style: AppTheme.bodySmall.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Call button (only if phone available)
                if (place.phone != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final url = Uri.parse('tel:${place.phone}');
                        launchUrl(url);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.successGreen.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone, color: AppTheme.successGreen,
                                size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Call',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.successGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Place helper methods ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  static Color _placeColor(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return const Color(0xFFFF5252);
      case PlaceType.police:
        return const Color(0xFF448AFF);
      case PlaceType.ambulance:
        return AppTheme.warningAmber;
    }
  }

  static IconData _placeIcon(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return Icons.local_hospital;
      case PlaceType.police:
        return Icons.local_police;
      case PlaceType.ambulance:
        return Icons.emergency;
    }
  }

  static String _placeLabel(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return 'Hospital';
      case PlaceType.police:
        return 'Police Station';
      case PlaceType.ambulance:
        return 'Ambulance';
    }
  }

  Widget _buildLocationMarker() {
    const Color markerBlue = Color(0xFF4285F4);
    return AnimatedBuilder(
      animation: _statusPulse,
      builder: (context, _) {
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              Container(
                width: 40 + (_statusPulse.value * 10),
                height: 40 + (_statusPulse.value * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: markerBlue
                      .withOpacity(0.12 * (1 - _statusPulse.value * 0.5)),
                  border: Border.all(
                    color: markerBlue
                        .withOpacity(0.35 * (1 - _statusPulse.value * 0.5)),
                    width: 1.5,
                  ),
                ),
              ),
              // Inner blue dot
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: markerBlue,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: markerBlue.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ΓöÇΓöÇ Location Bar ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: AppTheme.glassDecoration(
          borderRadius: 14,
          opacity: 0.05,
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined,
                color: AppTheme.primaryCyan.withOpacity(0.7), size: 20),
            const SizedBox(width: 10),
            Text(
              _gpsCoords,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryCyan.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.successGreen,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                _locationText,
                style: AppTheme.bodySmall.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ΓöÇΓöÇ Ripple Painter ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = 70 + ringProgress * 40;
      final opacity = (1 - ringProgress) * 0.4;

      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ΓöÇΓöÇ Particle Painter ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint();

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.15 + random.nextDouble() * 0.5;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.4 + random.nextDouble() * 1.0;
      final opacity = 0.06 + random.nextDouble() * 0.2;

      paint.color = (i % 7 == 0 ? AppTheme.primaryCyan : Colors.white)
          .withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
