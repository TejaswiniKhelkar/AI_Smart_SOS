import 'dart:convert';

/// AI Emergency Profile — personal identity for emergency scenarios.
class UserProfile {
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final String? phone;
  final String? email;
  final String? homeAddress;
  final String preferredLanguage;
  final String? profilePhotoPath;

  UserProfile({
    this.fullName = '',
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.heightCm,
    this.weightKg,
    this.phone,
    this.email,
    this.homeAddress,
    this.preferredLanguage = 'English',
    this.profilePhotoPath,
  });

  /// Computes age from [dateOfBirth].  Returns null when DOB is not set.
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  /// Whether the profile has enough data for an emergency scenario.
  bool get isComplete =>
      fullName.isNotEmpty &&
      bloodGroup != null &&
      phone != null &&
      phone!.isNotEmpty;

  /// Completion percentage (0–100).
  int get completionPercent {
    int total = 0;
    int filled = 0;
    final checks = <bool>[
      fullName.isNotEmpty,
      dateOfBirth != null,
      gender != null,
      bloodGroup != null && bloodGroup!.isNotEmpty,
      heightCm != null,
      weightKg != null,
      phone != null && phone!.isNotEmpty,
      email != null && email!.isNotEmpty,
      homeAddress != null && homeAddress!.isNotEmpty,
      profilePhotoPath != null && profilePhotoPath!.isNotEmpty,
    ];
    total = checks.length;
    filled = checks.where((c) => c).length;
    return ((filled / total) * 100).round();
  }

  UserProfile copyWith({
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    double? heightCm,
    double? weightKg,
    String? phone,
    String? email,
    String? homeAddress,
    String? preferredLanguage,
    String? profilePhotoPath,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      homeAddress: homeAddress ?? this.homeAddress,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'bloodGroup': bloodGroup,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'phone': phone,
        'email': email,
        'homeAddress': homeAddress,
        'preferredLanguage': preferredLanguage,
        'profilePhotoPath': profilePhotoPath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['fullName'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      homeAddress: json['homeAddress'] as String?,
      preferredLanguage: json['preferredLanguage'] as String? ?? 'English',
      profilePhotoPath: json['profilePhotoPath'] as String?,
    );
  }

  static String encode(UserProfile profile) => json.encode(profile.toJson());

  static UserProfile decode(String encoded) =>
      UserProfile.fromJson(json.decode(encoded));
}
