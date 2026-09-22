import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';
import 'network_service.dart';
import 'sync_queue_service.dart';

/// Manages emergency contacts stored securely in Firebase Firestore and cached locally.
///
/// Ensures data isolation per authenticated user. Supports offline read/writes
/// and syncs via SyncQueueService.
class ContactService {
  static const String _localCacheKey = 'emergency_contacts_cache';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static DocumentReference? get _userDoc => _uid != null 
      ? FirebaseFirestore.instance.collection('users').doc(_uid)
      : null;

  /// Retrieves all saved emergency contacts, prioritizing local cache when offline.
  static Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (NetworkService().isOnline && _userDoc != null) {
      try {
        final doc = await _userDoc!.get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('emergencyContacts')) {
            final List<dynamic> contactsData = data['emergencyContacts'];
            final contacts = contactsData
                .map((e) => EmergencyContact.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            // Update local cache
            await _updateLocalCache(prefs, contacts);
            return contacts;
          }
        }
      } catch (e) {
        // Fallback to local cache on error
      }
    }
    
    // Read from local cache
    return _readLocalCache(prefs);
  }

  /// Adds a new emergency contact.
  static Future<bool> addContact(EmergencyContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await _readLocalCache(prefs);
    contacts.add(contact);
    await _updateLocalCache(prefs, contacts);
    await _syncOrQueue(contacts);
    return true;
  }

  /// Updates an existing contact by ID.
  static Future<void> updateContact(EmergencyContact updated) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await _readLocalCache(prefs);
    final index = contacts.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      contacts[index] = updated;
      await _updateLocalCache(prefs, contacts);
      await _syncOrQueue(contacts);
    }
  }

  /// Deletes a contact by ID.
  static Future<void> deleteContact(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await _readLocalCache(prefs);
    contacts.removeWhere((c) => c.id == id);
    await _updateLocalCache(prefs, contacts);
    await _syncOrQueue(contacts);
  }

  /// Attempt immediate sync if online; otherwise, queue for later.
  static Future<void> _syncOrQueue(List<EmergencyContact> contacts) async {
    final payload = {'emergencyContacts': contacts.map((c) => c.toJson()).toList()};
    
    if (NetworkService().isOnline && _userDoc != null) {
      try {
        await _userDoc!.set(payload, SetOptions(merge: true));
        return; // Success
      } catch (e) {
        // Fallback to queue
      }
    }
    
    // Enqueue
    await SyncQueueService().enqueue(
      QueueItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: QueueItemType.contactSync,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );
  }

  /// Sync handler invoked by SyncQueueService.
  static Future<bool> syncContactsToFirebase(Map<String, dynamic> payload) async {
    if (_userDoc == null) return false;
    try {
      await _userDoc!.set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Helpers ---

  static Future<List<EmergencyContact>> _readLocalCache(SharedPreferences prefs) async {
    final encoded = prefs.getString(_localCacheKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(encoded);
      return list.map((e) => EmergencyContact.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _updateLocalCache(SharedPreferences prefs, List<EmergencyContact> contacts) async {
    final encoded = json.encode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_localCacheKey, encoded);
  }

  /// Returns the current number of saved contacts.
  static Future<int> getContactCount() async {
    final contacts = await getContacts();
    return contacts.length;
  }

  /// Returns contacts sorted by priority (primary first).
  static Future<List<EmergencyContact>> getContactsByPriority() async {
    final contacts = await getContacts();
    contacts.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return contacts;
  }

  /// Returns only primary contacts.
  static Future<List<EmergencyContact>> getPrimaryContacts() async {
    final contacts = await getContacts();
    return contacts
        .where((c) => c.priority == ContactPriority.primary)
        .toList();
  }

  /// Returns only priority contacts (primary + secondary).
  static Future<List<EmergencyContact>> getPriorityContacts() async {
    final contacts = await getContacts();
    return contacts
        .where((c) =>
            c.priority == ContactPriority.primary ||
            c.priority == ContactPriority.secondary)
        .toList();
  }

  /// Searches contacts by name, phone, or relationship.
  static Future<List<EmergencyContact>> searchContacts(String query) async {
    if (query.isEmpty) return getContacts();
    final contacts = await getContacts();
    final q = query.toLowerCase();
    return contacts
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            c.relationship.toLowerCase().contains(q))
        .toList();
  }
}
