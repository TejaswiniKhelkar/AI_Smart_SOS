import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/nearby_place.dart';

/// Fetches nearby emergency places from the OpenStreetMap Overpass API.
/// No API key is required.
class NearbyPlacesService {
  static const String _overpassUrl =
      'https://overpass-api.de/api/interpreter';

  /// Search radius in meters (20 km).
  static const double _searchRadiusMeters = 20000;

  /// Fetches hospitals, police stations, and ambulance stations
  /// within [_searchRadiusMeters] of the given coordinates.
  static Future<List<NearbyPlace>> fetchNearbyPlaces(
    double lat,
    double lng,
  ) async {
    final query = '''
[out:json][timeout:25];
(
  nwr["amenity"="hospital"](around:$_searchRadiusMeters,$lat,$lng);
  nwr["amenity"="police"](around:$_searchRadiusMeters,$lat,$lng);
  nwr["emergency"="ambulance_station"](around:$_searchRadiusMeters,$lat,$lng);
);
out center;
''';

    final response = await http.post(
      Uri.parse(_overpassUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'AI Smart SOS/1.0',
        'Accept': 'application/json',
      },
      body: {
        'data': query,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch nearby places (${response.statusCode})');
    }

    final data = json.decode(response.body);
    final elements = data['elements'] as List;
    const distance = Distance();
    final userLocation = LatLng(lat, lng);

    final places = <NearbyPlace>[];

    for (final element in elements) {
      double? placeLat, placeLng;

      // Nodes have lat/lon directly; ways/relations have a center point
      if (element['type'] == 'node') {
        placeLat = (element['lat'] as num?)?.toDouble();
        placeLng = (element['lon'] as num?)?.toDouble();
      } else if (element['center'] != null) {
        placeLat = (element['center']['lat'] as num?)?.toDouble();
        placeLng = (element['center']['lon'] as num?)?.toDouble();
      }

      if (placeLat == null || placeLng == null) continue;

      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final name = tags['name'] as String? ?? _fallbackName(tags);
      final type = _determineType(tags);
      final address = _buildAddress(tags);
      final phone = tags['phone'] as String? ??
          tags['contact:phone'] as String?;

      final distKm = distance.as(
        LengthUnit.Kilometer,
        userLocation,
        LatLng(placeLat, placeLng),
      );

      places.add(NearbyPlace(
        name: name,
        latitude: placeLat,
        longitude: placeLng,
        type: type,
        distanceKm: distKm,
        address: address,
        phone: phone,
      ));
    }

    // Sort by distance (nearest first)
    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places;
  }

  static PlaceType _determineType(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'hospital') return PlaceType.hospital;
    if (tags['amenity'] == 'police') return PlaceType.police;
    return PlaceType.ambulance;
  }

  static String _fallbackName(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'hospital') return 'Hospital';
    if (tags['amenity'] == 'police') return 'Police Station';
    return 'Ambulance Station';
  }

  /// Builds a human-readable address from OSM address tags.
  static String? _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];

    final house = tags['addr:housenumber'] as String?;
    final street = tags['addr:street'] as String?;
    if (street != null) {
      parts.add(house != null ? '$house $street' : street);
    }

    final city = tags['addr:city'] as String? ??
        tags['addr:suburb'] as String?;
    if (city != null) parts.add(city);

    final postcode = tags['addr:postcode'] as String?;
    if (postcode != null) parts.add(postcode);

    return parts.isNotEmpty ? parts.join(', ') : null;
  }
}
