import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

/// Manages emergency contacts stored locally via SharedPreferences.
///
/// No hard-coded contact limit — allows unlimited contacts.
class ContactService {
  static const String _storageKey = 'emergency_contacts';

  /// Retrieves all saved emergency contacts.
  static Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    return EmergencyContact.decode(encoded);
  }

  /// Adds a new emergency contact.
  static Future<bool> addContact(EmergencyContact contact) async {
    final contacts = await getContacts();
    contacts.add(contact);
    await _save(contacts);
    return true;
  }

  /// Updates an existing contact by ID.
  static Future<void> updateContact(EmergencyContact updated) async {
    final contacts = await getContacts();
    final index = contacts.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      contacts[index] = updated;
      await _save(contacts);
    }
  }

  /// Deletes a contact by ID.
  static Future<void> deleteContact(String id) async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, EmergencyContact.encode(contacts));
  }
}
