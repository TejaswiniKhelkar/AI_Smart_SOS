import 'package:geolocator/geolocator.dart';

/// Enhanced location service providing GPS position, Google Maps links,
/// and structured location data for SOS alerts.
class LocationService {
  /// Returns the current device [Position] after handling permissions.
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permissions are permanently denied. '
        'Please enable them in Settings.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 30),
      ),
    );
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

/// Custom exception for location errors.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}