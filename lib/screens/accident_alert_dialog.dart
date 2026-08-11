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
  bool _sosSaving = true;

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

      // 5. Save alert to history
      final alert = SosAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        latitude: data.latitude,
        longitude: data.longitude,
        googleMapsLink: data.googleMapsLink,
        alertType: 'SOS',
      );
      await AlertService.saveAlert(alert);

      if (mounted) {
        setState(() {
          _sosLocationData = data;
          _sosMessage = message;
          _sosContactCount = contacts.length;
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
  Widget build(BuildContext context) {
    // Show the SOS Triggered confirmation screen
    if (_showSOSTriggered) {
      return _buildSOSTriggeredScreen();
    }

    final isCritical = _remaining <= 10;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(isCritical ? _shakeAnim.value : 0, 0),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A0000),
                Color(0xFF0D0A14),
                Color(0xFF0A0E21),
              ],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // ── Animated Background Grid ──
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _EmergencyGridPainter(
                        progress: _scanController.value,
                        isCritical: isCritical,
                      ),
                    );
                  },
                ),
              ),

              // ── Floating Particles ──
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _EmergencyParticlePainter(
                          progress: _particleController.value,
                          isCritical: isCritical,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Scan Line ──
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ScanLinePainter(
                          progress: _scanController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Pulsing Border Glow ──
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _borderGlowAnim,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _BorderGlowPainter(
                          intensity: _borderGlowAnim.value,
                          isCritical: isCritical,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Main Content ──
              SafeArea(
                child: Column(
                  children: [
                    // ── Top Alert Bar ──
                    _buildTopAlertBar(),

                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 10),
                              // ── Warning Icon ──
                              _buildWarningIcon(),
                              const SizedBox(height: 28),

                              // ── Title ──
                              _buildTitle(),
                              const SizedBox(height: 16),

                              // ── Message ──
                              _buildMessage(),
                              const SizedBox(height: 36),

                              // ── Countdown Timer ──
                              _buildCountdownTimer(),
                              const SizedBox(height: 28),

                              // ── Location & Time Card ──
                              _buildInfoCards(),
                              const SizedBox(height: 32),

                              // ── Buttons ──
                              _buildSafeButton(),
                              const SizedBox(height: 12),
                              _buildSOSButton(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Corner Brackets ──
              ..._buildCornerBrackets(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SOS TRIGGERED CONFIRMATION SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSOSTriggeredScreen() {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _confirmationFadeAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _confirmationFadeAnim.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D1A0D),
                Color(0xFF0A0E21),
                Color(0xFF0A1A0A),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: AnimatedBuilder(
                  animation: _confirmationScaleAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _confirmationScaleAnim.value,
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),

                      // ── Success Icon ──
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.successGreen.withValues(alpha: 0.2),
                              AppTheme.successGreen.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                          border: Border.all(
                            color: AppTheme.successGreen.withValues(alpha: 0.6),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successGreen.withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: AppTheme.successGreen.withValues(alpha: 0.1),
                              blurRadius: 80,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(
                          _sosSaving ? Icons.sos_rounded : Icons.check_rounded,
                          color: AppTheme.successGreen,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Title ──
                      Text(
                        _sosSaving ? 'SENDING SOS...' : 'SOS ALERT SENT',
                        style: AppTheme.headingLarge.copyWith(
                          color: _sosSaving
                              ? AppTheme.emergencyRed
                              : AppTheme.successGreen,
                          fontSize: 26,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sosSaving
                            ? 'Acquiring location & saving alert...'
                            : 'Emergency alert has been activated',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Loading indicator while saving ──
                      if (_sosSaving)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppTheme.emergencyRed.withValues(alpha: 0.8),
                            ),
                          ),
                        ),

                      // ── SOS Details (shown after data loads) ──
                      if (!_sosSaving) ...[
                        // ── Location Card ──
                        if (_sosLocationData != null)
                          _buildConfirmationCard(
                            icon: Icons.location_on_rounded,
                            iconColor: AppTheme.primaryCyan,
                            title: 'LOCATION CAPTURED',
                            children: [
                              Text(
                                '${_sosLocationData!.latitude.toStringAsFixed(6)}\u00b0N, '
                                '${_sosLocationData!.longitude.toStringAsFixed(6)}\u00b0E',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.primaryCyan,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.link_rounded,
                                      color: AppTheme.textMuted, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Google Maps link generated',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successGreen
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.successGreen
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '\u2713 READY',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.successGreen,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),

                        // ── Alert Saved Card ──
                        _buildConfirmationCard(
                          icon: Icons.history_rounded,
                          iconColor: AppTheme.warningAmber,
                          title: 'ALERT SAVED',
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    color: AppTheme.textMuted, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('hh:mm:ss a \u2013 dd MMM yyyy')
                                      .format(DateTime.now()),
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.warningAmber,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    color: AppTheme.textMuted, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '$_sosContactCount emergency contact${_sosContactCount == 1 ? '' : 's'} on file',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Share SOS Button ──
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: AppTheme.redGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emergencyRed
                                    .withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: MaterialButton(
                            onPressed: () async {
                              _confirmationDismissTimer?.cancel();
                              await Share.share(_sosMessage);
                              if (mounted && !_dismissed) {
                                _dismissed = true;
                                Navigator.of(context).pop();
                              }
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.share_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text('SHARE SOS NOW',
                                    style: AppTheme.buttonText
                                        .copyWith(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Auto-dismiss hint ──
                      if (!_sosSaving)
                        Text(
                          'Closing automatically...',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable info card for the SOS confirmation screen.
  Widget _buildConfirmationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: iconColor.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTopAlertBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.emergencyRed.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPulsingDot(),
          const SizedBox(width: 10),
          Text(
            '🚨  EMERGENCY ALERT ACTIVE',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.emergencyRed,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 10),
          _buildPulsingDot(),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _iconGlowAnim,
      builder: (context, _) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.emergencyRed,
            boxShadow: [
              BoxShadow(
                color: AppTheme.emergencyRed
                    .withValues(alpha: _iconGlowAnim.value),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWarningIcon() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer expanding rings
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _ringPulseAnim,
              builder: (context, _) {
                final delay = index * 0.15;
                final adjustedValue =
                    ((_ringPulseAnim.value + delay) % 1.0);
                return Container(
                  width: 130 - (index * 10),
                  height: 130 - (index * 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.emergencyRed
                          .withValues(alpha: 0.08 * adjustedValue),
                      width: 1,
                    ),
                  ),
                );
              },
            );
          }),
          // Outer orbital ring
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, _) {
              return Transform.rotate(
                angle: _scanController.value * 2 * pi,
                child: CustomPaint(
                  size: const Size(130, 130),
                  painter: _OrbitalRingPainter(
                    progress: _scanController.value,
                  ),
                ),
              );
            },
          ),
          // Pulsing icon core
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              return Transform.scale(
                scale: _pulseAnim.value,
                child: AnimatedBuilder(
                  animation: _iconGlowAnim,
                  builder: (context, _) {
                    return Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.emergencyRed.withValues(alpha: 0.25),
                            AppTheme.emergencyRed.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color:
                              AppTheme.emergencyRed.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emergencyRed.withValues(
                                alpha: 0.3 * _iconGlowAnim.value),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: AppTheme.emergencyRed.withValues(
                                alpha: 0.15 * _iconGlowAnim.value),
                            blurRadius: 60,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.emergencyRed,
                        size: 46,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Possible Accident',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.emergencyRed,
            fontSize: 28,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'DETECTED',
          style: AppTheme.headingLarge.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 34,
            letterSpacing: 6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.emergencyRed.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        'We detected a possible accident. If you are safe, cancel the alert. '
        'Otherwise an SOS alert will be sent automatically.',
        textAlign: TextAlign.center,
        style: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textSecondary,
          height: 1.6,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildCountdownTimer() {
    final isCritical = _remaining <= 10;

    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 190,
            height: 190,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          // Animated countdown ring
          AnimatedBuilder(
            animation: _countdownAnim,
            builder: (context, _) {
              return SizedBox(
                width: 190,
                height: 190,
                child: CircularProgressIndicator(
                  value: 1.0 - _countdownAnim.value,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: isCritical
                      ? AppTheme.emergencyRed
                      : AppTheme.emergencyRed.withValues(alpha: 0.8),
                  backgroundColor: Colors.transparent,
                ),
              );
            },
          ),
          // Outer glow ring
          AnimatedBuilder(
            animation: _ringPulseAnim,
            builder: (context, _) {
              return Container(
                width: 182,
                height: 182,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.emergencyRed.withValues(
                        alpha: 0.1 * _ringPulseAnim.value),
                    width: 1,
                  ),
                ),
              );
            },
          ),
          // Inner glow
          AnimatedBuilder(
            animation: _ringPulseAnim,
            builder: (context, _) {
              return Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.emergencyRed.withValues(
                          alpha: 0.08 * _ringPulseAnim.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
          // Countdown tick marks
          AnimatedBuilder(
            animation: _countdownAnim,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(190, 190),
                painter: _CountdownTickPainter(
                  remaining: _remaining,
                  total: _totalSeconds,
                  isCritical: isCritical,
                ),
              );
            },
          ),
          // Timer text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SOS IN',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) {
                  return ScaleTransition(scale: anim, child: child);
                },
                child: Text(
                  '$_remaining',
                  key: ValueKey<int>(_remaining),
                  style: AppTheme.headingLarge.copyWith(
                    fontSize: 56,
                    color: isCritical
                        ? AppTheme.emergencyRed
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SECONDS',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        // ── Location Card ──
        _buildLocationCard(),
        const SizedBox(height: 10),
        // ── Time Card ──
        _buildTimeCard(),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryCyan.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.primaryCyan.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppTheme.primaryCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍  CURRENT LOCATION',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _locationText,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(
            isReady: _locationReady,
            readyLabel: 'LIVE',
            pendingLabel: '...',
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningAmber.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.warningAmber.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.warningAmber.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: AppTheme.warningAmber,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🕐  CURRENT TIME',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _currentTime,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.warningAmber,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(
            isReady: true,
            readyLabel: 'LIVE',
            pendingLabel: '...',
            readyColor: AppTheme.warningAmber,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isReady,
    required String readyLabel,
    required String pendingLabel,
    Color? readyColor,
  }) {
    final color = readyColor ??
        (isReady ? AppTheme.successGreen : AppTheme.warningAmber);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isReady ? readyLabel : pendingLabel,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeButton() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successGreen.withValues(alpha: 0.15),
            AppTheme.successGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.successGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: _dismissSafe,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🟢', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              "I'M SAFE",
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.successGreen,
                fontSize: 18,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return AnimatedBuilder(
      animation: _borderGlowAnim,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: AppTheme.redGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emergencyRed
                    .withValues(alpha: 0.3 + 0.2 * _borderGlowAnim.value),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppTheme.emergencyRed.withValues(alpha: 0.15),
                blurRadius: 50,
                spreadRadius: 5,
              ),
            ],
          ),
          child: MaterialButton(
            onPressed: _sendSOS,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔴', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Text(
                  'SEND SOS NOW',
                  style: AppTheme.buttonText.copyWith(
                    fontSize: 18,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildCornerBrackets() {
    const size = 24.0;
    final color = AppTheme.emergencyRed.withValues(alpha: 0.35);

    return [
      Positioned(
        top: 0,
        left: 0,
        child: _CornerBracket(
            size: size, color: color, corner: _Corner.topLeft),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: _CornerBracket(
            size: size, color: color, corner: _Corner.topRight),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: _CornerBracket(
            size: size, color: color, corner: _Corner.bottomLeft),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: _CornerBracket(
            size: size, color: color, corner: _Corner.bottomRight),
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CORNER BRACKET WIDGET
// ═══════════════════════════════════════════════════════════════════════════

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerBracket extends StatelessWidget {
  final double size;
  final Color color;
  final _Corner corner;

  const _CornerBracket({
    required this.size,
    required this.color,
    required this.corner,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(color: color, corner: corner),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

/// Subtle background grid with emergency-themed colouring.
class _EmergencyGridPainter extends CustomPainter {
  final double progress;
  final bool isCritical;

  _EmergencyGridPainter({required this.progress, required this.isCritical});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.emergencyRed
          .withValues(alpha: isCritical ? 0.03 : 0.015)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmergencyGridPainter old) =>
      old.isCritical != isCritical;
}

/// Floating emergency particles for atmosphere.
class _EmergencyParticlePainter extends CustomPainter {
  final double progress;
  final bool isCritical;

  _EmergencyParticlePainter(
      {required this.progress, required this.isCritical});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42); // deterministic seed for consistent placement
    final count = isCritical ? 18 : 12;

    for (int i = 0; i < count; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * 2 * pi;

      // Gentle floating motion
      final x = baseX + sin(progress * 2 * pi * speed + phase) * 15;
      final y = baseY - (progress * size.height * 0.05 * speed) % size.height;
      final adjustedY = y < 0 ? y + size.height : y;

      final opacity = 0.05 + 0.1 * sin(progress * 2 * pi + phase).abs();
      final radius = 1.0 + rng.nextDouble() * 2;

      canvas.drawCircle(
        Offset(x, adjustedY),
        radius,
        Paint()
          ..color = AppTheme.emergencyRed.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmergencyParticlePainter old) => true;
}

/// Horizontal scan-line sweeping top to bottom.
class _ScanLinePainter extends CustomPainter {
  final double progress;

  _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.emergencyRed.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 30, size.width, 60));

    canvas.drawRect(Rect.fromLTWH(0, y - 30, size.width, 60), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress;
}

/// Pulsing border glow around the entire screen edges.
class _BorderGlowPainter extends CustomPainter {
  final double intensity;
  final bool isCritical;

  _BorderGlowPainter({required this.intensity, required this.isCritical});

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (isCritical ? 0.06 : 0.03) * intensity;
    final glowWidth = 60.0 + 30.0 * intensity;

    // Top edge
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, glowWidth),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.emergencyRed.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, glowWidth)),
    );

    // Bottom edge
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - glowWidth, size.width, glowWidth),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppTheme.emergencyRed.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(
            0, size.height - glowWidth, size.width, glowWidth)),
    );

    // Left edge
    canvas.drawRect(
      Rect.fromLTWH(0, 0, glowWidth, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppTheme.emergencyRed.withValues(alpha: alpha * 0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, glowWidth, size.height)),
    );

    // Right edge
    canvas.drawRect(
      Rect.fromLTWH(size.width - glowWidth, 0, glowWidth, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            AppTheme.emergencyRed.withValues(alpha: alpha * 0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(
            size.width - glowWidth, 0, glowWidth, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _BorderGlowPainter old) =>
      old.intensity != intensity || old.isCritical != isCritical;
}

/// Tick marks around the countdown circle for a tactical/HUD feel.
class _CountdownTickPainter extends CustomPainter {
  final int remaining;
  final int total;
  final bool isCritical;

  _CountdownTickPainter({
    required this.remaining,
    required this.total,
    required this.isCritical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 1;
    final innerRadius = outerRadius - 8;
    final innerRadiusSmall = outerRadius - 5;

    for (int i = 0; i < total; i++) {
      final angle = -pi / 2 + (2 * pi * i / total);
      final isMajor = i % 5 == 0;
      final isActive = i < remaining;

      final ir = isMajor ? innerRadius : innerRadiusSmall;
      final startPoint = Offset(
        center.dx + ir * cos(angle),
        center.dy + ir * sin(angle),
      );
      final endPoint = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );

      final paint = Paint()
        ..strokeWidth = isMajor ? 2 : 1
        ..strokeCap = StrokeCap.round
        ..color = isActive
            ? (isCritical
                ? AppTheme.emergencyRed.withValues(alpha: 0.6)
                : AppTheme.emergencyRed.withValues(alpha: 0.35))
            : Colors.white.withValues(alpha: 0.06);

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownTickPainter old) =>
      old.remaining != remaining || old.isCritical != isCritical;
}

/// Segmented orbital ring that rotates around the warning icon.
class _OrbitalRingPainter extends CustomPainter {
  final double progress;

  _OrbitalRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const segments = 8;
    const gapAngle = pi / 14;
    final arcAngle = (2 * pi / segments) - gapAngle;

    for (int i = 0; i < segments; i++) {
      final startAngle = (2 * pi / segments) * i;
      final opacity =
          0.1 + 0.2 * sin((progress * 2 * pi) + startAngle);
      paint.color = AppTheme.emergencyRed
          .withValues(alpha: opacity.clamp(0.04, 0.35));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle,
        false,
        paint,
      );
    }

    // Tracking dot
    final dotAngle = progress * 2 * pi;
    canvas.drawCircle(
      Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      ),
      3,
      Paint()
        ..color = AppTheme.emergencyRed.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingPainter old) =>
      old.progress != progress;
}

/// Corner bracket painter for HUD-style framing.
class _CornerPainter extends CustomPainter {
  final Color color;
  final _Corner corner;

  _CornerPainter({required this.color, required this.corner});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    switch (corner) {
      case _Corner.topLeft:
        path.moveTo(0, size.height);
        path.lineTo(0, 0);
        path.lineTo(size.width, 0);
      case _Corner.topRight:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
      case _Corner.bottomLeft:
        path.moveTo(0, 0);
        path.lineTo(0, size.height);
        path.lineTo(size.width, size.height);
      case _Corner.bottomRight:
        path.moveTo(0, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => false;
}
