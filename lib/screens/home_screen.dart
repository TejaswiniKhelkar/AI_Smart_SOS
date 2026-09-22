import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../models/sos_alert.dart';
import '../services/location_service.dart';
import '../services/alert_service.dart';
import '../services/contact_service.dart';
import '../services/nearby_places_service.dart';
import '../services/sms_service.dart';
import '../models/nearby_place.dart';
import 'emergency_contacts_screen.dart';
import 'nearby_services_screen.dart';
import 'alert_history_screen.dart';
import 'accident_alert_dialog.dart';
import 'ai_emergency_dashboard_screen.dart';
import 'ai_profile_screen.dart';
import '../services/foreground_sensor_bridge.dart';
import '../services/settings_service.dart';
import '../widgets/global_drawer.dart';

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
      drawer: GlobalDrawer(
        onTabSelected: (index) {
          setState(() {
            _currentTab = index;
          });
        },
      ),
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _HomeBody(),
          AiEmergencyDashboardScreen(),
          AiProfileScreen(),
          AlertHistoryScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppTheme.glassBorder, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryCyan.withValues(alpha: 0.05),
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
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'AI Chat',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'History',
                index: 3,
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
              ? AppTheme.primaryCyan.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.2))
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
  List<dynamic> _contacts = [];
  bool _loadingContacts = true;

  Future<void> _fetchContacts() async {
    try {
      // dynamic to avoid import issues if Contact is not imported
      final contacts = await ContactService.getContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _loadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

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

  List<NearbyPlace> _nearbyPlaces = [];
  bool _loadingPlaces = true;
  String _nearbyError = '';

  // Accident detection
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

    // Start accident detection if enabled in settings
    ForegroundSensorBridge.instance.onAccidentDetected = _onAccidentDetected;
    SettingsService.getSettings().then((settings) {
      if (settings.accidentDetection && mounted) {
        ForegroundSensorBridge.instance.start();
      }
    });
  }

  void _onAccidentDetected() {
    if (!mounted || _accidentDialogShowing) return;
    _accidentDialogShowing = true;
    ForegroundSensorBridge.instance.dismissAccidentAlertNotification();
    AccidentAlertDialog.show(context, onSendSOS: _triggerSOS).then((_) {
      _accidentDialogShowing = false;
    });
  }

  @override
  void dispose() {
    ForegroundSensorBridge.instance.onAccidentDetected = null;
    _sosController.dispose();
    _rippleController.dispose();
    _particleController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final data = await LocationService.getLocationData();
      final address = await LocationService.getAddressFromCoordinates(data.latitude, data.longitude);

      if (mounted) {
        setState(() {
          _gpsCoords =
              '${data.latitude.toStringAsFixed(4)}┬░, ${data.longitude.toStringAsFixed(4)}┬░';
          _locationText = address ?? 'Live location active';
          _currentLat = data.latitude;
          _currentLng = data.longitude;
        });

        _fetchNearbyPlaces(data.latitude, data.longitude);

        // Move map camera to user's current location
        try {
          _mapController.move(
            LatLng(data.latitude, data.longitude),
            15.0,
          );
        } catch (_) {
          // MapController may not be ready yet on first build
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsCoords = 'Location Unavailable';
          _locationText = e is LocationException 
              ? e.message 
              : 'Unable to get your location. Please check GPS and try again.';
          _loadingPlaces = false;
          _nearbyError = 'Location required for nearby services';
        });
      }
    }
  }

  Future<void> _fetchNearbyPlaces(double lat, double lng) async {
    try {
      final places = await NearbyPlacesService.fetchNearbyPlaces(lat, lng);
      if (mounted) {
        setState(() {
          _nearbyPlaces = places;
          _loadingPlaces = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPlaces = false;
          _nearbyError = 'Failed to load nearby services';
        });
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

      // Send SMS via Backend
      String smsStatus = 'pending';
      try {
        smsStatus = await SmsService.sendEmergencySMS(
          latitude: data.latitude,
          longitude: data.longitude,
          googleMapsLink: data.googleMapsLink,
        );
      } catch (e) {
        smsStatus = 'failed';
      }

      // Save alert to history
      final alert = SosAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        latitude: data.latitude,
        longitude: data.longitude,
        googleMapsLink: data.googleMapsLink,
        alertType: 'SOS',
        smsDeliveryStatus: smsStatus,
      );
      await AlertService.saveAlert(alert);

      // Update location display
      setState(() {
        _gpsCoords =
            '${data.latitude.toStringAsFixed(4)}┬░, ${data.longitude.toStringAsFixed(4)}┬░';
        _locationText = 'Live location active';
      });

      if (mounted) {
        _showSOSConfirmation(data, contacts.length, smsStatus);
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

      // Send SMS via Backend
      String smsStatus = 'pending';
      try {
        smsStatus = await SmsService.sendEmergencySMS(
          latitude: data.latitude,
          longitude: data.longitude,
          googleMapsLink: data.googleMapsLink,
        );
      } catch (e) {
        smsStatus = 'failed';
      }

      final alert = SosAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        latitude: data.latitude,
        longitude: data.longitude,
        googleMapsLink: data.googleMapsLink,
        alertType: type,
        smsDeliveryStatus: smsStatus,
      );
      await AlertService.saveAlert(alert);

      setState(() {
        _gpsCoords =
            '${data.latitude.toStringAsFixed(4)}°, ${data.longitude.toStringAsFixed(4)}°';
      });

      if (mounted) {
        _showSOSConfirmation(data, 0, smsStatus);
      }
    } on LocationException catch (e) {
      if (mounted) _showErrorSnackbar(e.message);
    } catch (e) {
      if (mounted) _showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSOSConfirmation(LocationData data, int contactCount, String smsStatus) {
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
                  color: AppTheme.textMuted.withValues(alpha: 0.4),
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
                  color: AppTheme.emergencyRed.withValues(alpha: 0.12),
                  boxShadow:
                      AppTheme.neonGlow(AppTheme.emergencyRed, intensity: 0.4),
                ),
                child:
                    const Icon(Icons.sos, color: AppTheme.emergencyRed, size: 32),
              ),
              const SizedBox(height: 16),
              Text('SOS ALERT LOGGED', style: AppTheme.headingSmall),
              const SizedBox(height: 8),
              
              if (smsStatus == 'sent')
                Text(
                  'Alert sent to $contactCount emergency contacts.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.successGreen),
                )
              else if (smsStatus == 'queued')
                Text(
                  'Network unavailable.\nEmergency alert saved and queued.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.warningAmber),
                )
              else if (smsStatus == 'failed_no_provider')
                Text(
                  'Alert logged locally.\nSMS Not Sent: Provider credentials missing in backend.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.warningAmber),
                )
              else
                Text(
                  'Alert logged locally.\nSMS delivery failed.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.emergencyRed),
                ),
              const SizedBox(height: 20),

              // Location info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration(
                  borderRadius: 14,
                  opacity: 0.06,
                  borderColor: AppTheme.primaryCyan.withValues(alpha: 0.15),
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

              Container(
                width: double.infinity,
                height: 54,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(
                      'https://maps.google.com/?q=${data.latitude},${data.longitude}',
                    );

                    await launchUrl(
                      url,
                      mode: LaunchMode.platformDefault,
                    );
                  },
                  icon: const Icon(Icons.map),
                  label: const Text("OPEN IN GOOGLE MAPS"),
                ),
              ),


              // Share button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.redGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emergencyRed.withValues(alpha: 0.3),
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
      color: AppTheme.background,
      child: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  _buildSOSButton(),
                  const SizedBox(height: 20),
                  _buildLocationBar(),
                  const SizedBox(height: 24),
                  _buildNearbyServicesSection(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildAssistantCard(),
                  const SizedBox(height: 24),
                  _buildEmergencyContactsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Temporary Test Emergency Button (for testing popup) ──
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildTestEmergencyButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestEmergencyButton() {
    return GestureDetector(
      onTap: () {
        AccidentAlertDialog.show(
          context,
          onSendSOS: _triggerSOS,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.emergencyRed,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emergencyRed.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Test Emergency',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(Icons.menu, color: AppTheme.primaryCyan, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI SMART SOS',
                style: AppTheme.headingMedium.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 2),
              Text(
                'Emergency Response',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.successGreen, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Protected',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: AppTheme.glassDecoration(borderRadius: 32),
        child: Column(
          children: [
            Text(
              'PRESS FOR EMERGENCY',
              style: AppTheme.bodyMedium.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _triggerSOS,
              child: AnimatedBuilder(
                animation: _sosPulse,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _sosPulse.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.redGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emergencyRed.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppTheme.emergencyRed.withValues(alpha: 0.1),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: _isSending
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SOS',
                              style: AppTheme.headingLarge.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Tap to send emergency alert',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: AppTheme.successGreen, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Location shared with trusted contacts',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: AppTheme.glassDecoration(borderRadius: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.my_location, color: AppTheme.primaryCyan, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Location',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _locationText,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (_currentLat == null && _gpsCoords == 'Location Unavailable')
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryCyan),
                onPressed: () {
                  setState(() {
                    _locationText = 'Fetching...';
                  });
                  _fetchLocation();
                },
              )
            else
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gpsCoords.contains('°') ? AppTheme.successGreen : AppTheme.warningAmber,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionCard(
                icon: Icons.local_police,
                label: 'Police',
                number: '100',
                color: AppTheme.primaryCyan,
                onTap: () => _triggerQuickAction('Police'),
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.local_hospital,
                label: 'Ambulance',
                number: '108',
                color: AppTheme.emergencyRed,
                onTap: () => _triggerQuickAction('Ambulance'),
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.local_fire_department,
                label: 'Fire',
                number: '101',
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
    required String number,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: AppTheme.glassDecoration(borderRadius: 20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                number,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          setState(() {
            final state = context.findAncestorStateOfType<_HomeScreenState>();
            if (state != null) {
              state.setState(() => state._currentTab = 1);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.cyanGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Emergency Assistant',
                      style: AppTheme.headingSmall.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get safe guidance instantly.',
                      style: AppTheme.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmergencyContactsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency Contacts',
                style: AppTheme.headingSmall.copyWith(color: AppTheme.textPrimary),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
                  ).then((_) => _fetchContacts());
                },
                child: Text(
                  'Manage',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingContacts)
            const Center(child: CircularProgressIndicator())
          else if (_contacts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassDecoration(borderRadius: 16),
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: AppTheme.textMuted, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No contacts added yet',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            ..._contacts.take(3).map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: AppTheme.glassDecoration(borderRadius: 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          contact.name.substring(0, 1).toUpperCase(),
                          style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryCyan),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact.relationship,
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.call, color: AppTheme.successGreen),
                        onPressed: () {
                          // Call logic
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNearbyServicesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Emergency Services',
                style: AppTheme.headingSmall.copyWith(color: AppTheme.textPrimary),
              ),
              Row(
                children: [
                  if (_loadingPlaces)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan),
                      ),
                    ),
                  if (!_loadingPlaces && _nearbyPlaces.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NearbyServicesScreen(
                              places: _nearbyPlaces,
                              currentLat: _currentLat ?? 0,
                              currentLng: _currentLng ?? 0,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'View All →',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingPlaces)
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return Container(
                    width: 280,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassDecoration(borderRadius: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.textMuted.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 120,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: AppTheme.textMuted.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 80,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppTheme.textMuted.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.textMuted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else if (_nearbyPlaces.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nearbyError.isNotEmpty ? _nearbyError : 'No services found within 20km.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
                ),
                if (_nearbyError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () {
                        if (_currentLat != null && _currentLng != null) {
                          setState(() {
                            _loadingPlaces = true;
                            _nearbyError = '';
                          });
                          _fetchNearbyPlaces(_currentLat!, _currentLng!);
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Retry',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryCyan, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
              ],
            )
          else if (_nearbyPlaces.isNotEmpty)
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _nearbyPlaces.length > 5 ? 5 : _nearbyPlaces.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final place = _nearbyPlaces[index];
                  final isHospital = place.type == PlaceType.hospital;
                  final isPolice = place.type == PlaceType.police;
                  
                  final icon = isHospital 
                    ? Icons.local_hospital 
                    : (isPolice ? Icons.local_police : Icons.local_fire_department);
                  
                  final color = isHospital 
                    ? AppTheme.emergencyRed 
                    : (isPolice ? AppTheme.primaryCyan : AppTheme.warningAmber);

                  return Container(
                    width: 280,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassDecoration(borderRadius: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
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
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${place.distanceText} ΓÇó ${place.address ?? "Unknown Address"}',
                                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (place.isOpen != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (place.isOpen! ? AppTheme.successGreen : AppTheme.emergencyRed).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  place.isOpen! ? 'Open' : 'Closed',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: place.isOpen! ? AppTheme.successGreen : AppTheme.emergencyRed,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                final url = Uri.parse(
                                  'https://www.google.com/maps/dir/?api=1'
                                  '&origin=${_currentLat ?? ""},${_currentLng ?? ""}'
                                  '&destination=${place.latitude},${place.longitude}'
                                  '&travelmode=driving',
                                );
                                launchUrl(url, mode: LaunchMode.externalApplication);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.navigation, size: 14, color: AppTheme.primaryCyan),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Navigate',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.primaryCyan,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
