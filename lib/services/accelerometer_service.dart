import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A single accelerometer reading with pre-computed magnitude.
///
/// Magnitude represents total acceleration: `sqrt(x² + y² + z²)`.
/// At rest the phone reads ~9.8 m/s² (gravity). Values well above that
/// indicate active movement or impact.
class AccelerometerReading {
  const AccelerometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });

  /// Acceleration along the X axis in m/s².
  final double x;

  /// Acceleration along the Y axis in m/s².
  final double y;

  /// Acceleration along the Z axis in m/s².
  final double z;

  /// Total acceleration magnitude: `sqrt(x² + y² + z²)`.
  final double magnitude;

  /// When this reading was captured.
  final DateTime timestamp;

  /// A short label describing movement intensity based on magnitude.
  ///
  /// Useful for quick UI display. Thresholds:
  /// - **Stationary** — magnitude ≤ 10.5 m/s² (gravity ± noise)
  /// - **Light movement** — 10.5 – 15 m/s²
  /// - **Moderate movement** — 15 – 25 m/s²
  /// - **Strong movement** — > 25 m/s²
  String get intensityLabel {
    if (magnitude <= 10.5) return 'Stationary';
    if (magnitude <= 15.0) return 'Light movement';
    if (magnitude <= 25.0) return 'Moderate movement';
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

/// Low-level accelerometer service that continuously reads sensor data and
/// exposes a stream of [AccelerometerReading] values.
///
/// This is the **foundation layer** for movement-based features. It only
/// reads and broadcasts data — it does **not** detect accidents, trigger SOS,
/// or interact with the countdown system.
///
/// ## Observable interfaces
///
/// Consumers can observe readings in three ways:
/// 1. **[readingStream]** — a broadcast `Stream<AccelerometerReading>`.
/// 2. **[onReading]** callback — set via [startListening].
/// 3. **[latestReading]** getter — the most recent snapshot.
///
/// ## Platform safety
///
/// On platforms without an accelerometer (e.g. Chrome/web) the sensor stream
/// simply won't produce events. Errors are caught and logged — no crash.
///
/// ## Extensibility
///
/// Higher-level services (impact detection, gyroscope fusion, cooldown logic)
/// can subscribe to [readingStream] or wrap this service instead of
/// duplicating raw sensor code.
class AccelerometerService {
  AccelerometerService({
    this.samplingPeriod = SensorInterval.normalInterval,
    this.emitIntervalMs = 100,
  });

  /// How often the OS should sample the sensor. `normalInterval` (~200 ms)
  /// balances responsiveness with battery life. Use `gameInterval` for
  /// higher frequency if needed later.
  final Duration samplingPeriod;

  /// Minimum interval (ms) between emitted readings on the public stream.
  /// Raw sensor events can arrive at very high frequency; this throttle
  /// prevents flooding consumers (and keeps UI rebuilds manageable).
  /// Set to 0 to emit every raw event.
  final int emitIntervalMs;

  // ── Internal state ───────────────────────────────────────────────────────

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  bool _isListening = false;

  final StreamController<AccelerometerReading> _readingController =
      StreamController<AccelerometerReading>.broadcast();

  AccelerometerReading? _latestReading;
  AccelerometerReadingCallback? _onReading;

  DateTime _lastEmitTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Public getters ───────────────────────────────────────────────────────

  /// Whether the service is actively reading the accelerometer.
  bool get isListening => _isListening;

  /// The most recent reading, or `null` if no data has been received yet.
  AccelerometerReading? get latestReading => _latestReading;

  /// A broadcast stream of throttled accelerometer readings.
  ///
  /// Multiple listeners are supported. The stream stays alive across
  /// start/stop cycles (it is never closed until the service is disposed).
  Stream<AccelerometerReading> get readingStream => _readingController.stream;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Begins reading the accelerometer sensor.
  ///
  /// [onReading] is an optional convenience callback invoked on each
  /// throttled reading. Equivalent to listening on [readingStream].
  ///
  /// Safe to call multiple times — duplicate subscriptions are prevented.
  void startListening({AccelerometerReadingCallback? onReading}) {
    if (_isListening) {
      debugPrint('[Accelerometer] Already listening — ignoring start().');
      return;
    }

    _isListening = true;
    _onReading = onReading;

    debugPrint(
      '[Accelerometer] Starting sensor stream '
      '(samplingPeriod: ${samplingPeriod.inMilliseconds}ms, '
      'emitInterval: ${emitIntervalMs}ms).',
    );

    try {
      _sensorSubscription = accelerometerEventStream(
        samplingPeriod: samplingPeriod,
      ).listen(
        _onSensorEvent,
        onError: (Object error) {
          debugPrint(
            '[Accelerometer] Sensor error: $error '
            '(expected on platforms without sensors, e.g. Chrome).',
          );
        },
        cancelOnError: false,
      );
      debugPrint('[Accelerometer] Sensor stream active.');
    } catch (e) {
      _isListening = false;
      debugPrint(
        '[Accelerometer] Could not start sensor: $e '
        '(platform may not support accelerometer).',
      );
    }
  }

  /// Stops reading and releases the sensor subscription.
  ///
  /// Does **not** close [readingStream] — the service can be restarted.
  void stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _isListening = false;
    _onReading = null;
    debugPrint('[Accelerometer] Sensor stream stopped.');
  }

  /// Releases all resources. After calling this the service cannot be
  /// restarted — create a new instance instead.
  void dispose() {
    stopListening();
    _readingController.close();
    debugPrint('[Accelerometer] Service disposed.');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _onSensorEvent(AccelerometerEvent event) {
    final now = DateTime.now();

    // Throttle: skip if we emitted too recently.
    if (emitIntervalMs > 0 &&
        now.difference(_lastEmitTime).inMilliseconds < emitIntervalMs) {
      return;
    }
    _lastEmitTime = now;

    final reading = AccelerometerReading(
      x: event.x,
      y: event.y,
      z: event.z,
      magnitude: _magnitude(event.x, event.y, event.z),
      timestamp: now,
    );

    _latestReading = reading;

    // Broadcast to stream listeners
    if (!_readingController.isClosed) {
      _readingController.add(reading);
    }

    // Convenience callback
    _onReading?.call(reading);
  }

  /// Injects a reading from an external source (e.g. the native Android
  /// foreground service) into the same broadcast stream used by
  /// `sensors_plus`. This allows background sensor data to flow through
  /// the existing detection pipeline unchanged.
  ///
  /// Applies the same throttling as [_onSensorEvent].
  void injectReading(double x, double y, double z) {
    final now = DateTime.now();

    if (emitIntervalMs > 0 &&
        now.difference(_lastEmitTime).inMilliseconds < emitIntervalMs) {
      return;
    }
    _lastEmitTime = now;

    final reading = AccelerometerReading(
      x: x,
      y: y,
      z: z,
      magnitude: _magnitude(x, y, z),
      timestamp: now,
    );

    _latestReading = reading;

    if (!_readingController.isClosed) {
      _readingController.add(reading);
    }

    _onReading?.call(reading);
  }

  /// Computes the vector magnitude: sqrt(x² + y² + z²).
  static double _magnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }
}
