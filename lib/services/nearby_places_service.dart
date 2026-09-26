import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nearby_place.dart';
import 'network_service.dart';

/// Fetches nearby emergency places from the OpenStreetMap Overpass API.
/// Caches results for offline use.
class NearbyPlacesService {
  static const String _overpassUrl =
      'https://overpass-api.de/api/interpreter';
  static const String _cacheKey = 'nearby_places_cache';

  /// Search radius in meters (20 km).
  static const double _searchRadiusMeters = 20000;

  /// Fetches hospitals, police stations, and ambulance stations
  /// within [_searchRadiusMeters] of the given coordinates.
  static Future<List<NearbyPlace>> fetchNearbyPlaces(
    double lat,
    double lng,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    if (!NetworkService().isOnline) {
      return _readCache(prefs);
    }

    final query = '''
[out:json][timeout:25];
(
  nwr["amenity"="hospital"](around:$_searchRadiusMeters,$lat,$lng);
  nwr["amenity"="police"](around:$_searchRadiusMeters,$lat,$lng);
  nwr["amenity"="fire_station"](around:$_searchRadiusMeters,$lat,$lng);
  nwr["emergency"="ambulance_station"](around:$_searchRadiusMeters,$lat,$lng);
);
out center;
''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'AI Smart SOS/1.0',
          'Accept': 'application/json',
          'Accept-Language': 'en',
        },
        body: {
          'data': query,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch nearby places (${response.statusCode})');
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
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

      // Enforce strict 20 km limit
      if (distKm > 20.0) continue;

      final isOpen = _determineIsOpen(tags, type);

      places.add(NearbyPlace(
        name: name,
        latitude: placeLat,
        longitude: placeLng,
        type: type,
        distanceKm: distKm,
        address: address,
        phone: phone,
        isOpen: isOpen,
      ));
    }

    // Sort by priority rules:
    // 1. Currently OPEN services first
    // 2. Then nearest distance
    // 3. Emergency-service priority (Hospital > Ambulance > Police)
    places.sort((a, b) {
      final aOpen = a.isOpen == true ? 0 : (a.isOpen == false ? 2 : 1);
      final bOpen = b.isOpen == true ? 0 : (b.isOpen == false ? 2 : 1);
      
      if (aOpen != bOpen) {
        return aOpen.compareTo(bOpen);
      }
      
      if ((a.distanceKm - b.distanceKm).abs() > 0.1) {
        return a.distanceKm.compareTo(b.distanceKm);
      }
      
      return a.priority.compareTo(b.priority);
    });
    
      // Save to cache
      await _updateCache(prefs, places);
      return places;

    } catch (e) {
      // Fallback to cache on error
      final cached = await _readCache(prefs);
      if (cached.isNotEmpty) {
        return cached;
      }
      throw Exception('Nearby emergency services require an internet connection.');
    }
  }

  static Future<List<NearbyPlace>> _readCache(SharedPreferences prefs) async {
    final encoded = prefs.getString(_cacheKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(encoded);
      return list.map((e) => NearbyPlace.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _updateCache(SharedPreferences prefs, List<NearbyPlace> places) async {
    final encoded = json.encode(places.map((p) => p.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
  }

  static PlaceType _determineType(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'hospital') return PlaceType.hospital;
    if (tags['amenity'] == 'police') return PlaceType.police;
    if (tags['amenity'] == 'fire_station') return PlaceType.fire;
    return PlaceType.ambulance;
  }

  static bool? _determineIsOpen(Map<String, dynamic> tags, PlaceType type) {
    final oh = tags['opening_hours']?.toString().toLowerCase();
    if (oh != null) {
      if (oh.contains('24/7')) return true;
      if (oh.contains('off') || oh.contains('closed')) return false;
      // Other complex patterns we leave as unknown
    }
    // Assume hospitals are almost always open 24/7 if not specified
    if (type == PlaceType.hospital) return true;
    return null;
  }

  static String _fallbackName(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'hospital') return 'Hospital';
    if (tags['amenity'] == 'police') return 'Police Station';
    if (tags['amenity'] == 'fire_station') return 'Fire Station';
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
