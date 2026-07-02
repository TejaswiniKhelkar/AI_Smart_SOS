import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Full-screen accident detection alert dialog with a 15-second countdown.
///
/// Displays "Possible Accident Detected" with an animated countdown ring.
/// - **I am Safe** → dismisses, no SOS sent.
/// - **Send SOS Now** → immediately triggers SOS.
/// - Countdown reaches 0 → auto-sends SOS.
class AccidentAlertDialog extends StatefulWidget {
  const AccidentAlertDialog({super.key, required this.onSendSOS});

  /// Callback that triggers the existing SOS flow from the home screen.
  final VoidCallback onSendSOS;

  /// Shows the accident alert dialog over the current route.
  ///
  /// [onSendSOS] is called when the user taps "Send SOS Now" or the
  /// 15-second countdown reaches zero. It should trigger the existing
  /// SOS function which handles GPS, Google Maps link, timestamp,
  /// and saving to Alert History.
  static Future<void> show(BuildContext context, {required VoidCallback onSendSOS}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, _, _) => AccidentAlertDialog(onSendSOS: onSendSOS),
    );
  }

  @override
  State<AccidentAlertDialog> createState() => _AccidentAlertDialogState();
}

class _AccidentAlertDialogState extends State<AccidentAlertDialog>
    with TickerProviderStateMixin {
  static const int _countdownSeconds = 15;

  late AnimationController _countdownController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  int _remainingSeconds = _countdownSeconds;
  Timer? _ticker;
  bool _isSending = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    // Countdown ring animation (15 seconds, linear)
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    )..forward();

    // Pulse animation for the warning icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Subtle shake animation for urgency
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _shakeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Tick every second
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _dismissed) return;
      setState(() {
        _remainingSeconds--;
      });

      // Shake when time is running low
      if (_remainingSeconds <= 5 && _remainingSeconds > 0) {
        _shakeController.forward().then((_) {
          if (mounted) _shakeController.reverse();
        });
      }

      if (_remainingSeconds <= 0) {
        _ticker?.cancel();
        _sendSOS();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _countdownController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Dismisses the dialog — user confirmed they are safe.
  void _dismissSafe() {
    if (_dismissed) return;
    _dismissed = true;
    _ticker?.cancel();
    Navigator.of(context).pop();
  }

  /// Triggers the existing SOS flow via the callback, then closes the dialog.
  void _sendSOS() {
    if (_dismissed || _isSending) return;
    _dismissed = true;
    _ticker?.cancel();

    setState(() => _isSending = true);

    // Close dialog first, then trigger the existing SOS function
    // which handles: GPS location, Google Maps link, timestamp,
    // saving to Alert History, and sharing.
    Navigator.of(context).pop();
    widget.onSendSOS();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _remainingSeconds <= 5;
    final urgentColor =
        isUrgent ? AppTheme.emergencyRed : AppTheme.warningAmber;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_remainingSeconds <= 5 ? _shakeAnimation.value : 0, 0),
          child: child,
        );
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.97),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: urgentColor.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: urgentColor.withOpacity(0.25),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: urgentColor.withOpacity(0.1),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Warning Icon with pulse ───────────────
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: urgentColor.withOpacity(0.15),
                            boxShadow: AppTheme.neonGlow(
                              urgentColor,
                              intensity: 0.6,
                            ),
                          ),
                          child: Icon(
                            Icons.car_crash_rounded,
                            color: urgentColor,
                            size: 42,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Title ─────────────────────────────────
                  Text(
                    'POSSIBLE ACCIDENT',
                    style: AppTheme.headingSmall.copyWith(
                      color: urgentColor,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'DETECTED',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.textPrimary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'An unusual impact or movement was detected.\n'
                    'SOS will be sent automatically if no response.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Countdown Ring ────────────────────────
                  _buildCountdownRing(urgentColor),
                  const SizedBox(height: 28),

                  // ── "Send SOS Now" Button ─────────────────
                  _buildSendSOSButton(),
                  const SizedBox(height: 12),

                  // ── "I am Safe" Button ────────────────────
                  _buildSafeButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownRing(Color urgentColor) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              color: AppTheme.glassBorder,
            ),
          ),
          // Animated countdown ring
          AnimatedBuilder(
            animation: _countdownController,
            builder: (context, _) {
              return SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1.0 - _countdownController.value,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: urgentColor,
                  backgroundColor: Colors.transparent,
                ),
              );
            },
          ),
          // Glow behind the number
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: urgentColor.withOpacity(0.08),
            ),
          ),
          // Seconds number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) {
                  return ScaleTransition(scale: anim, child: child);
                },
                child: Text(
                  '$_remainingSeconds',
                  key: ValueKey<int>(_remainingSeconds),
                  style: AppTheme.headingLarge.copyWith(
                    fontSize: 38,
                    color: urgentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'SECONDS',
                style: AppTheme.bodySmall.copyWith(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendSOSButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.redGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emergencyRed.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: _isSending ? null : _sendSOS,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: _isSending
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sos, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text('SEND SOS NOW', style: AppTheme.buttonText),
                ],
              ),
      ),
    );
  }

  Widget _buildSafeButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.successGreen.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: MaterialButton(
        onPressed: _isSending ? null : _dismissSafe,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined,
                color: AppTheme.successGreen, size: 22),
            const SizedBox(width: 10),
            Text(
              'I AM SAFE',
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.successGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
