import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

/// Manages emergency contacts stored locally via SharedPreferences.
class ContactService {
  static const String _storageKey = 'emergency_contacts';
  static const int maxContacts = 5;

  /// Retrieves all saved emergency contacts.
  static Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    return EmergencyContact.decode(encoded);
  }

  /// Adds a new emergency contact. Returns false if max limit reached.
  static Future<bool> addContact(EmergencyContact contact) async {
    final contacts = await getContacts();
    if (contacts.length >= maxContacts) return false;
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

  static Future<void> _save(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, EmergencyContact.encode(contacts));
  }
}
