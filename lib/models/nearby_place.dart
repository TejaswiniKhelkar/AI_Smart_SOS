/// Type of emergency service place.
enum PlaceType { hospital, police, ambulance }

/// Represents a nearby emergency service location.
class NearbyPlace {
  final String name;
  final double latitude;
  final double longitude;
  final PlaceType type;
  final double distanceKm;
  final String? address;
  final String? phone;

  NearbyPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.distanceKm,
    this.address,
    this.phone,
  });

  /// Human-readable distance string.
  String get distanceText {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m away';
    }
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  /// Estimated travel time by car (~40 km/h avg in city).
  String get estimatedTravelTime {
    final minutes = (distanceKm / 40 * 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem > 0 ? '${hours}h ${rem}m' : '${hours}h';
  }

  /// Status badge text based on distance.
  String get statusLabel {
    if (distanceKm <= 2) return 'Nearby';
    if (distanceKm <= 10) return 'Available';
    return 'Reachable';
  }

  /// Whether this place is considered "nearby" (within 2 km).
  bool get isNearby => distanceKm <= 2;
}
