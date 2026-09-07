import 'package:geolocator/geolocator.dart';
import '../models/emergency_contact.dart';
import 'profile_service.dart';
import 'health_service.dart';
import 'contact_service.dart';

/// Result item for the readiness checklist.
class ReadinessItem {
  final String label;
  final bool completed;
  final String? suggestion;

  ReadinessItem({
    required this.label,
    required this.completed,
    this.suggestion,
  });
}

/// Computes the AI Emergency Readiness Score (0–100).
class ReadinessService {
  /// Calculates the overall readiness score and returns individual items.
  static Future<({int score, List<ReadinessItem> items})> calculate() async {
    final profile = await ProfileService.getProfile();
    final health = await HealthService.getProfile();
    final contacts = await ContactService.getContacts();

    bool locationEnabled = false;
    try {
      // Use permission status as the readiness indicator instead of
      // Geolocator.isLocationServiceEnabled() which is unreliable on
      // many Android devices (returns false even when GPS is ON).
      final permission = await Geolocator.checkPermission();
      locationEnabled = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {}

    final items = <ReadinessItem>[
      ReadinessItem(
        label: 'Profile Completed',
        completed: profile.isComplete,
        suggestion:
            profile.isComplete ? null : 'Complete your emergency profile',
      ),
      ReadinessItem(
        label: 'Medical Information Added',
        completed: health.hasData,
        suggestion: health.hasData
            ? null
            : 'Add your medical information for responders',
      ),
      ReadinessItem(
        label: 'Blood Group Available',
        completed:
            profile.bloodGroup != null && profile.bloodGroup!.isNotEmpty,
        suggestion: profile.bloodGroup != null ? null : 'Set your blood group',
      ),
      ReadinessItem(
        label: 'Emergency Contacts Available',
        completed: contacts.isNotEmpty,
        suggestion: contacts.isNotEmpty
            ? null
            : 'Add at least one emergency contact',
      ),
      ReadinessItem(
        label: 'Primary Contact Set',
        completed:
            contacts.any((c) => c.priority == ContactPriority.primary),
        suggestion: contacts.any((c) => c.priority == ContactPriority.primary)
            ? null
            : 'Set a primary emergency contact',
      ),
      ReadinessItem(
        label: 'Location Enabled',
        completed: locationEnabled,
        suggestion:
            locationEnabled ? null : 'Enable location services for SOS',
      ),
      ReadinessItem(
        label: 'Allergy Information',
        completed: health.allergies.isNotEmpty,
        suggestion: health.allergies.isNotEmpty
            ? null
            : 'Complete allergy information',
      ),
      ReadinessItem(
        label: 'Insurance Details',
        completed: health.insuranceProvider != null &&
            health.insuranceProvider!.isNotEmpty,
        suggestion: health.insuranceProvider != null
            ? null
            : 'Add insurance details',
      ),
      ReadinessItem(
        label: 'Home Address Set',
        completed:
            profile.homeAddress != null && profile.homeAddress!.isNotEmpty,
        suggestion: profile.homeAddress != null
            ? null
            : 'Add your home address',
      ),
      ReadinessItem(
        label: 'Profile Photo',
        completed: profile.profilePhotoPath != null &&
            profile.profilePhotoPath!.isNotEmpty,
        suggestion: profile.profilePhotoPath != null
            ? null
            : 'Add a profile photo for identification',
      ),
    ];

    final completed = items.where((i) => i.completed).length;
    final score = ((completed / items.length) * 100).round();

    return (score: score, items: items);
  }

  /// Returns only the suggestions (incomplete items).
  static Future<List<String>> getSuggestions() async {
    final result = await calculate();
    return result.items
        .where((i) => !i.completed && i.suggestion != null)
        .map((i) => i.suggestion!)
        .toList();
  }
}
