// ignore_for_file: use_null_aware_elements
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiApiService {
  AiApiService._();
  static final AiApiService _instance = AiApiService._();
  factory AiApiService() => _instance;

  // Retrieve the API key via dart-define to avoid hardcoding secrets.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<bool> ping() async {
    // If the API key is provided, we consider the backend reachable.
    return _apiKey.isNotEmpty;
  }

  Future<String> fetchResponse(
    String prompt, {
    Map<String, dynamic>? profile,
    Map<String, dynamic>? location,
    List<Map<String, dynamic>>? nearbyPlaces,
    String? language,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('API key not configured in the app.');
    }

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey');

    // Build the system context
    final systemPrompt = StringBuffer();
    systemPrompt.writeln(
        'You are an emergency response assistant. Provide short, clear, actionable guidance. '
        'Always recommend contacting professional services or using SOS for life-threatening emergencies. '
        'Do not claim to replace doctors, police, or ambulance services.');

    if (language != null) {
      final langMap = {'en': 'English', 'hi': 'Hindi', 'mr': 'Marathi'};
      final langName = langMap[language] ?? language;
      systemPrompt.writeln('Respond in $langName. Keep answers short and actionable.');
    }
    if (profile != null) {
      systemPrompt.writeln('User profile: ${json.encode(profile)}');
    }
    if (location != null) {
      systemPrompt.writeln('Location: ${json.encode(location)}');
    }
    if (nearbyPlaces != null) {
      systemPrompt.writeln('Nearby places: ${json.encode(nearbyPlaces)}');
    }

    final body = {
      "systemInstruction": {
        "parts": [
          {"text": systemPrompt.toString()}
        ]
      },
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.2,
        "maxOutputTokens": 300,
      }
    };

    final resp = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      try {
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      } catch (e) {
        throw Exception('Failed to parse AI response: $e');
      }
    } else {
      final errorText = resp.body;
      throw Exception('AI API returned ${resp.statusCode}: $errorText');
    }
  }
}
