import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// AI Voice Assistant for emergency announcements.
///
/// Provides queue-based TTS announcements during emergency flows.
/// Supports future multilingual expansion via [setLanguage].
class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true;

  /// Initialize the TTS engine.
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
      debugPrint('[VoiceAssistant] Initialized successfully');
    } catch (e) {
      debugPrint('[VoiceAssistant] Init failed: $e');
    }
  }

  /// Enable or disable voice guidance.
  void setEnabled(bool enabled) => _enabled = enabled;

  /// Change TTS language (future multilingual support).
  Future<void> setLanguage(String languageCode) async {
    await init();
    await _tts.setLanguage(languageCode);
  }

  /// Speak a custom message.
  Future<void> speak(String message) async {
    if (!_enabled) return;
    await init();
    try {
      await _tts.speak(message);
    } catch (e) {
      debugPrint('[VoiceAssistant] Speak error: $e');
    }
  }

  /// Stop any current speech.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // ── Pre-built Emergency Announcements ──────────────────────────────────

  Future<void> speakEmergencyDetected() =>
      speak('Emergency detected. SOS will be activated in 30 seconds.');

  Future<void> speakCountdown(int seconds) =>
      speak('$seconds seconds remaining.');

  Future<void> speakLocationAcquired() =>
      speak('Location acquired successfully.');

  Future<void> speakMessageSent() =>
      speak('Emergency message sent successfully.');

  Future<void> speakSOSCancelled() =>
      speak('Emergency cancelled. You are safe.');

  Future<void> speakSOSActivated() =>
      speak('SOS activated. Sending emergency alerts now.');

  /// Release resources.
  void dispose() {
    _tts.stop();
  }
}
