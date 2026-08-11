import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/readiness_service.dart';
import '../services/profile_service.dart';
import '../services/health_service.dart';
import '../services/contact_service.dart';
import '../services/alert_service.dart';
import '../widgets/reusable_widgets.dart';

class AiSafetyInsightsScreen extends StatefulWidget {
  const AiSafetyInsightsScreen({super.key});

  @override
  State<AiSafetyInsightsScreen> createState() => _AiSafetyInsightsScreenState();
}

class _AiSafetyInsightsScreenState extends State<AiSafetyInsightsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _readinessScore = 0;
  int _profilePercent = 0;
  int _healthPercent = 0;
  int _contactCount = 0;
  int _alertCount = 0;
  DateTime? _lastAlertDate;
  List<ReadinessItem> _items = [];
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
      _items = readiness.items;
      _profilePercent = profile.completionPercent;
      _healthPercent = health.completionPercent;
      _contactCount = contactCount;
      _alertCount = alerts.length;
      _lastAlertDate = alerts.isNotEmpty ? alerts.first.timestamp : null;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ParticleBackground(
          seed: 122,
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
                                _buildOverallScoreCard(),
                                const SizedBox(height: 16),
                                _buildCategoryBreakdown(),
                                const SizedBox(height: 16),
                                _buildChecklistCard(),
                                const SizedBox(height: 16),
                                _buildActivityCard(),
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
              Text('SAFETY INSIGHTS',
                  style: AppTheme.headingSmall.copyWith(fontSize: 14)),
              Text('AI-powered safety analysis',
                  style: AppTheme.bodySmall.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScoreCard() {
    Color scoreColor;
    if (_readinessScore >= 80) {
      scoreColor = AppTheme.successGreen;
    } else if (_readinessScore >= 50) {
      scoreColor = AppTheme.warningAmber;
    } else {
      scoreColor = AppTheme.emergencyRed;
    }

    return GlassCard(
      borderColor: scoreColor.withValues(alpha: 0.2),
      child: Row(
        children: [
          AnimatedProgressRing(
            progress: _readinessScore / 100,
            size: 100,
            strokeWidth: 8,
            color: scoreColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$_readinessScore',
                    style: AppTheme.headingLarge.copyWith(
                      color: scoreColor,
                      fontSize: 32,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Readiness',
                    style: AppTheme.headingSmall.copyWith(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  _readinessScore >= 80
                      ? 'Your emergency profile is well-prepared'
                      : _readinessScore >= 50
                          ? 'Some improvements needed for full readiness'
                          : 'Critical information missing for emergencies',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    return Column(
      children: [
        const SectionHeader(title: 'BREAKDOWN', icon: Icons.analytics_outlined),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniProgress(
                  'Profile', _profilePercent, AppTheme.primaryCyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniProgress(
                  'Medical', _healthPercent, AppTheme.successGreen),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniProgress(
                  'Contacts',
                  _contactCount > 0 ? 100 : 0,
                  AppTheme.warningAmber),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniProgress(String label, int percent, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: 14,
        opacity: 0.06,
        borderColor: color.withValues(alpha: 0.15),
      ),
      child: Column(
        children: [
          AnimatedProgressRing(
            progress: percent / 100,
            size: 52,
            strokeWidth: 4,
            color: color,
            child: Text('$percent%',
                style: AppTheme.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                )),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: AppTheme.bodySmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded,
                  color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text('READINESS CHECKLIST',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryCyan,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          ..._items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    item.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: item.completed
                        ? AppTheme.successGreen
                        : AppTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                            style: AppTheme.bodyMedium.copyWith(
                              color: item.completed
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontWeight: item.completed
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              decoration: item.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                        if (!item.completed && item.suggestion != null)
                          Text(item.suggestion!,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.warningAmber,
                                fontSize: 11,
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return GlassCard(
      borderColor: AppTheme.emergencyRed.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: AppTheme.emergencyRed, size: 20),
              const SizedBox(width: 8),
              Text('EMERGENCY ACTIVITY',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.emergencyRed,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActivityStat(
                  'Total Alerts',
                  '$_alertCount',
                  Icons.notifications_active_outlined,
                  AppTheme.emergencyRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivityStat(
                  'Last Alert',
                  _lastAlertDate != null
                      ? DateFormat('dd MMM').format(_lastAlertDate!)
                      : 'None',
                  Icons.access_time,
                  AppTheme.warningAmber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivityStat(
                  'Status',
                  _readinessScore >= 80 ? 'Ready' : 'Setup',
                  Icons.shield_outlined,
                  _readinessScore >= 80
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            )),
        Text(label,
            style: AppTheme.bodySmall.copyWith(fontSize: 10)),
      ],
    );
  }
}
