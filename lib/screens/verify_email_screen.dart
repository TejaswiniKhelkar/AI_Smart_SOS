import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading = false;
  bool _isResending = false;

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);
    
    // Reload user to get the latest email verified status
    await AuthService.reloadUser();
    final isVerified = await AuthService.isEmailVerified();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (isVerified) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email is not verified yet. Please check your inbox.'),
          backgroundColor: AppTheme.emergencyRed,
        ),
      );
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    final error = await AuthService.sendEmailVerification();
    if (!mounted) return;
    setState(() => _isResending = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verification email sent! Check your inbox/spam folder.'),
          backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.8),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.emergencyRed,
        ),
      );
    }
  }

  Future<void> _cancelAndLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppTheme.primaryCyan,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify Your Email',
                    style: AppTheme.headingMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification link to your email address. Please tap the link in the email to activate your account.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: 48),

                  // Check Verification Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTheme.cyanGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: MaterialButton(
                      onPressed: _isLoading ? null : _checkVerification,
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
                          : Text('I\'VE VERIFIED MY EMAIL', style: AppTheme.buttonText),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resend Email Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isResending ? null : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primaryCyan.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryCyan,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Resend Verification Email',
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryCyan),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Cancel/Logout
                  TextButton(
                    onPressed: _cancelAndLogout,
                    child: Text(
                      'Cancel and return to Login',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
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
}
