import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../widgets/reusable_widgets.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  AppSettings _settings = AppSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  Future<void> _updateSetting(AppSettings updated) async {
    setState(() => _settings = updated);
    await SettingsService.saveSettings(updated);
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Settings', style: AppTheme.headingSmall),
        content: Text('Reset all settings to defaults?',
            style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.emergencyRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SettingsService.resetSettings();
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ParticleBackground(
          seed: 88,
          child: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryCyan))
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Column(
                              children: [
                                _buildSharingSection(),
                                const SizedBox(height: 16),
                                _buildAutomationSection(),
                                const SizedBox(height: 16),
                                _buildRecipientModeSection(),
                                const SizedBox(height: 16),
                                _buildVoiceAlertsSection(),
                                const SizedBox(height: 16),
                                _buildAppearanceSection(),
                                const SizedBox(height: 24),
                                _buildResetButton(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.glassWhite,
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: AppTheme.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI SETTINGS',
                  style: AppTheme.headingSmall.copyWith(fontSize: 14)),
              Text('Configure your emergency preferences',
                  style: AppTheme.bodySmall.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sharing Section ────────────────────────────────────────────────────

  Widget _buildSharingSection() {
    return GlassCard(
      borderColor: AppTheme.primaryCyan.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share_outlined,
                  color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text('EMERGENCY SHARING',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryCyan,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          _buildToggle(
            icon: Icons.bloodtype_outlined,
            title: 'Share Blood Group',
            subtitle: 'Include blood group in emergency alerts',
            value: _settings.shareBloodGroup,
            color: AppTheme.emergencyRed,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(shareBloodGroup: v)),
          ),
          _buildDivider(),
          _buildToggle(
            icon: Icons.medical_services_outlined,
            title: 'Share Medical Info',
            subtitle: 'Include allergies & conditions in alerts',
            value: _settings.shareMedicalInfo,
            color: AppTheme.warningAmber,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(shareMedicalInfo: v)),
          ),
          _buildDivider(),
          _buildToggle(
            icon: Icons.location_on_outlined,
            title: 'Share Live Location',
            subtitle: 'Include GPS coordinates in SOS',
            value: _settings.shareLiveLocation,
            color: AppTheme.successGreen,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(shareLiveLocation: v)),
          ),
        ],
      ),
    );
  }

  // ── Automation Section ─────────────────────────────────────────────────

  Widget _buildAutomationSection() {
    return GlassCard(
      borderColor: AppTheme.warningAmber.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_mode, color: AppTheme.warningAmber, size: 20),
              const SizedBox(width: 8),
              Text('AUTOMATION',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningAmber,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          _buildToggle(
            icon: Icons.sms_outlined,
            title: 'Auto-Send SMS',
            subtitle: 'Automatically send SMS during SOS',
            value: _settings.autoSendSMS,
            color: AppTheme.primaryCyan,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(autoSendSMS: v)),
          ),
          _buildDivider(),
          _buildToggle(
            icon: Icons.phone_in_talk_outlined,
            title: 'Auto-Call Primary',
            subtitle: 'Auto-call primary contact during SOS',
            value: _settings.autoCallPrimary,
            color: AppTheme.successGreen,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(autoCallPrimary: v)),
          ),
        ],
      ),
    );
  }

  // ── Recipient Mode ─────────────────────────────────────────────────────

  Widget _buildRecipientModeSection() {
    return GlassCard(
      borderColor: const Color(0xFF448AFF).withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined,
                  color: Color(0xFF448AFF), size: 20),
              const SizedBox(width: 8),
              Text('ALERT RECIPIENTS',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF448AFF),
                  )),
            ],
          ),
          const SizedBox(height: 16),
          ...AlertRecipientMode.values.map((mode) {
            final selected = _settings.alertRecipientMode == mode;
            return GestureDetector(
              onTap: () =>
                  _updateSetting(_settings.copyWith(alertRecipientMode: mode)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF448AFF).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF448AFF).withValues(alpha: 0.4)
                        : AppTheme.glassBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? const Color(0xFF448AFF)
                          : AppTheme.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(mode.label,
                        style: AppTheme.bodyMedium.copyWith(
                          color: selected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Voice & Alerts ─────────────────────────────────────────────────────

  Widget _buildVoiceAlertsSection() {
    return GlassCard(
      borderColor: AppTheme.successGreen.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over_outlined,
                  color: AppTheme.successGreen, size: 20),
              const SizedBox(width: 8),
              Text('VOICE & ALERTS',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successGreen,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          _buildToggle(
            icon: Icons.mic,
            title: 'AI Voice Guidance',
            subtitle: 'Voice announcements during emergency',
            value: _settings.aiVoiceGuidance,
            color: AppTheme.primaryCyan,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(aiVoiceGuidance: v)),
          ),
          _buildDivider(),
          _buildToggle(
            icon: Icons.vibration,
            title: 'Emergency Vibration',
            subtitle: 'Vibrate during emergency alerts',
            value: _settings.emergencyVibration,
            color: AppTheme.warningAmber,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(emergencyVibration: v)),
          ),
          _buildDivider(),
          _buildToggle(
            icon: Icons.notifications_active_outlined,
            title: 'Notification Sound',
            subtitle: 'Play sound for emergency alerts',
            value: _settings.notificationSound,
            color: AppTheme.emergencyRed,
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(notificationSound: v)),
          ),
        ],
      ),
    );
  }

  // ── Appearance ─────────────────────────────────────────────────────────

  Widget _buildAppearanceSection() {
    return GlassCard(
      borderColor: const Color(0xFFE040FB).withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined,
                  color: Color(0xFFE040FB), size: 20),
              const SizedBox(width: 8),
              Text('APPEARANCE',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE040FB),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          _buildToggle(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Theme',
            subtitle: 'Premium dark emergency interface',
            value: _settings.darkTheme,
            color: const Color(0xFFE040FB),
            onChanged: (v) =>
                _updateSetting(_settings.copyWith(darkTheme: v)),
          ),
        ],
      ),
    );
  }

  // ── Reset ──────────────────────────────────────────────────────────────

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: _resetSettings,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.emergencyRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.emergencyRed.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restore,
                color: AppTheme.emergencyRed.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 10),
            Text('Reset to Defaults',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.emergencyRed.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }

  // ── Shared Helpers ─────────────────────────────────────────────────────

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                Text(subtitle,
                    style: AppTheme.bodySmall.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppTheme.glassBorder.withValues(alpha: 0.5),
      height: 1,
    );
  }
}
