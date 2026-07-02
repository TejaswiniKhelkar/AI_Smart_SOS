import 'package:shared_preferences/shared_preferences.dart';
import '../models/sos_alert.dart';

/// Manages SOS alert history stored locally via SharedPreferences.
class AlertService {
  static const String _storageKey = 'sos_alert_history';

  /// Retrieves all saved alerts, sorted by most recent first.
  static Future<List<SosAlert>> getAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    final alerts = SosAlert.decode(encoded);
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alerts;
  }

  /// Saves a new SOS alert to history.
  static Future<void> saveAlert(SosAlert alert) async {
    final alerts = await getAlerts();
    alerts.insert(0, alert); // Most recent first
    await _save(alerts);
  }

  /// Clears all alert history.
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Returns the total number of saved alerts.
  static Future<int> getAlertCount() async {
    final alerts = await getAlerts();
    return alerts.length;
  }

  static Future<void> _save(List<SosAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, SosAlert.encode(alerts));
  }
}
