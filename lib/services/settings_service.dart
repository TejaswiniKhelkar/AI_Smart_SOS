import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

/// Manages application settings via SharedPreferences.
class SettingsService {
  static const String _storageKey = 'app_settings';

  /// Retrieves the saved settings, or defaults.
  static Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return AppSettings();
    return AppSettings.decode(encoded);
  }

  /// Saves settings.
  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, AppSettings.encode(settings));
  }

  /// Resets all settings to defaults.
  static Future<void> resetSettings() async {
    await saveSettings(AppSettings());
  }
}
