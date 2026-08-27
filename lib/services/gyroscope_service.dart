import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A single gyroscope reading with pre-computed rotation magnitude.
///
/// Magnitude represents total rotation rate: `sqrt(x² + y² + z²)` in rad/s.
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

  /// Rotation rate around the X axis in rad/s.
  final double x;

  /// Rotation rate around the Y axis in rad/s.
  final double y;

  /// Rotation rate around the Z axis in rad/s.
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

/// Low-level gyroscope service that continuously reads sensor data and
/// exposes a stream of [GyroscopeReading] values.
///
/// This is the **Layer 1 companion** to [AccelerometerService]. It only
/// reads and broadcasts data — it does **not** detect accidents, trigger SOS,
/// or interact with the countdown system.
///
/// ## Observable interfaces
///
/// Consumers can observe readings in three ways:
/// 1. **[readingStream]** — a broadcast `Stream<GyroscopeReading>`.
/// 2. **[onReading]** callback — set via [startListening].
/// 3. **[latestReading]** getter — the most recent snapshot.
///
/// ## Platform safety
///
/// On platforms without a gyroscope (e.g. Chrome/web) the sensor stream
/// simply won't produce events. Errors are caught and logged — no crash.
class GyroscopeService {
  GyroscopeService({
    this.samplingPeriod = SensorInterval.normalInterval,
    this.emitIntervalMs = 100,
  });

  /// How often the OS should sample the gyroscope.
  final Duration samplingPeriod;

  /// Minimum interval (ms) between emitted readings on the public stream.
  /// Set to 0 to emit every raw event.
  final int emitIntervalMs;

  // ── Internal state ───────────────────────────────────────────────────────

  StreamSubscription<GyroscopeEvent>? _sensorSubscription;
  bool _isListening = false;

  final StreamController<GyroscopeReading> _readingController =
      StreamController<GyroscopeReading>.broadcast();

  GyroscopeReading? _latestReading;
  GyroscopeReadingCallback? _onReading;

  DateTime _lastEmitTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Public getters ───────────────────────────────────────────────────────

  /// Whether the service is actively reading the gyroscope.
  bool get isListening => _isListening;

  /// The most recent reading, or `null` if no data has been received yet.
  GyroscopeReading? get latestReading => _latestReading;

  /// A broadcast stream of throttled gyroscope readings.
  Stream<GyroscopeReading> get readingStream => _readingController.stream;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Begins reading the gyroscope sensor.
  ///
  /// Safe to call multiple times — duplicate subscriptions are prevented.
  void startListening({GyroscopeReadingCallback? onReading}) {
    if (_isListening) {
      debugPrint('[Gyroscope] Already listening — ignoring start().');
      return;
    }

    _isListening = true;
    _onReading = onReading;

    debugPrint(
      '[Gyroscope] Starting sensor stream '
      '(samplingPeriod: ${samplingPeriod.inMilliseconds}ms, '
      'emitInterval: ${emitIntervalMs}ms).',
    );

    try {
      _sensorSubscription = gyroscopeEventStream(
        samplingPeriod: samplingPeriod,
      ).listen(
        _onSensorEvent,
        onError: (Object error) {
          debugPrint(
            '[Gyroscope] Sensor error: $error '
            '(expected on platforms without sensors, e.g. Chrome).',
          );
        },
        cancelOnError: false,
      );
      debugPrint('[Gyroscope] Sensor stream active.');
    } catch (e) {
      _isListening = false;
      debugPrint(
        '[Gyroscope] Could not start sensor: $e '
        '(platform may not support gyroscope).',
      );
    }
  }

  /// Stops reading and releases the sensor subscription.
  void stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _isListening = false;
    _onReading = null;
    debugPrint('[Gyroscope] Sensor stream stopped.');
  }

  /// Releases all resources.
  void dispose() {
    stopListening();
    _readingController.close();
    debugPrint('[Gyroscope] Service disposed.');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _onSensorEvent(GyroscopeEvent event) {
    final now = DateTime.now();

    if (emitIntervalMs > 0 &&
        now.difference(_lastEmitTime).inMilliseconds < emitIntervalMs) {
      return;
    }
    _lastEmitTime = now;

    final reading = GyroscopeReading(
      x: event.x,
      y: event.y,
      z: event.z,
      magnitude: _magnitude(event.x, event.y, event.z),
      timestamp: now,
    );

    _latestReading = reading;

    if (!_readingController.isClosed) {
      _readingController.add(reading);
    }

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

    final reading = GyroscopeReading(
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
