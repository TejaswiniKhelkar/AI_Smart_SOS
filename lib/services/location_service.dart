import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'network_service.dart';

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

    // ── Step 2: Try Last Known Position first to speed up load ─
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age.inMinutes < 5) {
          debugPrint('[LocationService] Using recent last known position (age: ${age.inSeconds}s)');
          return lastKnown;
        }
      }
    } catch (_) {
      // Ignore errors fetching last known position
    }

    // ── Step 3: Fetch current position if no recent cached position ─
    debugPrint('[LocationService] Fetching current position...');
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 15),
        ),
      );
      debugPrint(
        '[LocationService] ✅ Position: '
        '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}',
      );
      return position;
    } on TimeoutException {
      if (lastKnown != null) {
        debugPrint('[LocationService] Timeout fetching current position, falling back to older lastKnown.');
        return lastKnown;
      }
      throw LocationException('Unable to get your location. Please check GPS and try again.');
    } on LocationServiceDisabledException {
      if (lastKnown != null) {
        debugPrint('[LocationService] Location service disabled, falling back to lastKnown.');
        return lastKnown;
      }
      // This is thrown by the platform when GPS is truly disabled.
      debugPrint('[LocationService] Platform: location service disabled.');
      throw SosLocationServiceException(
        'Location services are disabled. '
        'Please enable GPS in your device settings.',
      );
    } catch (e) {
      if (lastKnown != null) return lastKnown;
      throw LocationException('Unable to get your location. Please check GPS and try again.');
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

  /// Reverse geocodes using OpenStreetMap Nominatim
  static Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    if (!NetworkService().isOnline) {
      return "Address unavailable offline";
    }
    
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'AI Smart SOS/1.0',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['address'] != null) {
          final address = data['address'];
          final parts = <String>[];
          
          if (address['road'] != null) parts.add(address['road']);
          if (address['suburb'] != null) parts.add(address['suburb']);
          if (address['city'] ?? address['town'] ?? address['village'] != null) {
            parts.add(address['city'] ?? address['town'] ?? address['village']);
          }
          
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return null;
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