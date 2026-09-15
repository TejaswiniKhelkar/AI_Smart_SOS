import 'dart:convert';

/// Alert recipient mode for SOS automation.
enum AlertRecipientMode {
  primaryOnly,
  priorityContacts,
  allContacts,
}

extension AlertRecipientModeLabel on AlertRecipientMode {
  String get label {
    switch (this) {
      case AlertRecipientMode.primaryOnly:
        return 'Primary Contact Only';
      case AlertRecipientMode.priorityContacts:
        return 'Priority Contacts';
      case AlertRecipientMode.allContacts:
        return 'All Saved Contacts';
    }
  }
}

/// Application-wide AI settings.
class AppSettings {
  final bool shareBloodGroup;
  final bool shareMedicalInfo;
  final bool shareLiveLocation;
  final bool autoSendSMS;
  final bool autoCallPrimary;
  final bool aiVoiceGuidance;
  final bool emergencyVibration;
  final bool darkTheme;
  final bool notificationSound;
  final String emergencyLanguage;
  final AlertRecipientMode alertRecipientMode;
  final bool accidentDetection;

  AppSettings({
    this.shareBloodGroup = true,
    this.shareMedicalInfo = true,
    this.shareLiveLocation = true,
    this.autoSendSMS = true,
    this.autoCallPrimary = false,
    this.aiVoiceGuidance = true,
    this.emergencyVibration = true,
    this.darkTheme = true,
    this.notificationSound = true,
    this.emergencyLanguage = 'English',
    this.alertRecipientMode = AlertRecipientMode.allContacts,
    this.accidentDetection = false,
  });

  AppSettings copyWith({
    bool? shareBloodGroup,
    bool? shareMedicalInfo,
    bool? shareLiveLocation,
    bool? autoSendSMS,
    bool? autoCallPrimary,
    bool? aiVoiceGuidance,
    bool? emergencyVibration,
    bool? darkTheme,
    bool? notificationSound,
    String? emergencyLanguage,
    AlertRecipientMode? alertRecipientMode,
    bool? accidentDetection,
  }) {
    return AppSettings(
      shareBloodGroup: shareBloodGroup ?? this.shareBloodGroup,
      shareMedicalInfo: shareMedicalInfo ?? this.shareMedicalInfo,
      shareLiveLocation: shareLiveLocation ?? this.shareLiveLocation,
      autoSendSMS: autoSendSMS ?? this.autoSendSMS,
      autoCallPrimary: autoCallPrimary ?? this.autoCallPrimary,
      aiVoiceGuidance: aiVoiceGuidance ?? this.aiVoiceGuidance,
      emergencyVibration: emergencyVibration ?? this.emergencyVibration,
      darkTheme: darkTheme ?? this.darkTheme,
      notificationSound: notificationSound ?? this.notificationSound,
      emergencyLanguage: emergencyLanguage ?? this.emergencyLanguage,
      alertRecipientMode: alertRecipientMode ?? this.alertRecipientMode,
      accidentDetection: accidentDetection ?? this.accidentDetection,
    );
  }

  Map<String, dynamic> toJson() => {
        'shareBloodGroup': shareBloodGroup,
        'shareMedicalInfo': shareMedicalInfo,
        'shareLiveLocation': shareLiveLocation,
        'autoSendSMS': autoSendSMS,
        'autoCallPrimary': autoCallPrimary,
        'aiVoiceGuidance': aiVoiceGuidance,
        'emergencyVibration': emergencyVibration,
        'darkTheme': darkTheme,
        'notificationSound': notificationSound,
        'emergencyLanguage': emergencyLanguage,
        'alertRecipientMode': alertRecipientMode.index,
        'accidentDetection': accidentDetection,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      shareBloodGroup: json['shareBloodGroup'] as bool? ?? true,
      shareMedicalInfo: json['shareMedicalInfo'] as bool? ?? true,
      shareLiveLocation: json['shareLiveLocation'] as bool? ?? true,
      autoSendSMS: json['autoSendSMS'] as bool? ?? true,
      autoCallPrimary: json['autoCallPrimary'] as bool? ?? false,
      aiVoiceGuidance: json['aiVoiceGuidance'] as bool? ?? true,
      emergencyVibration: json['emergencyVibration'] as bool? ?? true,
      darkTheme: json['darkTheme'] as bool? ?? true,
      notificationSound: json['notificationSound'] as bool? ?? true,
      emergencyLanguage: json['emergencyLanguage'] as String? ?? 'English',
      alertRecipientMode: AlertRecipientMode.values[
          (json['alertRecipientMode'] as int?) ??
              AlertRecipientMode.allContacts.index],
      accidentDetection: json['accidentDetection'] as bool? ?? false,
    );
  }

  static String encode(AppSettings settings) =>
      json.encode(settings.toJson());

  static AppSettings decode(String encoded) =>
      AppSettings.fromJson(json.decode(encoded));
}
