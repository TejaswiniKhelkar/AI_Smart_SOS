import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Callback signature when a potential accident is detected.
typedef AccidentDetectedCallback = void Function();

/// Smart accident detection service that monitors accelerometer and gyroscope
/// sensors to detect sudden impacts combined with abnormal rotation, followed
/// by post-impact verification.
///
/// ## Three-stage detection pipeline
///
/// 1. **Correlation** — Both accelerometer (> [accelerometerThreshold]) and
///    gyroscope (> [gyroscopeThreshold]) must spike within [correlationWindow].
///    A single sensor spike alone will NOT trigger.
///
/// 2. **Post-impact observation** — After correlated spikes are detected, the
///    service enters a [postImpactDuration] observation period. During this
///    time it continuously samples both sensors to determine whether the
///    phone has returned to normal (false positive) or continues showing
///    abnormal readings (real accident).
///
/// 3. **Decision** — If the fraction of abnormal readings during observation
///    meets [minAbnormalFraction], the accident is confirmed and the callback
///    fires. Otherwise the event is silently rejected.
///
/// ## What gets filtered out
///
/// - Phone shaking (high accel, low rotation) — fails correlation
/// - Phone spinning (high rotation, low accel) — fails correlation
/// - Phone drop (correlated spike but stabilizes quickly) — fails observation
/// - Walking, jogging, normal handling — below both thresholds
///
/// ## Cooldown
///
/// A cooldown period prevents repeated triggers after a confirmed detection.
class AccidentDetectionService {
  AccidentDetectionService({
    this.accelerometerThreshold = 40.0,
    this.gyroscopeThreshold = 20.0,
    this.cooldownDuration = const Duration(seconds: 30),
    this.correlationWindow = const Duration(seconds: 2),
    this.postImpactDuration = const Duration(seconds: 3),
    this.postImpactAccelAbnormal = 15.0,
    this.postImpactGyroAbnormal = 5.0,
    this.minAbnormalFraction = 0.40,
  });

  /// Accelerometer magnitude threshold in m/s² (default ~4G).
  final double accelerometerThreshold;

  /// Gyroscope magnitude threshold in rad/s.
  final double gyroscopeThreshold;

  /// Minimum time between consecutive accident detections.
  final Duration cooldownDuration;

  /// Maximum time gap between an accelerometer spike and a gyroscope spike
  /// for them to be considered part of the same accident event.
  ///
  /// Default 2 seconds — in a real crash, both sensors spike nearly
  /// simultaneously, but we allow a small window for sensor sampling jitter.
  final Duration correlationWindow;

  /// How long to observe post-impact sensor activity before deciding
  /// whether the event was a real accident or a false positive.
  ///
  /// Default 3 seconds — a phone drop stabilizes within 1–2 seconds,
  /// while a real accident shows sustained abnormal readings.
  final Duration postImpactDuration;

  /// Accelerometer magnitude (m/s²) above which a post-impact reading is
  /// considered "abnormal" (not returned to rest). At rest the phone reads
  /// ~9.8 m/s² (gravity). Readings above 15 m/s² indicate the phone is
  /// still being subjected to significant forces.
  final double postImpactAccelAbnormal;

  /// Gyroscope magnitude (rad/s) above which a post-impact reading is
  /// considered "abnormal". At rest the gyroscope reads ~0. Readings above
  /// 5 rad/s indicate the phone is still rotating significantly.
  final double postImpactGyroAbnormal;

  /// Minimum fraction (0.0–1.0) of post-impact samples that must be
  /// "abnormal" to confirm the accident. Default 0.40 (40%) — a real
  /// accident keeps the phone in sustained distress, while a phone drop
  /// stabilizes quickly (mostly normal readings).
  final double minAbnormalFraction;

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  DateTime? _lastDetectionTime;
  bool _isListening = false;

  /// Timestamp of the most recent accelerometer spike above threshold.
  DateTime? _lastAccelSpikeTime;

  /// Magnitude of the most recent accelerometer spike.
  double _lastAccelSpikeMag = 0.0;

  /// Timestamp of the most recent gyroscope spike above threshold.
  DateTime? _lastGyroSpikeTime;

  /// Magnitude of the most recent gyroscope spike.
  double _lastGyroSpikeMag = 0.0;

  // ── Post-impact observation state ─────────────────────────────────────

  /// Whether we are currently in the post-impact observation period.
  bool _observing = false;

  /// Timer that fires when the observation period ends.
  Timer? _observationTimer;

  /// Accelerometer magnitudes collected during observation.
  final Queue<double> _obsAccelSamples = Queue<double>();

  /// Gyroscope magnitudes collected during observation.
  final Queue<double> _obsGyroSamples = Queue<double>();

  /// The correlated accel magnitude that triggered observation.
  double _obsAccelMag = 0.0;

  /// The correlated gyro magnitude that triggered observation.
  double _obsGyroMag = 0.0;

  /// The time gap of the correlated spikes (for logging).
  Duration _obsGap = Duration.zero;

  /// The callback to fire if post-impact verification passes.
  AccidentDetectedCallback? _pendingCallback;

  /// Whether the service is actively listening to sensors.
  bool get isListening => _isListening;

  /// Starts monitoring accelerometer and gyroscope sensors.
  ///
  /// An accident is detected ONLY when:
  /// 1. Both sensors spike within [correlationWindow].
  /// 2. Post-impact observation confirms sustained abnormal readings.
  ///
  /// Multiple calls are safe — the service will not create duplicate listeners.
  void startListening({required AccidentDetectedCallback onAccidentDetected}) {
    if (_isListening) return;
    _isListening = true;

    debugPrint('[AccidentDetection] Starting sensor monitoring...');
    debugPrint(
      '[AccidentDetection] Accel threshold: '
      '${accelerometerThreshold.toStringAsFixed(1)} m/s² '
      '(~${(accelerometerThreshold / 9.81).toStringAsFixed(1)}G)',
    );
    debugPrint(
      '[AccidentDetection] Gyro threshold: '
      '${gyroscopeThreshold.toStringAsFixed(1)} rad/s',
    );
    debugPrint(
      '[AccidentDetection] Correlation window: '
      '${correlationWindow.inMilliseconds}ms',
    );
    debugPrint(
      '[AccidentDetection] Post-impact observation: '
      '${postImpactDuration.inSeconds}s '
      '(accel abnormal > ${postImpactAccelAbnormal.toStringAsFixed(1)} m/s², '
      'gyro abnormal > ${postImpactGyroAbnormal.toStringAsFixed(1)} rad/s, '
      'min fraction: ${(minAbnormalFraction * 100).toStringAsFixed(0)}%)',
    );
    debugPrint(
      '[AccidentDetection] Mode: BOTH sensors must spike '
      'within ${correlationWindow.inSeconds}s, then '
      '${postImpactDuration.inSeconds}s observation must confirm',
    );

    // Listen to accelerometer events
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((AccelerometerEvent event) {
      final magnitude = _magnitude(event.x, event.y, event.z);

      // During post-impact observation, collect samples
      if (_observing) {
        _obsAccelSamples.add(magnitude);
        return;
      }

      // Compare raw magnitude — during a crash values spike well above 40 m/s².
      if (magnitude > accelerometerThreshold) {
        _lastAccelSpikeTime = DateTime.now();
        _lastAccelSpikeMag = magnitude;
        debugPrint(
          '[AccidentDetection] ⚠️ Accelerometer spike: '
          '${magnitude.toStringAsFixed(2)} m/s² '
          '(threshold: $accelerometerThreshold) — '
          'checking for correlated rotation...',
        );
        _checkCorrelation(onAccidentDetected);
      } else if (magnitude > 15.0) {
        debugPrint(
          '[AccidentDetection] 🔽 Movement IGNORED — below threshold: '
          '${magnitude.toStringAsFixed(2)} m/s² '
          '(threshold: $accelerometerThreshold)',
        );
      }
    }, onError: (error) {
      debugPrint('[AccidentDetection] Accelerometer error: $error');
    });

    // Listen to gyroscope events
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((GyroscopeEvent event) {
      final magnitude = _magnitude(event.x, event.y, event.z);

      // During post-impact observation, collect samples
      if (_observing) {
        _obsGyroSamples.add(magnitude);
        return;
      }

      if (magnitude > gyroscopeThreshold) {
        _lastGyroSpikeTime = DateTime.now();
        _lastGyroSpikeMag = magnitude;
        debugPrint(
          '[AccidentDetection] ⚠️ Gyroscope spike: '
          '${magnitude.toStringAsFixed(2)} rad/s '
          '(threshold: $gyroscopeThreshold) — '
          'checking for correlated impact...',
        );
        _checkCorrelation(onAccidentDetected);
      } else if (magnitude > 5.0) {
        debugPrint(
          '[AccidentDetection] 🔽 Rotation IGNORED — below threshold: '
          '${magnitude.toStringAsFixed(2)} rad/s '
          '(threshold: $gyroscopeThreshold)',
        );
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
    _lastAccelSpikeTime = null;
    _lastGyroSpikeTime = null;
    _cancelObservation();
    debugPrint('[AccidentDetection] Sensor monitoring stopped.');
  }

  /// Computes the vector magnitude: sqrt(x² + y² + z²).
  double _magnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Checks whether both accelerometer and gyroscope spikes have occurred
  /// within [correlationWindow]. If so, starts post-impact observation
  /// instead of immediately triggering.
  void _checkCorrelation(AccidentDetectedCallback callback) {
    // Need both sensor spikes to be present
    if (_lastAccelSpikeTime == null || _lastGyroSpikeTime == null) {
      if (_lastAccelSpikeTime != null && _lastGyroSpikeTime == null) {
        debugPrint(
          '[AccidentDetection] ⏱ Impact recorded — waiting for '
          'gyroscope spike within '
          '${correlationWindow.inMilliseconds}ms...',
        );
      } else if (_lastGyroSpikeTime != null && _lastAccelSpikeTime == null) {
        debugPrint(
          '[AccidentDetection] ⏱ Rotation recorded — waiting for '
          'accelerometer spike within '
          '${correlationWindow.inMilliseconds}ms...',
        );
      }
      return;
    }

    // Check if both spikes occurred within the correlation window
    final gap = _lastAccelSpikeTime!.difference(_lastGyroSpikeTime!).abs();

    if (gap > correlationWindow) {
      debugPrint(
        '[AccidentDetection] ❌ Spikes too far apart — '
        'gap: ${gap.inMilliseconds}ms > '
        '${correlationWindow.inMilliseconds}ms window. '
        'Accel: ${_lastAccelSpikeMag.toStringAsFixed(1)} m/s², '
        'Gyro: ${_lastGyroSpikeMag.toStringAsFixed(1)} rad/s. '
        'NOT triggering.',
      );
      // Clear the older spike so it doesn't combine with future events
      if (_lastAccelSpikeTime!.isBefore(_lastGyroSpikeTime!)) {
        _lastAccelSpikeTime = null;
      } else {
        _lastGyroSpikeTime = null;
      }
      return;
    }

    // Both sensors correlated — check cooldown
    final now = DateTime.now();
    if (_lastDetectionTime != null &&
        now.difference(_lastDetectionTime!) < cooldownDuration) {
      debugPrint(
        '[AccidentDetection] ⏳ Correlated detection suppressed — '
        'cooldown active (${cooldownDuration.inSeconds}s window).',
      );
      _lastAccelSpikeTime = null;
      _lastGyroSpikeTime = null;
      return;
    }

    // ── CORRELATED — start post-impact observation ────────────────────
    final accelMag = _lastAccelSpikeMag;
    final gyroMag = _lastGyroSpikeMag;
    _lastAccelSpikeTime = null;
    _lastGyroSpikeTime = null;

    _startPostImpactObservation(
      callback: callback,
      accelMag: accelMag,
      gyroMag: gyroMag,
      gap: gap,
    );
  }

  // ── Post-impact observation ───────────────────────────────────────────

  /// Begins the post-impact observation period.
  ///
  /// During this period, sensor events are collected (not threshold-checked).
  /// When the timer fires, [_evaluatePostImpact] analyzes whether the
  /// readings indicate a real accident or a false positive.
  void _startPostImpactObservation({
    required AccidentDetectedCallback callback,
    required double accelMag,
    required double gyroMag,
    required Duration gap,
  }) {
    _observing = true;
    _pendingCallback = callback;
    _obsAccelSamples.clear();
    _obsGyroSamples.clear();
    _obsAccelMag = accelMag;
    _obsGyroMag = gyroMag;
    _obsGap = gap;

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────────────────┐');
    debugPrint('│  🔍 POST-IMPACT OBSERVATION STARTED');
    debugPrint('│  Correlated impact : '
        '${accelMag.toStringAsFixed(2)} m/s² '
        '(~${(accelMag / 9.81).toStringAsFixed(1)}G)');
    debugPrint('│  Correlated rotation: '
        '${gyroMag.toStringAsFixed(2)} rad/s');
    debugPrint('│  Correlation gap   : ${gap.inMilliseconds}ms');
    debugPrint('│  Observation period: ${postImpactDuration.inSeconds}s');
    debugPrint('│  Abnormal accel    : '
        '> ${postImpactAccelAbnormal.toStringAsFixed(1)} m/s²');
    debugPrint('│  Abnormal gyro     : '
        '> ${postImpactGyroAbnormal.toStringAsFixed(1)} rad/s');
    debugPrint('│  Required fraction : '
        '${(minAbnormalFraction * 100).toStringAsFixed(0)}%');
    debugPrint('│  Watching for sustained abnormality...');
    debugPrint('└──────────────────────────────────────────────────────┘');
    debugPrint('');

    _observationTimer = Timer(postImpactDuration, _evaluatePostImpact);
  }

  /// Evaluates the sensor data collected during the observation period.
  ///
  /// Counts how many readings were "abnormal" (above the post-impact
  /// thresholds). If the abnormal fraction meets [minAbnormalFraction],
  /// the accident is confirmed. Otherwise it's rejected as a false positive
  /// (likely a phone drop that stabilized).
  void _evaluatePostImpact() {
    _observing = false;
    final callback = _pendingCallback;
    _pendingCallback = null;

    final accelCount = _obsAccelSamples.length;
    final gyroCount = _obsGyroSamples.length;

    // Count abnormal readings
    int abnormalAccel = 0;
    for (final mag in _obsAccelSamples) {
      if (mag > postImpactAccelAbnormal) abnormalAccel++;
    }

    int abnormalGyro = 0;
    for (final mag in _obsGyroSamples) {
      if (mag > postImpactGyroAbnormal) abnormalGyro++;
    }

    // Use the combined total across both sensors
    final totalSamples = accelCount + gyroCount;
    final totalAbnormal = abnormalAccel + abnormalGyro;
    final abnormalFraction =
        totalSamples > 0 ? totalAbnormal / totalSamples : 0.0;

    _obsAccelSamples.clear();
    _obsGyroSamples.clear();

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║  🔍 POST-IMPACT EVALUATION');
    debugPrint('╠══════════════════════════════════════════════════════╣');
    debugPrint('║  Accel samples  : $accelCount total, '
        '$abnormalAccel abnormal '
        '(> ${postImpactAccelAbnormal.toStringAsFixed(1)} m/s²)');
    debugPrint('║  Gyro samples   : $gyroCount total, '
        '$abnormalGyro abnormal '
        '(> ${postImpactGyroAbnormal.toStringAsFixed(1)} rad/s)');
    debugPrint('║  Combined       : $totalAbnormal / $totalSamples '
        '= ${(abnormalFraction * 100).toStringAsFixed(1)}% abnormal');
    debugPrint('║  Required       : '
        '${(minAbnormalFraction * 100).toStringAsFixed(0)}%');

    if (totalSamples == 0) {
      debugPrint('║  Decision       : ❌ REJECTED (no samples collected '
          '— sensor may be unavailable)');
      debugPrint('╚══════════════════════════════════════════════════════╝');
      debugPrint('');
      return;
    }

    if (abnormalFraction < minAbnormalFraction) {
      // Phone returned to normal — false positive (likely phone drop)
      debugPrint('║  Decision       : ❌ REJECTED — phone stabilized');
      debugPrint('║  Reason         : Abnormal fraction '
          '${(abnormalFraction * 100).toStringAsFixed(1)}% < '
          '${(minAbnormalFraction * 100).toStringAsFixed(0)}% required');
      debugPrint('║  Conclusion     : Impact+rotation correlated, but '
          'post-impact readings returned to normal. '
          'Likely a phone drop, not an accident.');
      debugPrint('╚══════════════════════════════════════════════════════╝');
      debugPrint('');
      return;
    }

    // ── ACCIDENT CONFIRMED after post-impact verification ─────────────
    final now = DateTime.now();

    // Final cooldown check (in case cooldown was triggered during observation)
    if (_lastDetectionTime != null &&
        now.difference(_lastDetectionTime!) < cooldownDuration) {
      debugPrint('║  Decision       : ⏳ SUPPRESSED — cooldown active '
          'during observation');
      debugPrint('╚══════════════════════════════════════════════════════╝');
      debugPrint('');
      return;
    }

    _lastDetectionTime = now;

    debugPrint('║  Decision       : ✅ ACCIDENT CONFIRMED');
    debugPrint('║  Correlated     : accel '
        '${_obsAccelMag.toStringAsFixed(1)} m/s² + gyro '
        '${_obsGyroMag.toStringAsFixed(1)} rad/s '
        '(gap: ${_obsGap.inMilliseconds}ms)');
    debugPrint('║  Post-impact    : '
        '${(abnormalFraction * 100).toStringAsFixed(1)}% abnormal '
        '≥ ${(minAbnormalFraction * 100).toStringAsFixed(0)}% required');
    debugPrint('║  Conclusion     : Sustained abnormal readings confirm '
        'this is a real accident, not a phone drop.');
    debugPrint('║  Time           : ${now.toIso8601String()}');
    debugPrint('╚══════════════════════════════════════════════════════╝');
    debugPrint('');

    callback?.call();
  }

  /// Cancels any in-progress post-impact observation.
  void _cancelObservation() {
    _observationTimer?.cancel();
    _observationTimer = null;
    _observing = false;
    _pendingCallback = null;
    _obsAccelSamples.clear();
    _obsGyroSamples.clear();
  }

  /// Resets the cooldown timer (e.g., after the user dismisses an alert).
  void resetCooldown() {
    _lastDetectionTime = DateTime.now();
    _cancelObservation();
  }
}
