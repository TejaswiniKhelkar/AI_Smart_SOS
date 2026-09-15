import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A single accelerometer reading with pre-computed normalized magnitude.
///
/// Magnitude represents linear acceleration (gravity removed): `sqrt(x² + y² + z²)`.
/// At rest the phone reads ~0 m/s². Values well above that
/// indicate active movement or impact.
class AccelerometerReading {
  const AccelerometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });

  /// Linear acceleration along the X axis in m/s² (gravity removed).
  final double x;

  /// Linear acceleration along the Y axis in m/s² (gravity removed).
  final double y;

  /// Linear acceleration along the Z axis in m/s² (gravity removed).
  final double z;

  /// Total linear acceleration magnitude: `sqrt(x² + y² + z²)`.
  final double magnitude;

  /// When this reading was captured.
  final DateTime timestamp;

  /// A short label describing movement intensity based on normalized magnitude.
  ///
  /// Thresholds:
  /// - **Stationary** — magnitude ≤ 1.5 m/s² (noise)
  /// - **Light movement** — 1.5 – 5.0 m/s²
  /// - **Moderate movement** — 5.0 – 15.0 m/s²
  /// - **Strong movement** — > 15.0 m/s²
  String get intensityLabel {
    if (magnitude <= 1.5) return 'Stationary';
    if (magnitude <= 5.0) return 'Light movement';
    if (magnitude <= 15.0) return 'Moderate movement';
    return 'Strong movement';
  }

  @override
  String toString() =>
      'AccelerometerReading('
      'x=${x.toStringAsFixed(2)}, '
      'y=${y.toStringAsFixed(2)}, '
      'z=${z.toStringAsFixed(2)}, '
      'mag=${magnitude.toStringAsFixed(2)} m/s², '
      '$intensityLabel)';
}

/// Callback signature for accelerometer reading updates.
typedef AccelerometerReadingCallback = void Function(AccelerometerReading reading);

/// Low-level accelerometer service that continuously reads sensor data,
/// calibrates it (removes gravity), and exposes a stream of normalized
/// [AccelerometerReading] values.
class AccelerometerService {
  AccelerometerService({
    this.samplingPeriod = SensorInterval.normalInterval,
    this.emitIntervalMs = 100,
  });

  final Duration samplingPeriod;
  final int emitIntervalMs;

  // ── Internal state ───────────────────────────────────────────────────────

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  bool _isListening = false;
  
  // Sensor availability state
  bool _isAvailable = true; // Assume true until timeout
  Timer? _availabilityTimer;
  final StreamController<bool> _availabilityController = StreamController<bool>.broadcast();

  final StreamController<AccelerometerReading> _readingController =
      StreamController<AccelerometerReading>.broadcast();

  AccelerometerReading? _latestReading;
  AccelerometerReadingCallback? _onReading;

  DateTime _lastEmitTime = DateTime.fromMillisecondsSinceEpoch(0);
  
  // Calibration (Low-Pass Filter state)
  double _gravityX = 0;
  double _gravityY = 0;
  double _gravityZ = 0;
  bool _isCalibrated = false;
  final double _alpha = 0.8; // LPF constant

  // ── Public getters ───────────────────────────────────────────────────────

  bool get isListening => _isListening;
  
  /// Whether the accelerometer sensor is available and producing data.
  bool get isAvailable => _isAvailable;

  AccelerometerReading? get latestReading => _latestReading;

  Stream<AccelerometerReading> get readingStream => _readingController.stream;
  
  /// Stream notifying about changes in sensor availability.
  Stream<bool> get availabilityStream => _availabilityController.stream;

  // ── Public API ───────────────────────────────────────────────────────────

  void startListening({AccelerometerReadingCallback? onReading}) {
    if (_isListening) {
      debugPrint('[Accelerometer] Already listening — ignoring start().');
      return;
    }

    _isListening = true;
    _onReading = onReading;
    _isCalibrated = false;
    _isAvailable = true; // Optimistic initially

    debugPrint(
      '[Accelerometer] Starting sensor stream '
      '(samplingPeriod: ${samplingPeriod.inMilliseconds}ms, '
      'emitInterval: ${emitIntervalMs}ms).',
    );
    
    // Start availability timeout
    _startAvailabilityTimeout();

    try {
      _sensorSubscription = accelerometerEventStream(
        samplingPeriod: samplingPeriod,
      ).listen(
        _onSensorEvent,
        onError: (Object error) {
          debugPrint('[Accelerometer] Sensor error: $error');
          _markUnavailable();
        },
        cancelOnError: false,
      );
      debugPrint('[Accelerometer] Sensor stream active.');
    } catch (e) {
      debugPrint('[Accelerometer] Could not start sensor: $e');
      _markUnavailable();
    }
  }

  void stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _availabilityTimer?.cancel();
    _isListening = false;
    _onReading = null;
    debugPrint('[Accelerometer] Sensor stream stopped.');
  }

  void dispose() {
    stopListening();
    _readingController.close();
    _availabilityController.close();
    debugPrint('[Accelerometer] Service disposed.');
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
      debugPrint('[Accelerometer] ❌ Sensor marked UNAVAILABLE.');
      if (!_availabilityController.isClosed) {
        _availabilityController.add(false);
      }
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _onSensorEvent(AccelerometerEvent event) {
    _processRawData(event.x, event.y, event.z);
  }

  void injectReading(double x, double y, double z) {
    _processRawData(x, y, z);
  }
  
  void _processRawData(double rawX, double rawY, double rawZ) {
    _availabilityTimer?.cancel(); // We received data, so it's available
    
    if (!_isAvailable) {
      _isAvailable = true;
      if (!_availabilityController.isClosed) {
        _availabilityController.add(true);
      }
    }

    if (!_isCalibrated) {
      _gravityX = rawX;
      _gravityY = rawY;
      _gravityZ = rawZ;
      _isCalibrated = true;
    } else {
      // Low-pass filter to isolate gravity
      _gravityX = _alpha * _gravityX + (1 - _alpha) * rawX;
      _gravityY = _alpha * _gravityY + (1 - _alpha) * rawY;
      _gravityZ = _alpha * _gravityZ + (1 - _alpha) * rawZ;
    }
    
    // High-pass filter to isolate linear acceleration (gravity removed)
    final double linearX = rawX - _gravityX;
    final double linearY = rawY - _gravityY;
    final double linearZ = rawZ - _gravityZ;

    final now = DateTime.now();

    // Throttle
    if (emitIntervalMs > 0 &&
        now.difference(_lastEmitTime).inMilliseconds < emitIntervalMs) {
      return;
    }
    _lastEmitTime = now;

    final reading = AccelerometerReading(
      x: linearX,
      y: linearY,
      z: linearZ,
      magnitude: _magnitude(linearX, linearY, linearZ),
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
