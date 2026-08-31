import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'accelerometer_service.dart';
import 'gyroscope_service.dart';
import 'impact_detection_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENT TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// The type of motion event detected.
enum MotionEventType {
  /// Accelerometer magnitude exceeded the impact threshold.
  suddenImpactDetected,

  /// Gyroscope magnitude exceeded the rotation threshold.
  abnormalRotationDetected,

  /// Both impact AND rotation detected within the configured time window,
  /// suggesting a possible accident (fall, collision, crash).
  possibleAccidentMotionDetected,

  /// Confidence analysis determined that the combined sensor evidence
  /// strongly indicates an actual accident, not just a phone drop or
  /// normal movement. Emitted only after post-impact observation and
  /// evidence scoring confirm a high-confidence incident.
  highConfidenceAccidentDetected,
}

/// A detected motion event with full context.
class MotionEvent {
  const MotionEvent({
    required this.type,
    required this.detectedAt,
    this.impactEvent,
    this.rotationReading,
    this.rotationMagnitude,
    this.confidenceScore,
    this.message = '',
  });

  /// What kind of motion was detected.
  final MotionEventType type;

  /// When this event was recorded.
  final DateTime detectedAt;

  /// The accelerometer impact event (present for [suddenImpactDetected]
  /// and [possibleAccidentMotionDetected]).
  final ImpactEvent? impactEvent;

  /// The gyroscope reading that triggered rotation detection (present for
  /// [abnormalRotationDetected] and [possibleAccidentMotionDetected]).
  final GyroscopeReading? rotationReading;

  /// The gyroscope magnitude at time of detection (rad/s).
  final double? rotationMagnitude;

  /// The confidence score from the analysis stage. Present only for
  /// [highConfidenceAccidentDetected] events.
  final double? confidenceScore;

  /// Human-readable description of the event.
  final String message;

  @override
  String toString() => 'MotionEvent($type, "$message")';
}

/// Callback signature for motion events.
typedef MotionEventCallback = void Function(MotionEvent event);

// ═══════════════════════════════════════════════════════════════════════════
// FALSE-POSITIVE FILTER CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// Configurable thresholds for the false-positive filter.
///
/// These values determine what counts as "normal daily movement" that should
/// be silently rejected rather than treated as an impact or accident.
///
/// ## Filtered movements
///
/// | Movement               | Accel pattern            | Gyro pattern         |
/// |------------------------|--------------------------|----------------------|
/// | Walking                | Rhythmic 10–16 m/s²      | Low rotation < 3     |
/// | Small hand shake       | Brief spike < 22 m/s²    | Low rotation < 4     |
/// | Picking up phone       | Gradual rise, low peak   | Moderate < 6 rad/s   |
/// | Normal phone rotation  | Near gravity (~9.8)      | Moderate < 6 rad/s   |
/// | Gentle surface place   | Brief bump, quick settle | Very low < 2 rad/s   |
class FalsePositiveFilterConfig {
  const FalsePositiveFilterConfig({
    this.walkingAccelMax = 16.0,
    this.walkingAccelMin = 8.0,
    this.walkingGyroMax = 3.0,
    this.handShakeAccelMax = 22.0,
    this.handShakeGyroMax = 4.0,
    this.pickupAccelMax = 18.0,
    this.pickupGyroMax = 6.0,
    this.normalRotationAccelMax = 12.0,
    this.normalRotationGyroMax = 6.0,
    this.gentlePlaceAccelMax = 18.0,
    this.gentlePlaceGyroMax = 2.0,
    this.gentlePlaceSettleMs = 400,
    this.bufferDuration = const Duration(seconds: 2),
  });

  // ── Walking filter ─────────────────────────────────────────────────────

  /// Max average accel magnitude (m/s²) for "normal walking" classification.
  /// Walking oscillates rhythmically between 8–16 m/s².
  final double walkingAccelMax;

  /// Min average accel magnitude (m/s²) for "normal walking" — phone in
  /// freefall (< 8) or stationary (< 8) is not walking.
  final double walkingAccelMin;

  /// Max concurrent gyro magnitude (rad/s) during walking. Walking produces
  /// very little rotation (< 3 rad/s).
  final double walkingGyroMax;

  // ── Hand shake filter ──────────────────────────────────────────────────

  /// Max accel magnitude (m/s²) for "small hand shake" — brief spikes
  /// below this with low rotation are filtered.
  final double handShakeAccelMax;

  /// Max concurrent gyro magnitude (rad/s) for hand-shake classification.
  final double handShakeGyroMax;

  // ── Phone pickup filter ────────────────────────────────────────────────

  /// Max accel magnitude (m/s²) for "picking up the phone".
  final double pickupAccelMax;

  /// Max concurrent gyro magnitude (rad/s) during pickup.
  final double pickupGyroMax;

  // ── Normal rotation filter ─────────────────────────────────────────────

  /// Max accel magnitude (m/s²) during normal rotation — if the phone
  /// isn't accelerating much (near gravity), rotation alone is just the
  /// user turning the phone in their hand.
  final double normalRotationAccelMax;

  /// Max gyro magnitude (rad/s) for "normal rotation". Moderate rotation
  /// without significant acceleration is everyday use.
  final double normalRotationGyroMax;

  // ── Gentle surface placement filter ────────────────────────────────────

  /// Max accel spike (m/s²) for placing the phone on a surface.
  final double gentlePlaceAccelMax;

  /// Max gyro magnitude (rad/s) during gentle placement.
  final double gentlePlaceGyroMax;

  /// Time (ms) within which accel must settle back to near-gravity after
  /// the spike for it to be classified as placement.
  final int gentlePlaceSettleMs;

  // ── Buffer ─────────────────────────────────────────────────────────────

  /// How much sensor history to keep for pattern analysis.
  final Duration bufferDuration;
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIDENCE ANALYSIS CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// Configurable parameters for the accident confidence analysis stage.
///
/// After initial sensor events (impact, rotation, combined accident) are
/// detected, the confidence analyzer collects evidence within a time window
/// and observes post-impact behavior to distinguish phone drops from real
/// accidents.
///
/// ## Scoring
///
/// Each sensor event contributes a score. After the observation period,
/// a stability/abnormality adjustment is applied. If the total score
/// meets [minConfidenceScore], a [highConfidenceAccidentDetected] event
/// is emitted.
///
/// ## Phone drop vs accident
///
/// A phone drop produces a strong impact + tumble rotation, but the phone
/// **stabilizes quickly** afterward (readings return to near-gravity within
/// 1–2 seconds). A real accident produces **sustained abnormality** — the
/// accelerometer and gyroscope remain erratic during the observation period.
///
/// ## Example scoring scenarios
///
/// | Scenario                          | Evidence           | Post-obs   | Score |
/// |-----------------------------------|--------------------|------------|-------|
/// | Phone drop (impact+rot+stable)    | 1.5+1.0+1.0 = 3.5 | −2.0       | 1.5 ❌|
/// | Accident (impact+rot+abnormal)    | 1.5+1.0+1.0 = 3.5 | +1.0       | 4.5 ✓|
/// | Impact only + stable              | 1.5                | −2.0       | −0.5 ❌|
/// | 2 impacts + rotation + abnormal   | 3.0+1.0+1.0 = 5.0 | +1.0       | 6.0 ✓|
class ConfidenceAnalysisConfig {
  const ConfidenceAnalysisConfig({
    this.incidentWindow = const Duration(seconds: 5),
    this.postImpactObservation = const Duration(seconds: 3),
    this.highConfidenceCooldown = const Duration(seconds: 30),
    this.minConfidenceScore = 3.0,
    this.impactScore = 1.5,
    this.rotationScore = 1.0,
    this.combinedAccidentScore = 1.0,
    this.sustainedAbnormalityBonus = 1.0,
    this.postImpactStabilityPenalty = -2.0,
    this.strongImpactThreshold = 30.0,
    this.strongRotationThreshold = 12.0,
    this.stabilityAccelTolerance = 1.5,
    this.stabilityGyroMax = 2.0,
    this.stabilityCheckSamples = 8,
    this.stabilityMinStableFraction = 0.75,
  });

  // ── Time windows ──────────────────────────────────────────────────────

  /// Maximum duration to collect corroborating evidence after the first
  /// trigger event. If the window expires, evaluation is forced.
  final Duration incidentWindow;

  /// How long to wait after the last significant event before evaluating.
  /// During this period the analyzer watches whether the phone stabilizes
  /// (phone drop) or stays erratic (accident).
  final Duration postImpactObservation;

  /// Minimum time between consecutive [highConfidenceAccidentDetected]
  /// events. Prevents repeated triggering for a single real incident.
  final Duration highConfidenceCooldown;

  // ── Score thresholds ──────────────────────────────────────────────────

  /// Minimum accumulated score required to emit
  /// [highConfidenceAccidentDetected]. Below this → incident rejected.
  final double minConfidenceScore;

  // ── Score contributions ───────────────────────────────────────────────

  /// Score for each sudden impact event during the incident window.
  final double impactScore;

  /// Score for each abnormal rotation event during the incident window.
  final double rotationScore;

  /// Bonus score added when impact and rotation occur together within
  /// the combination window (possibleAccidentMotionDetected). This is
  /// additive on top of the individual impact and rotation scores.
  final double combinedAccidentScore;

  /// Bonus added when post-impact observation shows sustained abnormal
  /// readings (accelerometer or gyroscope remain erratic).
  final double sustainedAbnormalityBonus;

  /// Penalty applied when post-impact observation shows the phone
  /// quickly stabilized (typical phone drop pattern). Should be negative.
  final double postImpactStabilityPenalty;

  // ── Magnitude qualifiers ──────────────────────────────────────────────

  /// Impact magnitude (m/s²) above which the impact is considered "strong"
  /// and receives 1.5× its base score.
  final double strongImpactThreshold;

  /// Rotation magnitude (rad/s) above which the rotation is considered
  /// "strong" and receives 1.5× its base score.
  final double strongRotationThreshold;

  // ── Stability detection ───────────────────────────────────────────────

  /// Acceleration tolerance (m/s²) around gravity (9.81) for "stable"
  /// classification during post-impact observation.
  final double stabilityAccelTolerance;

  /// Maximum gyroscope magnitude (rad/s) to consider "stable".
  final double stabilityGyroMax;

  /// Number of recent buffer samples to check for stability.
  final int stabilityCheckSamples;

  /// Fraction of samples that must be stable to classify as "stabilized".
  /// 0.75 means 75% of recent samples must be near gravity with low gyro.
  final double stabilityMinStableFraction;
}

// ═══════════════════════════════════════════════════════════════════════════
// ACCIDENT MOTION DETECTOR — LAYER 3
// (with false-positive filtering + confidence analysis)
// ═══════════════════════════════════════════════════════════════════════════

/// Combines real accelerometer impact detection with real gyroscope rotation
/// detection to identify possible accident motion patterns.
///
/// ## False-positive filtering
///
/// Before emitting impact or rotation events, the detector checks the
/// recent sensor history against known normal-movement patterns:
///
/// 1. **Walking** — rhythmic accel 8–16 m/s² with low rotation (< 3 rad/s)
/// 2. **Hand shake** — brief accel spike < 22 m/s² with low rotation (< 4)
/// 3. **Phone pickup** — accel < 18 m/s² with moderate rotation (< 6)
/// 4. **Normal rotation** — accel near gravity (< 12) with rotation < 6
/// 5. **Gentle placement** — accel spike < 18 m/s² that settles to gravity
///    within 400 ms, with very low rotation (< 2)
///
/// If any filter matches, the event is suppressed with a debug log
/// explaining which filter caught it.
///
/// ## Confidence analysis (Layer 4)
///
/// After events pass the false-positive filter, the confidence analyzer
/// collects them as evidence within an incident window. When no new events
/// arrive for [postImpactObservation] seconds, it evaluates:
///
/// 1. Sums the evidence scores (impact, rotation, combined correlation).
/// 2. Checks whether the phone **stabilized** (phone drop) or shows
///    **sustained abnormality** (accident).
/// 3. Applies a stability penalty or abnormality bonus.
/// 4. If the final score meets [minConfidenceScore], emits
///    [highConfidenceAccidentDetected].
///
/// ## Architecture
///
/// ```
/// Layer 1a: AccelerometerService  ──→  ImpactDetectionService (Layer 2)
///                │                              │
/// Layer 1b: GyroscopeService  ─────────────────┤
///                │                              ▼
///                └─ buffers ──→  AccidentMotionDetector (Layer 3)
///                                  + FalsePositiveFilter
///                                  + ConfidenceAnalyzer (Layer 4)
///                                              │
///                               Emits: MotionEvent stream
///                               (incl. highConfidenceAccidentDetected)
/// ```
///
/// ## Safety
///
/// - Does **not** trigger SOS or modify the 30-second countdown.
/// - Web/Chrome: sensor streams won't fire — no crash.
/// - All data comes from real physical sensors via `sensors_plus`.
class AccidentMotionDetector {
  AccidentMotionDetector({
    ImpactDetectionService? impactService,
    GyroscopeService? gyroscopeService,
    this.impactThreshold = 40.0,
    this.rotationThreshold = 20.0,
    this.combinationWindow = const Duration(seconds: 2),
    this.rotationCooldown = const Duration(seconds: 3),
    this.accidentCooldown = const Duration(seconds: 10),
    this.debugLogIntervalMs = 1000,
    this.filterConfig = const FalsePositiveFilterConfig(),
    this.confidenceConfig = const ConfidenceAnalysisConfig(),
  })  : _impactService = impactService ??
            ImpactDetectionService(impactThreshold: impactThreshold),
        _gyroscopeService = gyroscopeService ??
            GyroscopeService(
              samplingPeriod: const Duration(milliseconds: 20),
              emitIntervalMs: 0,
            );

  // ── Configuration ────────────────────────────────────────────────────────

  /// Accelerometer magnitude (m/s²) for sudden-impact detection.
  final double impactThreshold;

  /// Gyroscope magnitude (rad/s) above which abnormal rotation is detected.
  final double rotationThreshold;

  /// Max time gap between impact & rotation for combined detection.
  final Duration combinationWindow;

  /// Min time between consecutive rotation events.
  final Duration rotationCooldown;

  /// Min time between consecutive combined accident events.
  final Duration accidentCooldown;

  /// Interval (ms) between periodic gyroscope debug logs.
  final int debugLogIntervalMs;

  /// False-positive filter configuration. All thresholds are configurable.
  final FalsePositiveFilterConfig filterConfig;

  /// Confidence analysis configuration. Controls evidence scoring,
  /// observation periods, and the high-confidence emission threshold.
  final ConfidenceAnalysisConfig confidenceConfig;

  // ── Internal state ───────────────────────────────────────────────────────

  final ImpactDetectionService _impactService;
  final GyroscopeService _gyroscopeService;

  StreamSubscription<ImpactEvent>? _impactSubscription;
  StreamSubscription<GyroscopeReading>? _gyroSubscription;
  StreamSubscription<AccelerometerReading>? _accelBufferSubscription;
  bool _isDetecting = false;

  DateTime _lastRotationTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAccidentTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastGyroLogTime = DateTime.fromMillisecondsSinceEpoch(0);

  ImpactEvent? _recentImpact;
  GyroscopeReading? _recentRotation;
  DateTime? _recentRotationTime;

  /// Timer that auto-clears [_recentImpact] after [combinationWindow]
  /// expires, preventing stale impacts from combining with unrelated
  /// rotation events that arrive much later.
  Timer? _impactExpiryTimer;

  /// Timer that auto-clears [_recentRotation] after [combinationWindow].
  Timer? _rotationExpiryTimer;

  int _totalRotations = 0;
  int _totalAccidents = 0;
  int _filteredImpacts = 0;
  int _filteredRotations = 0;
  int _expiredImpacts = 0;
  int _expiredRotations = 0;
  int _suppressedDuringCooldown = 0;

  final StreamController<MotionEvent> _eventController =
      StreamController<MotionEvent>.broadcast();

  MotionEventCallback? _onMotionEvent;
  MotionEvent? _lastEvent;

  // ── Rolling sensor buffers (for false-positive analysis) ────────────────

  /// Recent accelerometer magnitudes with timestamps.
  final Queue<_TimestampedValue> _accelBuffer = Queue<_TimestampedValue>();

  /// Recent gyroscope magnitudes with timestamps.
  final Queue<_TimestampedValue> _gyroBuffer = Queue<_TimestampedValue>();

  // ── Confidence analysis state ───────────────────────────────────────────

  /// Whether an incident is currently being analyzed.
  bool _incidentActive = false;

  /// When the current incident window started.
  DateTime? _incidentStartTime;

  /// Evidence collected during the current incident.
  final List<_IncidentEvidence> _incidentEvidence = [];

  /// Strongest impact event seen during the current incident (for
  /// reporting on the [highConfidenceAccidentDetected] event).
  ImpactEvent? _incidentStrongestImpact;

  /// Strongest rotation reading seen during the current incident.
  GyroscopeReading? _incidentStrongestRotation;

  /// Timer for the post-impact observation period. Fires when no new
  /// evidence has arrived for [postImpactObservation] seconds.
  Timer? _observationTimer;

  /// Timer for the maximum incident window. Forces evaluation when
  /// the [incidentWindow] expires regardless of ongoing events.
  Timer? _incidentWindowTimer;

  /// Cooldown tracking for high-confidence events.
  DateTime _lastHighConfidenceTime = DateTime.fromMillisecondsSinceEpoch(0);

  int _totalHighConfidence = 0;
  int _totalRejectedIncidents = 0;

  // ── Public getters ───────────────────────────────────────────────────────

  bool get isDetecting => _isDetecting;
  MotionEvent? get lastEvent => _lastEvent;
  int get totalRotations => _totalRotations;
  int get totalAccidents => _totalAccidents;

  /// How many impact events were suppressed by the false-positive filter.
  int get filteredImpacts => _filteredImpacts;

  /// How many rotation events were suppressed by the false-positive filter.
  int get filteredRotations => _filteredRotations;

  /// How many impact events expired without a matching rotation.
  int get expiredImpacts => _expiredImpacts;

  /// How many rotation events expired without a matching impact.
  int get expiredRotations => _expiredRotations;

  /// How many high-confidence accident events were emitted.
  int get totalHighConfidence => _totalHighConfidence;

  /// How many incidents were analyzed and rejected (insufficient evidence).
  int get totalRejectedIncidents => _totalRejectedIncidents;

  /// How many sensor events were suppressed because the high-confidence
  /// cooldown was active (preventing duplicate triggers from the same
  /// physical incident).
  int get suppressedDuringCooldown => _suppressedDuringCooldown;

  Stream<MotionEvent> get eventStream => _eventController.stream;
  ImpactDetectionService get impactService => _impactService;
  GyroscopeService get gyroscopeService => _gyroscopeService;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Starts all sensor monitoring and combined detection.
  void startDetection({MotionEventCallback? onMotionEvent}) {
    if (_isDetecting) {
      debugPrint(
          '[AccidentMotion] Already detecting — ignoring startDetection().');
      return;
    }

    _isDetecting = true;
    _onMotionEvent = onMotionEvent;
    _totalRotations = 0;
    _totalAccidents = 0;
    _filteredImpacts = 0;
    _filteredRotations = 0;
    _expiredImpacts = 0;
    _expiredRotations = 0;
    _totalHighConfidence = 0;
    _totalRejectedIncidents = 0;
    _suppressedDuringCooldown = 0;
    _lastHighConfidenceTime = DateTime.fromMillisecondsSinceEpoch(0);
    _clearRecentImpact();
    _clearRecentRotation();
    _accelBuffer.clear();
    _gyroBuffer.clear();
    _resetIncident();

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════╗');
    debugPrint('║  ACCIDENT MOTION DETECTOR — STARTED                     ║');
    debugPrint('╠══════════════════════════════════════════════════════════╣');
    debugPrint('║  Impact threshold  : '
        '${impactThreshold.toStringAsFixed(1)} m/s² '
        '(~${(impactThreshold / 9.81).toStringAsFixed(1)}G)');
    debugPrint('║  Rotation threshold: '
        '${rotationThreshold.toStringAsFixed(1)} rad/s');
    debugPrint('║  Combination window: '
        '${combinationWindow.inMilliseconds}ms');
    debugPrint('║  Rotation cooldown : '
        '${rotationCooldown.inSeconds}s');
    debugPrint('║  Accident cooldown : '
        '${accidentCooldown.inSeconds}s');
    debugPrint('║  False-positive filter: ENABLED');
    debugPrint('║    Walking    : accel ${filterConfig.walkingAccelMin.toStringAsFixed(0)}'
        '–${filterConfig.walkingAccelMax.toStringAsFixed(0)} m/s², '
        'gyro < ${filterConfig.walkingGyroMax.toStringAsFixed(0)} rad/s');
    debugPrint('║    Hand shake : accel < ${filterConfig.handShakeAccelMax.toStringAsFixed(0)} m/s², '
        'gyro < ${filterConfig.handShakeGyroMax.toStringAsFixed(0)} rad/s');
    debugPrint('║    Pickup     : accel < ${filterConfig.pickupAccelMax.toStringAsFixed(0)} m/s², '
        'gyro < ${filterConfig.pickupGyroMax.toStringAsFixed(0)} rad/s');
    debugPrint('║    Rotation   : accel < ${filterConfig.normalRotationAccelMax.toStringAsFixed(0)} m/s², '
        'gyro < ${filterConfig.normalRotationGyroMax.toStringAsFixed(0)} rad/s');
    debugPrint('║    Placement  : accel < ${filterConfig.gentlePlaceAccelMax.toStringAsFixed(0)} m/s², '
        'gyro < ${filterConfig.gentlePlaceGyroMax.toStringAsFixed(0)} rad/s, '
        'settle < ${filterConfig.gentlePlaceSettleMs}ms');
    debugPrint('║  Confidence analysis: ENABLED');
    debugPrint('║    Incident window : '
        '${confidenceConfig.incidentWindow.inSeconds}s');
    debugPrint('║    Observation     : '
        '${confidenceConfig.postImpactObservation.inSeconds}s');
    debugPrint('║    Min score       : '
        '${confidenceConfig.minConfidenceScore.toStringAsFixed(1)}');
    debugPrint('║    HC cooldown     : '
        '${confidenceConfig.highConfidenceCooldown.inSeconds}s');
    debugPrint('║    Impact score    : '
        '${confidenceConfig.impactScore.toStringAsFixed(1)}');
    debugPrint('║    Rotation score  : '
        '${confidenceConfig.rotationScore.toStringAsFixed(1)}');
    debugPrint('║    Combined bonus  : '
        '${confidenceConfig.combinedAccidentScore.toStringAsFixed(1)}');
    debugPrint('║    Abnormal bonus  : '
        '+${confidenceConfig.sustainedAbnormalityBonus.toStringAsFixed(1)}');
    debugPrint('║    Stability pen.  : '
        '${confidenceConfig.postImpactStabilityPenalty.toStringAsFixed(1)}');
    debugPrint('║    Strong impact   : '
        '≥${confidenceConfig.strongImpactThreshold.toStringAsFixed(0)} m/s²');
    debugPrint('║    Strong rotation : '
        '≥${confidenceConfig.strongRotationThreshold.toStringAsFixed(0)} rad/s');
    debugPrint('║  Source: Real sensors via sensors_plus');
    debugPrint('╚══════════════════════════════════════════════════════════╝');
    debugPrint('');

    // Start the impact detection pipeline (Layer 2 → Layer 1a)
    _impactService.startDetection();

    // Start the gyroscope data layer (Layer 1b)
    if (!_gyroscopeService.isListening) {
      _gyroscopeService.startListening();
    }

    // Subscribe to impact events from Layer 2
    _impactSubscription = _impactService.impactStream.listen(
      _onImpactDetected,
      onError: (Object e) =>
          debugPrint('[AccidentMotion] Impact stream error: $e'),
      cancelOnError: false,
    );

    // Subscribe to raw gyroscope readings from Layer 1b
    _gyroSubscription = _gyroscopeService.readingStream.listen(
      _onGyroscopeReading,
      onError: (Object e) =>
          debugPrint('[AccidentMotion] Gyroscope stream error: $e'),
      cancelOnError: false,
    );

    // Subscribe to raw accelerometer readings for the rolling buffer
    _accelBufferSubscription =
        _impactService.accelerometerService.readingStream.listen(
      _onAccelBufferReading,
      onError: (Object e) =>
          debugPrint('[AccidentMotion] Accel buffer stream error: $e'),
      cancelOnError: false,
    );

    debugPrint('[AccidentMotion] All sensor streams connected '
        '(including buffer streams).');
  }

  /// Stops all detection and unsubscribes from sensor streams.
  void stopDetection() {
    _impactSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelBufferSubscription?.cancel();
    _impactSubscription = null;
    _gyroSubscription = null;
    _accelBufferSubscription = null;
    _clearRecentImpact();
    _clearRecentRotation();
    _resetIncident();
    _impactService.stopDetection();
    _gyroscopeService.stopListening();
    _isDetecting = false;
    _onMotionEvent = null;

    debugPrint(
      '[AccidentMotion] Stopped. '
      'Rotations: $_totalRotations, '
      'Combined accidents: $_totalAccidents, '
      'High-confidence: $_totalHighConfidence, '
      'Rejected incidents: $_totalRejectedIncidents, '
      'Filtered impacts: $_filteredImpacts, '
      'Filtered rotations: $_filteredRotations, '
      'Expired impacts: $_expiredImpacts, '
      'Expired rotations: $_expiredRotations, '
      'Suppressed (cooldown): $_suppressedDuringCooldown.',
    );
  }

  /// Releases all resources.
  void dispose() {
    stopDetection();
    _eventController.close();
    _impactService.dispose();
    _gyroscopeService.dispose();
    debugPrint('[AccidentMotion] Disposed.');
  }

  /// Resets all cooldowns, allowing immediate re-detection.
  void resetCooldowns() {
    _lastRotationTime = DateTime.fromMillisecondsSinceEpoch(0);
    _lastAccidentTime = DateTime.fromMillisecondsSinceEpoch(0);
    _lastHighConfidenceTime = DateTime.fromMillisecondsSinceEpoch(0);
    _impactService.resetCooldown();
    _clearRecentImpact();
    _clearRecentRotation();
    _resetIncident();
    debugPrint('[AccidentMotion] All cooldowns reset '
        '(including high-confidence cooldown).');
  }

  /// Engages the high-confidence cooldown so no new
  /// [highConfidenceAccidentDetected] event can be emitted for
  /// [ConfidenceAnalysisConfig.highConfidenceCooldown] seconds.
  ///
  /// Also clears any in-progress incident analysis and pending
  /// impact/rotation events so stale sensor data from the same
  /// physical incident cannot re-trigger.
  ///
  /// Call this after the user dismisses/cancels a sensor-triggered
  /// SOS countdown.
  void enforceHighConfidenceCooldown() {
    final now = DateTime.now();
    _lastHighConfidenceTime = now;
    // Also engage rotation and accident cooldowns so individual sensor
    // events from the same physical incident are suppressed immediately.
    _lastRotationTime = now;
    _lastAccidentTime = now;
    _clearRecentImpact();
    _clearRecentRotation();
    _resetIncident();
    // Reset the underlying impact service cooldown to suppress residual
    // accelerometer spikes from the same physical event.
    _impactService.resetCooldown();
    debugPrint(
      '[AccidentMotion] High-confidence cooldown ENFORCED — '
      'no new events for '
      '${confidenceConfig.highConfidenceCooldown.inSeconds}s. '
      'All sub-cooldowns synchronized.',
    );
  }

  /// Returns `true` if the high-confidence cooldown is currently active,
  /// meaning a recent accident was already detected and we should not
  /// process new sensor events as potential incidents.
  bool get _isHighConfidenceCooldownActive {
    final now = DateTime.now();
    return now.difference(_lastHighConfidenceTime) <
        confidenceConfig.highConfidenceCooldown;
  }

  // ── Recent-event management with auto-expiry ────────────────────────────

  /// Records a recent impact and starts an expiry timer.
  /// If no matching rotation arrives within [combinationWindow], the
  /// impact is automatically cleared as stale.
  void _setRecentImpact(ImpactEvent event) {
    _recentImpact = event;
    _impactExpiryTimer?.cancel();
    _impactExpiryTimer = Timer(combinationWindow, () {
      if (_recentImpact != null) {
        _expiredImpacts++;
        debugPrint(
          '[AccidentMotion] ⌛ Impact EXPIRED — no matching rotation within '
          '${combinationWindow.inMilliseconds}ms window. '
          'Impact was at ${_recentImpact!.detectedAt.toIso8601String()}, '
          'mag=${_recentImpact!.magnitude.toStringAsFixed(1)} m/s² '
          '(#$_expiredImpacts expired total)',
        );
        _recentImpact = null;
      }
    });
  }

  /// Records a recent rotation and starts an expiry timer.
  void _setRecentRotation(GyroscopeReading reading, DateTime time) {
    _recentRotation = reading;
    _recentRotationTime = time;
    _rotationExpiryTimer?.cancel();
    _rotationExpiryTimer = Timer(combinationWindow, () {
      if (_recentRotation != null) {
        _expiredRotations++;
        debugPrint(
          '[AccidentMotion] ⌛ Rotation EXPIRED — no matching impact within '
          '${combinationWindow.inMilliseconds}ms window. '
          'Rotation was at ${_recentRotationTime?.toIso8601String()}, '
          'mag=${_recentRotation!.magnitude.toStringAsFixed(1)} rad/s '
          '(#$_expiredRotations expired total)',
        );
        _recentRotation = null;
        _recentRotationTime = null;
      }
    });
  }

  /// Clears a recent impact and cancels its expiry timer.
  void _clearRecentImpact() {
    _recentImpact = null;
    _impactExpiryTimer?.cancel();
    _impactExpiryTimer = null;
  }

  /// Clears a recent rotation and cancels its expiry timer.
  void _clearRecentRotation() {
    _recentRotation = null;
    _recentRotationTime = null;
    _rotationExpiryTimer?.cancel();
    _rotationExpiryTimer = null;
  }

  // ── Buffer management ───────────────────────────────────────────────────

  /// Feeds raw accelerometer readings into the rolling buffer.
  void _onAccelBufferReading(AccelerometerReading reading) {
    final now = reading.timestamp;
    _accelBuffer.add(_TimestampedValue(now, reading.magnitude));
    _pruneBuffer(_accelBuffer, now);
  }

  /// Feeds gyroscope readings into the rolling buffer (called from the
  /// existing _onGyroscopeReading handler).
  void _addGyroToBuffer(GyroscopeReading reading) {
    final now = reading.timestamp;
    _gyroBuffer.add(_TimestampedValue(now, reading.magnitude));
    _pruneBuffer(_gyroBuffer, now);
  }

  /// Removes entries older than [filterConfig.bufferDuration].
  void _pruneBuffer(Queue<_TimestampedValue> buffer, DateTime now) {
    while (buffer.isNotEmpty &&
        now.difference(buffer.first.time) > filterConfig.bufferDuration) {
      buffer.removeFirst();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FALSE-POSITIVE FILTER LOGIC
  // ═══════════════════════════════════════════════════════════════════════

  /// Returns the name of the filter that caught this impact as a false
  /// positive, or `null` if the impact should be treated as genuine.
  String? _filterImpact(ImpactEvent event) {
    final accelMag = event.magnitude;
    final currentGyro = _currentGyroMagnitude();
    final avgAccel = _averageAccelMagnitude();

    // ── Walking filter ──────────────────────────────────────────────────
    // Walking produces rhythmic accel oscillations in the 8–16 m/s² range.
    // If the recent average is in walking range AND the spike is modest
    // AND rotation is low, it's just walking.
    if (avgAccel >= filterConfig.walkingAccelMin &&
        avgAccel <= filterConfig.walkingAccelMax &&
        accelMag < filterConfig.handShakeAccelMax &&
        currentGyro < filterConfig.walkingGyroMax) {
      return 'walking (avg accel ${avgAccel.toStringAsFixed(1)} m/s², '
          'spike ${accelMag.toStringAsFixed(1)}, '
          'gyro ${currentGyro.toStringAsFixed(1)} rad/s)';
    }

    // ── Hand-shake filter ───────────────────────────────────────────────
    // A small hand shake or jostle produces brief spikes under 22 m/s²
    // without significant rotation.
    if (accelMag < filterConfig.handShakeAccelMax &&
        currentGyro < filterConfig.handShakeGyroMax) {
      return 'hand shake (accel ${accelMag.toStringAsFixed(1)} m/s², '
          'gyro ${currentGyro.toStringAsFixed(1)} rad/s)';
    }

    // ── Phone pickup filter ─────────────────────────────────────────────
    // Picking up the phone causes a gradual acceleration increase (not a
    // sharp spike) with moderate rotation. If the spike is under 18 m/s²
    // and rotation is modest, it's a pickup.
    if (accelMag < filterConfig.pickupAccelMax &&
        currentGyro < filterConfig.pickupGyroMax &&
        currentGyro > 0.5) {
      return 'phone pickup (accel ${accelMag.toStringAsFixed(1)} m/s², '
          'gyro ${currentGyro.toStringAsFixed(1)} rad/s)';
    }

    // ── Gentle placement filter ─────────────────────────────────────────
    // Placing the phone down produces a brief bump that quickly settles
    // back to gravity, with very little rotation.
    if (accelMag < filterConfig.gentlePlaceAccelMax &&
        currentGyro < filterConfig.gentlePlaceGyroMax &&
        _accelSettledRecently()) {
      return 'gentle placement (accel ${accelMag.toStringAsFixed(1)} m/s², '
          'gyro ${currentGyro.toStringAsFixed(1)} rad/s, settled)';
    }

    // No filter matched — this is a genuine impact.
    return null;
  }

  /// Returns the name of the filter that caught this rotation as a false
  /// positive, or `null` if the rotation should be treated as genuine.
  String? _filterRotation(GyroscopeReading reading) {
    final gyroMag = reading.magnitude;
    final currentAccel = _currentAccelMagnitude();

    // ── Normal rotation filter ──────────────────────────────────────────
    // If the phone is just being rotated in hand, accel stays near gravity
    // (~9.8 m/s²) while gyro is moderate. No real impact happening.
    if (currentAccel < filterConfig.normalRotationAccelMax &&
        gyroMag < filterConfig.normalRotationGyroMax) {
      return 'normal rotation (accel ${currentAccel.toStringAsFixed(1)} m/s², '
          'gyro ${gyroMag.toStringAsFixed(1)} rad/s)';
    }

    // ── Phone pickup rotation filter ────────────────────────────────────
    // Picking up the phone causes moderate rotation with low acceleration.
    if (currentAccel < filterConfig.pickupAccelMax &&
        gyroMag < filterConfig.pickupGyroMax) {
      return 'pickup rotation (accel ${currentAccel.toStringAsFixed(1)} m/s², '
          'gyro ${gyroMag.toStringAsFixed(1)} rad/s)';
    }

    // No filter matched — this is a genuine abnormal rotation.
    return null;
  }

  // ── Buffer analysis helpers ─────────────────────────────────────────────

  /// Average accelerometer magnitude over the buffer window.
  double _averageAccelMagnitude() {
    if (_accelBuffer.isEmpty) return 9.81; // assume gravity at rest
    double sum = 0;
    for (final entry in _accelBuffer) {
      sum += entry.value;
    }
    return sum / _accelBuffer.length;
  }

  /// Current (most recent) accelerometer magnitude.
  double _currentAccelMagnitude() {
    if (_accelBuffer.isNotEmpty) return _accelBuffer.last.value;
    final latest = _impactService.accelerometerService.latestReading;
    return latest?.magnitude ?? 9.81;
  }

  /// Current (most recent) gyroscope magnitude.
  double _currentGyroMagnitude() {
    if (_gyroBuffer.isNotEmpty) return _gyroBuffer.last.value;
    final latest = _gyroscopeService.latestReading;
    return latest?.magnitude ?? 0.0;
  }

  /// Returns `true` if recent accel readings have settled near gravity
  /// (~9.8 m/s²), indicating the phone was placed down and is now still.
  bool _accelSettledRecently() {
    if (_accelBuffer.length < 3) return false;

    // Check the last few readings — if they're all within ±1.5 of gravity,
    // the phone has settled.
    const gravity = 9.81;
    const tolerance = 1.5;
    int settledCount = 0;
    final recent = _accelBuffer.toList().reversed.take(5);
    for (final entry in recent) {
      if ((entry.value - gravity).abs() < tolerance) {
        settledCount++;
      }
    }
    return settledCount >= 3;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONFIDENCE ANALYSIS — INCIDENT LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════

  /// Starts a new incident analysis window.
  ///
  /// Called when the first significant sensor event (impact, rotation, or
  /// combined accident) arrives and no incident is currently active.
  void _startIncident(DateTime triggerTime) {
    _incidentActive = true;
    _incidentStartTime = triggerTime;
    _incidentEvidence.clear();
    _incidentStrongestImpact = null;
    _incidentStrongestRotation = null;

    // Set a hard deadline for the incident window — forces evaluation
    // even if events keep arriving.
    _incidentWindowTimer?.cancel();
    _incidentWindowTimer = Timer(confidenceConfig.incidentWindow, () {
      if (_incidentActive) {
        debugPrint(
          '[AccidentMotion] 📋 Incident window EXPIRED after '
          '${confidenceConfig.incidentWindow.inSeconds}s — '
          'force-evaluating with '
          '${_incidentEvidence.length} evidence entries.',
        );
        _evaluateIncident();
      }
    });

    debugPrint('');
    debugPrint(
        '┌──────────────────────────────────────────────────────────┐');
    debugPrint('│  📋 INCIDENT ANALYSIS STARTED');
    debugPrint('│  Trigger time : ${triggerTime.toIso8601String()}');
    debugPrint('│  Window       : '
        '${confidenceConfig.incidentWindow.inSeconds}s');
    debugPrint('│  Observation  : '
        '${confidenceConfig.postImpactObservation.inSeconds}s '
        '(after last event)');
    debugPrint('│  Min score    : '
        '${confidenceConfig.minConfidenceScore.toStringAsFixed(1)}');
    debugPrint(
        '└──────────────────────────────────────────────────────────┘');
    debugPrint('');
  }

  /// Adds a piece of evidence to the current incident.
  ///
  /// If no incident is active, starts one. If the incident window has
  /// expired, the evidence is ignored.
  void _addEvidence({
    required String type,
    required double score,
    required String description,
    double? magnitude,
  }) {
    final now = DateTime.now();

    // Start incident if not already active
    if (!_incidentActive) {
      _startIncident(now);
    }

    // Check if we've exceeded the incident window
    if (_incidentStartTime != null &&
        now.difference(_incidentStartTime!) >
            confidenceConfig.incidentWindow) {
      debugPrint(
        '[AccidentMotion] 📋 Evidence arrived after incident window — '
        'ignoring: $type',
      );
      return;
    }

    final evidence = _IncidentEvidence(
      type: type,
      timestamp: now,
      score: score,
      description: description,
      magnitude: magnitude,
    );
    _incidentEvidence.add(evidence);

    debugPrint(
      '[AccidentMotion] 📋 Evidence added: $type '
      'score=${score.toStringAsFixed(1)} '
      '${magnitude != null ? "mag=${magnitude.toStringAsFixed(1)} " : ""}'
      '(total evidence: ${_incidentEvidence.length}, '
      'running score: ${_runningScore().toStringAsFixed(1)})',
    );

    // Reset observation timer — extends the quiet period after each
    // new piece of evidence.
    _startPostImpactObservation();
  }

  /// Starts (or restarts) the post-impact observation timer.
  ///
  /// When this timer fires (no new evidence for [postImpactObservation]),
  /// the incident is evaluated.
  void _startPostImpactObservation() {
    _observationTimer?.cancel();
    _observationTimer =
        Timer(confidenceConfig.postImpactObservation, () {
      if (_incidentActive) {
        debugPrint(
          '[AccidentMotion] 📋 Post-impact observation ended '
          '(${confidenceConfig.postImpactObservation.inSeconds}s quiet) '
          '— evaluating incident.',
        );
        _evaluateIncident();
      }
    });
  }

  /// Evaluates the collected evidence and decides whether to emit
  /// [highConfidenceAccidentDetected] or reject the incident.
  void _evaluateIncident() {
    if (!_incidentActive || _incidentEvidence.isEmpty) {
      _resetIncident();
      return;
    }

    final now = DateTime.now();

    // ── Sum base evidence scores ──────────────────────────────────────
    double totalScore = _runningScore();

    debugPrint('');
    debugPrint(
        '╔══════════════════════════════════════════════════════════╗');
    debugPrint('║  📋 INCIDENT EVALUATION');
    debugPrint(
        '╠══════════════════════════════════════════════════════════╣');
    debugPrint('║  Evidence count : ${_incidentEvidence.length}');
    debugPrint('║  Base score     : ${totalScore.toStringAsFixed(2)}');

    // Log each evidence entry
    for (int i = 0; i < _incidentEvidence.length; i++) {
      final e = _incidentEvidence[i];
      debugPrint(
          '║    ${i + 1}. ${e.type}: '
          'score=${e.score.toStringAsFixed(1)}'
          '${e.magnitude != null ? ", mag=${e.magnitude!.toStringAsFixed(1)}" : ""}'
          ' — ${e.description}');
    }

    // ── Post-impact stability analysis ────────────────────────────────
    final isStable = _isPhoneStable();

    if (isStable) {
      debugPrint(
          '║  Stability      : STABLE (phone settled — likely drop)');
      debugPrint('║  Penalty        : '
          '${confidenceConfig.postImpactStabilityPenalty.toStringAsFixed(1)}');
      totalScore += confidenceConfig.postImpactStabilityPenalty;
    } else {
      debugPrint(
          '║  Stability      : ABNORMAL (sustained erratic readings)');
      debugPrint('║  Bonus          : '
          '+${confidenceConfig.sustainedAbnormalityBonus.toStringAsFixed(1)}');
      totalScore += confidenceConfig.sustainedAbnormalityBonus;
    }

    debugPrint(
        '║  Final score    : ${totalScore.toStringAsFixed(2)}');
    debugPrint('║  Threshold      : '
        '${confidenceConfig.minConfidenceScore.toStringAsFixed(1)}');

    // ── Decision ──────────────────────────────────────────────────────
    if (totalScore < confidenceConfig.minConfidenceScore) {
      _totalRejectedIncidents++;
      debugPrint(
          '║  Decision       : ❌ REJECTED (score below threshold)');
      debugPrint('║  Total rejected : $_totalRejectedIncidents');
      debugPrint(
          '╚══════════════════════════════════════════════════════════╝');
      debugPrint('');
      _resetIncident();
      return;
    }

    // ── Cooldown check ────────────────────────────────────────────────
    if (now.difference(_lastHighConfidenceTime) <
        confidenceConfig.highConfidenceCooldown) {
      debugPrint(
          '║  Decision       : ⏳ SUPPRESSED (cooldown active)');
      debugPrint('║  Cooldown       : '
          '${confidenceConfig.highConfidenceCooldown.inSeconds}s');
      debugPrint('║  Last at        : '
          '${_lastHighConfidenceTime.toIso8601String()}');
      debugPrint(
          '╚══════════════════════════════════════════════════════════╝');
      debugPrint('');
      _resetIncident();
      return;
    }

    // ── HIGH-CONFIDENCE ACCIDENT DETECTED ─────────────────────────────
    _lastHighConfidenceTime = now;
    _totalHighConfidence++;

    // Engage all sub-cooldowns to prevent duplicate events from the
    // same physical incident. This ensures that residual sensor spikes
    // (common after a crash) don't start a new incident window.
    _lastRotationTime = now;
    _lastAccidentTime = now;
    _impactService.resetCooldown();

    debugPrint(
        '║  Decision       : 🚨 HIGH-CONFIDENCE ACCIDENT');
    debugPrint(
        '║  Confidence     : ${totalScore.toStringAsFixed(2)}');
    debugPrint('║  Total emitted  : $_totalHighConfidence');
    debugPrint('║  Cooldown       : '
        '${confidenceConfig.highConfidenceCooldown.inSeconds}s '
        'until next (all sub-cooldowns synchronized)');
    debugPrint('║  ✅ SOS auto-trigger CONNECTED via eventStream');
    debugPrint(
        '╚══════════════════════════════════════════════════════════╝');
    debugPrint('');

    final motionEvent = MotionEvent(
      type: MotionEventType.highConfidenceAccidentDetected,
      detectedAt: now,
      impactEvent: _incidentStrongestImpact,
      rotationReading: _incidentStrongestRotation,
      rotationMagnitude: _incidentStrongestRotation?.magnitude,
      confidenceScore: totalScore,
      message: 'High-confidence accident: '
          'score=${totalScore.toStringAsFixed(1)}, '
          'evidence=${_incidentEvidence.length} entries, '
          '${isStable ? "post-stable" : "sustained-abnormal"}',
    );
    _emit(motionEvent);

    // Reset incident state and clear any pending events so residual
    // sensor data cannot re-trigger.
    _resetIncident();
    _clearRecentImpact();
    _clearRecentRotation();
  }

  /// Computes the running score from all collected evidence.
  double _runningScore() {
    double score = 0;
    for (final e in _incidentEvidence) {
      score += e.score;
    }
    return score;
  }

  /// Checks whether the phone has stabilized (readings near gravity,
  /// low rotation) — indicative of a phone drop rather than an accident.
  bool _isPhoneStable() {
    final cfg = confidenceConfig;
    const gravity = 9.81;

    // Check recent accelerometer readings
    int accelStable = 0;
    int accelTotal = 0;
    final recentAccel =
        _accelBuffer.toList().reversed.take(cfg.stabilityCheckSamples);
    for (final entry in recentAccel) {
      accelTotal++;
      if ((entry.value - gravity).abs() < cfg.stabilityAccelTolerance) {
        accelStable++;
      }
    }

    // Check recent gyroscope readings
    int gyroStable = 0;
    int gyroTotal = 0;
    final recentGyro =
        _gyroBuffer.toList().reversed.take(cfg.stabilityCheckSamples);
    for (final entry in recentGyro) {
      gyroTotal++;
      if (entry.value < cfg.stabilityGyroMax) {
        gyroStable++;
      }
    }

    // Need samples from both sensors to make a determination
    if (accelTotal == 0 || gyroTotal == 0) {
      debugPrint(
        '[AccidentMotion] 📋 Stability check: insufficient data '
        '(accel=$accelTotal, gyro=$gyroTotal samples) — defaulting to '
        'NOT stable',
      );
      return false;
    }

    final accelFraction = accelStable / accelTotal;
    final gyroFraction = gyroStable / gyroTotal;

    debugPrint(
      '[AccidentMotion] 📋 Stability check: '
      'accel ${(accelFraction * 100).toStringAsFixed(0)}% stable '
      '($accelStable/$accelTotal within '
      '±${cfg.stabilityAccelTolerance.toStringAsFixed(1)} m/s²), '
      'gyro ${(gyroFraction * 100).toStringAsFixed(0)}% stable '
      '($gyroStable/$gyroTotal '
      '< ${cfg.stabilityGyroMax.toStringAsFixed(1)} rad/s), '
      'need ${(cfg.stabilityMinStableFraction * 100).toStringAsFixed(0)}%',
    );

    // Both accel and gyro must show stability above the threshold
    return accelFraction >= cfg.stabilityMinStableFraction &&
        gyroFraction >= cfg.stabilityMinStableFraction;
  }

  /// Clears all incident analysis state and cancels timers.
  void _resetIncident() {
    _incidentActive = false;
    _incidentStartTime = null;
    _incidentEvidence.clear();
    _incidentStrongestImpact = null;
    _incidentStrongestRotation = null;
    _observationTimer?.cancel();
    _observationTimer = null;
    _incidentWindowTimer?.cancel();
    _incidentWindowTimer = null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EVENT HANDLERS
  // ═══════════════════════════════════════════════════════════════════════

  // ── Impact handling (from ImpactDetectionService) ───────────────────────

  void _onImpactDetected(ImpactEvent event) {
    // ── High-confidence cooldown guard ──────────────────────────────────
    // If a high-confidence accident was recently detected, suppress all
    // new impact events to prevent duplicate triggers from the same
    // physical incident. Sensor monitoring stays active for buffer data.
    if (_isHighConfidenceCooldownActive) {
      _suppressedDuringCooldown++;
      debugPrint(
        '[AccidentMotion] ⏳ Impact SUPPRESSED — high-confidence cooldown '
        'active (${confidenceConfig.highConfidenceCooldown.inSeconds}s). '
        'mag=${event.magnitude.toStringAsFixed(1)} m/s² '
        '(#$_suppressedDuringCooldown suppressed total)',
      );
      return;
    }

    // ── Run false-positive filter ───────────────────────────────────────
    final filterReason = _filterImpact(event);
    if (filterReason != null) {
      _filteredImpacts++;
      debugPrint(
        '[AccidentMotion] 🚫 Impact FILTERED as: $filterReason '
        '(#$_filteredImpacts filtered total)',
      );
      return;
    }

    // Record impact with auto-expiry timer
    _setRecentImpact(event);

    // Emit suddenImpactDetected event
    final motionEvent = MotionEvent(
      type: MotionEventType.suddenImpactDetected,
      detectedAt: event.detectedAt,
      impactEvent: event,
      message:
          'Sudden impact: ${event.magnitude.toStringAsFixed(1)} m/s² '
          '(~${(event.magnitude / 9.81).toStringAsFixed(1)}G)',
    );
    _emit(motionEvent);

    debugPrint(
      '[AccidentMotion] 💥 IMPACT passed filter — '
      'mag=${event.magnitude.toStringAsFixed(2)} m/s², '
      'timestamp=${event.detectedAt.toIso8601String()}, '
      'window=${combinationWindow.inMilliseconds}ms '
      '(waiting for rotation...)',
    );

    // Check for time-window combination with recent rotation
    _checkCombination(event.detectedAt);

    // ── Feed into confidence analysis ──────────────────────────────────
    final impactMag = event.magnitude;
    final isStrong =
        impactMag >= confidenceConfig.strongImpactThreshold;
    _addEvidence(
      type: 'impact',
      score: isStrong
          ? confidenceConfig.impactScore * 1.5
          : confidenceConfig.impactScore,
      description:
          'Impact ${impactMag.toStringAsFixed(1)} m/s²'
          '${isStrong ? " (STRONG ≥${confidenceConfig.strongImpactThreshold.toStringAsFixed(0)})" : ""}',
      magnitude: impactMag,
    );
    // Track strongest impact for high-confidence event reporting
    if (_incidentStrongestImpact == null ||
        impactMag > _incidentStrongestImpact!.magnitude) {
      _incidentStrongestImpact = event;
    }
  }

  // ── Gyroscope handling ──────────────────────────────────────────────────

  void _onGyroscopeReading(GyroscopeReading reading) {
    final now = reading.timestamp;

    // Always feed into the rolling buffer
    _addGyroToBuffer(reading);

    // ── Periodic debug logging (throttled) ──────────────────────────────
    if (debugLogIntervalMs > 0 &&
        now.difference(_lastGyroLogTime).inMilliseconds >=
            debugLogIntervalMs) {
      _lastGyroLogTime = now;
      debugPrint(
        '[AccidentMotion] 🌀 Gyro: '
        'x=${reading.x.toStringAsFixed(2)}, '
        'y=${reading.y.toStringAsFixed(2)}, '
        'z=${reading.z.toStringAsFixed(2)} '
        '| mag=${reading.magnitude.toStringAsFixed(2)} rad/s '
        '(${reading.intensityLabel}) '
        '| threshold: ${rotationThreshold.toStringAsFixed(1)}',
      );
    }

    // ── Threshold check ─────────────────────────────────────────────────
    if (reading.magnitude < rotationThreshold) {
      // Log notable-but-below-threshold readings for debugging.
      // Only log magnitudes above 5.0 rad/s (beyond normal hand movement)
      // to avoid flooding the console with idle/walking noise.
      if (reading.magnitude > 5.0) {
        debugPrint(
          '[AccidentMotion] 🔽 Rotation IGNORED — below threshold: '
          'mag=${reading.magnitude.toStringAsFixed(2)} rad/s '
          '(threshold: ${rotationThreshold.toStringAsFixed(1)} rad/s) '
          '| x=${reading.x.toStringAsFixed(2)}, '
          'y=${reading.y.toStringAsFixed(2)}, '
          'z=${reading.z.toStringAsFixed(2)}',
        );
      }
      return;
    }

    // ── High-confidence cooldown guard ──────────────────────────────────
    // Suppress rotation events during cooldown to prevent duplicate
    // triggers from the same physical incident.
    if (_isHighConfidenceCooldownActive) {
      _suppressedDuringCooldown++;
      debugPrint(
        '[AccidentMotion] ⏳ Rotation SUPPRESSED — high-confidence cooldown '
        'active (${confidenceConfig.highConfidenceCooldown.inSeconds}s). '
        'mag=${reading.magnitude.toStringAsFixed(1)} rad/s '
        '(#$_suppressedDuringCooldown suppressed total)',
      );
      return;
    }

    // ── Cooldown check ──────────────────────────────────────────────────
    if (now.difference(_lastRotationTime) < rotationCooldown) {
      debugPrint(
        '[AccidentMotion] ⏳ Rotation spike '
        '${reading.magnitude.toStringAsFixed(1)} rad/s suppressed — '
        'cooldown active (${rotationCooldown.inSeconds}s window).',
      );
      return;
    }

    // ── Run false-positive filter ───────────────────────────────────────
    final filterReason = _filterRotation(reading);
    if (filterReason != null) {
      _filteredRotations++;
      debugPrint(
        '[AccidentMotion] 🚫 Rotation FILTERED as: $filterReason '
        '(#$_filteredRotations filtered total)',
      );
      return;
    }

    // ── ABNORMAL ROTATION DETECTED ──────────────────────────────────────
    _lastRotationTime = now;
    _totalRotations++;

    // Record rotation with auto-expiry timer
    _setRecentRotation(reading, now);

    // Show whether a pending impact exists for potential combination
    final pendingImpact = _recentImpact != null
        ? 'pending impact at ${_recentImpact!.detectedAt.toIso8601String()} '
          '(${now.difference(_recentImpact!.detectedAt).inMilliseconds}ms ago)'
        : 'no pending impact';

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────────────────────┐');
    debugPrint('│  🔄 ABNORMAL ROTATION DETECTED  #$_totalRotations');
    debugPrint('│  Magnitude : '
        '${reading.magnitude.toStringAsFixed(2)} rad/s');
    debugPrint('│  Threshold : '
        '${rotationThreshold.toStringAsFixed(1)} rad/s');
    debugPrint('│  Raw values: '
        'x=${reading.x.toStringAsFixed(2)}, '
        'y=${reading.y.toStringAsFixed(2)}, '
        'z=${reading.z.toStringAsFixed(2)}');
    debugPrint('│  Timestamp : ${now.toIso8601String()}');
    debugPrint('│  Accel now : '
        '${_currentAccelMagnitude().toStringAsFixed(1)} m/s²');
    debugPrint('│  Correlator: $pendingImpact');
    debugPrint('└──────────────────────────────────────────────────────────┘');
    debugPrint('');

    final motionEvent = MotionEvent(
      type: MotionEventType.abnormalRotationDetected,
      detectedAt: now,
      rotationReading: reading,
      rotationMagnitude: reading.magnitude,
      message:
          'Abnormal rotation: ${reading.magnitude.toStringAsFixed(1)} rad/s',
    );
    _emit(motionEvent);

    // Check for time-window combination with recent impact
    _checkCombination(now);

    // ── Feed into confidence analysis ──────────────────────────────────
    final isStrong =
        reading.magnitude >= confidenceConfig.strongRotationThreshold;
    _addEvidence(
      type: 'rotation',
      score: isStrong
          ? confidenceConfig.rotationScore * 1.5
          : confidenceConfig.rotationScore,
      description:
          'Rotation ${reading.magnitude.toStringAsFixed(1)} rad/s'
          '${isStrong ? " (STRONG ≥${confidenceConfig.strongRotationThreshold.toStringAsFixed(0)})" : ""}',
      magnitude: reading.magnitude,
    );
    // Track strongest rotation for high-confidence event reporting
    if (_incidentStrongestRotation == null ||
        reading.magnitude > _incidentStrongestRotation!.magnitude) {
      _incidentStrongestRotation = reading;
    }
  }

  // ── Combination logic (time-window correlation) ─────────────────────────

  /// Checks whether a recent impact AND a recent rotation event both
  /// occurred within [combinationWindow].
  ///
  /// This is called immediately after each new impact or rotation event.
  /// The expiry timers ensure stale events are auto-cleared, so by the
  /// time this runs both events are guaranteed to be fresh if they exist.
  void _checkCombination(DateTime now) {
    if (_recentImpact == null || _recentRotationTime == null) {
      // Only one event exists — log what we're waiting for.
      if (_recentImpact != null) {
        debugPrint(
          '[AccidentMotion] ⏱ Impact recorded at '
          '${_recentImpact!.detectedAt.toIso8601String()} — '
          'waiting for rotation within '
          '${combinationWindow.inMilliseconds}ms...',
        );
      } else if (_recentRotationTime != null) {
        debugPrint(
          '[AccidentMotion] ⏱ Rotation recorded at '
          '${_recentRotationTime!.toIso8601String()} — '
          'waiting for impact within '
          '${combinationWindow.inMilliseconds}ms...',
        );
      }
      return;
    }

    // Both events exist — calculate the time gap.
    final impactTime = _recentImpact!.detectedAt;
    final rotationTime = _recentRotationTime!;
    final gap = impactTime.difference(rotationTime).abs();

    debugPrint(
      '[AccidentMotion] 🔗 Correlation check: '
      'impact at ${impactTime.toIso8601String()} '
      '+ rotation at ${rotationTime.toIso8601String()} '
      '= gap ${gap.inMilliseconds}ms '
      '(window: ${combinationWindow.inMilliseconds}ms)',
    );

    if (gap > combinationWindow) {
      debugPrint(
        '[AccidentMotion] ❌ Events too far apart — '
        '${gap.inMilliseconds}ms > '
        '${combinationWindow.inMilliseconds}ms window. '
        'NOT combining.',
      );
      return;
    }

    // Check accident cooldown
    if (now.difference(_lastAccidentTime) < accidentCooldown) {
      debugPrint(
        '[AccidentMotion] ⏳ Combined accident suppressed — '
        'cooldown active (${accidentCooldown.inSeconds}s window, '
        'last at ${_lastAccidentTime.toIso8601String()}).',
      );
      return;
    }

    // ── POSSIBLE ACCIDENT MOTION DETECTED ───────────────────────────────
    _lastAccidentTime = now;
    _totalAccidents++;

    final impact = _recentImpact!;
    final rotation = _recentRotation!;

    // Clear both events AND cancel their expiry timers so they can't
    // trigger another combination.
    _clearRecentImpact();
    _clearRecentRotation();

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════╗');
    debugPrint('║  🚨 POSSIBLE ACCIDENT MOTION DETECTED  '
        '#$_totalAccidents');
    debugPrint('╠══════════════════════════════════════════════════════════╣');
    debugPrint('║  Impact mag   : '
        '${impact.magnitude.toStringAsFixed(2)} m/s² '
        '(~${(impact.magnitude / 9.81).toStringAsFixed(1)}G)');
    debugPrint('║  Impact time  : '
        '${impact.detectedAt.toIso8601String()}');
    debugPrint('║  Rotation mag : '
        '${rotation.magnitude.toStringAsFixed(2)} rad/s');
    debugPrint('║  Rotation time: '
        '${rotationTime.toIso8601String()}');
    debugPrint('║  Time gap     : ${gap.inMilliseconds}ms '
        '(window: ${combinationWindow.inMilliseconds}ms)');
    debugPrint('║  Cooldown     : ${accidentCooldown.inSeconds}s '
        'until next detection');
    debugPrint('║  Stats        : '
        '$_totalAccidents combined, '
        '$_expiredImpacts expired impacts, '
        '$_expiredRotations expired rotations');
    debugPrint('║  ✅ SOS auto-trigger CONNECTED via eventStream');
    debugPrint('╚══════════════════════════════════════════════════════════╝');
    debugPrint('');

    final motionEvent = MotionEvent(
      type: MotionEventType.possibleAccidentMotionDetected,
      detectedAt: now,
      impactEvent: impact,
      rotationReading: rotation,
      rotationMagnitude: rotation.magnitude,
      message:
          'Possible accident: impact '
          '${impact.magnitude.toStringAsFixed(1)} m/s² '
          'at ${impact.detectedAt.toIso8601String()} + rotation '
          '${rotation.magnitude.toStringAsFixed(1)} rad/s '
          'at ${rotationTime.toIso8601String()} '
          '(gap: ${gap.inMilliseconds}ms)',
    );
    _emit(motionEvent);

    // ── Feed combined-accident bonus into confidence analysis ──────────
    _addEvidence(
      type: 'combined',
      score: confidenceConfig.combinedAccidentScore,
      description: 'Combined impact+rotation correlation '
          '(gap: ${gap.inMilliseconds}ms)',
      magnitude: impact.magnitude,
    );
  }

  // ── Event emission ──────────────────────────────────────────────────────

  void _emit(MotionEvent event) {
    _lastEvent = event;

    if (!_eventController.isClosed) {
      _eventController.add(event);
    }

    _onMotionEvent?.call(event);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// A simple timestamped magnitude value for the rolling buffer.
class _TimestampedValue {
  const _TimestampedValue(this.time, this.value);
  final DateTime time;
  final double value;
}

/// A single piece of evidence collected during an incident analysis window.
class _IncidentEvidence {
  const _IncidentEvidence({
    required this.type,
    required this.timestamp,
    required this.score,
    required this.description,
    this.magnitude,
  });

  /// Evidence type label (e.g. 'impact', 'rotation', 'combined').
  final String type;

  /// When this evidence was recorded.
  final DateTime timestamp;

  /// Score contribution of this evidence.
  final double score;

  /// Human-readable description.
  final String description;

  /// Raw sensor magnitude (m/s² or rad/s), if applicable.
  final double? magnitude;
}
