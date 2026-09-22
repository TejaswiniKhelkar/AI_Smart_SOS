import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/nearby_place.dart';
import '../services/ai_emergency_assistant_service.dart';
import '../services/location_service.dart';
import '../services/nearby_places_service.dart';
import '../services/profile_service.dart';
import '../services/ai_api_service.dart';
import '../services/assistant_settings_service.dart';
import '../services/network_service.dart';
import 'ai_profile_screen.dart';
import 'emergency_contacts_screen.dart';

class AiEmergencyAssistantScreen extends StatefulWidget {
  final bool clearOnOpen;
  const AiEmergencyAssistantScreen({super.key, this.clearOnOpen = false});

  @override
  State<AiEmergencyAssistantScreen> createState() =>
      _AiEmergencyAssistantScreenState();
}

class _AiEmergencyAssistantScreenState
    extends State<AiEmergencyAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiEmergencyAssistantService _assistantService =
      AiEmergencyAssistantService();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _backendAvailable = false;
  String _assistantLanguage = 'en';
  String _assistantTheme = 'system';
  String _currentLocationLabel = 'Fetching location...';
  String? _lastFailedMessage;
  int _hospitalCount = 0;
  int _policeCount = 0;
  int _ambulanceCount = 0;
  int _rescueCount = 0;
  bool _nearbySummaryLoading = true;

  static const List<String> _quickSuggestions = [
    'I had an accident',
    'First Aid',
    'Nearby Hospital',
    'Emergency Help',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.clearOnOpen) _messages.clear();
    _messages.add(_ChatMessage(
      role: _MessageRole.ai,
      text:
          'Hello. I am your AI Emergency Assistant. I can help with first-aid guidance, accident response, nearby help, and what information to share. If this is life-threatening, please use the SOS button or call emergency services immediately.',
    ));
    _loadAssistantSettings();
    _loadDashboardSummary();
  }

  Future<void> _loadAssistantSettings() async {
    final lang = await AssistantSettingsService.getLanguage();
    final theme = await AssistantSettingsService.getTheme();
    if (mounted) setState(() {
      _assistantLanguage = lang;
      _assistantTheme = theme;
    });
  }

  Future<void> _loadDashboardSummary() async {
    try {
      final location = await LocationService.getLocationData();
      final places = await NearbyPlacesService.fetchNearbyPlaces(
        location.latitude,
        location.longitude,
      );
      if (!mounted) return;
      final hospitals = places.where((place) => place.type == PlaceType.hospital).length;
      final police = places.where((place) => place.type == PlaceType.police).length;
      final ambulances = places.where((place) => place.type == PlaceType.ambulance).length;
      final rescue = places.length;
      setState(() {
        _currentLocationLabel = '${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)}';
        _hospitalCount = hospitals;
        _policeCount = police;
        _ambulanceCount = ambulances;
        _rescueCount = rescue;
        _nearbySummaryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLocationLabel = 'Location unavailable';
        _nearbySummaryLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkBackendAvailability();
  }
  
  Future<void> _checkBackendAvailability() async {
    if (!NetworkService().isOnline) {
      if (mounted) setState(() => _backendAvailable = false);
      return;
    }
    
    final ok = await AiApiService().ping();
    if (mounted) setState(() => _backendAvailable = ok);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.user, text: message));
      _isSending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    // Collect contextual data (profile, location, nearby places) if available
    Map<String, dynamic>? profileMap;
    Map<String, dynamic>? locationMap;
    List<Map<String, dynamic>>? nearbyMap;

    try {
      final profile = await ProfileService.getProfile();
      profileMap = profile.toJson();
    } catch (_) {}

    try {
      final loc = await LocationService.getLocationData();
      locationMap = {
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'googleMapsLink': loc.googleMapsLink,
      };

      try {
        final places = await NearbyPlacesService.fetchNearbyPlaces(
          loc.latitude,
          loc.longitude,
        );
        nearbyMap = places.take(6).map((p) => {
              'name': p.name,
              'latitude': p.latitude,
              'longitude': p.longitude,
              'type': p.type.toString(),
              'distanceKm': p.distanceKm,
            }).toList();
      } catch (_) {
        nearbyMap = null;
      }
    } catch (_) {}

    try {
      final response = await _assistantService.getResponse(
        message,
        profile: profileMap,
        location: locationMap,
        nearbyPlaces: nearbyMap,
        language: _assistantLanguage,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: _MessageRole.ai, text: response));
        _isSending = false;
        _lastFailedMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
            role: _MessageRole.ai,
            text:
                'Unable to reach AI service. Please check your network or try again.'));
        _isSending = false;
        _lastFailedMessage = message;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildSuggestionChips(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildMessageList()),
                  ],
                ),
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppTheme.primaryCyan, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Emergency Assistant',
                  style: AppTheme.headingSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _backendAvailable ? AppTheme.successGreen : AppTheme.emergencyRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _backendAvailable ? 'Online / Ready to help' : 'Backend Offline',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: Text(
              'AI POWERED',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryCyan,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _quickSuggestions[index];
          return GestureDetector(
            onTap: () => _sendMessage(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    final itemCount = _messages.length + (_isSending ? 1 : 0);
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }
        final message = _messages[index];
        return _buildChatBubble(message);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryCyan,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI is typing...',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(_ChatMessage message) {
    final isUser = message.role == _MessageRole.user;
    
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isUser ? AppTheme.primaryCyan : AppTheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
              border: isUser ? null : Border.all(color: AppTheme.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: AppTheme.bodyMedium.copyWith(
                color: isUser ? Colors.white : AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_lastFailedMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                final retryMsg = _lastFailedMessage!;
                setState(() => _lastFailedMessage = null);
                _sendMessage(retryMsg);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: AppTheme.emergencyRed, size: 16),
                  const SizedBox(width: 4),
                  Text('Tap to retry last message', style: AppTheme.bodySmall.copyWith(color: AppTheme.emergencyRed)),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: _backendAvailable,
              decoration: InputDecoration(
                hintText: _backendAvailable ? 'Type your emergency...' : 'AI Assistant requires internet.',
                hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              onSubmitted: _backendAvailable ? _sendMessage : null,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _backendAvailable ? _sendMessage(_inputController.text) : null,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _backendAvailable ? AppTheme.primaryCyan : AppTheme.glassBorder,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, color: _backendAvailable ? Colors.white : AppTheme.textMuted, size: 24),
            ),
          ),
        ],
      ),
        )
      ],
    );
  }
}

enum _MessageRole {
  user,
  ai,
}

class _ChatMessage {
  final String text;
  final _MessageRole role;

  _ChatMessage({required this.text, required this.role});
}
