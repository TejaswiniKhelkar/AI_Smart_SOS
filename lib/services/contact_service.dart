import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_contact.dart';

/// Manages emergency contacts stored securely in Firebase Firestore.
///
/// Ensures data isolation per authenticated user.
class ContactService {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static DocumentReference? get _userDoc => _uid != null 
      ? FirebaseFirestore.instance.collection('users').doc(_uid)
      : null;

  /// Retrieves all saved emergency contacts from Firestore.
  static Future<List<EmergencyContact>> getContacts() async {
    if (_userDoc == null) return [];
    
    final doc = await _userDoc!.get();
    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || !data.containsKey('emergencyContacts')) return [];

    final List<dynamic> contactsData = data['emergencyContacts'];
    return contactsData
        .map((e) => EmergencyContact.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Adds a new emergency contact.
  static Future<bool> addContact(EmergencyContact contact) async {
    if (_userDoc == null) return false;
    final contacts = await getContacts();
    contacts.add(contact);
    await _save(contacts);
    return true;
  }

  /// Updates an existing contact by ID.
  static Future<void> updateContact(EmergencyContact updated) async {
    if (_userDoc == null) return;
    final contacts = await getContacts();
    final index = contacts.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      contacts[index] = updated;
      await _save(contacts);
    }
  }

  /// Deletes a contact by ID.
  static Future<void> deleteContact(String id) async {
    if (_userDoc == null) return;
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.id == id);
    await _save(contacts);
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

  static Future<void> _save(List<EmergencyContact> contacts) async {
    if (_userDoc == null) return;
    final contactsJson = contacts.map((c) => c.toJson()).toList();
    await _userDoc!.set({'emergencyContacts': contactsJson}, SetOptions(merge: true));
  }
}
