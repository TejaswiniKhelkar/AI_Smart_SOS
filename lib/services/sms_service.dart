import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import '../models/app_settings.dart';
import 'profile_service.dart';
import 'health_service.dart';
import 'settings_service.dart';
import 'contact_service.dart';

/// Builds and sends emergency SMS messages with enriched profile data.
class SmsService {
  /// Builds the emergency SMS message.
  static Future<String> buildEmergencyMessage({
    required double latitude,
    required double longitude,
    required String googleMapsLink,
  }) async {
    final profile = await ProfileService.getProfile();
    final health = await HealthService.getProfile();
    final settings = await SettingsService.getSettings();

    final buffer = StringBuffer();
    buffer.writeln('🚨 EMERGENCY ALERT');
    buffer.writeln();

    // User name
    if (profile.fullName.isNotEmpty) {
      buffer.writeln(
          '${profile.fullName} may have been involved in an accident.');
    } else {
      buffer.writeln('An emergency has been detected.');
    }
    buffer.writeln();

    // Blood group
    if (settings.shareBloodGroup &&
        profile.bloodGroup != null &&
        profile.bloodGroup!.isNotEmpty) {
      buffer.writeln('Blood Group: ${profile.bloodGroup}');
    }

    // Medical summary
    if (settings.shareMedicalInfo && health.hasData) {
      buffer.writeln(health.smsSummary);
    }
    buffer.writeln();

    // Live location
    if (settings.shareLiveLocation) {
      buffer.writeln('Live Location:');
      buffer.writeln(googleMapsLink);
      buffer.writeln();
      buffer.writeln(
          'Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}');
    }
    buffer.writeln();
    buffer.writeln('Please contact immediately.');
    buffer.writeln();
    buffer.writeln('Sent via AI Smart SOS');

    return buffer.toString();
  }

  /// Returns the list of contacts to notify based on settings.
  static Future<List<EmergencyContact>> getRecipients() async {
    final settings = await SettingsService.getSettings();
    final contacts = await ContactService.getContacts();

    switch (settings.alertRecipientMode) {
      case AlertRecipientMode.primaryOnly:
        return contacts
            .where((c) => c.priority == ContactPriority.primary)
            .toList();
      case AlertRecipientMode.priorityContacts:
        return contacts
            .where((c) =>
                c.priority == ContactPriority.primary ||
                c.priority == ContactPriority.secondary)
            .toList();
      case AlertRecipientMode.allContacts:
        return contacts;
    }
  }

  /// Opens the SMS app with the emergency message for each recipient.
  /// Returns the number of SMS intents launched.
  static Future<int> sendEmergencySMS({
    required double latitude,
    required double longitude,
    required String googleMapsLink,
  }) async {
    final message = await buildEmergencyMessage(
      latitude: latitude,
      longitude: longitude,
      googleMapsLink: googleMapsLink,
    );

    final recipients = await getRecipients();
    if (recipients.isEmpty) return 0;

    int sent = 0;
    for (final contact in recipients) {
      final uri = Uri(
        scheme: 'sms',
        path: contact.phone,
        queryParameters: {'body': message},
      );
      try {
        await launchUrl(uri);
        sent++;
      } catch (_) {
        // SMS app may not be available; continue
      }
    }
    return sent;
  }
}
