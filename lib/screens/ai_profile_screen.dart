import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/reusable_widgets.dart';

class AiProfileScreen extends StatefulWidget {
  const AiProfileScreen({super.key});

  @override
  State<AiProfileScreen> createState() => _AiProfileScreenState();
}

class _AiProfileScreenState extends State<AiProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  UserProfile _profile = UserProfile();
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  DateTime? _selectedDOB;
  String? _selectedGender;
  String? _selectedBloodGroup;
  String _selectedLanguage = 'English';

  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];
  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _languages = [
    'English', 'Hindi', 'Marathi', 'Tamil', 'Telugu',
    'Kannada', 'Bengali', 'Gujarati', 'Punjabi',
  ];

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
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getProfile();
    setState(() {
      _profile = profile;
      _nameCtrl.text = profile.fullName;
      _phoneCtrl.text = profile.phone ?? '';
      _emailCtrl.text = profile.email ?? '';
      _addressCtrl.text = profile.homeAddress ?? '';
      _heightCtrl.text =
          profile.heightCm != null ? profile.heightCm!.toString() : '';
      _weightCtrl.text =
          profile.weightKg != null ? profile.weightKg!.toString() : '';
      _selectedDOB = profile.dateOfBirth;
      _selectedGender = profile.gender;
      _selectedBloodGroup = profile.bloodGroup;
      _selectedLanguage = profile.preferredLanguage;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final updated = _profile.copyWith(
      fullName: _nameCtrl.text.trim(),
      dateOfBirth: _selectedDOB,
      gender: _selectedGender,
      bloodGroup: _selectedBloodGroup,
      heightCm: double.tryParse(_heightCtrl.text),
      weightKg: double.tryParse(_weightCtrl.text),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      homeAddress: _addressCtrl.text.trim(),
      preferredLanguage: _selectedLanguage,
    );
    await ProfileService.saveProfile(updated);
    setState(() {
      _profile = updated;
      _isSaving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile saved successfully',
              style: AppTheme.bodyMedium.copyWith(color: Colors.white)),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final savedPath = await ProfileService.saveProfilePhoto(picked.path);
    final updated = _profile.copyWith(profilePhotoPath: savedPath);
    await ProfileService.saveProfile(updated);
    setState(() => _profile = updated);
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryCyan,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDOB = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration:
            const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ParticleBackground(
          seed: 55,
          child: SafeArea(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryCyan))
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
                                _buildProfilePhoto(),
                                const SizedBox(height: 24),
                                _buildCompletionCard(),
                                const SizedBox(height: 20),
                                _buildPersonalInfoCard(),
                                const SizedBox(height: 16),
                                _buildBloodGroupGrid(),
                                const SizedBox(height: 16),
                                _buildBodyMetricsCard(),
                                const SizedBox(height: 16),
                                _buildContactCard(),
                                const SizedBox(height: 16),
                                _buildPreferencesCard(),
                                const SizedBox(height: 24),
                                NeonButton(
                                  text: 'SAVE PROFILE',
                                  icon: Icons.save_rounded,
                                  onPressed: _saveProfile,
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
              width: 40,
              height: 40,
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
              Text('AI EMERGENCY PROFILE',
                  style: AppTheme.headingSmall.copyWith(fontSize: 14)),
              Text('Your identity for responders',
                  style: AppTheme.bodySmall.copyWith(fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _profile.isComplete
                  ? AppTheme.successGreen.withValues(alpha: 0.1)
                  : AppTheme.warningAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _profile.isComplete
                    ? AppTheme.successGreen.withValues(alpha: 0.3)
                    : AppTheme.warningAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${_profile.completionPercent}%',
              style: AppTheme.bodySmall.copyWith(
                color: _profile.isComplete
                    ? AppTheme.successGreen
                    : AppTheme.warningAmber,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto() {
    final hasPhoto = _profile.profilePhotoPath != null &&
        File(_profile.profilePhotoPath!).existsSync();

    return GestureDetector(
      onTap: _pickPhoto,
      child: Hero(
        tag: 'profile_photo',
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasPhoto ? null : AppTheme.cyanGradient,
            border: Border.all(
              color: AppTheme.primaryCyan.withValues(alpha: 0.4),
              width: 3,
            ),
            boxShadow: AppTheme.neonGlow(AppTheme.primaryCyan, intensity: 0.3),
            image: hasPhoto
                ? DecorationImage(
                    image: FileImage(File(_profile.profilePhotoPath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: hasPhoto
              ? Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryCyan,
                      border: Border.all(color: AppTheme.background, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 40),
                    const SizedBox(height: 4),
                    Text('Add Photo',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    final percent = _profile.completionPercent;
    return GlassCard(
      borderColor: percent >= 80
          ? AppTheme.successGreen.withValues(alpha: 0.2)
          : AppTheme.warningAmber.withValues(alpha: 0.2),
      child: Row(
        children: [
          AnimatedProgressRing(
            progress: percent / 100,
            size: 56,
            strokeWidth: 5,
            color: percent >= 80 ? AppTheme.successGreen : AppTheme.warningAmber,
            child: Text(
              '$percent%',
              style: AppTheme.bodySmall.copyWith(
                color: percent >= 80
                    ? AppTheme.successGreen
                    : AppTheme.warningAmber,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile Completion',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                Text(
                  percent >= 80
                      ? 'Your profile is ready for emergencies'
                      : 'Complete your profile for better safety',
                  style: AppTheme.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text('PERSONAL INFORMATION',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryCyan,
                  )),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Full Name',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 14),
          // Date of Birth
          GestureDetector(
            onTap: _pickDOB,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: AppTheme.primaryCyan, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDOB != null
                          ? '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}'
                          : 'Date of Birth',
                      style: AppTheme.bodyMedium.copyWith(
                        color: _selectedDOB != null
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  if (_selectedDOB != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Age: ${_profile.copyWith(dateOfBirth: _selectedDOB).age ?? "-"}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Gender
          _buildDropdown(
            value: _selectedGender,
            hint: 'Gender',
            icon: Icons.wc_outlined,
            items: _genders,
            onChanged: (v) => setState(() => _selectedGender = v),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupGrid() {
    return GlassCard(
      borderColor: AppTheme.emergencyRed.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bloodtype_outlined,
                  color: AppTheme.emergencyRed, size: 20),
              const SizedBox(width: 8),
              Text('BLOOD GROUP',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.emergencyRed,
                  )),
              const Spacer(),
              Text('Required',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.emergencyRed.withValues(alpha: 0.7),
                    fontSize: 11,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _bloodGroups.map((bg) {
              final selected = _selectedBloodGroup == bg;
              return GestureDetector(
                onTap: () => setState(() => _selectedBloodGroup = bg),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 68,
                  height: 50,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.emergencyRed.withValues(alpha: 0.15)
                        : AppTheme.glassWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppTheme.emergencyRed
                          : AppTheme.glassBorder,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color:
                                  AppTheme.emergencyRed.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    bg,
                    style: AppTheme.headingSmall.copyWith(
                      fontSize: 16,
                      color: selected
                          ? AppTheme.emergencyRed
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMetricsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_outlined,
                  color: AppTheme.successGreen, size: 20),
              const SizedBox(width: 8),
              Text('BODY METRICS',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successGreen,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTheme.bodyLarge
                      .copyWith(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration(
                    label: 'Height (cm)',
                    icon: Icons.height,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTheme.bodyLarge
                      .copyWith(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration(
                    label: 'Weight (kg)',
                    icon: Icons.fitness_center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_phone_outlined,
                  color: const Color(0xFF448AFF), size: 20),
              const SizedBox(width: 8),
              Text('CONTACT DETAILS',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF448AFF),
                  )),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Phone Number',
              icon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Email Address',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Home Address',
              icon: Icons.home_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language, color: AppTheme.warningAmber, size: 20),
              const SizedBox(width: 8),
              Text('PREFERENCES',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningAmber,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            value: _selectedLanguage,
            hint: 'Preferred Language',
            icon: Icons.translate,
            items: _languages,
            onChanged: (v) {
              if (v != null) setState(() => _selectedLanguage = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, color: AppTheme.primaryCyan, size: 22),
              const SizedBox(width: 12),
              Text(hint, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
            ],
          ),
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppTheme.primaryCyan),
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(icon, color: AppTheme.primaryCyan, size: 20),
                  const SizedBox(width: 12),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
