import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Callback signature when a potential accident is detected.
typedef AccidentDetectedCallback = void Function();

/// Smart accident detection service that monitors accelerometer and gyroscope
/// sensors to detect sudden impacts or abnormal movement patterns.
///
/// Detection thresholds:
/// - Accelerometer magnitude > 30 m/s² (~3G) indicates sudden impact.
/// - Gyroscope magnitude > 15 rad/s indicates rapid rotational change.
///
/// A cooldown period prevents repeated false-positive triggers.
class AccidentDetectionService {
  AccidentDetectionService({
    this.accelerometerThreshold = 30.0,
    this.gyroscopeThreshold = 15.0,
    this.cooldownDuration = const Duration(seconds: 30),
  });

  /// Accelerometer magnitude threshold in m/s² (default ~3G).
  final double accelerometerThreshold;

  /// Gyroscope magnitude threshold in rad/s.
  final double gyroscopeThreshold;

  /// Minimum time between consecutive accident detections.
  final Duration cooldownDuration;

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  DateTime? _lastDetectionTime;
  bool _isListening = false;

  /// Whether the service is actively listening to sensors.
  bool get isListening => _isListening;

  /// Starts monitoring accelerometer and gyroscope sensors.
  ///
  /// When a potential accident is detected, [onAccidentDetected] is called.
  /// Multiple calls are safe — the service will not create duplicate listeners.
  void startListening({required AccidentDetectedCallback onAccidentDetected}) {
    if (_isListening) return;
    _isListening = true;

    debugPrint('[AccidentDetection] Starting sensor monitoring...');

    // Listen to accelerometer events
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((AccelerometerEvent event) {
      final magnitude = _magnitude(event.x, event.y, event.z);

      // Subtract gravity (~9.8) to measure net force, but compare raw magnitude
      // because during a crash the values spike well above 30 m/s².
      if (magnitude > accelerometerThreshold) {
        debugPrint(
          '[AccidentDetection] ⚠️ Accelerometer spike: '
          '${magnitude.toStringAsFixed(2)} m/s² '
          '(threshold: $accelerometerThreshold)',
        );
        _handleDetection(onAccidentDetected);
      }
    }, onError: (error) {
      debugPrint('[AccidentDetection] Accelerometer error: $error');
    });

    // Listen to gyroscope events
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((GyroscopeEvent event) {
      final magnitude = _magnitude(event.x, event.y, event.z);

      if (magnitude > gyroscopeThreshold) {
        debugPrint(
          '[AccidentDetection] ⚠️ Gyroscope spike: '
          '${magnitude.toStringAsFixed(2)} rad/s '
          '(threshold: $gyroscopeThreshold)',
        );
        _handleDetection(onAccidentDetected);
      }
    }, onError: (error) {
      debugPrint('[AccidentDetection] Gyroscope error: $error');
    });

    debugPrint('[AccidentDetection] Sensor monitoring active.');
  }

  /// Stops monitoring sensors and cancels all subscriptions.
  void stopListening() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _isListening = false;
    debugPrint('[AccidentDetection] Sensor monitoring stopped.');
  }

  /// Computes the vector magnitude: sqrt(x² + y² + z²).
  double _magnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Handles a detection event, enforcing the cooldown window.
  void _handleDetection(AccidentDetectedCallback callback) {
    final now = DateTime.now();

    if (_lastDetectionTime != null &&
        now.difference(_lastDetectionTime!) < cooldownDuration) {
      debugPrint(
        '[AccidentDetection] Detection suppressed — cooldown active '
        '(${cooldownDuration.inSeconds}s window).',
      );
      return;
    }

    _lastDetectionTime = now;
    debugPrint('[AccidentDetection] 🚨 ACCIDENT DETECTED — triggering alert.');
    callback();
  }

  /// Resets the cooldown timer (e.g., after the user dismisses an alert).
  void resetCooldown() {
    _lastDetectionTime = DateTime.now();
  }
}
