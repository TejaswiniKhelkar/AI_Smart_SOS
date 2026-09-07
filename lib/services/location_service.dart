import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Enhanced location service providing GPS position, Google Maps links,
/// and structured location data for SOS alerts.
class LocationService {
  /// Returns the current device [Position] after handling permissions.
  ///
  /// Does NOT call [Geolocator.isLocationServiceEnabled] because that API
  /// is unreliable on many Android devices — it returns `false` even when
  /// GPS is enabled and permission is granted (a known issue with
  /// LocationManagerCompat on certain OEM ROMs and Android 12+).
  ///
  /// Instead, we request permission, then go straight to
  /// [Geolocator.getCurrentPosition]. If GPS is truly disabled the call
  /// will throw a platform-level [LocationServiceDisabledException] which
  /// we catch and wrap in [SosLocationServiceException].
  static Future<Position> getCurrentPosition() async {
    // ── Step 1: Handle permission ────────────────────────────────────────
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[LocationService] Current permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[LocationService] After request: $permission');
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationService] Permission permanently denied.');
      throw SosLocationPermissionException(
        'Location permission is permanently denied. '
        'Please open Settings → App Permissions and enable Location.',
      );
    }

    // ── Step 2: Fetch position directly (skip isLocationServiceEnabled) ─
    debugPrint('[LocationService] Fetching current position...');
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 30),
        ),
      );
      debugPrint(
        '[LocationService] ✅ Position: '
        '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}',
      );
      return position;
    } on LocationServiceDisabledException {
      // This is thrown by the platform when GPS is truly disabled.
      debugPrint('[LocationService] Platform: location service disabled.');
      throw SosLocationServiceException(
        'Location services are disabled. '
        'Please enable GPS in your device settings.',
      );
    }
  }

  /// Generates a Google Maps search link for the given coordinates.
  static String generateMapsLink(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  /// Convenience: fetches position and returns a Google Maps link.
  static Future<String> getLocationLink() async {
    final position = await getCurrentPosition();
    return generateMapsLink(position.latitude, position.longitude);
  }

  /// Returns structured location data: position + maps link.
  static Future<LocationData> getLocationData() async {
    final position = await getCurrentPosition();
    final link = generateMapsLink(position.latitude, position.longitude);
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      googleMapsLink: link,
      timestamp: position.timestamp,
    );
  }
}

/// Structured location result.
class LocationData {
  final double latitude;
  final double longitude;
  final String googleMapsLink;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.googleMapsLink,
    required this.timestamp,
  });
}

/// Base exception for location errors.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the device's location service (GPS/network) is disabled.
class SosLocationServiceException extends LocationException {
  SosLocationServiceException(super.message);
}

/// Thrown when location permission is permanently denied.
class SosLocationPermissionException extends LocationException {
  SosLocationPermissionException(super.message);
}