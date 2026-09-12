import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'ai_profile_screen.dart'; // Assuming this is the Emergency Profile
import 'emergency_contacts_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) return;

    try {
      final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_currentUser == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final file = File(image.path);
      final ref = _storage.ref().child('profile_photos/${_currentUser!.uid}.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'profilePhotoUrl': url,
      });

      setState(() {
        _userData?['profilePhotoUrl'] = url;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile photo updated successfully', style: AppTheme.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e', style: AppTheme.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppTheme.emergencyRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _userData?['name'] ?? '');
    final phoneController = TextEditingController(text: _userData?['phone'] ?? '');

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profile', style: AppTheme.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration(
                label: 'Full Name',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration(
                label: 'Phone Number',
                icon: Icons.phone_outlined,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (_currentUser != null) {
                final newName = nameController.text.trim();
                final newPhone = phoneController.text.trim();

                await _firestore.collection('users').doc(_currentUser!.uid).update({
                  'name': newName,
                  'phone': newPhone,
                });

                setState(() {
                  _userData?['name'] = newName;
                  _userData?['phone'] = newPhone;
                });

                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) => FadeTransition(opacity: anim, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('USER PROFILE'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.primaryCyan, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : _userData == null
              ? Center(
                  child: Text(
                    'Failed to load profile data',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.textMuted),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildPersonalInfoCard(),
                      const SizedBox(height: 20),
                      _buildAccountInfoCard(),
                      const SizedBox(height: 24),
                      _buildShortcutsSection(),
                      const SizedBox(height: 32),
                      _buildLogoutButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final photoUrl = _userData?['profilePhotoUrl'] as String?;
    final name = _userData?['name'] as String? ?? 'Unknown User';
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceLight,
                border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.5), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: _isUploading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
                    : (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan));
                            },
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person,
                              size: 60,
                              color: AppTheme.textMuted,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: AppTheme.textMuted,
                          ),
              ),
            ),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryCyan,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: AppTheme.headingMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showEditProfileDialog,
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Edit Profile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceLight,
            foregroundColor: AppTheme.primaryCyan,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    final email = _userData?['email'] as String? ?? 'Not set';
    final phone = _userData?['phone'] as String? ?? 'Not set';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(borderRadius: 20, opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'PERSONAL INFORMATION',
                style: AppTheme.bodySmall.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.email_outlined, 'Email', email),
          const Divider(color: AppTheme.glassBorder, height: 24),
          _buildInfoRow(Icons.phone_outlined, 'Phone Number', phone),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    final isVerified = _currentUser?.emailVerified ?? false;
    final createdAt = _userData?['createdAt'] as Timestamp?;
    final dateString = createdAt != null 
        ? DateFormat('MMMM d, yyyy').format(createdAt.toDate())
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(borderRadius: 20, opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'ACCOUNT STATUS',
                style: AppTheme.bodySmall.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                isVerified ? Icons.check_circle_outline : Icons.error_outline,
                color: isVerified ? AppTheme.successGreen : AppTheme.warningAmber,
                size: 24,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email Verification',
                    style: AppTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVerified ? 'Verified' : 'Unverified',
                    style: AppTheme.bodyMedium.copyWith(
                      color: isVerified ? AppTheme.successGreen : AppTheme.warningAmber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: AppTheme.glassBorder, height: 24),
          _buildInfoRow(Icons.calendar_today_outlined, 'Member Since', dateString),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutsSection() {
    return Column(
      children: [
        _buildShortcutCard(
          title: 'Emergency Profile',
          subtitle: 'Medical data, blood type, conditions',
          icon: Icons.health_and_safety_outlined,
          color: AppTheme.primaryCyan,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiProfileScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildShortcutCard(
          title: 'Emergency Contacts',
          subtitle: 'Manage who gets notified',
          icon: Icons.people_outline,
          color: const Color(0xFF448AFF),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShortcutCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecoration(
          borderRadius: 16,
          opacity: 0.08,
          borderColor: color.withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, color: AppTheme.emergencyRed),
        label: Text(
          'LOGOUT',
          style: AppTheme.buttonText.copyWith(color: AppTheme.emergencyRed),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.emergencyRed.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.emergencyRed.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}
