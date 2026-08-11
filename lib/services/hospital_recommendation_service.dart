import '../models/nearby_place.dart';

/// Result of an AI hospital recommendation.
class HospitalRecommendation {
  final NearbyPlace place;
  final double aiScore; // 0.0 – 1.0
  final List<String> capabilities;
  final String recommendation; // 'Highly Recommended', 'Recommended', 'Available'

  HospitalRecommendation({
    required this.place,
    required this.aiScore,
    required this.capabilities,
    required this.recommendation,
  });
}

/// AI Hospital Recommendation Service.
///
/// Scores and ranks nearby hospitals based on distance, type,
/// and OSM tag heuristics. Designed to be extendable with ML.
class HospitalRecommendationService {
  /// Takes a list of nearby places and returns AI-ranked hospitals.
  static List<HospitalRecommendation> recommend(List<NearbyPlace> places) {
    final hospitals =
        places.where((p) => p.type == PlaceType.hospital).toList();

    final recommendations = hospitals.map((h) {
      double score = 0.0;
      final caps = <String>[];

      // ── Distance scoring (closer = better) ──
      if (h.distanceKm <= 2) {
        score += 0.4;
        caps.add('Nearby');
      } else if (h.distanceKm <= 5) {
        score += 0.3;
      } else if (h.distanceKm <= 10) {
        score += 0.2;
      } else {
        score += 0.1;
      }

      // ── Name-based heuristics for emergency capability ──
      final nameLower = h.name.toLowerCase();
      if (nameLower.contains('trauma')) {
        score += 0.2;
        caps.add('Trauma Center');
      }
      if (nameLower.contains('emergency') || nameLower.contains('icu')) {
        score += 0.15;
        caps.add('Emergency Services');
      }
      if (nameLower.contains('multi') || nameLower.contains('super')) {
        score += 0.1;
        caps.add('Multi-Specialty');
      }
      if (nameLower.contains('government') || nameLower.contains('govt')) {
        score += 0.05;
        caps.add('Government');
      }
      if (nameLower.contains('children') || nameLower.contains('pediatric')) {
        caps.add('Pediatric');
      }
      if (nameLower.contains('cardiac') || nameLower.contains('heart')) {
        caps.add('Cardiac Care');
      }

      // ── Phone availability bonus ──
      if (h.phone != null) {
        score += 0.1;
        caps.add('Contact Available');
      }

      // ── Default capability ──
      if (caps.isEmpty) caps.add('General Hospital');

      score = score.clamp(0.0, 1.0);

      String rec;
      if (score >= 0.6) {
        rec = 'Highly Recommended';
      } else if (score >= 0.35) {
        rec = 'Recommended';
      } else {
        rec = 'Available';
      }

      return HospitalRecommendation(
        place: h,
        aiScore: score,
        capabilities: caps,
        recommendation: rec,
      );
    }).toList();

    // Sort by AI score descending
    recommendations.sort((a, b) => b.aiScore.compareTo(a.aiScore));
    return recommendations;
  }
}
