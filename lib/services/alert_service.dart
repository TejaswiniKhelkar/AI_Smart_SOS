import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sos_alert.dart';
import 'network_service.dart';
import 'sync_queue_service.dart';

/// Manages SOS alert history stored locally via SharedPreferences and synced to Firestore.
class AlertService {
  static const String _storageKey = 'sos_alert_history';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static CollectionReference? get _alertsCol => _uid != null 
      ? FirebaseFirestore.instance.collection('users').doc(_uid).collection('sos_alerts')
      : null;

  /// Retrieves all saved alerts, sorted by most recent first.
  static Future<List<SosAlert>> getAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    final alerts = SosAlert.decode(encoded);
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alerts;
  }

  /// Saves a new SOS alert to history locally, and either syncs immediately or queues.
  static Future<void> saveAlert(SosAlert alert) async {
    final alerts = await getAlerts();
    
    // Check if it already exists to prevent duplicate local entries during sync
    final index = alerts.indexWhere((a) => a.id == alert.id);
    if (index != -1) {
      alerts[index] = alert;
    } else {
      alerts.insert(0, alert); // Most recent first
    }
    
    await _save(alerts);

    if (_alertsCol != null) {
      if (NetworkService().isOnline) {
        try {
          await _alertsCol!.doc(alert.id).set(alert.toJson());
        } catch (e) {
          // Fallback to queue if the immediate sync fails (e.g. Firebase rules or transient network issue)
          await _enqueueAlert(alert);
        }
      } else {
        await _enqueueAlert(alert);
      }
    }
  }

  static Future<void> _enqueueAlert(SosAlert alert) async {
    await SyncQueueService().enqueue(
      QueueItem(
        id: alert.id,
        type: QueueItemType.sosAlert,
        timestamp: DateTime.now(),
        payload: alert.toJson(),
      ),
    );
  }

  /// Syncs an alert to Firebase (called by SyncQueueService)
  static Future<bool> syncAlertToFirebase(Map<String, dynamic> payload) async {
    if (_alertsCol == null) return false;
    final id = payload['id'] as String;
    try {
      await _alertsCol!.doc(id).set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
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
