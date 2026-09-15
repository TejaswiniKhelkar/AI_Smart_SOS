import 'dart:async';
import 'ai_api_service.dart';

/// AI Emergency Assistant service.
///
/// Provides a local fallback response system and is structured for
/// future AI API integration without affecting existing app logic.
class AiEmergencyAssistantService {
  AiEmergencyAssistantService._();

  static final AiEmergencyAssistantService _instance =
      AiEmergencyAssistantService._();

  factory AiEmergencyAssistantService() => _instance;

  Future<String> getResponse(
    String prompt, {
    Map<String, dynamic>? profile,
    Map<String, dynamic>? location,
    List<Map<String, dynamic>>? nearbyPlaces,
    String? language,
  }) async {
    final message = prompt.trim();
    if (message.isEmpty) {
      return _defaultResponse();
    }

    // Check backend reachability first
      try {
        final api = AiApiService();
        final reachable = await api.ping();
        if (reachable) {
          try {
            final response = await api.fetchResponse(
              message,
              profile: profile,
              location: location,
              nearbyPlaces: nearbyPlaces,
              language: language,
            );
            if (response.isNotEmpty) return response.trim();
          } catch (_) {
            // backend error — fall back locally
          }
        }
      } catch (_) {
        // ping failed — use local fallback
      }

    // Local fallback
    return Future.delayed(const Duration(milliseconds: 250), () {
      final fallback = _localResponse(message);
      if (fallback == _defaultResponse()) {
        throw Exception('API failed and no specific local fallback is available.');
      }
      return fallback;
    });
  }


  String _localResponse(String prompt) {
    final text = prompt.toLowerCase();

    if (text.contains('unconscious') || text.contains('unconscious person')) {
      return '''If someone is unconscious:

1. Check for responsiveness and breathing.
2. If they are not breathing, call emergency services and begin CPR if you are trained.
3. Keep the airway open and place them on their side if they are breathing.
4. Do not leave them alone. Use SOS if the situation is life-threatening.

This assistant does not replace professional medical help.''';
    }

    if (text.contains('breath') || text.contains('breathing') || text.contains('chest pain')) {
      return '''Breathing or chest concerns are urgent:

1. Call local emergency services immediately or use the SOS button.
2. Keep the person calm and seated if possible.
3. Loosen tight clothing and monitor breathing.
4. Do not delay care for chest pain or severe breathing difficulty.

Always prioritize professional responders over self-treatment.''';
    }

    if (text.contains('head injury') || text.contains('concussion') || text.contains('brain')) {
      return '''For a head injury:

1. Keep the person still and do not move their neck unless necessary.
2. Monitor for confusion, vomiting, or loss of consciousness.
3. Seek medical help right away if symptoms worsen.
4. Use SOS or call emergency services if the injury is severe.

A head injury should be evaluated by medical professionals.''';
    }

    if (text.contains('burn') || text.contains('burns')) {
      return '''For burns:

1. Remove the person from the source of heat.
2. Cool the area with running water for at least 10 minutes.
3. Cover the burn with a clean, dry cloth.
 4. Do not apply ice, creams, or adhesive dressings.

Seek professional care for large, deep, or chemical burns.''';
    }

    if (text.contains('fracture') || text.contains('broken') || text.contains('fractured')) {
      return '''For possible fractures:

1. Keep the injured limb still and supported.
2. Avoid moving the person unless they are in danger.
3. Use padding or a splint if available.
4. Get medical care as soon as possible.

Use emergency services if there is severe pain, deformity, or loss of sensation.''';
    }

    if (text.contains('bleed') || text.contains('bleeding')) {
      return '''For bleeding:

1. Apply firm pressure with a clean cloth or bandage.
2. Elevate the injured area if it is safe to do so.
3. Do not remove objects embedded in the wound.
4. Call emergency services or use SOS if bleeding is heavy or uncontrolled.

Major bleeding is a medical emergency.''';
    }

    if (text.contains('road accident') || text.contains('accident') || text.contains('car crash') || text.contains('collision')) {
      return '''After a road accident:

1. Ensure the scene is safe before moving.
2. Call emergency services or press SOS immediately.
3. Check for injuries and treat severe bleeding or breathing problems.
4. Share your exact location and describe the incident clearly.

Always rely on professional emergency responders after a crash.''';
    }

    if (text.contains('first aid') || text.contains('first-aid') || text.contains('help me heal') || text.contains('aid guidance')) {
      return '''First-aid guidance:

1. Stop bleeding with pressure and protect the airway.
2. Keep the injured person warm and comfortable.
3. Watch for changes in breathing, consciousness, or circulation.
4. Call emergency services if the injury is serious.

These steps are supportive, not a replacement for professional care.''';
    }

    if (text.contains('nearby') || text.contains('near me') || text.contains('location') || text.contains('ambulance') || text.contains('hospital') || text.contains('police')) {
      return '''Use nearby emergency support immediately:

1. Find the closest hospital, ambulance, or police station using the app.
2. Share your exact location and nature of the emergency.
3. Stay calm and follow the responder's instructions.
4. Notify your emergency contacts if you are able.

This app can help locate nearby services, but always contact local responders first.''';
    }

    if (text.contains('information') || text.contains('share') || text.contains('contacts') || text.contains('emergency contacts')) {
      return '''What to tell emergency responders:

1. Your exact location and any nearby landmarks.
2. The type of emergency and any injuries.
3. Whether the person is breathing and conscious.
4. If anyone is in severe pain, bleeding heavily, or not moving.

Also tell them if you have already pressed SOS or called for help.''';
    }

    if (text.contains('sos') || text.contains('when to use sos') || text.contains('use sos') || text.contains('press sos')) {
      return '''Use SOS when the situation is life-threatening or when you need immediate professional help:

1. Severe bleeding or uncontrolled bleeding.
2. Difficulty breathing or chest pain.
3. Unconsciousness or confusion.
4. Serious injuries from an accident.

SOS is a priority tool for emergencies, and it does not replace trained responders.''';
    }

    return _defaultResponse();
  }

  String _defaultResponse() {
    return '''I can help with emergency first-aid, accident steps, safety instructions, and what to tell your contacts.

If this is a life-threatening emergency, use the SOS button or call local emergency services immediately. I am not a substitute for doctors, police, or ambulance professionals.''';
  }
}
