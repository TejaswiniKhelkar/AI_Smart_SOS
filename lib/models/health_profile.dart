import 'dart:convert';

/// AI Health Profile — medical data for emergency responders.
class HealthProfile {
  final List<String> allergies;
  final List<String> existingDiseases;
  final List<String> currentMedications;
  final String? medicalNotes;
  final bool organDonorStatus;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final String? disabilityInfo;

  HealthProfile({
    this.allergies = const [],
    this.existingDiseases = const [],
    this.currentMedications = const [],
    this.medicalNotes,
    this.organDonorStatus = false,
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.disabilityInfo,
  });

  /// Rule-based risk level: Low / Medium / High.
  String get riskLevel {
    int score = 0;
    if (allergies.isNotEmpty) score += allergies.length;
    if (existingDiseases.isNotEmpty) score += existingDiseases.length * 2;
    if (currentMedications.length > 3) score += 2;
    if (score == 0) return 'Low';
    if (score <= 3) return 'Medium';
    return 'High';
  }

  /// Whether any health data has been filled.
  bool get hasData =>
      allergies.isNotEmpty ||
      existingDiseases.isNotEmpty ||
      currentMedications.isNotEmpty ||
      (medicalNotes != null && medicalNotes!.isNotEmpty);

  /// Completion percentage (0–100).
  int get completionPercent {
    final checks = <bool>[
      allergies.isNotEmpty,
      existingDiseases.isNotEmpty || true, // "none" is a valid answer
      currentMedications.isNotEmpty || true,
      medicalNotes != null && medicalNotes!.isNotEmpty,
      organDonorStatus || true, // toggle is always set
      insuranceProvider != null && insuranceProvider!.isNotEmpty,
      disabilityInfo != null && disabilityInfo!.isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;
    return ((filled / checks.length) * 100).round();
  }

  /// Generates a human-readable AI health summary string.
  String generateSummary(String? bloodGroup) {
    final lines = <String>[];
    lines.add('Risk Level: $riskLevel');
    if (bloodGroup != null && bloodGroup.isNotEmpty) {
      lines.add('Blood Group: $bloodGroup');
    }
    if (allergies.isNotEmpty) {
      lines.add('Known Allergies: ${allergies.join(", ")}');
    } else {
      lines.add('Known Allergies: None reported');
    }
    if (existingDiseases.isNotEmpty) {
      lines.add('Conditions: ${existingDiseases.join(", ")}');
    }
    if (currentMedications.isNotEmpty) {
      lines.add('Current Medications: ${currentMedications.join(", ")}');
    } else {
      lines.add('Current Medications: None');
    }
    if (medicalNotes != null && medicalNotes!.isNotEmpty) {
      lines.add('Medical Notes: Ready');
    }
    if (organDonorStatus) {
      lines.add('Organ Donor: Yes');
    }
    return lines.join('\n');
  }

  /// Compact summary for SMS.
  String get smsSummary {
    final parts = <String>[];
    if (allergies.isNotEmpty) parts.add('Allergies: ${allergies.join(", ")}');
    if (existingDiseases.isNotEmpty) {
      parts.add('Conditions: ${existingDiseases.join(", ")}');
    }
    if (currentMedications.isNotEmpty) {
      parts.add('Meds: ${currentMedications.join(", ")}');
    }
    return parts.isEmpty ? 'No critical medical info' : parts.join(' | ');
  }

  HealthProfile copyWith({
    List<String>? allergies,
    List<String>? existingDiseases,
    List<String>? currentMedications,
    String? medicalNotes,
    bool? organDonorStatus,
    String? insuranceProvider,
    String? insurancePolicyNumber,
    String? disabilityInfo,
  }) {
    return HealthProfile(
      allergies: allergies ?? this.allergies,
      existingDiseases: existingDiseases ?? this.existingDiseases,
      currentMedications: currentMedications ?? this.currentMedications,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      organDonorStatus: organDonorStatus ?? this.organDonorStatus,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      insurancePolicyNumber:
          insurancePolicyNumber ?? this.insurancePolicyNumber,
      disabilityInfo: disabilityInfo ?? this.disabilityInfo,
    );
  }

  Map<String, dynamic> toJson() => {
        'allergies': allergies,
        'existingDiseases': existingDiseases,
        'currentMedications': currentMedications,
        'medicalNotes': medicalNotes,
        'organDonorStatus': organDonorStatus,
        'insuranceProvider': insuranceProvider,
        'insurancePolicyNumber': insurancePolicyNumber,
        'disabilityInfo': disabilityInfo,
      };

  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    return HealthProfile(
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      existingDiseases: (json['existingDiseases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      currentMedications: (json['currentMedications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      medicalNotes: json['medicalNotes'] as String?,
      organDonorStatus: json['organDonorStatus'] as bool? ?? false,
      insuranceProvider: json['insuranceProvider'] as String?,
      insurancePolicyNumber: json['insurancePolicyNumber'] as String?,
      disabilityInfo: json['disabilityInfo'] as String?,
    );
  }

  static String encode(HealthProfile profile) =>
      json.encode(profile.toJson());

  static HealthProfile decode(String encoded) =>
      HealthProfile.fromJson(json.decode(encoded));
}
