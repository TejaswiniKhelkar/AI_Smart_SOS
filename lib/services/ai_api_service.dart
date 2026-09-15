import 'dart:convert';
import 'package:http/http.dart' as http;

class AiApiService {
  AiApiService._();
  static final AiApiService _instance = AiApiService._();
  factory AiApiService() => _instance;

  static const String _envBackend = String.fromEnvironment('AI_BACKEND_URL');
  static const String _emulatorUrl = 'http://10.0.2.2:3000';
  static const String _lanUrl = 'http://192.168.31.74:3000'; // Replace with actual PC LAN IP if it changes

  String _activeBackend = _emulatorUrl; // fallback default
  
  String get backendUrl => _envBackend.isNotEmpty ? _envBackend : _activeBackend;

  Future<bool> ping() async {
    // If explicitly defined via dart-define, use it
    if (_envBackend.isNotEmpty) {
      return await _pingUrl(_envBackend);
    }
    
    // Check LAN IP first (works for physical devices on same WiFi, and emulator)
    if (await _pingUrl(_lanUrl)) {
      _activeBackend = _lanUrl;
      return true;
    }
    
    // Check emulator loopback
    if (await _pingUrl(_emulatorUrl)) {
      _activeBackend = _emulatorUrl;
      return true;
    }
    
    return false;
  }

  Future<bool> _pingUrl(String url) async {
    try {
      final uri = Uri.parse('$url/health');
      final r = await http.get(uri).timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> fetchResponse(
    String prompt, {
    Map<String, dynamic>? profile,
    Map<String, dynamic>? location,
    List<Map<String, dynamic>>? nearbyPlaces,
    String? language,
  }) async {
    final uri = Uri.parse('$backendUrl/api/assistant');
    final body = {
      'prompt': prompt,
      if (language != null) 'language': language,
      if (profile != null) 'profile': profile,
      if (location != null) 'location': location,
      if (nearbyPlaces != null) 'nearbyPlaces': nearbyPlaces,
    };

    final resp = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      final j = json.decode(resp.body) as Map<String, dynamic>;
      return (j['reply'] as String?) ?? '';
    }

    throw Exception('Backend returned ${resp.statusCode}');
  }
}
