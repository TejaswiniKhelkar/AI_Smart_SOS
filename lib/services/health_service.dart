import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_profile.dart';

/// Manages health profile data via SharedPreferences.
class HealthService {
  static const String _storageKey = 'health_profile';

  /// Retrieves the saved health profile, or a default empty one.
  static Future<HealthProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return HealthProfile();
    return HealthProfile.decode(encoded);
  }

  /// Saves the health profile.
  static Future<void> saveProfile(HealthProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, HealthProfile.encode(profile));
  }

  /// Generates an AI health summary using rule-based logic.
  /// [bloodGroup] is passed from the user profile.
  static Future<String> generateAISummary(String? bloodGroup) async {
    final profile = await getProfile();
    return profile.generateSummary(bloodGroup);
  }

  /// Clears health data.
  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
