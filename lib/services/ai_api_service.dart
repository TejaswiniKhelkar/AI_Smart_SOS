// ignore_for_file: use_null_aware_elements
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiApiService {
  AiApiService._();
  static final AiApiService _instance = AiApiService._();
  factory AiApiService() => _instance;

  // Configure the backend URL via dart-define or use sensible defaults.
  // For Android emulator use 10.0.2.2, for web or desktop use localhost.
  static const String _defaultBackend = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  String get backendUrl => _defaultBackend;

  Future<bool> ping() async {
    try {
      final uri = Uri.parse('$backendUrl/health');
      final r = await http.get(uri).timeout(const Duration(seconds: 3));
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
