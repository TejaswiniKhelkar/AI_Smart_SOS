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
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _alerts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          itemCount: _alerts.length,
                          itemBuilder: (context, index) => _buildAlertCard(_alerts[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Emergency History',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.textPrimary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_alerts.length} Records',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryCyan,
                fontWeight: FontWeight.w600,
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
          Icon(Icons.history_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No emergency alerts recorded',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(SosAlert alert) {
    final date = alert.timestamp;
    final String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final String dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emergencyRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_rounded, color: AppTheme.emergencyRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SOS Alert',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    dateStr,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryCyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                alert.smsDeliveryStatus == 'sent'
                    ? Icons.mark_email_read
                    : Icons.error_outline,
                color: alert.smsDeliveryStatus == 'sent'
                    ? AppTheme.successGreen
                    : (alert.smsDeliveryStatus == 'failed_no_provider'
                        ? AppTheme.warningAmber
                        : AppTheme.emergencyRed),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.smsDeliveryStatus == 'sent'
                      ? 'SMS Delivered'
                      : (alert.smsDeliveryStatus == 'failed_no_provider'
                          ? 'SMS Not Sent (Provider missing)'
                          : 'SMS Failed'),
                  style: AppTheme.bodySmall.copyWith(
                    color: alert.smsDeliveryStatus == 'sent'
                        ? AppTheme.successGreen
                        : (alert.smsDeliveryStatus == 'failed_no_provider'
                            ? AppTheme.warningAmber
                            : AppTheme.emergencyRed),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
