import 'dart:async';
import 'package:flutter/foundation.dart';
import 'accelerometer_service.dart';

/// Data class carrying full context of a detected sudden impact.
///
/// Consumers receive this via [ImpactDetectionService.impactStream] or
/// [ImpactDetectionService.onImpactDetected] callback.
class ImpactEvent {
  const ImpactEvent({
    required this.reading,
    required this.threshold,
    required this.detectedAt,
  });

  /// The accelerometer reading that triggered the detection.
  final AccelerometerReading reading;

  /// The threshold that was exceeded (for logging / UI display).
  final double threshold;

  /// When the detection was recorded.
  final DateTime detectedAt;

  /// Shortcut to the magnitude that caused the trigger.
  double get magnitude => reading.magnitude;

  @override
  String toString() =>
      'ImpactEvent(mag=${magnitude.toStringAsFixed(2)} m/s², '
      'threshold=${threshold.toStringAsFixed(1)}, '
      'x=${reading.x.toStringAsFixed(2)}, '
      'y=${reading.y.toStringAsFixed(2)}, '
      'z=${reading.z.toStringAsFixed(2)})';
}

/// Callback signature for impact detection events.
typedef ImpactDetectedCallback = void Function(ImpactEvent event);

/// Real-time sudden-impact detection service built on top of
/// [AccelerometerService].
///
/// ## How it works
///
/// 1. Subscribes to the [AccelerometerService.readingStream] which provides
///    real accelerometer data from the physical device via `sensors_plus`.
/// 2. On every reading, compares the computed magnitude against
///    [impactThreshold].
/// 3. When the threshold is exceeded **and** the cooldown period has elapsed,
///    an [ImpactEvent] is emitted via:
///    - [impactStream] — a broadcast `Stream<ImpactEvent>`.
///    - [onImpactDetected] callback — set in [startDetection].
///    - [lastImpact] getter — the most recent impact snapshot.
///
/// ## Threshold guidance
/// 
/// | Magnitude (m/s²) | What it means                     |
/// |-------------------|-----------------------------------|
/// | ~0                | Phone at rest (gravity removed)   |
/// | 1–5               | Normal walking, pocket movement   |
/// | 5–15              | Vigorous shake, jogging           |
/// | 15–30             | Hard drop, strong jerk            |
/// | 30+               | Severe impact, potential crash    |
///
/// Default threshold is **30.0 m/s²** (~3G), high enough to ignore normal
/// phone shaking, hand movement, and drops while still catching severe
/// impacts indicative of a real crash or accident.
///
/// ## Cooldown
///
/// A single physical impact often produces a burst of high readings over
/// 50–200 ms. The cooldown (default **3 seconds**) ensures only one event
/// is emitted per physical movement.
///
/// ## Platform safety
///
/// On Chrome/web the underlying [AccelerometerService] simply won't emit
/// events, so no detection fires and no crash occurs.
///
/// ## Extensibility
///
/// This service is designed as a building block. Future steps can:
/// - Add gyroscope fusion for fall-vs-impact discrimination.
/// - Layer a sliding-window filter to reduce false positives.
/// - Feed [impactStream] into the full accident detection → SOS pipeline.
///
/// It does **not** trigger SOS or modify the 30-second countdown.
class ImpactDetectionService {
  ImpactDetectionService({
    AccelerometerService? accelerometerService,
    this.impactThreshold = 30.0,
    this.cooldownDuration = const Duration(seconds: 3),
    this.debugLogIntervalMs = 1000,
  }) : _accelerometerService = accelerometerService ?? AccelerometerService(
         // Use a faster sampling rate for impact detection — we need to
         // catch brief spikes that last only 50–100 ms.
         samplingPeriod: const Duration(milliseconds: 20),
         // Emit every event to the stream so we don't miss short spikes.
         emitIntervalMs: 0,
       );

  // ── Configuration ────────────────────────────────────────────────────────

  /// Acceleration magnitude (m/s²) above which a sudden impact is detected.
  ///
  /// Default 30.0 m/s² (~3G) — high enough to ignore normal phone shaking
  /// and everyday movement. Only severe impacts (crashes, collisions) exceed
  /// this threshold.
  final double impactThreshold;

  /// Minimum time between consecutive impact events. Prevents a single
  /// physical shock from generating multiple detections.
  final Duration cooldownDuration;

  /// Interval (ms) between periodic debug logs of live sensor values.
  /// Set to 0 to disable periodic logging (impact logs still print).
  final int debugLogIntervalMs;

  // ── Internal state ───────────────────────────────────────────────────────

  final AccelerometerService _accelerometerService;
  StreamSubscription<AccelerometerReading>? _streamSubscription;
  bool _isDetecting = false;

  DateTime _lastImpactTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDebugLogTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _totalReadings = 0;
  int _totalImpacts = 0;

  final StreamController<ImpactEvent> _impactController =
      StreamController<ImpactEvent>.broadcast();

  ImpactDetectedCallback? _onImpactDetected;
  ImpactEvent? _lastImpact;

  // ── Public getters ───────────────────────────────────────────────────────

  /// Whether impact detection is actively running.
  bool get isDetecting => _isDetecting;

  /// The most recent impact event, or `null` if none has been detected.
  ImpactEvent? get lastImpact => _lastImpact;

  /// Total number of impacts detected since [startDetection] was called.
  int get totalImpacts => _totalImpacts;

  /// A broadcast stream of impact events. Multiple listeners are supported.
  Stream<ImpactEvent> get impactStream => _impactController.stream;

  /// Direct access to the underlying accelerometer service (e.g. to read
  /// [AccelerometerService.latestReading] for current sensor values).
  AccelerometerService get accelerometerService => _accelerometerService;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Starts real-time impact detection.
  ///
  /// Automatically starts the underlying [AccelerometerService] if it isn't
  /// already listening. [onImpactDetected] is an optional convenience
  /// callback — equivalent to subscribing to [impactStream].
  ///
  /// Safe to call multiple times — duplicate detection is prevented.
  void startDetection({ImpactDetectedCallback? onImpactDetected}) {
    if (_isDetecting) {
      debugPrint('[ImpactDetection] Already detecting — ignoring start().');
      return;
    }

    _isDetecting = true;
    _onImpactDetected = onImpactDetected;
    _totalReadings = 0;
    _totalImpacts = 0;

    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║  IMPACT DETECTION SERVICE — STARTED                 ║');
    debugPrint('╠══════════════════════════════════════════════════════╣');
    debugPrint('║  Threshold : ${impactThreshold.toStringAsFixed(1)} m/s² '
        '(~${(impactThreshold / 9.81).toStringAsFixed(1)}G)');
    debugPrint('║  Cooldown  : ${cooldownDuration.inSeconds}s');
    debugPrint('║  Source    : Real accelerometer via sensors_plus');
    debugPrint('╚══════════════════════════════════════════════════════╝');

    // Start the underlying accelerometer if needed
    if (!_accelerometerService.isListening) {
      _accelerometerService.startListening();
    }

    // Subscribe to the accelerometer stream
    _streamSubscription = _accelerometerService.readingStream.listen(
      _onReading,
      onError: (Object error) {
        debugPrint('[ImpactDetection] Stream error: $error');
      },
      cancelOnError: false,
    );

    debugPrint('[ImpactDetection] Listening to accelerometer stream.');
  }

  /// Stops impact detection and unsubscribes from the accelerometer stream.
  ///
  /// Does **not** stop the underlying [AccelerometerService] — other
  /// consumers may still need it. Call
  /// [AccelerometerService.stopListening] separately if desired.
  void stopDetection() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isDetecting = false;
    _onImpactDetected = null;

    debugPrint(
      '[ImpactDetection] Stopped. '
      'Processed $_totalReadings readings, '
      'detected $_totalImpacts impacts.',
    );
  }

  /// Releases all resources including the impact stream.
  /// After calling this, create a new instance to restart.
  void dispose() {
    stopDetection();
    _impactController.close();
    debugPrint('[ImpactDetection] Disposed.');
  }

  /// Manually resets the cooldown timer. Useful after the user acknowledges
  /// an alert, allowing immediate re-detection if another impact occurs.
  void resetCooldown() {
    _lastImpactTime = DateTime.fromMillisecondsSinceEpoch(0);
    debugPrint('[ImpactDetection] Cooldown reset.');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _onReading(AccelerometerReading reading) {
    _totalReadings++;
    final now = reading.timestamp;

    // ── Periodic debug logging (throttled) ──────────────────────────────
    if (debugLogIntervalMs > 0 &&
        now.difference(_lastDebugLogTime).inMilliseconds >= debugLogIntervalMs) {
      _lastDebugLogTime = now;
      debugPrint(
        '[ImpactDetection] 📡 Live sensor: '
        'x=${reading.x.toStringAsFixed(2)}, '
        'y=${reading.y.toStringAsFixed(2)}, '
        'z=${reading.z.toStringAsFixed(2)} '
        '| mag=${reading.magnitude.toStringAsFixed(2)} m/s² '
        '(${reading.intensityLabel}) '
        '| threshold: ${impactThreshold.toStringAsFixed(1)}',
      );
    }

    // ── Threshold check ─────────────────────────────────────────────────
    if (reading.magnitude < impactThreshold) {
      // Log notable-but-below-threshold readings for debugging.
      // Only log magnitudes above 15 m/s² (~1.5G) to avoid flooding the
      // console with normal gravity-level noise.
      if (reading.magnitude > 15.0) {
        debugPrint(
          '[ImpactDetection] 🔽 Movement IGNORED — below impact threshold: '
          'mag=${reading.magnitude.toStringAsFixed(2)} m/s² '
          '(threshold: ${impactThreshold.toStringAsFixed(1)} m/s²) '
          '| x=${reading.x.toStringAsFixed(2)}, '
          'y=${reading.y.toStringAsFixed(2)}, '
          'z=${reading.z.toStringAsFixed(2)}',
        );
      }
      return;
    }

    // ── Cooldown check ──────────────────────────────────────────────────
    if (now.difference(_lastImpactTime) < cooldownDuration) {
      debugPrint(
        '[ImpactDetection] ⏳ Spike ${reading.magnitude.toStringAsFixed(1)} '
        'm/s² suppressed — cooldown active '
        '(${cooldownDuration.inSeconds}s window).',
      );
      return;
    }

    // ── IMPACT DETECTED ─────────────────────────────────────────────────
    _lastImpactTime = now;
    _totalImpacts++;

    final event = ImpactEvent(
      reading: reading,
      threshold: impactThreshold,
      detectedAt: now,
    );
    _lastImpact = event;

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────────────────┐');
    debugPrint('│  ⚠️  SUDDEN IMPACT DETECTED  #$_totalImpacts');
    debugPrint('│  Magnitude : ${reading.magnitude.toStringAsFixed(2)} m/s² '
        '(~${(reading.magnitude / 9.81).toStringAsFixed(1)}G)');
    debugPrint('│  Threshold : ${impactThreshold.toStringAsFixed(1)} m/s²');
    debugPrint('│  Raw values: '
        'x=${reading.x.toStringAsFixed(2)}, '
        'y=${reading.y.toStringAsFixed(2)}, '
        'z=${reading.z.toStringAsFixed(2)}');
    debugPrint('│  Time      : ${now.toIso8601String()}');
    debugPrint('│  Cooldown  : ${cooldownDuration.inSeconds}s until next detection');
    debugPrint('└──────────────────────────────────────────────────────┘');
    debugPrint('');

    // Broadcast to stream listeners
    if (!_impactController.isClosed) {
      _impactController.add(event);
    }

    // Fire convenience callback
    _onImpactDetected?.call(event);
  }
}
