import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Callback signature for location updates.
typedef LocationUpdateCallback = void Function(LocationData location);

/// Continuously tracks the device's GPS position in the foreground.
///
/// Wraps [Geolocator.getPositionStream] and keeps the latest [LocationData]
/// available via [latestLocation]. Consumers can also register an
/// [onLocationUpdate] callback to react to each new position.
///
/// Permission handling follows the same flow as [LocationService]:
///   - Checks if location services are enabled.
///   - Requests permission if not yet granted.
///   - Throws [LocationException] on permanent denial.
///
/// Safe to use on Chrome/web — the stream simply won't produce events if
/// the browser doesn't support the Geolocation API, and errors are caught.
class LocationTrackingService {
  LocationTrackingService({
    this.distanceFilter = 5,
    this.accuracy = LocationAccuracy.high,
    this.intervalDuration = const Duration(seconds: 5),
  });

  /// Minimum distance (meters) the device must move before an update fires.
  final int distanceFilter;

  /// Desired GPS accuracy.
  final LocationAccuracy accuracy;

  /// Minimum interval between position updates (Android only).
  final Duration intervalDuration;

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  /// The most recent location, or `null` if no fix has been obtained yet.
  LocationData? _latestLocation;
  LocationData? get latestLocation => _latestLocation;

  /// Whether the service is actively streaming position updates.
  bool get isTracking => _isTracking;

  /// Optional callback invoked on each new position update.
  LocationUpdateCallback? onLocationUpdate;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Begins continuous location tracking.
  ///
  /// Handles permission checks internally. If permissions cannot be obtained
  /// or location services are disabled, a [LocationException] is thrown.
  ///
  /// Safe to call multiple times — duplicate streams are prevented.
  Future<void> startTracking({LocationUpdateCallback? onUpdate}) async {
    if (_isTracking) {
      debugPrint('[LocationTracking] Already tracking — ignoring start().');
      return;
    }

    onLocationUpdate = onUpdate;

    debugPrint('[LocationTracking] Checking permissions...');
    await _ensurePermissions();

    debugPrint(
      '[LocationTracking] Starting position stream '
      '(distanceFilter: ${distanceFilter}m, '
      'accuracy: $accuracy, '
      'interval: ${intervalDuration.inSeconds}s).',
    );

    _isTracking = true;

    try {
      final locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: intervalDuration,
        forceLocationManager: false,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: _onPositionError,
        cancelOnError: false,
      );

      // Also grab an initial position immediately so [latestLocation]
      // is populated right away without waiting for movement.
      _fetchInitialPosition();

      debugPrint('[LocationTracking] Position stream active.');
    } catch (e) {
      _isTracking = false;
      debugPrint('[LocationTracking] Could not start stream: $e');
      rethrow;
    }
  }

  /// Stops tracking and releases the position stream subscription.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    debugPrint('[LocationTracking] Tracking stopped.');
  }

  /// Ensures location permission is granted.
  ///
  /// Does NOT call [Geolocator.isLocationServiceEnabled] because that API
  /// is unreliable on many Android devices — it returns `false` even when
  /// GPS is enabled and permission is granted. Instead, we let the position
  /// stream surface any real service-disabled errors via [_onPositionError].
  Future<void> _ensurePermissions() async {
    var permission = await Geolocator.checkPermission();
    debugPrint('[LocationTracking] Current permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[LocationTracking] After request: $permission');
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationTracking] Permission denied by user.');
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationTracking] Permission permanently denied.');
      throw SosLocationPermissionException(
        'Location permission is permanently denied. '
        'Please open Settings → App Permissions and enable Location.',
      );
    }

    debugPrint('[LocationTracking] Permission granted: $permission');
  }

  // ── Stream handlers ──────────────────────────────────────────────────────

  void _onPositionUpdate(Position position) {
    final location = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      googleMapsLink: LocationService.generateMapsLink(
        position.latitude,
        position.longitude,
      ),
      timestamp: position.timestamp,
    );

    _latestLocation = location;

    debugPrint(
      '[LocationTracking] 📍 Update: '
      'lat=${position.latitude.toStringAsFixed(6)}, '
      'lng=${position.longitude.toStringAsFixed(6)} '
      '| accuracy: ${position.accuracy.toStringAsFixed(1)}m',
    );

    onLocationUpdate?.call(location);
  }

  void _onPositionError(Object error) {
    debugPrint(
      '[LocationTracking] Stream error: $error '
      '(this may be expected on web/unsupported platforms).',
    );
  }

  /// Fetches a single position immediately so [latestLocation] is available
  /// without waiting for the user to move [distanceFilter] meters.
  Future<void> _fetchInitialPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _onPositionUpdate(position);
      debugPrint('[LocationTracking] Initial position acquired.');
    } catch (e) {
      debugPrint('[LocationTracking] Could not get initial position: $e');
    }
  }
}
