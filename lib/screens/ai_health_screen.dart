import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/health_profile.dart';
import '../services/health_service.dart';
import '../services/profile_service.dart';
import '../widgets/reusable_widgets.dart';

class AiHealthScreen extends StatefulWidget {
  const AiHealthScreen({super.key});

  @override
  State<AiHealthScreen> createState() => _AiHealthScreenState();
}

class _AiHealthScreenState extends State<AiHealthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  HealthProfile _health = HealthProfile();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _bloodGroup;
  String _aiSummary = '';

  final _allergyCtrl = TextEditingController();
  final _diseaseCtrl = TextEditingController();
  final _medicationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _insuranceProviderCtrl = TextEditingController();
  final _insurancePolicyCtrl = TextEditingController();
  final _disabilityCtrl = TextEditingController();

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
    _allergyCtrl.dispose();
    _diseaseCtrl.dispose();
    _medicationCtrl.dispose();
    _notesCtrl.dispose();
    _insuranceProviderCtrl.dispose();
    _insurancePolicyCtrl.dispose();
    _disabilityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final health = await HealthService.getProfile();
    final profile = await ProfileService.getProfile();
    final summary = await HealthService.generateAISummary(profile.bloodGroup);
    setState(() {
      _health = health;
      _bloodGroup = profile.bloodGroup;
      _aiSummary = summary;
      _notesCtrl.text = health.medicalNotes ?? '';
      _insuranceProviderCtrl.text = health.insuranceProvider ?? '';
      _insurancePolicyCtrl.text = health.insurancePolicyNumber ?? '';
      _disabilityCtrl.text = health.disabilityInfo ?? '';
      _isLoading = false;
    });
    _fadeController.forward();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = _health.copyWith(
      medicalNotes: _notesCtrl.text.trim(),
      insuranceProvider: _insuranceProviderCtrl.text.trim(),
      insurancePolicyNumber: _insurancePolicyCtrl.text.trim(),
      disabilityInfo: _disabilityCtrl.text.trim(),
    );
    await HealthService.saveProfile(updated);
    final summary = await HealthService.generateAISummary(_bloodGroup);
    setState(() {
      _health = updated;
      _aiSummary = summary;
      _isSaving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Health profile saved',
              style: AppTheme.bodyMedium.copyWith(color: Colors.white)),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _addTag(String tag, List<String> list, TextEditingController ctrl) {
    if (tag.trim().isEmpty) return;
    setState(() {
      list.add(tag.trim());
      ctrl.clear();
      _health = _health.copyWith(
        allergies: list == _health.allergies ? list : null,
        existingDiseases: list == _health.existingDiseases ? list : null,
        currentMedications: list == _health.currentMedications ? list : null,
      );
    });
  }

  void _removeTag(int index, List<String> list) {
    setState(() {
      list.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ParticleBackground(
          seed: 66,
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
                                _buildAISummaryCard(),
                                const SizedBox(height: 16),
                                _buildTagSection(
                                  title: 'ALLERGIES',
                                  icon: Icons.warning_amber_rounded,
                                  color: AppTheme.emergencyRed,
                                  tags: _health.allergies,
                                  ctrl: _allergyCtrl,
                                  hint: 'e.g. Penicillin',
                                  onAdd: (t) => _addTag(
                                      t, _health.allergies, _allergyCtrl),
                                  onRemove: (i) =>
                                      _removeTag(i, _health.allergies),
                                ),
                                const SizedBox(height: 16),
                                _buildTagSection(
                                  title: 'EXISTING CONDITIONS',
                                  icon: Icons.medical_services_outlined,
                                  color: AppTheme.warningAmber,
                                  tags: _health.existingDiseases,
                                  ctrl: _diseaseCtrl,
                                  hint: 'e.g. Diabetes',
                                  onAdd: (t) => _addTag(
                                      t, _health.existingDiseases, _diseaseCtrl),
                                  onRemove: (i) =>
                                      _removeTag(i, _health.existingDiseases),
                                ),
                                const SizedBox(height: 16),
                                _buildTagSection(
                                  title: 'CURRENT MEDICATIONS',
                                  icon: Icons.medication_outlined,
                                  color: const Color(0xFF448AFF),
                                  tags: _health.currentMedications,
                                  ctrl: _medicationCtrl,
                                  hint: 'e.g. Metformin 500mg',
                                  onAdd: (t) => _addTag(t,
                                      _health.currentMedications, _medicationCtrl),
                                  onRemove: (i) =>
                                      _removeTag(i, _health.currentMedications),
                                ),
                                const SizedBox(height: 16),
                                _buildNotesCard(),
                                const SizedBox(height: 16),
                                _buildOrganDonorCard(),
                                const SizedBox(height: 16),
                                _buildInsuranceCard(),
                                const SizedBox(height: 16),
                                _buildDisabilityCard(),
                                const SizedBox(height: 24),
                                NeonButton(
                                  text: 'SAVE HEALTH PROFILE',
                                  icon: Icons.save_rounded,
                                  onPressed: _save,
                                  isLoading: _isSaving,
                                ),
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
              Text('AI HEALTH PROFILE',
                  style: AppTheme.headingSmall.copyWith(fontSize: 14)),
              Text('Medical data for responders',
                  style: AppTheme.bodySmall.copyWith(fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _health.riskLevel == 'Low'
                  ? AppTheme.successGreen.withValues(alpha: 0.1)
                  : _health.riskLevel == 'Medium'
                      ? AppTheme.warningAmber.withValues(alpha: 0.1)
                      : AppTheme.emergencyRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _health.riskLevel == 'Low'
                    ? AppTheme.successGreen.withValues(alpha: 0.3)
                    : _health.riskLevel == 'Medium'
                        ? AppTheme.warningAmber.withValues(alpha: 0.3)
                        : AppTheme.emergencyRed.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Risk: ${_health.riskLevel}',
              style: AppTheme.bodySmall.copyWith(
                color: _health.riskLevel == 'Low'
                    ? AppTheme.successGreen
                    : _health.riskLevel == 'Medium'
                        ? AppTheme.warningAmber
                        : AppTheme.emergencyRed,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryCard() {
    return GlassCard(
      borderColor: AppTheme.primaryCyan.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: AppTheme.cyanGradient,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text('AI HEALTH SUMMARY',
                  style: AppTheme.headingSmall.copyWith(
                    fontSize: 13,
                    color: AppTheme.primaryCyan,
                    letterSpacing: 2,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          ..._aiSummary.split('\n').map((line) {
            final isLabel = line.contains(':');
            if (line.isEmpty) return const SizedBox(height: 4);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    line.startsWith('Risk')
                        ? Icons.shield_outlined
                        : line.startsWith('Blood')
                            ? Icons.bloodtype_outlined
                            : Icons.check_circle_outline,
                    color: isLabel
                        ? AppTheme.primaryCyan.withValues(alpha: 0.6)
                        : AppTheme.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
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

  Widget _buildTagSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> tags,
    required TextEditingController ctrl,
    required String hint,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    return GlassCard(
      borderColor: color.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
              const Spacer(),
              Text('${tags.length}',
                  style: AppTheme.bodySmall.copyWith(
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.asMap().entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.value,
                          style: AppTheme.bodySmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          )),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onRemove(entry.key),
                        child: Icon(Icons.close, color: color, size: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  style:
                      AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (v) => onAdd(v),
                ),
              ),
              GestureDetector(
                onTap: () => onAdd(ctrl.text),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.add, color: color, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_outlined,
                  color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text('MEDICAL NOTES',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryCyan,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Additional medical notes...',
              icon: Icons.edit_note,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganDonorCard() {
    return GlassCard(
      borderColor: AppTheme.successGreen.withValues(alpha: 0.15),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: AppTheme.successGreen.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.volunteer_activism,
                color: AppTheme.successGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organ Donor',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                Text('Register as an organ donor',
                    style: AppTheme.bodySmall.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: _health.organDonorStatus,
            onChanged: (v) =>
                setState(() => _health = _health.copyWith(organDonorStatus: v)),
            activeThumbColor: AppTheme.successGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined,
                  color: AppTheme.warningAmber, size: 20),
              const SizedBox(width: 8),
              Text('INSURANCE (OPTIONAL)',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningAmber,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _insuranceProviderCtrl,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Insurance Provider',
              icon: Icons.business,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _insurancePolicyCtrl,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Policy Number',
              icon: Icons.pin_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabilityCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.accessible_outlined,
                  color: const Color(0xFFE040FB), size: 20),
              const SizedBox(width: 8),
              Text('DISABILITY INFO (OPTIONAL)',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE040FB),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _disabilityCtrl,
            maxLines: 2,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Disability information...',
              icon: Icons.info_outline,
            ),
          ),
        ],
      ),
    );
  }
}
