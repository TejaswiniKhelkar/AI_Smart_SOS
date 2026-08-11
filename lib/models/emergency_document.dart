import 'dart:convert';

/// Types of emergency documents stored in the Document Locker.
enum DocumentType {
  medicalReport,
  insurance,
  prescription,
  bloodReport,
  drivingLicense,
  identity,
  other,
}

/// Extension for human-readable labels.
extension DocumentTypeLabel on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.medicalReport:
        return 'Medical Report';
      case DocumentType.insurance:
        return 'Insurance';
      case DocumentType.prescription:
        return 'Prescription';
      case DocumentType.bloodReport:
        return 'Blood Report';
      case DocumentType.drivingLicense:
        return 'Driving License';
      case DocumentType.identity:
        return 'Identity Document';
      case DocumentType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case DocumentType.medicalReport:
        return '🏥';
      case DocumentType.insurance:
        return '🛡️';
      case DocumentType.prescription:
        return '💊';
      case DocumentType.bloodReport:
        return '🩸';
      case DocumentType.drivingLicense:
        return '🚗';
      case DocumentType.identity:
        return '🪪';
      case DocumentType.other:
        return '📄';
    }
  }
}

/// Represents a document stored in the Emergency Document Locker.
class EmergencyDocument {
  final String id;
  final String name;
  final DocumentType type;
  final String filePath;
  final DateTime dateAdded;
  final bool isShareable;
  final int fileSizeBytes;

  EmergencyDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.filePath,
    required this.dateAdded,
    this.isShareable = false,
    this.fileSizeBytes = 0,
  });

  /// Human-readable file size.
  String get fileSizeText {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  EmergencyDocument copyWith({
    String? name,
    DocumentType? type,
    bool? isShareable,
  }) {
    return EmergencyDocument(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      filePath: filePath,
      dateAdded: dateAdded,
      isShareable: isShareable ?? this.isShareable,
      fileSizeBytes: fileSizeBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'filePath': filePath,
        'dateAdded': dateAdded.toIso8601String(),
        'isShareable': isShareable,
        'fileSizeBytes': fileSizeBytes,
      };

  factory EmergencyDocument.fromJson(Map<String, dynamic> json) {
    return EmergencyDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DocumentType.values[json['type'] as int],
      filePath: json['filePath'] as String,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      isShareable: json['isShareable'] as bool? ?? false,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
    );
  }

  static String encode(List<EmergencyDocument> docs) =>
      json.encode(docs.map((d) => d.toJson()).toList());

  static List<EmergencyDocument> decode(String encoded) {
    final List<dynamic> list = json.decode(encoded);
    return list.map((e) => EmergencyDocument.fromJson(e)).toList();
  }
}
