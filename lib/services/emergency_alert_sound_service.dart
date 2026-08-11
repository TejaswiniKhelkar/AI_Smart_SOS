import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Lightweight emergency alert sound service.
///
/// Generates a short sine-wave beep tone entirely in memory (no asset files
/// required) and repeats it at a configurable interval.  During the last
/// 10 seconds of the countdown the interval tightens so the beep cadence
/// conveys increasing urgency.
///
/// Usage:
/// ```dart
/// final sound = EmergencyAlertSoundService();
/// sound.start();           // begin repeating beep
/// sound.setUrgent(true);   // increase beep frequency
/// sound.stop();            // silence & release resources
/// ```
class EmergencyAlertSoundService {
  EmergencyAlertSoundService();

  final AudioPlayer _player = AudioPlayer();
  Timer? _beepTimer;
  bool _isPlaying = false;
  bool _isUrgent = false;

  // ── Tone parameters ────────────────────────────────────────────────────
  static const int _sampleRate = 44100;
  static const double _frequency = 880.0; // A5 — sharp, alerting tone
  static const double _urgentFrequency = 1200.0; // higher pitch for urgency
  static const double _durationSec = 0.15; // 150 ms beep
  static const double _volume = 0.7;

  // ── Repeat intervals ──────────────────────────────────────────────────
  static const Duration _normalInterval = Duration(milliseconds: 1200);
  static const Duration _urgentInterval = Duration(milliseconds: 500);

  Uint8List? _normalBeepWav;
  Uint8List? _urgentBeepWav;

  // ─────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────

  /// Begin playing the repeating beep.
  void start() {
    if (_isPlaying) return;
    _isPlaying = true;

    // Pre-generate both tones so switching is instant.
    _normalBeepWav ??= _generateBeepWav(_frequency);
    _urgentBeepWav ??= _generateBeepWav(_urgentFrequency);

    _player.setVolume(_volume);
    _playOnce(); // play immediately
    _scheduleNext();
  }

  /// Switch between normal and urgent (fast) beep cadence.
  void setUrgent(bool urgent) {
    if (_isUrgent == urgent) return;
    _isUrgent = urgent;
    if (_isPlaying) {
      _beepTimer?.cancel();
      _scheduleNext();
    }
  }

  /// Stop all beeps and release the player.
  void stop() {
    _isPlaying = false;
    _beepTimer?.cancel();
    _beepTimer = null;
    _player.stop();
  }

  /// Release underlying resources.  Call when the widget is disposed.
  void dispose() {
    stop();
    _player.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // INTERNALS
  // ─────────────────────────────────────────────────────────────────────

  void _playOnce() {
    if (!_isPlaying) return;
    final wav = _isUrgent ? _urgentBeepWav! : _normalBeepWav!;
    _player.play(BytesSource(wav));
  }

  void _scheduleNext() {
    final interval = _isUrgent ? _urgentInterval : _normalInterval;
    _beepTimer = Timer.periodic(interval, (_) => _playOnce());
  }

  /// Generates a minimal 16-bit mono PCM WAV file containing a sine-wave
  /// beep at the given [freq] Hz.  The result is fully self-contained and
  /// can be played directly via `BytesSource`.
  static Uint8List _generateBeepWav(double freq) {
    final numSamples = (_sampleRate * _durationSec).round();
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample

    // ── WAV header (44 bytes) + PCM data ──
    final totalSize = 44 + dataSize;
    final buffer = ByteData(totalSize);
    int offset = 0;

    void writeString(String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset++, s.codeUnitAt(i));
      }
    }

    void writeUint32(int v) {
      buffer.setUint32(offset, v, Endian.little);
      offset += 4;
    }

    void writeUint16(int v) {
      buffer.setUint16(offset, v, Endian.little);
      offset += 2;
    }

    // RIFF header
    writeString('RIFF');
    writeUint32(totalSize - 8); // file size minus RIFF header
    writeString('WAVE');

    // fmt sub-chunk
    writeString('fmt ');
    writeUint32(16); // sub-chunk size (PCM)
    writeUint16(1); // audio format = PCM
    writeUint16(1); // mono
    writeUint32(_sampleRate);
    writeUint32(_sampleRate * 2); // byte rate
    writeUint16(2); // block align
    writeUint16(16); // bits per sample

    // data sub-chunk
    writeString('data');
    writeUint32(dataSize);

    // ── Generate sine-wave samples with fade-in/out envelope ──
    const fadeLength = 0.01; // 10 ms fade to prevent clicks
    final fadeSamples = (_sampleRate * fadeLength).round();

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      double sample = sin(2.0 * pi * freq * t);

      // Apply envelope to prevent audible clicks
      if (i < fadeSamples) {
        sample *= i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        sample *= (numSamples - i) / fadeSamples;
      }

      // Scale to 16-bit range
      final pcmValue = (sample * 32767 * 0.8).round().clamp(-32768, 32767);
      buffer.setInt16(offset, pcmValue, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}
