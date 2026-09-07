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
    // Check backend availability
    AiApiService().ping().then((ok) {
      if (mounted) setState(() => _backendAvailable = ok);
    });
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
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      return Column(
                        children: [
                          Expanded(
                            child: isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 6, child: _buildMainColumn()),
                                      const SizedBox(width: 18),
                                      Expanded(flex: 4, child: _buildSidePanel()),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildMainColumn(),
                                      const SizedBox(height: 18),
                                      _buildSidePanel(),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 18),
                          _buildQuickActionRow(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              return GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surface.withValues(alpha: 0.8),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: const Icon(Icons.menu, color: AppTheme.primaryCyan, size: 22),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Emergency Assistant', style: AppTheme.headingMedium),
                const SizedBox(height: 4),
                Text('Command Center', style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _backendAvailable ? Icons.wifi : Icons.wifi_off,
                  color: _backendAvailable ? AppTheme.successGreen : AppTheme.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _backendAvailable ? 'AI Ready' : 'Offline',
                  style: AppTheme.bodySmall.copyWith(
                    color: _backendAvailable ? AppTheme.successGreen : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: AppTheme.primaryCyan, size: 18),
                const SizedBox(width: 8),
                Text(_currentLocationLabel, style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPanelHeader(
          icon: Icons.chat_bubble_outline,
          title: 'AI Emergency Chat',
          subtitle: 'Send urgent messages and get guidance fast.',
        ),
        const SizedBox(height: 14),
        Expanded(child: _buildMessageList()),
        const SizedBox(height: 12),
        _buildLanguageSelector(),
        const SizedBox(height: 12),
        _buildSuggestionChips(),
        const SizedBox(height: 12),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildSidePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPanelHeader(
          icon: Icons.shield_rounded,
          title: 'Emergency Services',
          subtitle: 'Compact status overview of nearby responders.',
        ),
        const SizedBox(height: 14),
        _buildEmergencyServiceCard(
          icon: Icons.local_hospital,
          label: 'Hospitals',
          count: _hospitalCount,
          color: AppTheme.successGreen,
          onTap: () => _showNearbyService(PlaceType.hospital, 'Nearby Hospitals'),
        ),
        const SizedBox(height: 12),
        _buildEmergencyServiceCard(
          icon: Icons.local_police,
          label: 'Police Stations',
          count: _policeCount,
          color: AppTheme.emergencyRed,
          onTap: () => _showNearbyService(PlaceType.police, 'Nearby Police Stations'),
        ),
        const SizedBox(height: 12),
        _buildEmergencyServiceCard(
          icon: Icons.local_shipping,
          label: 'Ambulances',
          count: _ambulanceCount,
          color: AppTheme.primaryCyan,
          onTap: () => _showNearbyService(PlaceType.ambulance, 'Nearby Ambulances'),
        ),
        const SizedBox(height: 12),
        _buildEmergencyServiceCard(
          icon: Icons.support_agent,
          label: 'Rescue Services',
          count: _rescueCount,
          color: AppTheme.warningAmber,
          onTap: () => _showNearbyService(null, 'Nearby Emergency Services'),
        ),
        const SizedBox(height: 18),
        _buildInfoBanner(),
      ],
    );
  }

  Widget _buildPanelHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: AppTheme.cyanGradient,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.headingSmall.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyServiceCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: AppTheme.glassDecoration(
          borderRadius: 20,
          opacity: 0.12,
          borderColor: AppTheme.glassBorder,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    _nearbySummaryLoading
                        ? 'Loading nearby status'
                        : count > 0
                            ? '$count nearby locations'
                            : 'No nearby data available',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.open_in_new, color: AppTheme.textPrimary, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: 18,
        opacity: 0.08,
        borderColor: AppTheme.primaryCyan.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withValues(alpha: 0.14),
            ),
            child: const Icon(Icons.health_and_safety_outlined,
                color: AppTheme.primaryCyan, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This command center provides AI emergency guidance and quick access to nearby help while keeping the main app emergency workflow intact.',
              style: AppTheme.bodySmall.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final itemCount = _messages.length + (_isSending ? 1 : 0);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _messages.length) {
            return _buildTypingIndicator();
          }
          final message = _messages[index];
          return _buildChatBubble(message);
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final dark = _isDarkTheme(context);
    final bubbleColor = dark ? AppTheme.surfaceLight : Colors.white;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
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
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryCyan,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI is typing...',
                style: AppTheme.bodyMedium.copyWith(
                  color: dark ? AppTheme.textSecondary : AppTheme.textPrimary,
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
    final dark = _isDarkTheme(context);
    final bubbleColor = isUser
      ? AppTheme.primaryCyan.withValues(alpha: 0.18)
      : (dark ? AppTheme.surfaceLight : Colors.white);
    final textColor = isUser ? AppTheme.textPrimary : (dark ? AppTheme.textSecondary : AppTheme.textPrimary);
    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Text(
              message.text,
              style: AppTheme.bodyMedium.copyWith(color: textColor, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.glassDecoration(
        borderRadius: 18,
        opacity: 0.13,
        borderColor: AppTheme.glassBorder,
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: AppTheme.primaryCyan, size: 20),
          const SizedBox(width: 12),
          Text('Language', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
          const Spacer(),
          _buildLanguageChip('English', 'en'),
          const SizedBox(width: 10),
          _buildLanguageChip('Hindi', 'hi'),
          const SizedBox(width: 10),
          _buildLanguageChip('Marathi', 'mr'),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label, String value) {
    final selected = _assistantLanguage == value;
    return GestureDetector(
      onTap: () async {
        if (selected) return;
        await AssistantSettingsService.setLanguage(value);
        if (mounted) setState(() => _assistantLanguage = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryCyan : AppTheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppTheme.primaryCyan : AppTheme.glassBorder),
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: selected ? Colors.black : AppTheme.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final label = _quickSuggestions[index];
          return GestureDetector(
            onTap: () => _sendMessage(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showNearbyService(PlaceType? type, String title) async {
    try {
      final location = await LocationService.getLocationData();
      final allPlaces = await NearbyPlacesService.fetchNearbyPlaces(
        location.latitude,
        location.longitude,
      );
      final filtered = type == null
          ? allPlaces
          : allPlaces.where((place) => place.type == type).toList();

      if (!mounted) return;

      if (filtered.isEmpty) {
        await _showInfoSheet(
          title,
          'No nearby emergency locations were found. Please try again or contact emergency services directly.',
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppTheme.headingSmall.copyWith(
                                fontSize: 18,
                              )),
                          const SizedBox(height: 4),
                          Text(
                            'Tap a result to open the location in maps.',
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 340,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final place = filtered[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: AppTheme.glassDecoration(
                          borderRadius: 18,
                          opacity: 0.08,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(place.name,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              )),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(place.distanceText,
                                  style: AppTheme.bodySmall),
                              if (place.address != null) ...[
                                const SizedBox(height: 4),
                                Text(place.address!, style: AppTheme.bodySmall),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (place.phone != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.phone,
                                    color: AppTheme.primaryCyan,
                                  ),
                                  onPressed: () => _callPhone(place.phone!),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.navigation_rounded,
                                  color: AppTheme.successGreen,
                                ),
                                onPressed: () => _launchMap(place),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      await _showInfoSheet(
        title,
        'Unable to load nearby help. Please ensure location permission is enabled and try again.',
      );
    }
  }

  Future<void> _showCurrentLocation() async {
    try {
      final location = await LocationService.getLocationData();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Current Location', style: AppTheme.headingSmall.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                Text('Latitude: ${location.latitude.toStringAsFixed(6)}', style: AppTheme.bodySmall),
                const SizedBox(height: 6),
                Text('Longitude: ${location.longitude.toStringAsFixed(6)}', style: AppTheme.bodySmall),
                const SizedBox(height: 6),
                Text('Last updated: ${location.timestamp}', style: AppTheme.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _launchUrl(location.googleMapsLink),
                        child: const Text('Open in Maps'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      await _showInfoSheet(
        'Location unavailable',
        'Unable to retrieve your current location. Please enable location services and try again.',
      );
    }
  }

  void _openEmergencyContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
    );
  }

  void _openMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiProfileScreen()),
    );
  }

  void _showSosReminder() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Use SOS for serious emergencies', style: AppTheme.headingSmall),
          content: Text(
            'For life-threatening situations, press the main SOS button on the home screen or call emergency services immediately. This assistant is for guidance and does not replace professional responders.',
            style: AppTheme.bodySmall,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Go Home'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInfoSheet(String title, String message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTheme.headingSmall.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Text(message, style: AppTheme.bodySmall),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchMap(NearbyPlace place) async {
    final url = LocationService.generateMapsLink(place.latitude, place.longitude);
    await _launchUrl(url);
  }

  Future<void> _callPhone(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type your emergency question',
                    hintStyle: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textMuted.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isSending ? null : _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isSending
                    ? null
                    : () => _sendMessage(_inputController.text),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.cyanGradient,
                    boxShadow: AppTheme.neonGlow(AppTheme.primaryCyan,
                        intensity: 0.25),
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
          if (_lastFailedMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Last send failed', style: AppTheme.bodySmall.copyWith(color: AppTheme.emergencyRed)),
                ),
                TextButton(
                  onPressed: _isSending ? null : () {
                    final toRetry = _lastFailedMessage;
                    setState(() => _lastFailedMessage = null);
                    if (toRetry != null) _sendMessage(toRetry);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Text('AI Assistant', style: AppTheme.headingMedium),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('AI Assistant'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            ExpansionTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              children: [
                RadioListTile<String>(
                  value: 'en',
                  groupValue: _assistantLanguage,
                  title: const Text('English'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await AssistantSettingsService.setLanguage(value);
                    if (mounted) setState(() => _assistantLanguage = value);
                  },
                ),
                RadioListTile<String>(
                  value: 'hi',
                  groupValue: _assistantLanguage,
                  title: const Text('Hindi'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await AssistantSettingsService.setLanguage(value);
                    if (mounted) setState(() => _assistantLanguage = value);
                  },
                ),
                RadioListTile<String>(
                  value: 'mr',
                  groupValue: _assistantLanguage,
                  title: const Text('Marathi'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await AssistantSettingsService.setLanguage(value);
                    if (mounted) setState(() => _assistantLanguage = value);
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              children: [
                RadioListTile<String>(
                  value: 'system',
                  groupValue: _assistantTheme,
                  title: const Text('System'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await AssistantSettingsService.setTheme(value);
                    if (mounted) setState(() => _assistantTheme = value);
                  },
                ),
                RadioListTile<String>(
                  value: 'light',
                  groupValue: _assistantTheme,
                  title: const Text('Light'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await AssistantSettingsService.setTheme(value);
                    if (mounted) setState(() => _assistantTheme = value);
                  },
                ),
                RadioListTile<String>(
                  value: 'dark',
                  groupValue: _assistantTheme,
                  title: const Text('Dark'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await AssistantSettingsService.setTheme(value);
                    if (mounted) setState(() => _assistantTheme = value);
                  },
                ),
              ],
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _messages.clear();
                  _messages.add(_ChatMessage(
                    role: _MessageRole.ai,
                    text:
                        'Hello. I am your AI Emergency Assistant. I can help with first-aid guidance, accident response, nearby help, and what information to share. If this is life-threatening, please use the SOS button or call emergency services immediately.',
                  ));
                  _lastFailedMessage = null;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Clear Chat'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _messages.clear();
                  _messages.add(_ChatMessage(
                    role: _MessageRole.ai,
                    text:
                        'Hello. I am your AI Emergency Assistant. I can help with first-aid guidance, accident response, nearby help, and what information to share. If this is life-threatening, please use the SOS button or call emergency services immediately.',
                  ));
                  _lastFailedMessage = null;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Emergency Assistant Info'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'AI Emergency Assistant',
                  children: const [
                    Text('This assistant provides short, actionable emergency guidance. It does not replace professional help.'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickActionButton(
          icon: Icons.medical_services,
          label: 'First Aid',
          color: AppTheme.successGreen,
          onTap: () => _sendMessage('Give first aid guidance'),
        ),
        _buildQuickActionButton(
          icon: Icons.my_location,
          label: 'Live Location',
          color: AppTheme.primaryCyan,
          onTap: _showCurrentLocation,
        ),
        _buildQuickActionButton(
          icon: Icons.contacts,
          label: 'Emergency Contacts',
          color: AppTheme.primaryCyanDark,
          onTap: _openEmergencyContacts,
        ),
        _buildQuickActionButton(
          icon: Icons.badge_outlined,
          label: 'My Profile',
          color: AppTheme.warningAmber,
          onTap: _openMyProfile,
        ),
        _buildQuickActionButton(
          icon: Icons.sos,
          label: 'SOS',
          color: AppTheme.emergencyRed,
          onTap: _showSosReminder,
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDarkTheme(BuildContext context) {
    if (_assistantTheme == 'dark') return true;
    if (_assistantTheme == 'light') return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }
}

enum _MessageRole { user, ai }

class _ChatMessage {
  final _MessageRole role;
  final String text;

  _ChatMessage({required this.role, required this.text});
}
