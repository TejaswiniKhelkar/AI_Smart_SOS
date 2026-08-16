import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/nearby_place.dart';
import '../services/ai_emergency_assistant_service.dart';
import '../services/location_service.dart';
import '../services/nearby_places_service.dart';
import '../services/ai_api_service.dart';
import '../services/assistant_settings_service.dart';
import '../services/profile_service.dart';
import 'ai_profile_screen.dart';
import 'emergency_contacts_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Emergency Command Center — Professional Dashboard Redesign
// ─────────────────────────────────────────────────────────────────────────────

class AiEmergencyDashboardScreen extends StatefulWidget {
  const AiEmergencyDashboardScreen({super.key});

  @override
  State<AiEmergencyDashboardScreen> createState() =>
      _AiEmergencyDashboardScreenState();
}

class _AiEmergencyDashboardScreenState
    extends State<AiEmergencyDashboardScreen> with TickerProviderStateMixin {
  // ── Chat state ──────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiEmergencyAssistantService _assistantService =
      AiEmergencyAssistantService();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  String? _lastFailedMessage;

  // ── Dashboard state ─────────────────────────────────────────────────────
  bool _backendAvailable = false;
  String _assistantLanguage = 'en';
  String _assistantTheme = 'system';
  String _currentLocationLabel = 'Fetching...';
  int _hospitalCount = 0;
  int _policeCount = 0;
  int _ambulanceCount = 0;
  int _rescueCount = 0;
  bool _nearbySummaryLoading = true;

  // ── Animation ───────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const List<String> _quickSuggestions = [
    'I had an accident',
    'First Aid',
    'I\'m injured',
    'Find emergency help',
    'What should I do?',
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);

    _messages.add(_ChatMessage(
      role: _MessageRole.ai,
      text:
          'Hello. I am your AI Emergency Assistant. I can help with first-aid guidance, accident response, nearby help, and what information to share. If this is life-threatening, please use the SOS button or call emergency services immediately.',
    ));

    _loadAssistantSettings();
    _loadDashboardSummary();
    _fadeCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AiApiService().ping().then((ok) {
      if (mounted) setState(() => _backendAvailable = ok);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  Future<void> _loadAssistantSettings() async {
    final lang = await AssistantSettingsService.getLanguage();
    final theme = await AssistantSettingsService.getTheme();
    if (mounted) {
      setState(() {
        _assistantLanguage = lang;
        _assistantTheme = theme;
      });
    }
  }

  Future<void> _loadDashboardSummary() async {
    try {
      final location = await LocationService.getLocationData();
      final places = await NearbyPlacesService.fetchNearbyPlaces(
        location.latitude,
        location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _currentLocationLabel =
            '${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)}';
        _hospitalCount =
            places.where((p) => p.type == PlaceType.hospital).length;
        _policeCount =
            places.where((p) => p.type == PlaceType.police).length;
        _ambulanceCount =
            places.where((p) => p.type == PlaceType.ambulance).length;
        _rescueCount = places.length;
        _nearbySummaryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLocationLabel = 'Unavailable';
        _nearbySummaryLoading = false;
      });
    }
  }

  // ── Chat logic (reuses existing service) ────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.user, text: message));
      _isSending = true;
      _inputController.clear();
    });
    _scrollToBottom();

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
            loc.latitude, loc.longitude);
        nearbyMap = places
            .take(6)
            .map((p) => {
                  'name': p.name,
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                  'type': p.type.toString(),
                  'distanceKm': p.distanceKm,
                })
            .toList();
      } catch (_) {}
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
    } catch (_) {
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

  // ── Nearby service bottom-sheet (reuses existing logic) ─────────────────

  Future<void> _showNearbyService(PlaceType? type, String title) async {
    try {
      final location = await LocationService.getLocationData();
      final allPlaces = await NearbyPlacesService.fetchNearbyPlaces(
          location.latitude, location.longitude);
      final filtered = type == null
          ? allPlaces
          : allPlaces.where((p) => p.type == type).toList();

      if (!mounted) return;

      if (filtered.isEmpty) {
        await _showInfoSheet(title,
            'No nearby emergency locations were found. Please try again or contact emergency services directly.');
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: AppTheme.headingSmall.copyWith(fontSize: 18)),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tap a result to open in maps.',
                      style: AppTheme.bodySmall),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 340,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final place = filtered[i];
                      return _nearbyPlaceTile(place);
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      await _showInfoSheet(title,
          'Unable to load nearby help. Please ensure location permission is enabled and try again.');
    }
  }

  Widget _nearbyPlaceTile(NearbyPlace place) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(borderRadius: 16, opacity: 0.08),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name,
                    style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(place.distanceText, style: AppTheme.bodySmall),
                if (place.address != null) ...[
                  const SizedBox(height: 2),
                  Text(place.address!,
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textMuted)),
                ],
              ],
            ),
          ),
          if (place.phone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.primaryCyan,
                  size: 20),
              onPressed: () => _callPhone(place.phone!),
            ),
          IconButton(
            icon: const Icon(Icons.navigation_rounded,
                color: AppTheme.successGreen, size: 20),
            onPressed: () => _launchMap(place),
          ),
        ],
      ),
    );
  }

  // ── Location bottom-sheet ───────────────────────────────────────────────

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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Text('Current Location',
                    style: AppTheme.headingSmall.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                Text(
                    'Lat: ${location.latitude.toStringAsFixed(6)}  ·  Lng: ${location.longitude.toStringAsFixed(6)}',
                    style: AppTheme.bodySmall),
                const SizedBox(height: 6),
                Text('Updated: ${location.timestamp}',
                    style: AppTheme.bodySmall),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _launchUrl(location.googleMapsLink),
                    child: const Text('Open in Maps'),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      await _showInfoSheet('Location unavailable',
          'Unable to retrieve your current location. Please enable location services and try again.');
    }
  }

  // ── Navigation helpers ──────────────────────────────────────────────────

  void _openEmergencyContacts() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
  }

  void _openMyProfile() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AiProfileScreen()));
  }

  void _showSosReminder() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Use SOS for serious emergencies',
              style: AppTheme.headingSmall),
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 16),
              Text(title,
                  style: AppTheme.headingSmall.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Text(message, style: AppTheme.bodySmall),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.textMuted.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _launchMap(NearbyPlace place) async {
    final url =
        LocationService.generateMapsLink(place.latitude, place.longitude);
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

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 860;
                        return Column(
                          children: [
                            Expanded(
                              child: isWide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                            flex: 6,
                                            child: _buildChatPanel()),
                                        const SizedBox(width: 14),
                                        Expanded(
                                            flex: 4,
                                            child:
                                                _buildEmergencyServicesPanel()),
                                      ],
                                    )
                                  : _buildMobileLayout(),
                            ),
                            const SizedBox(height: 10),
                            _buildQuickActions(),
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
      ),
    );
  }

  // ── Mobile layout (single column with expandable services) ─────────────

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Emergency services as a compact horizontal row on mobile
        _buildMobileServicesRow(),
        const SizedBox(height: 10),
        // Chat takes remaining space
        Expanded(child: _buildChatPanel()),
      ],
    );
  }

  Widget _buildMobileServicesRow() {
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          _buildMiniServiceCard(
            icon: Icons.local_hospital,
            label: 'Hospitals',
            count: _hospitalCount,
            color: AppTheme.successGreen,
            onTap: () =>
                _showNearbyService(PlaceType.hospital, 'Nearby Hospitals'),
          ),
          const SizedBox(width: 8),
          _buildMiniServiceCard(
            icon: Icons.local_police,
            label: 'Police',
            count: _policeCount,
            color: AppTheme.emergencyRed,
            onTap: () => _showNearbyService(
                PlaceType.police, 'Nearby Police Stations'),
          ),
          const SizedBox(width: 8),
          _buildMiniServiceCard(
            icon: Icons.local_shipping,
            label: 'Ambulance',
            count: _ambulanceCount,
            color: AppTheme.primaryCyan,
            onTap: () => _showNearbyService(
                PlaceType.ambulance, 'Nearby Ambulances'),
          ),
          const SizedBox(width: 8),
          _buildMiniServiceCard(
            icon: Icons.support_agent,
            label: 'Rescue',
            count: _rescueCount,
            color: AppTheme.warningAmber,
            onTap: () => _showNearbyService(
                null, 'Nearby Emergency Services'),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniServiceCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                _nearbySummaryLoading ? '...' : '$count',
                style: AppTheme.bodySmall.copyWith(
                    color: color, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TOP APP BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: AppTheme.glassBorder.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Hamburger
          Builder(builder: (ctx) {
            return GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surface.withValues(alpha: 0.8),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: const Icon(Icons.menu,
                    color: AppTheme.primaryCyan, size: 20),
              ),
            );
          }),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Emergency Assistant',
                    style: AppTheme.headingSmall.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('Command Center',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          // Status chip
          _buildStatusChip(
            icon: _backendAvailable ? Icons.wifi : Icons.wifi_off,
            label: _backendAvailable ? 'AI Ready' : 'Offline',
            color: _backendAvailable
                ? AppTheme.successGreen
                : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          // Location chip
          _buildStatusChip(
            icon: Icons.location_on,
            label: _currentLocationLabel,
            color: AppTheme.primaryCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: AppTheme.bodySmall
                  .copyWith(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LEFT PANEL — AI EMERGENCY CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Panel header
          _buildPanelHeader(
            icon: Icons.chat_bubble_outline,
            title: 'AI Emergency Chat',
            color: AppTheme.primaryCyan,
          ),
          // Messages
          Expanded(child: _buildMessageList()),
          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _buildLanguageSelector(),
          ),
          // Quick suggestion chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSuggestionChips(),
          ),
          const SizedBox(height: 6),
          // Input area
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildInputArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppTheme.glassBorder.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: AppTheme.cyanGradient,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: AppTheme.headingSmall.copyWith(fontSize: 14)),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _backendAvailable
                  ? AppTheme.successGreen
                  : AppTheme.textMuted,
              boxShadow: _backendAvailable
                  ? [
                      BoxShadow(
                        color: AppTheme.successGreen.withValues(alpha: 0.4),
                        blurRadius: 6,
                      )
                    ]
                  : [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildChatBubble(_messages[i]),
    );
  }

  Widget _buildChatBubble(_ChatMessage message) {
    final isUser = message.role == _MessageRole.user;
    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.cyanGradient,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.primaryCyan.withValues(alpha: 0.15)
                  : AppTheme.surfaceLight.withValues(alpha: 0.8),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser
                    ? AppTheme.primaryCyan.withValues(alpha: 0.2)
                    : AppTheme.glassBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              message.text,
              style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary, height: 1.45, fontSize: 14),
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.person, color: AppTheme.primaryCyan, size: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildLanguageSelector() {
    return Row(
      children: [
        const Icon(Icons.language, color: AppTheme.primaryCyan, size: 16),
        const SizedBox(width: 8),
        Text('Language',
            style: AppTheme.bodySmall
                .copyWith(color: AppTheme.textPrimary, fontSize: 12)),
        const Spacer(),
        _buildLangChip('EN', 'en'),
        const SizedBox(width: 6),
        _buildLangChip('HI', 'hi'),
        const SizedBox(width: 6),
        _buildLangChip('MR', 'mr'),
      ],
    );
  }

  Widget _buildLangChip(String label, String value) {
    final selected = _assistantLanguage == value;
    return GestureDetector(
      onTap: () async {
        if (selected) return;
        await AssistantSettingsService.setLanguage(value);
        if (mounted) setState(() => _assistantLanguage = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryCyan
              : AppTheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppTheme.primaryCyan : AppTheme.glassBorder),
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: selected ? Colors.black : AppTheme.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => _sendMessage(_quickSuggestions[i]),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Text(
                _quickSuggestions[i],
                style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
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
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type your emergency question...',
                    hintStyle: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textMuted.withValues(alpha: 0.7),
                        fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.cyanGradient,
                    boxShadow: AppTheme.neonGlow(AppTheme.primaryCyan,
                        intensity: 0.2),
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          if (_lastFailedMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text('Send failed',
                      style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.emergencyRed, fontSize: 11)),
                ),
                GestureDetector(
                  onTap: _isSending
                      ? null
                      : () {
                          final toRetry = _lastFailedMessage;
                          setState(() => _lastFailedMessage = null);
                          if (toRetry != null) _sendMessage(toRetry);
                        },
                  child: Text('Retry',
                      style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RIGHT PANEL — EMERGENCY SERVICES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmergencyServicesPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _buildPanelHeader(
            icon: Icons.shield_rounded,
            title: 'Emergency Services',
            color: AppTheme.emergencyRed,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildServiceCard(
                    icon: Icons.local_hospital,
                    label: 'Hospitals',
                    count: _hospitalCount,
                    color: AppTheme.successGreen,
                    statusIcon: Icons.check_circle_outline,
                    onTap: () => _showNearbyService(
                        PlaceType.hospital, 'Nearby Hospitals'),
                  ),
                  const SizedBox(height: 10),
                  _buildServiceCard(
                    icon: Icons.local_police,
                    label: 'Police Stations',
                    count: _policeCount,
                    color: AppTheme.emergencyRed,
                    statusIcon: Icons.security,
                    onTap: () => _showNearbyService(
                        PlaceType.police, 'Nearby Police Stations'),
                  ),
                  const SizedBox(height: 10),
                  _buildServiceCard(
                    icon: Icons.local_shipping,
                    label: 'Ambulances',
                    count: _ambulanceCount,
                    color: AppTheme.primaryCyan,
                    statusIcon: Icons.speed,
                    onTap: () => _showNearbyService(
                        PlaceType.ambulance, 'Nearby Ambulances'),
                  ),
                  const SizedBox(height: 10),
                  _buildServiceCard(
                    icon: Icons.support_agent,
                    label: 'Rescue Services',
                    count: _rescueCount,
                    color: AppTheme.warningAmber,
                    statusIcon: Icons.groups,
                    onTap: () => _showNearbyService(
                        null, 'Nearby Emergency Services'),
                  ),
                  const SizedBox(height: 14),
                  _buildInfoBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required IconData statusIcon,
    required VoidCallback onTap,
  }) {
    final statusText = _nearbySummaryLoading
        ? 'Scanning...'
        : count > 0
            ? '$count found nearby'
            : 'No data available';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, color: _nearbySummaryLoading ? AppTheme.textMuted : count > 0 ? AppTheme.successGreen : AppTheme.textMuted, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(statusText,
                            style: AppTheme.bodySmall.copyWith(
                                color: _nearbySummaryLoading ? AppTheme.textMuted : count > 0 ? AppTheme.successGreen : AppTheme.textMuted, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.open_in_new, color: color, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryCyan.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.health_and_safety_outlined,
                color: AppTheme.primaryCyan, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI guidance & quick access to nearby help. For life-threatening emergencies use SOS.',
              style: AppTheme.bodySmall
                  .copyWith(height: 1.4, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  QUICK ACTIONS BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _buildQuickActionBtn(
            icon: Icons.medical_services,
            label: 'First Aid',
            color: AppTheme.successGreen,
            onTap: () => _sendMessage('Give first aid guidance'),
          ),
          _buildQuickActionBtn(
            icon: Icons.my_location,
            label: 'Location',
            color: AppTheme.primaryCyan,
            onTap: _showCurrentLocation,
          ),
          _buildQuickActionBtn(
            icon: Icons.contacts,
            label: 'Contacts',
            color: AppTheme.primaryCyanDark,
            onTap: _openEmergencyContacts,
          ),
          _buildQuickActionBtn(
            icon: Icons.badge_outlined,
            label: 'Profile',
            color: AppTheme.warningAmber,
            onTap: _openMyProfile,
          ),
          _buildQuickActionBtn(
            icon: Icons.sos,
            label: 'SOS',
            color: AppTheme.emergencyRed,
            onTap: _showSosReminder,
            isSos: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isSos = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isSos
                ? AppTheme.emergencyRed.withValues(alpha: 0.12)
                : AppTheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSos
                  ? AppTheme.emergencyRed.withValues(alpha: 0.3)
                  : AppTheme.glassBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HAMBURGER DRAWER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryCyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppTheme.cyanGradient,
                    ),
                    child: const Icon(Icons.smart_toy_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Assistant',
                          style: AppTheme.headingSmall.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Emergency Command Center',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            // Menu items
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline,
                  color: AppTheme.primaryCyan),
              title:
                  Text('AI Assistant', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            ExpansionTile(
              leading:
                  const Icon(Icons.language, color: AppTheme.primaryCyan),
              title: Text('Language',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
              iconColor: AppTheme.textMuted,
              collapsedIconColor: AppTheme.textMuted,
              children: [
                _drawerRadio('English', 'en', _assistantLanguage,
                    (v) async {
                  await AssistantSettingsService.setLanguage(v);
                  if (mounted) setState(() => _assistantLanguage = v);
                }),
                _drawerRadio('Hindi', 'hi', _assistantLanguage, (v) async {
                  await AssistantSettingsService.setLanguage(v);
                  if (mounted) setState(() => _assistantLanguage = v);
                }),
                _drawerRadio('Marathi', 'mr', _assistantLanguage,
                    (v) async {
                  await AssistantSettingsService.setLanguage(v);
                  if (mounted) setState(() => _assistantLanguage = v);
                }),
              ],
            ),
            ExpansionTile(
              leading:
                  const Icon(Icons.palette, color: AppTheme.primaryCyan),
              title: Text('Theme',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
              iconColor: AppTheme.textMuted,
              collapsedIconColor: AppTheme.textMuted,
              children: [
                _drawerRadio('Light', 'light', _assistantTheme,
                    (v) async {
                  await AssistantSettingsService.setTheme(v);
                  if (mounted) setState(() => _assistantTheme = v);
                }),
                _drawerRadio('Dark', 'dark', _assistantTheme, (v) async {
                  await AssistantSettingsService.setTheme(v);
                  if (mounted) setState(() => _assistantTheme = v);
                }),
                _drawerRadio('System', 'system', _assistantTheme,
                    (v) async {
                  await AssistantSettingsService.setTheme(v);
                  if (mounted) setState(() => _assistantTheme = v);
                }),
              ],
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            ListTile(
              leading: const Icon(Icons.add, color: AppTheme.primaryCyan),
              title: Text('New Chat',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
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
              leading:
                  const Icon(Icons.delete, color: AppTheme.emergencyRed),
              title: Text('Clear Chat',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
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
              leading: const Icon(Icons.info_outline,
                  color: AppTheme.primaryCyan),
              title: Text('Emergency Assistant Info',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'AI Emergency Assistant',
                  children: const [
                    Text(
                        'This assistant provides short, actionable emergency guidance. It does not replace professional help.'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerRadio(
      String label, String value, String groupValue, Function(String) onChanged) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      title: Text(label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary)),
      activeColor: AppTheme.primaryCyan,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── Chat models ───────────────────────────────────────────────────────────

enum _MessageRole { user, ai }

class _ChatMessage {
  final _MessageRole role;
  final String text;

  _ChatMessage({required this.role, required this.text});
}
