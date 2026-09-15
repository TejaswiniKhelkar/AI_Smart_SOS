import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A single gyroscope reading with pre-computed normalized rotation magnitude.
///
/// Magnitude represents total rotation rate (bias removed): `sqrt(x² + y² + z²)` in rad/s.
/// At rest the phone reads ~0 rad/s. Normal hand movement is 1–3 rad/s.
/// Values above 8–10 rad/s indicate violent rotation (tumble, drop, crash).
class GyroscopeReading {
  const GyroscopeReading({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });

  /// Rotation rate around the X axis in rad/s (bias removed).
  final double x;

  /// Rotation rate around the Y axis in rad/s (bias removed).
  final double y;

  /// Rotation rate around the Z axis in rad/s (bias removed).
  final double z;

  /// Total rotation magnitude: `sqrt(x² + y² + z²)` in rad/s.
  final double magnitude;

  /// When this reading was captured.
  final DateTime timestamp;

  /// A short label describing rotation intensity.
  ///
  /// Thresholds (rad/s):
  /// - **Stable**           — magnitude ≤ 1.0
  /// - **Normal rotation**  — 1.0 – 5.0
  /// - **Fast rotation**    — 5.0 – 10.0
  /// - **Violent rotation** — > 10.0
  String get intensityLabel {
    if (magnitude <= 1.0) return 'Stable';
    if (magnitude <= 5.0) return 'Normal rotation';
    if (magnitude <= 10.0) return 'Fast rotation';
    return 'Violent rotation';
  }

  @override
  String toString() =>
      'GyroscopeReading('
      'x=${x.toStringAsFixed(2)}, '
      'y=${y.toStringAsFixed(2)}, '
      'z=${z.toStringAsFixed(2)}, '
      'mag=${magnitude.toStringAsFixed(2)} rad/s, '
      '$intensityLabel)';
}

/// Callback signature for gyroscope reading updates.
typedef GyroscopeReadingCallback = void Function(GyroscopeReading reading);

/// Low-level gyroscope service that continuously reads sensor data, calibrates
/// it (removes hardware bias), and exposes a stream of [GyroscopeReading] values.
class GyroscopeService {
  GyroscopeService({
    this.samplingPeriod = SensorInterval.normalInterval,
    this.emitIntervalMs = 100,
  });

  final Duration samplingPeriod;
  final int emitIntervalMs;

  // ── Internal state ───────────────────────────────────────────────────────

  StreamSubscription<GyroscopeEvent>? _sensorSubscription;
  bool _isListening = false;
  
  // Sensor availability state
  bool _isAvailable = true;
  Timer? _availabilityTimer;
  final StreamController<bool> _availabilityController = StreamController<bool>.broadcast();

  final StreamController<GyroscopeReading> _readingController =
      StreamController<GyroscopeReading>.broadcast();

  GyroscopeReading? _latestReading;
  GyroscopeReadingCallback? _onReading;

  DateTime _lastEmitTime = DateTime.fromMillisecondsSinceEpoch(0);
  
  // Calibration (Bias removal state)
  double _biasX = 0;
  double _biasY = 0;
  double _biasZ = 0;
  bool _isCalibrated = false;
  final double _alpha = 0.99; // Slow moving average for bias

  // ── Public getters ───────────────────────────────────────────────────────

  bool get isListening => _isListening;
  
  /// Whether the gyroscope sensor is available and producing data.
  bool get isAvailable => _isAvailable;

  GyroscopeReading? get latestReading => _latestReading;

  Stream<GyroscopeReading> get readingStream => _readingController.stream;
  
  /// Stream notifying about changes in sensor availability.
  Stream<bool> get availabilityStream => _availabilityController.stream;

  // ── Public API ───────────────────────────────────────────────────────────

  void startListening({GyroscopeReadingCallback? onReading}) {
    if (_isListening) {
      debugPrint('[Gyroscope] Already listening — ignoring start().');
      return;
    }

    _isListening = true;
    _onReading = onReading;
    _isCalibrated = false;
    _isAvailable = true;

    debugPrint(
      '[Gyroscope] Starting sensor stream '
      '(samplingPeriod: ${samplingPeriod.inMilliseconds}ms, '
      'emitInterval: ${emitIntervalMs}ms).',
    );
    
    _startAvailabilityTimeout();

    try {
      _sensorSubscription = gyroscopeEventStream(
        samplingPeriod: samplingPeriod,
      ).listen(
        _onSensorEvent,
        onError: (Object error) {
          debugPrint('[Gyroscope] Sensor error: $error');
          _markUnavailable();
        },
        cancelOnError: false,
      );
      debugPrint('[Gyroscope] Sensor stream active.');
    } catch (e) {
      debugPrint('[Gyroscope] Could not start sensor: $e');
      _markUnavailable();
    }
  }

  void stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _availabilityTimer?.cancel();
    _isListening = false;
    _onReading = null;
    debugPrint('[Gyroscope] Sensor stream stopped.');
  }

  void dispose() {
    stopListening();
    _readingController.close();
    _availabilityController.close();
    debugPrint('[Gyroscope] Service disposed.');
  }
  
  void _startAvailabilityTimeout() {
    _availabilityTimer?.cancel();
    _availabilityTimer = Timer(const Duration(seconds: 2), () {
      if (_isListening && _latestReading == null) {
        _markUnavailable();
      }
    });
  }
  
  void _markUnavailable() {
    if (_isAvailable) {
      _isAvailable = false;
      debugPrint('[Gyroscope] ❌ Sensor marked UNAVAILABLE.');
      if (!_availabilityController.isClosed) {
        _availabilityController.add(false);
      }
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _onSensorEvent(GyroscopeEvent event) {
    _processRawData(event.x, event.y, event.z);
  }

  void injectReading(double x, double y, double z) {
    _processRawData(x, y, z);
  }
  
  void _processRawData(double rawX, double rawY, double rawZ) {
    _availabilityTimer?.cancel();
    
    if (!_isAvailable) {
      _isAvailable = true;
      if (!_availabilityController.isClosed) {
        _availabilityController.add(true);
      }
    }

    if (!_isCalibrated) {
      _biasX = rawX;
      _biasY = rawY;
      _biasZ = rawZ;
      _isCalibrated = true;
    } else {
      // Very slow low-pass filter to track zero-bias drift over time.
      // We only update bias if rotation is small, to avoid skewing during actual motion.
      final currentMag = _magnitude(rawX, rawY, rawZ);
      if (currentMag < 1.0) {
        _biasX = _alpha * _biasX + (1 - _alpha) * rawX;
        _biasY = _alpha * _biasY + (1 - _alpha) * rawY;
        _biasZ = _alpha * _biasZ + (1 - _alpha) * rawZ;
      }
    }
    
    // Remove bias
    final double normX = rawX - _biasX;
    final double normY = rawY - _biasY;
    final double normZ = rawZ - _biasZ;

    final now = DateTime.now();

    if (emitIntervalMs > 0 &&
        now.difference(_lastEmitTime).inMilliseconds < emitIntervalMs) {
      return;
    }
    _lastEmitTime = now;

    final reading = GyroscopeReading(
      x: normX,
      y: normY,
      z: normZ,
      magnitude: _magnitude(normX, normY, normZ),
      timestamp: now,
    );

    _latestReading = reading;

    if (!_readingController.isClosed) {
      _readingController.add(reading);
    }

    _onReading?.call(reading);
  }

  static double _magnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }
}
