import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/readiness_service.dart';
import '../services/profile_service.dart';
import '../services/health_service.dart';
import '../services/contact_service.dart';
import '../services/alert_service.dart';
import '../widgets/reusable_widgets.dart';
import 'ai_profile_screen.dart';
import 'ai_health_screen.dart';
import 'ice_card_screen.dart';
import 'document_locker_screen.dart';
import 'ai_settings_screen.dart';
import 'ai_safety_insights_screen.dart';

class AiDashboardScreen extends StatefulWidget {
  const AiDashboardScreen({super.key});

  @override
  State<AiDashboardScreen> createState() => _AiDashboardScreenState();
}

class _AiDashboardScreenState extends State<AiDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _readinessScore = 0;
  List<ReadinessItem> _readinessItems = [];
  int _profilePercent = 0;
  int _healthPercent = 0;
  int _contactCount = 0;
  int _alertCount = 0;
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
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final readiness = await ReadinessService.calculate();
    final profile = await ProfileService.getProfile();
    final health = await HealthService.getProfile();
    final contactCount = await ContactService.getContactCount();
    final alerts = await AlertService.getAlerts();

    setState(() {
      _readinessScore = readiness.score;
      _readinessItems = readiness.items;
      _profilePercent = profile.completionPercent;
      _healthPercent = health.completionPercent;
      _contactCount = contactCount;
      _alertCount = alerts.length;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryCyan))
        : FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadinessCard(),
                  const SizedBox(height: 20),
                  _buildQuickAccessGrid(),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  _buildSuggestionsCard(),
                  const SizedBox(height: 20),
                  _buildSafetyTips(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
  }

  // ── Readiness Score Card ───────────────────────────────────────────────

  Widget _buildReadinessCard() {
    Color scoreColor;
    String scoreLabel;
    if (_readinessScore >= 80) {
      scoreColor = AppTheme.successGreen;
      scoreLabel = 'Excellent';
    } else if (_readinessScore >= 50) {
      scoreColor = AppTheme.warningAmber;
      scoreLabel = 'Moderate';
    } else {
      scoreColor = AppTheme.emergencyRed;
      scoreLabel = 'Needs Attention';
    }

    return GlassCard(
      borderColor: scoreColor.withValues(alpha: 0.2),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedProgressRing(
                progress: _readinessScore / 100,
                size: 90,
                strokeWidth: 7,
                color: scoreColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_readinessScore',
                        style: AppTheme.headingLarge.copyWith(
                          color: scoreColor,
                          fontSize: 28,
                        )),
                    Text('%',
                        style: AppTheme.bodySmall.copyWith(
                          color: scoreColor.withValues(alpha: 0.7),
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: AppTheme.cyanGradient,
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text('AI READINESS',
                            style: AppTheme.bodySmall.copyWith(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryCyan,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Emergency Readiness Score',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(scoreLabel,
                          style: AppTheme.bodySmall.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Access Grid ──────────────────────────────────────────────────

  Widget _buildQuickAccessGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'QUICK ACCESS',
          icon: Icons.grid_view_rounded,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTile(
                icon: Icons.person_outline,
                label: 'Profile',
                color: AppTheme.primaryCyan,
                subtitle: '$_profilePercent%',
                onTap: () => _navigate(const AiProfileScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTile(
                icon: Icons.medical_services_outlined,
                label: 'Health',
                color: AppTheme.successGreen,
                subtitle: '$_healthPercent%',
                onTap: () => _navigate(const AiHealthScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTile(
                icon: Icons.credit_card,
                label: 'ICE Card',
                color: AppTheme.emergencyRed,
                subtitle: 'View',
                onTap: () => _navigate(const IceCardScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTile(
                icon: Icons.folder_outlined,
                label: 'Documents',
                color: AppTheme.warningAmber,
                subtitle: 'Locker',
                onTap: () => _navigate(const DocumentLockerScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTile(
                icon: Icons.insights,
                label: 'Safety',
                color: const Color(0xFF448AFF),
                subtitle: 'Insights',
                onTap: () => _navigate(const AiSafetyInsightsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                color: const Color(0xFFE040FB),
                subtitle: 'Config',
                onTap: () => _navigate(const AiSettingsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.glassDecoration(
          borderRadius: 18,
          opacity: 0.06,
          borderColor: color.withValues(alpha: 0.15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
            Text(subtitle,
                style: AppTheme.bodySmall.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Contacts', '$_contactCount', AppTheme.primaryCyan)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Alerts', '$_alertCount', AppTheme.emergencyRed)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Score', '$_readinessScore%',
            _readinessScore >= 80 ? AppTheme.successGreen : AppTheme.warningAmber)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: AppTheme.glassDecoration(
        borderRadius: 14,
        opacity: 0.06,
        borderColor: color.withValues(alpha: 0.15),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTheme.headingSmall.copyWith(
                color: color,
                fontSize: 20,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: AppTheme.bodySmall.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  // ── Suggestions Card ───────────────────────────────────────────────────

  Widget _buildSuggestionsCard() {
    final suggestions = _readinessItems
        .where((i) => !i.completed && i.suggestion != null)
        .take(3)
        .toList();

    if (suggestions.isEmpty) {
      return GlassCard(
        borderColor: AppTheme.successGreen.withValues(alpha: 0.2),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppTheme.successGreen, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Set!',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w600,
                      )),
                  Text('Your emergency profile is fully prepared',
                      style: AppTheme.bodySmall.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      borderColor: AppTheme.warningAmber.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates,
                  color: AppTheme.warningAmber, size: 20),
              const SizedBox(width: 8),
              Text('AI SUGGESTIONS',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningAmber,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.warningAmber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.suggestion!,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          )),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Safety Tips ────────────────────────────────────────────────────────

  Widget _buildSafetyTips() {
    const tips = [
      '💡 Keep your profile photo updated for easy identification',
      '🩸 Blood group info helps emergency responders save time',
      '📞 Set at least one primary emergency contact',
      '📄 Upload medical documents for comprehensive emergency data',
      '🔔 Enable AI voice guidance for hands-free emergency response',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'SAFETY TIPS',
          icon: Icons.lightbulb_outline,
          color: AppTheme.warningAmber,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tips.length,
            itemBuilder: (context, index) {
              return Container(
                width: 260,
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: AppTheme.glassDecoration(
                  borderRadius: 14,
                  opacity: 0.06,
                ),
                alignment: Alignment.centerLeft,
                child: Text(tips[index],
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    )),
              );
            },
          ),
        ),
      ],
    );
  }
}
