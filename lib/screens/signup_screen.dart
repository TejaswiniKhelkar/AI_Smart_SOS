import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  late AnimationController _particleController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _stepController;
  late Animation<double> _stepAnimation;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _stepAnimation = CurvedAnimation(
      parent: _stepController,
      curve: Curves.easeOutCubic,
    );
    _stepController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _particleController.dispose();
    _fadeController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  void _handleSignup() {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please agree to Terms & Conditions',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.emergencyRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context); // Go back to login
    });
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

            // Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Top bar with back button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.surface.withValues(alpha: 0.6),
                                border: Border.all(
                                    color:
                                        AppTheme.glassBorder.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.arrow_back_ios_new,
                                  color: AppTheme.primaryCyan, size: 18),
                            ),
                          ),
                          const Spacer(),
                          Text('CREATE ACCOUNT', style: AppTheme.headingSmall),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    // Step indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 8),
                      child: AnimatedBuilder(
                        animation: _stepAnimation,
                        builder: (context, _) {
                          return _buildStepIndicator();
                        },
                      ),
                    ),

                    // Form
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildSignupCard(),
                            const SizedBox(height: 24),
                            _buildLoginLink(),
                            const SizedBox(height: 40),
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
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Profile', 'Security', 'Complete'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = true; // All steps visible (single-page form)
        final progress = (_stepAnimation.value * 3 - i).clamp(0.0, 1.0);
        return Expanded(
          child: Row(
            children: [
              // Step dot
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryCyan.withValues(alpha: progress),
                  border: Border.all(
                    color: AppTheme.primaryCyan.withValues(alpha: progress),
                    width: 1.5,
                  ),
                  boxShadow: isActive && progress > 0.5
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: AppTheme.bodySmall.copyWith(
                      color: isActive && progress > 0.5
                          ? AppTheme.background
                          : AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // Connector line
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryCyan
                              .withValues(alpha: progress.clamp(0.0, 1.0)),
                          AppTheme.primaryCyan.withValues(alpha: 
                              ((_stepAnimation.value * 3 - i - 0.5)
                                  .clamp(0.0, 1.0))),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSignupCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.glassDecoration(
        borderRadius: 24,
        opacity: 0.08,
        borderColor: AppTheme.primaryCyan.withValues(alpha: 0.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Profile
          _buildSectionLabel('PROFILE INFORMATION', Icons.person_outline),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              label: 'Full Name',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _emailController,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            keyboardType: TextInputType.emailAddress,
            decoration: AppTheme.inputDecoration(
              label: 'Email Address',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _phoneController,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            keyboardType: TextInputType.phone,
            decoration: AppTheme.inputDecoration(
              label: 'Phone Number',
              icon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14, color: AppTheme.primaryCyan.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Used as emergency contact number',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Section: Security
          _buildSectionLabel('SECURITY', Icons.shield_outlined),
          const SizedBox(height: 16),

          TextField(
            controller: _passwordController,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            obscureText: _obscurePassword,
            decoration: AppTheme.inputDecoration(
              label: 'Password',
              icon: Icons.lock_outlined,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _confirmPasswordController,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            obscureText: _obscureConfirm,
            decoration: AppTheme.inputDecoration(
              label: 'Confirm Password',
              icon: Icons.lock_outlined,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Terms & Conditions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreedToTerms,
                  onChanged: (v) =>
                      setState(() => _agreedToTerms = v ?? false),
                  activeColor: AppTheme.primaryCyan,
                  side: const BorderSide(color: AppTheme.textMuted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: RichText(
                  text: TextSpan(
                    style: AppTheme.bodySmall,
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Create Account button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: _agreedToTerms
                  ? AppTheme.cyanGradient
                  : const LinearGradient(
                      colors: [AppTheme.surface, AppTheme.surfaceLight],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _agreedToTerms
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: MaterialButton(
              onPressed: _isLoading ? null : _handleSignup,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text('CREATE ACCOUNT', style: AppTheme.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryCyan, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.primaryCyan,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: AppTheme.bodyMedium),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Login',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.primaryCyan,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Particle Painter (reused pattern) ─────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint();

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.2 + random.nextDouble() * 0.6;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.5 + random.nextDouble() * 1.2;
      final opacity = 0.08 + random.nextDouble() * 0.25;

      paint.color = (i % 6 == 0 ? AppTheme.primaryCyan : Colors.white)
          .withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
