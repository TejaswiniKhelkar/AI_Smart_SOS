import 'dart:convert';

/// Priority levels for emergency contacts.
enum ContactPriority {
  primary,   // ⭐ Primary Contact
  secondary, // ⭐⭐ Secondary Contact
  normal,    // Normal Emergency Contact
}

extension ContactPriorityLabel on ContactPriority {
  String get label {
    switch (this) {
      case ContactPriority.primary:
        return '⭐ Primary';
      case ContactPriority.secondary:
        return '⭐⭐ Secondary';
      case ContactPriority.normal:
        return 'Normal';
    }
  }

  String get shortLabel {
    switch (this) {
      case ContactPriority.primary:
        return 'Primary';
      case ContactPriority.secondary:
        return 'Secondary';
      case ContactPriority.normal:
        return 'Normal';
    }
  }
}

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final ContactPriority priority;
  final String? email;
  final String? profilePhotoPath;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.priority = ContactPriority.normal,
    this.email,
    this.profilePhotoPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'priority': priority.index,
        'email': email,
        'profilePhotoPath': profilePhotoPath,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String,
      // Backward compatible: old contacts without priority default to normal
      priority: json['priority'] != null
          ? ContactPriority.values[json['priority'] as int]
          : ContactPriority.normal,
      email: json['email'] as String?,
      profilePhotoPath: json['profilePhotoPath'] as String?,
    );
  }

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relationship,
    ContactPriority? priority,
    String? email,
    String? profilePhotoPath,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
      email: email ?? this.email,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
    );
  }

  static String encode(List<EmergencyContact> contacts) =>
      json.encode(contacts.map((c) => c.toJson()).toList());

  static List<EmergencyContact> decode(String encoded) {
    final List<dynamic> list = json.decode(encoded);
    return list.map((e) => EmergencyContact.fromJson(e)).toList();
  }
}
