import 'package:shared_preferences/shared_preferences.dart';

class AssistantSettingsService {
  static const _langKey = 'assistant_language';
  static const _themeKey = 'assistant_theme';

  /// Supported languages: 'en', 'hi', 'mr'
  static Future<String> getLanguage() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_langKey) ?? 'en';
  }

  static Future<void> setLanguage(String lang) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_langKey, lang);
  }

  /// Theme: 'system', 'light', 'dark'
  static Future<String> getTheme() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_themeKey) ?? 'system';
  }

  static Future<void> setTheme(String theme) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_themeKey, theme);
  }
}
