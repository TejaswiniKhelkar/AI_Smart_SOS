import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'accelerometer_service.dart';
import 'gyroscope_service.dart';

/// Flutter-side bridge to the native Android
/// [AccidentDetectionForegroundService].
///
/// This class:
/// 1. Starts / stops the native foreground service via [MethodChannel].
/// 2. Handles the intent callback when an accident is detected.
///
/// ## Platform safety
///
/// On web and non-Android platforms all operations are no-ops.
class ForegroundSensorBridge {
  ForegroundSensorBridge();

  static const _channel =
      MethodChannel('com.example.ai_smart_sos/foreground_sensor');

  // ── References to the existing Dart sensor services ─────────────────

  AccelerometerService? _accelerometerService;
  GyroscopeService? _gyroscopeService;

  // ── State ───────────────────────────────────────────────────────────

  bool _serviceRunning = false;
  bool _started = false;
  
  VoidCallback? onAccidentDetected;

  /// Whether the native foreground service is running.
  bool get isServiceRunning => _serviceRunning;

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> start() async {
    if (_started) {
      debugPrint('[FgSensorBridge] Already started — ignoring.');
      return;
    }

    // Skip entirely on web / non-Android
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('[FgSensorBridge] Not Android — skipping foreground service.');
      return;
    }

    // Set up the handler for native intents
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAccidentAlertFromIntent') {
        onAccidentDetected?.call();
      }
    });

    // Start the native foreground service
    try {
      await _channel.invokeMethod<bool>('startService');
      _serviceRunning = true;
      _started = true;
      debugPrint('[FgSensorBridge] Native foreground service started. '
          'Background detection enabled.');
    } catch (e) {
      debugPrint('[FgSensorBridge] Failed to start service: $e');
    }
  }

  /// Stops the native foreground service and cleans up.
  Future<void> stop() async {
    if (!_started) return;

    _channel.setMethodCallHandler(null);

    if (_serviceRunning) {
      try {
        await _channel.invokeMethod<bool>('stopService');
      } catch (e) {
        debugPrint('[FgSensorBridge] Failed to stop service: $e');
      }
      _serviceRunning = false;
    }

    _started = false;
    debugPrint('[FgSensorBridge] Stopped and cleaned up.');
  }

  /// Shows a high-priority full-screen notification to bring the app
  /// to the foreground when an accident is detected in the background.
  Future<void> showAccidentAlertNotification() async {
    if (!_serviceRunning) return;
    try {
      await _channel.invokeMethod<bool>('showAccidentAlert');
      debugPrint('[FgSensorBridge] Accident alert notification requested.');
    } catch (e) {
      debugPrint('[FgSensorBridge] Failed to show accident alert: $e');
    }
  }

  /// Dismisses the accident alert notification (after the user has
  /// interacted with the SOS countdown dialog).
  Future<void> dismissAccidentAlertNotification() async {
    if (!_serviceRunning) return;
    try {
      await _channel.invokeMethod<bool>('dismissAccidentAlert');
    } catch (e) {
      debugPrint('[FgSensorBridge] Failed to dismiss alert: $e');
    }
  }


}
