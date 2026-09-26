import 'dart:convert';

class SosAlert {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String googleMapsLink;
  final String alertType; // 'SOS', 'Police', 'Ambulance', 'Fire'
  final String status; // 'sent', 'cancelled'

  // ── Enhanced fields (Phase 5) ─────────────────────────────────────────
  final int? contactsNotified;
  final int? nearbyHospitalCount;
  final int? nearbyPoliceCount;
  final int? nearbyAmbulanceCount;
  final String? smsDeliveryStatus; // 'sent', 'failed', 'pending'
  final String? emergencyStatus; // 'active', 'resolved', 'false_alarm'
  final int? responseTimeSeconds;
  
  // ── Enhanced fields (Phase 6) ─────────────────────────────────────────
  final List<Map<String, dynamic>>? contactDeliveryStatuses; // Detailed per-contact delivery status

  SosAlert({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.googleMapsLink,
    required this.alertType,
    this.status = 'sent',
    this.contactsNotified,
    this.nearbyHospitalCount,
    this.nearbyPoliceCount,
    this.nearbyAmbulanceCount,
    this.smsDeliveryStatus,
    this.emergencyStatus,
    this.responseTimeSeconds,
    this.contactDeliveryStatuses,
  });

  SosAlert copyWith({
    String? id,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? googleMapsLink,
    String? alertType,
    String? status,
    int? contactsNotified,
    int? nearbyHospitalCount,
    int? nearbyPoliceCount,
    int? nearbyAmbulanceCount,
    String? smsDeliveryStatus,
    String? emergencyStatus,
    int? responseTimeSeconds,
    List<Map<String, dynamic>>? contactDeliveryStatuses,
  }) {
    return SosAlert(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapsLink: googleMapsLink ?? this.googleMapsLink,
      alertType: alertType ?? this.alertType,
      status: status ?? this.status,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      nearbyHospitalCount: nearbyHospitalCount ?? this.nearbyHospitalCount,
      nearbyPoliceCount: nearbyPoliceCount ?? this.nearbyPoliceCount,
      nearbyAmbulanceCount: nearbyAmbulanceCount ?? this.nearbyAmbulanceCount,
      smsDeliveryStatus: smsDeliveryStatus ?? this.smsDeliveryStatus,
      emergencyStatus: emergencyStatus ?? this.emergencyStatus,
      responseTimeSeconds: responseTimeSeconds ?? this.responseTimeSeconds,
      contactDeliveryStatuses: contactDeliveryStatuses ?? this.contactDeliveryStatuses,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'googleMapsLink': googleMapsLink,
        'alertType': alertType,
        'status': status,
        'contactsNotified': contactsNotified,
        'nearbyHospitalCount': nearbyHospitalCount,
        'nearbyPoliceCount': nearbyPoliceCount,
        'nearbyAmbulanceCount': nearbyAmbulanceCount,
        'smsDeliveryStatus': smsDeliveryStatus,
        'emergencyStatus': emergencyStatus,
        'responseTimeSeconds': responseTimeSeconds,
        'contactDeliveryStatuses': contactDeliveryStatuses,
      };

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    return SosAlert(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      googleMapsLink: json['googleMapsLink'] as String,
      alertType: json['alertType'] as String,
      status: json['status'] as String? ?? 'sent',
      contactsNotified: json['contactsNotified'] as int?,
      nearbyHospitalCount: json['nearbyHospitalCount'] as int?,
      nearbyPoliceCount: json['nearbyPoliceCount'] as int?,
      nearbyAmbulanceCount: json['nearbyAmbulanceCount'] as int?,
      smsDeliveryStatus: json['smsDeliveryStatus'] as String?,
      emergencyStatus: json['emergencyStatus'] as String?,
      responseTimeSeconds: json['responseTimeSeconds'] as int?,
      contactDeliveryStatuses: json['contactDeliveryStatuses'] != null 
          ? List<Map<String, dynamic>>.from(json['contactDeliveryStatuses'])
          : null,
    );
  }

  static String encode(List<SosAlert> alerts) =>
      json.encode(alerts.map((a) => a.toJson()).toList());

  static List<SosAlert> decode(String encoded) {
    final List<dynamic> list = json.decode(encoded);
    return list.map((e) => SosAlert.fromJson(e)).toList();
  }
}
