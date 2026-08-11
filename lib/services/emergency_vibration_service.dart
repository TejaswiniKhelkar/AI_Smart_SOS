import 'dart:async';

import 'package:flutter/services.dart';

/// Lightweight emergency vibration service.
///
/// Uses Flutter's built-in [HapticFeedback] for cross-platform compatibility
/// and a [Timer]-based loop to produce repeating vibration patterns.
///
/// - **Normal mode**: medium-impact haptic every 1.2 seconds.
/// - **Urgent mode** (last 10 s): heavy-impact haptic every 400 ms for a
///   noticeably stronger, faster pulse.
///
/// Fails gracefully on platforms that don't support haptics (e.g. web,
/// desktop) — no errors are thrown, vibration simply does nothing.
///
/// Usage:
/// ```dart
/// final vib = EmergencyVibrationService();
/// vib.start();           // begin repeating vibration
/// vib.setUrgent(true);   // stronger & faster pattern
/// vib.stop();            // silence immediately
/// ```
class EmergencyVibrationService {
  Timer? _vibrationTimer;
  bool _isActive = false;
  bool _isUrgent = false;

  // ── Repeat intervals ──────────────────────────────────────────────────
  static const Duration _normalInterval = Duration(milliseconds: 1200);
  static const Duration _urgentInterval = Duration(milliseconds: 400);

  // ─────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────

  /// Begin the repeating vibration pattern.
  void start() {
    if (_isActive) return;
    _isActive = true;
    _vibrate(); // vibrate immediately
    _scheduleNext();
  }

  /// Switch between normal and urgent (stronger/faster) vibration.
  void setUrgent(bool urgent) {
    if (_isUrgent == urgent) return;
    _isUrgent = urgent;
    if (_isActive) {
      _vibrationTimer?.cancel();
      _vibrate(); // vibrate immediately with the new intensity
      _scheduleNext();
    }
  }

  /// Stop all vibration immediately.
  void stop() {
    _isActive = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  /// Release resources.  Call when the widget is disposed.
  void dispose() {
    stop();
  }

  // ─────────────────────────────────────────────────────────────────────
  // INTERNALS
  // ─────────────────────────────────────────────────────────────────────

  void _vibrate() {
    if (!_isActive) return;
    try {
      if (_isUrgent) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Gracefully ignore — platform may not support haptics
    }
  }

  void _scheduleNext() {
    final interval = _isUrgent ? _urgentInterval : _normalInterval;
    _vibrationTimer = Timer.periodic(interval, (_) => _vibrate());
  }
}
