import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Phone movement detection service using accelerometer and gyroscope.
///
/// Prints sensor values (x, y, z and magnitude) to the debug console
/// at a throttled interval so the log stays readable.
///
/// Detects:
/// - **Sudden impacts** when acceleration magnitude exceeds [impactThreshold].
/// - **Abnormal rotation** when gyroscope magnitude exceeds [rotationThreshold].
///
/// Both detections have independent cooldowns to prevent repeated triggers.
///
/// Safe to call on platforms without sensors (e.g. Chrome) — the listeners
/// will simply not fire and no crash will occur.
class MovementDetectionService {
  MovementDetectionService({
    this.logIntervalMs = 500,
    this.impactThreshold = 25.0,
    this.impactCooldown = const Duration(seconds: 5),
    this.rotationThreshold = 10.0,
    this.rotationCooldown = const Duration(seconds: 5),
  });

  /// Minimum interval between debug-print outputs (in milliseconds).
  /// Prevents flooding the console on high-frequency sensor streams.
  final int logIntervalMs;

  // ── Accelerometer settings ───────────────────────────────────────────────

  /// Acceleration magnitude (m/s²) above which a "possible impact" is logged.
  ///
  /// Gravity alone is ~9.8 m/s². Normal walking/pocket bumps peak around
  /// 12–15 m/s². A threshold of 25 m/s² (~2.5G) catches hard drops and
  /// impacts while ignoring everyday movement.
  final double impactThreshold;

  /// Minimum time between consecutive impact log messages.
  final Duration impactCooldown;

  // ── Gyroscope settings ───────────────────────────────────────────────────

  /// Gyroscope magnitude (rad/s) above which "abnormal rotation" is logged.
  ///
  /// Normal hand movements produce ~1–3 rad/s. Quickly flipping the phone
  /// reaches ~5–8 rad/s. A threshold of 10 rad/s catches sudden tumbles,
  /// drops, or violent shakes while ignoring regular use.
  final double rotationThreshold;

  /// Minimum time between consecutive rotation-spike log messages.
  final Duration rotationCooldown;

  // ── Internal state ───────────────────────────────────────────────────────

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  bool _isListening = false;

  DateTime _lastAccelLogTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastGyroLogTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastImpactTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRotationSpikeTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the service is actively listening.
  bool get isListening => _isListening;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Starts listening to accelerometer and gyroscope sensors.
  ///
  /// Safe to call multiple times — duplicate listeners are prevented.
  void startListening() {
    if (_isListening) {
      debugPrint('[MovementDetection] Already listening — ignoring start().');
      return;
    }
    _isListening = true;

    debugPrint('[MovementDetection] Starting sensor listeners...');
    debugPrint(
      '[MovementDetection] Accel impact threshold: '
      '${impactThreshold.toStringAsFixed(1)} m/s², '
      'cooldown: ${impactCooldown.inSeconds}s',
    );
    debugPrint(
      '[MovementDetection] Gyro rotation threshold: '
      '${rotationThreshold.toStringAsFixed(1)} rad/s, '
      'cooldown: ${rotationCooldown.inSeconds}s',
    );

    _startAccelerometer();
    _startGyroscope();
  }

  /// Stops listening and releases all subscriptions.
  void stopListening() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _isListening = false;
    debugPrint('[MovementDetection] All sensor listeners stopped.');
  }

  // ── Accelerometer ────────────────────────────────────────────────────────

  void _startAccelerometer() {
    try {
      _accelSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        _onAccelerometerEvent,
        onError: (Object error) {
          debugPrint(
            '[MovementDetection] Accelerometer error: $error '
            '(expected on platforms without sensors, e.g. Chrome).',
          );
        },
        cancelOnError: false,
      );
      debugPrint('[MovementDetection] Accelerometer listener active.');
    } catch (e) {
      debugPrint(
        '[MovementDetection] Could not start accelerometer: $e '
        '(platform may not support sensors).',
      );
    }
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = _magnitude(event.x, event.y, event.z);

    // ── Impact detection (checked on every event, no throttle) ──────────
    _checkForImpact(magnitude, event);

    // ── Throttled general logging ───────────────────────────────────────
    final now = DateTime.now();
    if (now.difference(_lastAccelLogTime).inMilliseconds < logIntervalMs) {
      return;
    }
    _lastAccelLogTime = now;

    debugPrint(
      '[MovementDetection][Accel] '
      'x=${event.x.toStringAsFixed(2)}, '
      'y=${event.y.toStringAsFixed(2)}, '
      'z=${event.z.toStringAsFixed(2)} '
      '| mag=${magnitude.toStringAsFixed(2)} m/s²',
    );
  }

  void _checkForImpact(double magnitude, AccelerometerEvent event) {
    if (magnitude < impactThreshold) return;

    final now = DateTime.now();
    if (now.difference(_lastImpactTime) < impactCooldown) return;
    _lastImpactTime = now;

    debugPrint(
      '[MovementDetection] ⚠️ Possible impact detected! '
      'mag=${magnitude.toStringAsFixed(2)} m/s² '
      '(threshold: ${impactThreshold.toStringAsFixed(1)}) '
      '| x=${event.x.toStringAsFixed(2)}, '
      'y=${event.y.toStringAsFixed(2)}, '
      'z=${event.z.toStringAsFixed(2)}',
    );
  }

  // ── Gyroscope ────────────────────────────────────────────────────────────

  void _startGyroscope() {
    try {
      _gyroSubscription = gyroscopeEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        _onGyroscopeEvent,
        onError: (Object error) {
          debugPrint(
            '[MovementDetection] Gyroscope error: $error '
            '(expected on platforms without sensors, e.g. Chrome).',
          );
        },
        cancelOnError: false,
      );
      debugPrint('[MovementDetection] Gyroscope listener active.');
    } catch (e) {
      debugPrint(
        '[MovementDetection] Could not start gyroscope: $e '
        '(platform may not support sensors).',
      );
    }
  }

  void _onGyroscopeEvent(GyroscopeEvent event) {
    final magnitude = _magnitude(event.x, event.y, event.z);

    // ── Rotation spike detection (checked on every event) ───────────────
    _checkForRotationSpike(magnitude, event);

    // ── Throttled general logging ───────────────────────────────────────
    final now = DateTime.now();
    if (now.difference(_lastGyroLogTime).inMilliseconds < logIntervalMs) {
      return;
    }
    _lastGyroLogTime = now;

    debugPrint(
      '[MovementDetection][Gyro] '
      'x=${event.x.toStringAsFixed(2)}, '
      'y=${event.y.toStringAsFixed(2)}, '
      'z=${event.z.toStringAsFixed(2)} '
      '| mag=${magnitude.toStringAsFixed(2)} rad/s',
    );
  }

  void _checkForRotationSpike(double magnitude, GyroscopeEvent event) {
    if (magnitude < rotationThreshold) return;

    final now = DateTime.now();
    if (now.difference(_lastRotationSpikeTime) < rotationCooldown) return;
    _lastRotationSpikeTime = now;

    debugPrint(
      '[MovementDetection] 🔄 Abnormal rotation detected! '
      'mag=${magnitude.toStringAsFixed(2)} rad/s '
      '(threshold: ${rotationThreshold.toStringAsFixed(1)}) '
      '| x=${event.x.toStringAsFixed(2)}, '
      'y=${event.y.toStringAsFixed(2)}, '
      'z=${event.z.toStringAsFixed(2)}',
    );
  }

  // ── Utilities ────────────────────────────────────────────────────────────

  /// Computes the vector magnitude: sqrt(x² + y² + z²).
  double _magnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }
}
