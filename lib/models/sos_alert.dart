import 'dart:convert';

class SosAlert {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String googleMapsLink;
  final String alertType; // 'SOS', 'Police', 'Ambulance', 'Fire'
  final String status; // 'sent', 'cancelled'

  SosAlert({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.googleMapsLink,
    required this.alertType,
    this.status = 'sent',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'googleMapsLink': googleMapsLink,
        'alertType': alertType,
        'status': status,
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
    );
  }

  static String encode(List<SosAlert> alerts) =>
      json.encode(alerts.map((a) => a.toJson()).toList());

  static List<SosAlert> decode(String encoded) {
    final List<dynamic> list = json.decode(encoded);
    return list.map((e) => SosAlert.fromJson(e)).toList();
  }
}
