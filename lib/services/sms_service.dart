import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/emergency_contact.dart';
import '../models/app_settings.dart';
import 'profile_service.dart';
import 'settings_service.dart';
import 'contact_service.dart';
import 'ai_api_service.dart';
import 'network_service.dart';

class SmsDeliveryResult {
  final String overallStatus; // 'sent', 'failed_no_provider', 'queued', 'failed'
  final Map<String, String> contactStatuses; // phone -> status ('sent', 'failed', 'queued')

  SmsDeliveryResult({
    required this.overallStatus,
    required this.contactStatuses,
  });
}

/// Builds and sends emergency SMS messages with enriched profile data.
class SmsService {
  
  /// Formats the phone number to E.164 (+91 format for India).
  static String formatPhoneNumber(String phone) {
    String num = phone.replaceAll(RegExp(r'\D'), '');
    if (num.length == 10) return '+91$num';
    if (num.startsWith('91') && num.length == 12) return '+$num';
    if (num.startsWith('91') && num.length > 12) return '+$num'; // Catch all for international if they prefixed
    return '+$num'; // Assuming it has country code if not 10 digits
  }

  /// Builds the emergency SMS message.
  static Future<String> buildEmergencyMessage({
    required double latitude,
    required double longitude,
    required String googleMapsLink,
  }) async {
    final profile = await ProfileService.getProfile();
    final timeStr = DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('EMERGENCY ALERT');
    buffer.writeln();

    if (profile.fullName.isNotEmpty) {
      buffer.writeln('${profile.fullName} may have been involved in a road accident.');
    } else {
      buffer.writeln('I may have been involved in a road accident.');
    }
    
    buffer.writeln();
    buffer.writeln('Location:');
    buffer.writeln(googleMapsLink);
    buffer.writeln();
    buffer.writeln('Time:');
    buffer.writeln(timeStr);
    buffer.writeln();
    buffer.write('Please contact them or emergency services immediately.');

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

  /// Sends the emergency SMS message via the backend provider.
  static Future<SmsDeliveryResult> sendEmergencySMS({
    required String eventId,
    required double latitude,
    required double longitude,
    required String googleMapsLink,
  }) async {
    final recipients = await getRecipients();
    final Map<String, String> contactStatuses = {};
    
    if (recipients.isEmpty) {
      return SmsDeliveryResult(overallStatus: 'failed', contactStatuses: {});
    }

    final toNumbers = recipients.map((c) => formatPhoneNumber(c.phone)).toList();

    if (!NetworkService().isOnline) {
      for (var num in toNumbers) {
        contactStatuses[num] = 'queued';
      }
      return SmsDeliveryResult(overallStatus: 'queued', contactStatuses: contactStatuses);
    }

    final message = await buildEmergencyMessage(
      latitude: latitude,
      longitude: longitude,
      googleMapsLink: googleMapsLink,
    );

    try {
      final backendUrl = AiApiService().backendUrl;
      final uri = Uri.parse('$backendUrl/api/sms');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'eventId': eventId,
          'to': toNumbers,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final failures = (data['failures'] as List?) ?? [];
        final failedNumbers = failures.map((f) => f['to'].toString()).toSet();
        
        for (var num in toNumbers) {
          contactStatuses[num] = failedNumbers.contains(num) ? 'failed' : 'sent';
        }
        
        return SmsDeliveryResult(
          overallStatus: failedNumbers.length == toNumbers.length ? 'failed' : 'sent', 
          contactStatuses: contactStatuses
        );
      } else if (response.statusCode == 501) {
        for (var num in toNumbers) {
          contactStatuses[num] = 'failed_no_provider';
        }
        return SmsDeliveryResult(overallStatus: 'failed_no_provider', contactStatuses: contactStatuses);
      } else {
        for (var num in toNumbers) {
          contactStatuses[num] = 'failed';
        }
        return SmsDeliveryResult(overallStatus: 'failed', contactStatuses: contactStatuses);
      }
    } catch (e) {
      for (var num in toNumbers) {
        contactStatuses[num] = 'failed';
      }
      return SmsDeliveryResult(overallStatus: 'failed', contactStatuses: contactStatuses);
    }
  }
}
