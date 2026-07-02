import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/sos_alert.dart';
import '../services/alert_service.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen>
    with TickerProviderStateMixin {
  List<SosAlert> _alerts = [];
  bool _isLoading = true;

  late AnimationController _particleController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _loadAlerts();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    final alerts = await AlertService.getAlerts();
    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear History', style: AppTheme.headingSmall),
        content: Text(
          'This will permanently delete all alert records. Continue?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AlertService.clearHistory();
              _loadAlerts();
            },
            child: Text('Clear All',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.emergencyRed)),
          ),
        ],
      ),
    );
  }

  Future<void> _openMapsLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _alertTypeColor(String type) {
    switch (type) {
      case 'Police':
        return const Color(0xFF448AFF);
      case 'Ambulance':
        return AppTheme.emergencyRed;
      case 'Fire':
        return AppTheme.warningAmber;
      default:
        return AppTheme.emergencyRed;
    }
  }

  IconData _alertTypeIcon(String type) {
    switch (type) {
      case 'Police':
        return Icons.local_police_outlined;
      case 'Ambulance':
        return Icons.local_hospital_outlined;
      case 'Fire':
        return Icons.local_fire_department_outlined;
      default:
        return Icons.sos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Particle background
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticlePainter(_particleController.value),
                  size: Size.infinite,
                );
              },
            ),

            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primaryCyan))
                          : _alerts.isEmpty
                              ? _buildEmptyState()
                              : _buildAlertList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.emergencyRed.withOpacity(0.1),
              border:
                  Border.all(color: AppTheme.emergencyRed.withOpacity(0.3)),
            ),
            child: const Icon(Icons.history,
                color: AppTheme.emergencyRed, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ALERT HISTORY',
                style: AppTheme.headingSmall.copyWith(fontSize: 14),
              ),
              Text(
                '${_alerts.length} alert${_alerts.length == 1 ? '' : 's'} logged',
                style: AppTheme.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          if (_alerts.isNotEmpty)
            GestureDetector(
              onTap: _confirmClearHistory,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.emergencyRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.emergencyRed.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline,
                        color: AppTheme.emergencyRed.withOpacity(0.8),
                        size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.emergencyRed,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.successGreen.withOpacity(0.08),
              border:
                  Border.all(color: AppTheme.successGreen.withOpacity(0.15)),
            ),
            child: Icon(Icons.verified_user_outlined,
                color: AppTheme.successGreen.withOpacity(0.5), size: 44),
          ),
          const SizedBox(height: 24),
          Text('No Alerts Triggered', style: AppTheme.headingSmall),
          const SizedBox(height: 8),
          Text(
            'All clear! No emergency alerts have\nbeen sent from this device',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        return _buildAlertCard(alert, index);
      },
    );
  }

  Widget _buildAlertCard(SosAlert alert, int index) {
    final color = _alertTypeColor(alert.alertType);
    final icon = _alertTypeIcon(alert.alertType);
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              if (index < _alerts.length - 1)
                Container(
                  width: 2,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withOpacity(0.4),
                        color.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassDecoration(
                borderRadius: 16,
                opacity: 0.06,
                borderColor: color.withOpacity(0.15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: type + status
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withOpacity(0.12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${alert.alertType} Alert',
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            dateFormat.format(alert.timestamp),
                            style: AppTheme.bodySmall.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: alert.status == 'sent'
                              ? AppTheme.successGreen.withOpacity(0.12)
                              : AppTheme.textMuted.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: alert.status == 'sent'
                                ? AppTheme.successGreen.withOpacity(0.25)
                                : AppTheme.textMuted.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          alert.status.toUpperCase(),
                          style: AppTheme.bodySmall.copyWith(
                            color: alert.status == 'sent'
                                ? AppTheme.successGreen
                                : AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Time + coordinates
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        timeFormat.format(alert.timestamp),
                        style: AppTheme.bodySmall.copyWith(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.location_on_outlined,
                          size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}',
                        style: AppTheme.bodySmall.copyWith(fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Maps link button
                  GestureDetector(
                    onTap: () => _openMapsLink(alert.googleMapsLink),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primaryCyan.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined,
                              color: AppTheme.primaryCyan, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Open in Google Maps',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.primaryCyan,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.open_in_new,
                              color: AppTheme.primaryCyan.withOpacity(0.6),
                              size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Particle Painter ──────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(99);
    final paint = Paint();

    for (int i = 0; i < 45; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.15 + random.nextDouble() * 0.5;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.4 + random.nextDouble() * 1.0;
      final opacity = 0.06 + random.nextDouble() * 0.2;

      paint.color = (i % 7 == 0 ? AppTheme.primaryCyan : Colors.white)
          .withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
