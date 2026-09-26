import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/accident_alert_dialog.dart';


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
  static final ForegroundSensorBridge instance = ForegroundSensorBridge._internal();
  ForegroundSensorBridge._internal();

  static const _channel =
      MethodChannel('com.example.ai_smart_sos/foreground_sensor');



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
      } else if (call.method == 'cancelAccidentAlert') {
        AccidentAlertDialog.currentState?.dismissSafe();
      } else if (call.method == 'triggerImmediateSOS') {
        AccidentAlertDialog.currentState?.sendSOS();
      }
    });

    // Request POST_NOTIFICATIONS permission for Android 13+
    // Required to ensure the foreground service notification and lock-screen full-screen intents appear.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        debugPrint('[FgSensorBridge] Notification permission denied. '
            'Background service might not be able to show alerts.');
      }
    }

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


  /// Diagnostic method to simulate a crash event safely without throwing the phone.
  Future<void> simulateTestAccident() async {
    if (!_serviceRunning) {
      debugPrint('[FgSensorBridge] Service not running. Cannot test.');
      return;
    }
    try {
      await _channel.invokeMethod<bool>('simulateTestAccident');
      debugPrint('[FgSensorBridge] Native crash simulation triggered.');
    } catch (e) {
      debugPrint('[FgSensorBridge] Failed to simulate accident: $e');
    }
  }

  /// Checks the runtime health of the native sensor service.
  /// Returns 'active', 'inactive', 'failed', or 'unavailable'
  Future<String> checkSensorHealth() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'unavailable';
    }
    try {
      final status = await _channel.invokeMethod<String>('checkSensorHealth');
      return status ?? 'inactive';
    } catch (e) {
      debugPrint('[FgSensorBridge] Failed to check sensor health: $e');
      return 'inactive';
    }
  }
}
