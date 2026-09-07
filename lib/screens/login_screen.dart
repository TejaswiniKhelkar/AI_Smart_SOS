import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'verify_email_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _particleController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _buttonGlowController;
  late Animation<double> _buttonGlowAnimation;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    _buttonGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _buttonGlowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _buttonGlowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _particleController.dispose();
    _fadeController.dispose();
    _buttonGlowController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }
    
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Artificial delay to show loading state as requested
    await Future.delayed(const Duration(milliseconds: 800));

    final error = await AuthService.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.emergencyRed,
        ),
      );
      return;
    }

    final isVerified = await AuthService.isEmailVerified();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => isVerified ? const HomeScreen() : const VerifyEmailScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address first')),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService.resetPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.emergencyRed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password reset email sent. Please check your inbox.'),
          backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Animated particle background
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
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        _buildBranding(),
                        const SizedBox(height: 48),
                        _buildLoginCard(),
                        const SizedBox(height: 24),
                        _buildSignupLink(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        // Globe icon with glow
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryCyan.withValues(alpha: 0.1),
            boxShadow: AppTheme.neonGlow(AppTheme.primaryCyan, intensity: 0.5),
          ),
          child: const Icon(
            Icons.public,
            color: AppTheme.primaryCyan,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text('AI SMART SOS', style: AppTheme.headingMedium),
        const SizedBox(height: 6),
        Text(
          'Secure Access Portal',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.primaryCyan.withValues(alpha: 0.7),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
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
          Text(
            'Welcome Back',
            style: AppTheme.headingSmall.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to your emergency account',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 28),

          // Email field
          TextField(
            controller: _emailController,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            keyboardType: TextInputType.emailAddress,
            decoration: AppTheme.inputDecoration(
              label: 'Email Address',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 18),

          // Password field
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
          const SizedBox(height: 12),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              child: Text(
                'Forgot Password?',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryCyan,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Login button
          AnimatedBuilder(
            animation: _buttonGlowAnimation,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.cyanGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryCyan
                          .withValues(alpha: _buttonGlowAnimation.value * 0.4),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: MaterialButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                      : Text('SIGN IN', style: AppTheme.buttonText),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Biometric divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppTheme.glassBorder,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('or', style: AppTheme.bodySmall),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppTheme.glassBorder,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Biometric login
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
                border: Border.all(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                ),
              ),
              child: IconButton(
                onPressed: _handleLogin,
                icon: const Icon(
                  Icons.fingerprint,
                  color: AppTheme.primaryCyan,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Biometric Login',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryCyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: AppTheme.bodyMedium),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, _, _) => const SignupScreen(),
                transitionsBuilder: (_, anim, _, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
          child: Text(
            'Sign Up',
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

// ── Background Particle Painter ─────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint();

    for (int i = 0; i < 60; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.5 + random.nextDouble() * 1.5;
      final opacity = 0.1 + random.nextDouble() * 0.3;

      paint.color = (i % 5 == 0 ? AppTheme.primaryCyan : Colors.white)
          .withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
