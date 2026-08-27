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
/// 2. Receives raw (x, y, z) sensor data sent by the service.
/// 3. Injects that data into the existing [AccelerometerService] and
///    [GyroscopeService] broadcast streams so the Dart-side
///    [AccidentMotionDetector] pipeline works unchanged.
/// 4. Monitors [AppLifecycleState] to only inject native data when the
///    app is in the background (foreground uses `sensors_plus`).
///
/// ## Platform safety
///
/// On web and non-Android platforms all operations are no-ops.
class ForegroundSensorBridge with WidgetsBindingObserver {
  ForegroundSensorBridge();

  static const _channel =
      MethodChannel('com.example.ai_smart_sos/foreground_sensor');

  // ── References to the existing Dart sensor services ─────────────────

  AccelerometerService? _accelerometerService;
  GyroscopeService? _gyroscopeService;

  // ── State ───────────────────────────────────────────────────────────

  bool _serviceRunning = false;
  bool _started = false;

  /// `true` when the app is paused / inactive / hidden / detached.
  bool _isInBackground = false;

  /// Whether the bridge is injecting native sensor data.
  bool get isInBackground => _isInBackground;

  /// Whether the native foreground service is running.
  bool get isServiceRunning => _serviceRunning;

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  /// Starts the native foreground service and begins listening for
  /// sensor data from the native side.
  ///
  /// [accelerometerService] and [gyroscopeService] are the **existing**
  /// service instances (owned by [AccidentMotionDetector]) into which
  /// background sensor readings will be injected.
  Future<void> start({
    required AccelerometerService accelerometerService,
    required GyroscopeService gyroscopeService,
  }) async {
    if (_started) {
      debugPrint('[FgSensorBridge] Already started — ignoring.');
      return;
    }

    // Skip entirely on web / non-Android
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('[FgSensorBridge] Not Android — skipping foreground service.');
      return;
    }

    _accelerometerService = accelerometerService;
    _gyroscopeService = gyroscopeService;

    // Register for lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Set up the handler for native → Flutter sensor data
    _channel.setMethodCallHandler(_handleNativeCall);

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

    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);

    if (_serviceRunning) {
      try {
        await _channel.invokeMethod<bool>('stopService');
      } catch (e) {
        debugPrint('[FgSensorBridge] Failed to stop service: $e');
      }
      _serviceRunning = false;
    }

    _accelerometerService = null;
    _gyroscopeService = null;
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

  // ═══════════════════════════════════════════════════════════════════════
  // LIFECYCLE OBSERVER
  // ═══════════════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBg = _isInBackground;

    switch (state) {
      case AppLifecycleState.resumed:
        _isInBackground = false;
        if (wasBg) {
          debugPrint('[FgSensorBridge] App RESUMED — '
              'native sensor injection paused (sensors_plus active).');
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _isInBackground = true;
        if (!wasBg) {
          debugPrint('[FgSensorBridge] App BACKGROUNDED — '
              'native sensor injection active.');
        }
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NATIVE → FLUTTER METHOD CALL HANDLER
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _handleNativeCall(MethodCall call) async {
    // Only inject sensor data when the app is in the background.
    // In the foreground, sensors_plus delivers data through its own
    // platform channel and we don't want duplicates.
    if (!_isInBackground) return;

    switch (call.method) {
      case 'onAccelerometerData':
        final args = call.arguments as Map;
        final x = (args['x'] as num).toDouble();
        final y = (args['y'] as num).toDouble();
        final z = (args['z'] as num).toDouble();
        _accelerometerService?.injectReading(x, y, z);
        break;

      case 'onGyroscopeData':
        final args = call.arguments as Map;
        final x = (args['x'] as num).toDouble();
        final y = (args['y'] as num).toDouble();
        final z = (args['z'] as num).toDouble();
        _gyroscopeService?.injectReading(x, y, z);
        break;
    }
  }
}
