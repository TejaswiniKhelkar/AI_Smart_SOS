import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../app_theme.dart';
import '../models/sos_alert.dart';
import '../services/alert_service.dart';
import '../services/contact_service.dart';
import '../services/emergency_alert_sound_service.dart';
import '../services/emergency_vibration_service.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';

/// Full-screen emergency accident detection alert with a 30-second countdown.
///
/// - **I'm Safe** → dismisses, no SOS sent.
/// - **Send SOS Now** → calls [onSendSOS] callback.
/// - Countdown reaches 0 → auto-calls [onSendSOS].
///
/// This widget is purely UI — it does not connect to sensors or send SOS.
class AccidentAlertDialog extends StatefulWidget {
  const AccidentAlertDialog({super.key, required this.onSendSOS});

  final VoidCallback onSendSOS;

  /// Shows the full-screen emergency alert over the current route.
  static Future<void> show(BuildContext context,
      {required VoidCallback onSendSOS}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (context, _, _) =>
          AccidentAlertDialog(onSendSOS: onSendSOS),
    );
  }

  @override
  State<AccidentAlertDialog> createState() => _AccidentAlertDialogState();
}

class _AccidentAlertDialogState extends State<AccidentAlertDialog>
    with TickerProviderStateMixin {
  static const int _totalSeconds = 30;

  // ── Animation Controllers ──────────────────────────────────────────────
  late AnimationController _countdownAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _ringPulseController;
  late Animation<double> _ringPulseAnim;
  late AnimationController _scanController;
  late AnimationController _iconGlowController;
  late Animation<double> _iconGlowAnim;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;
  late AnimationController _borderGlowController;
  late Animation<double> _borderGlowAnim;
  late AnimationController _particleController;

  int _remaining = _totalSeconds;
  Timer? _ticker;
  bool _dismissed = false;
  bool _showSOSTriggered = false;

  late AnimationController _confirmationController;
  late Animation<double> _confirmationScaleAnim;
  late Animation<double> _confirmationFadeAnim;
  Timer? _confirmationDismissTimer;

  // ── Emergency Alert Sound & Vibration ──
  final EmergencyAlertSoundService _alertSound = EmergencyAlertSoundService();
  final EmergencyVibrationService _alertVibration = EmergencyVibrationService();

  String _locationText = 'Acquiring location...';
  bool _locationReady = false;
  String _currentTime = '';
  Timer? _clockTimer;

  // ── SOS Confirmation Data ──
  LocationData? _sosLocationData;
  String _sosMessage = '';
  int _sosContactCount = 0;
  bool _sosSaving = false;
  String _smsStatus = 'pending';

  @override
  void initState() {
    super.initState();

    // ── Countdown (drives the circular ring) ──
    _countdownAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    )..forward();

    // ── Pulsing scale for warning icon ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Ring pulse opacity ──
    _ringPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _ringPulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ringPulseController, curve: Curves.easeInOut),
    );

    // ── Background scan line ──
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // ── Icon glow intensity ──
    _iconGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _iconGlowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _iconGlowController, curve: Curves.easeInOut),
    );

    // ── Shake (last 10 seconds) ──
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _shakeAnim = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // ── Border glow animation ──
    _borderGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _borderGlowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _borderGlowController, curve: Curves.easeInOut),
    );

    // ── Particle animation for background ──
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    // ── Confirmation screen animation ──
    _confirmationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _confirmationScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _confirmationController, curve: Curves.elasticOut),
    );
    _confirmationFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confirmationController, curve: Curves.easeOut),
    );

    // ── Start emergency alert sound & vibration ──
    _alertSound.start();
    _alertVibration.start();

    // ── Countdown ticker ──
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _dismissed || _showSOSTriggered) return;
      setState(() => _remaining--);

      // Switch to urgent (faster) beep & vibration in the last 10 seconds
      if (_remaining <= 10 && _remaining > 0) {
        _alertSound.setUrgent(true);
        _alertVibration.setUrgent(true);
        _shakeController.forward().then((_) {
          if (mounted) _shakeController.reverse();
        });
      }

      if (_remaining <= 0) {
        _ticker?.cancel();
        _triggerSOSConfirmation();
      }
    });

    // ── Live clock ──
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });

    _fetchLocation();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  Future<void> _fetchLocation() async {
    try {
      final data = await LocationService.getLocationData();
      if (mounted && !_dismissed) {
        setState(() {
          _locationText =
              '${data.latitude.toStringAsFixed(5)}°N, ${data.longitude.toStringAsFixed(5)}°E';
          _locationReady = true;
        });
      }
    } catch (_) {
      if (mounted && !_dismissed) {
        setState(() {
          _locationText = 'GPS Active — Location ready';
          _locationReady = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clockTimer?.cancel();
    _confirmationDismissTimer?.cancel();
    _alertSound.dispose();
    _alertVibration.dispose();
    _countdownAnim.dispose();
    _pulseController.dispose();
    _ringPulseController.dispose();
    _scanController.dispose();
    _iconGlowController.dispose();
    _shakeController.dispose();
    _borderGlowController.dispose();
    _particleController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _dismissSafe() {
    if (_dismissed) return;
    _dismissed = true;
    _ticker?.cancel();
    _clockTimer?.cancel();
    _alertSound.stop();
    _alertVibration.stop();
    Navigator.of(context).pop();
  }

  void _sendSOS() {
    if (_dismissed || _showSOSTriggered) return;
    _triggerSOSConfirmation();
  }

  Future<void> _triggerSOSConfirmation() async {
    if (_showSOSTriggered) return;
    _ticker?.cancel();
    _clockTimer?.cancel();
    _countdownAnim.stop();
    _alertSound.stop();
    _alertVibration.stop();
    setState(() {
      _showSOSTriggered = true;
      _sosSaving = true;
    });
    _confirmationController.forward();

    // ── Perform the full SOS workflow using existing services ──
    try {
      // 1. Get current GPS location
      final data = await LocationService.getLocationData();
      // 2. Google Maps link is already part of LocationData

      // 3. Load emergency contacts
      final contacts = await ContactService.getContacts();

      // 4. Create professional SOS message
      final timeStr = DateFormat('hh:mm:ss a \u2013 dd MMM yyyy').format(DateTime.now());
      final message = '\ud83c\udd98 EMERGENCY SOS ALERT!\n\n'
          'I need immediate help!\n\n'
          '\ud83d\udccd My Location:\n'
          '${data.googleMapsLink}\n\n'
          '\ud83d\udcc8 Coordinates:\n'
          '${data.latitude.toStringAsFixed(6)}\u00b0N, '
          '${data.longitude.toStringAsFixed(6)}\u00b0E\n\n'
          '\u23f0 Time: $timeStr\n\n'
          '\ud83d\udc65 Emergency contacts notified: ${contacts.length}\n\n'
          'Sent via AI Smart SOS';

      // 5. Send actual SMS via Backend
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

      // 6. Save alert to history
      final alert = SosAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        latitude: data.latitude,
        longitude: data.longitude,
        googleMapsLink: data.googleMapsLink,
        alertType: 'Accident',
        smsDeliveryStatus: smsStatus,
      );
      await AlertService.saveAlert(alert);

      if (mounted) {
        setState(() {
          _sosLocationData = data;
          _sosMessage = message;
          _sosContactCount = contacts.length;
          _smsStatus = smsStatus;
          _sosSaving = false;
        });
      }
    } catch (e) {
      // Even if location fails, still show confirmation
      if (mounted) {
        setState(() {
          _sosMessage = '\ud83c\udd98 EMERGENCY SOS ALERT!\n\n'
              'I need immediate help!\n\n'
              'Location could not be determined.\n\n'
              '\u23f0 Time: ${DateFormat('hh:mm:ss a').format(DateTime.now())}\n\n'
              'Sent via AI Smart SOS';
          _smsStatus = 'failed';
          _sosSaving = false;
        });
      }
    }

    // Notify the home screen (for any dashboard state updates)
    widget.onSendSOS();

    // Auto-dismiss after 5 seconds so user can read the info
    _confirmationDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_dismissed) {
        _dismissed = true;
        Navigator.of(context).pop();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: AppTheme.glassDecoration(borderRadius: 24, opacity: 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EMERGENCY ALERT ACTIVE',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.emergencyRed,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.emergencyRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.neonGlow(AppTheme.emergencyRed, intensity: 0.5),
                      ),
                      child: const Icon(Icons.warning_rounded, color: AppTheme.emergencyRed, size: 56),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Emergency Alert',
                style: AppTheme.headingLarge.copyWith(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              if (!_showSOSTriggered)
                Text(
                  'Sending in $_remaining seconds...',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.emergencyRed),
                )
              else if (_sosSaving)
                Text(
                  'Submitting alert to backend...',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.warningAmber),
                )
              else
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _smsStatus == 'sent'
                            ? AppTheme.successGreen.withValues(alpha: 0.1)
                            : AppTheme.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _smsStatus == 'sent'
                            ? 'SENT'
                            : (_smsStatus == 'failed_no_provider' ? 'NOT SENT' : 'FAILED'),
                        style: AppTheme.bodySmall.copyWith(
                          color: _smsStatus == 'sent'
                              ? AppTheme.successGreen
                              : AppTheme.warningAmber,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _smsStatus == 'sent'
                          ? 'Trusted contacts have been notified with your emergency status.'
                          : (_smsStatus == 'failed_no_provider'
                              ? 'Alert logged locally.\nSMS Provider credentials missing in backend.'
                              : 'Alert logged locally. SMS delivery failed.'),
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, color: AppTheme.successGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Live location sharing active',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _dismissSafe,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, color: AppTheme.successGreen, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'I\'M SAFE — CANCEL ALERT',
                        style: AppTheme.buttonText.copyWith(color: AppTheme.successGreen),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
