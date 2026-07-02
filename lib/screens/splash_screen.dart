import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Globe rotation
  late AnimationController _globeRotation;

  // Orbital rings
  late AnimationController _orbitalController;

  // Title fade + scale
  late AnimationController _titleController;
  late Animation<double> _titleFade;
  late Animation<double> _titleScale;

  // Subtitle
  late AnimationController _subtitleController;
  late Animation<double> _subtitleFade;
  late Animation<double> _underlineWidth;

  // Glow pulse on title
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Progress arc
  late AnimationController _progressController;
  late Animation<double> _progressSweep;

  // Background particles
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    // ── Globe ────────────────────────────────────────────────────────────
    _globeRotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // ── Orbital Rings ────────────────────────────────────────────────────
    _orbitalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // ── Title ────────────────────────────────────────────────────────────
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _titleScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // ── Subtitle ─────────────────────────────────────────────────────────
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );
    _underlineWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _subtitleController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // ── Glow pulse ───────────────────────────────────────────────────────
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 4, end: 20).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // ── Progress arc ─────────────────────────────────────────────────────
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _progressSweep = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // ── Particles ────────────────────────────────────────────────────────
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // ── Sequence ─────────────────────────────────────────────────────────
    Future.delayed(const Duration(milliseconds: 300), () {
      _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _subtitleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _progressController.forward();
    });

    // Navigate after 4s
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _globeRotation.dispose();
    _orbitalController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _glowController.dispose();
    _progressController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // ── Particle field ────────────────────────────────────────────
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _StarFieldPainter(_particleController.value),
                  size: Size.infinite,
                );
              },
            ),

            // ── Main content ─────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Globe + orbits
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Orbital rings
                        AnimatedBuilder(
                          animation: _orbitalController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _OrbitalRingsPainter(
                                progress: _orbitalController.value,
                              ),
                              size: const Size(220, 220),
                            );
                          },
                        ),
                        // Globe
                        AnimatedBuilder(
                          animation: _globeRotation,
                          builder: (context, _) {
                            return Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryCyan.withOpacity(0.25),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryCyan.withOpacity(0.1),
                                    blurRadius: 80,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: _GlobePainter(
                                  rotation: _globeRotation.value,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Title ───────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_titleController, _glowController]),
                    builder: (context, _) {
                      return Opacity(
                        opacity: _titleFade.value,
                        child: Transform.scale(
                          scale: _titleScale.value,
                          child: Text(
                            'AI SMART SOS',
                            style: AppTheme.headingLarge.copyWith(
                              shadows: [
                                Shadow(
                                  color: AppTheme.primaryCyan.withOpacity(0.8),
                                  blurRadius: _glowAnimation.value,
                                ),
                                Shadow(
                                  color: AppTheme.primaryCyan.withOpacity(0.4),
                                  blurRadius: _glowAnimation.value * 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Subtitle + underline ────────────────────────────────
                  AnimatedBuilder(
                    animation: _subtitleController,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _subtitleFade.value,
                        child: Column(
                          children: [
                            Text(
                              'Intelligent Emergency Response',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textSecondary.withOpacity(0.8),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 120 * _underlineWidth.value,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryCyan.withOpacity(0),
                                    AppTheme.primaryCyan,
                                    AppTheme.primaryCyan.withOpacity(0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 60),

                  // ── Progress arc ────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return SizedBox(
                        width: 48,
                        height: 48,
                        child: CustomPaint(
                          painter: _ProgressArcPainter(
                            progress: _progressSweep.value,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

/// Draws a wireframe globe with animated latitude/longitude lines
class _GlobePainter extends CustomPainter {
  final double rotation;
  _GlobePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer circle
    final outerPaint = Paint()
      ..color = AppTheme.primaryCyan.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, outerPaint);

    // Inner fill (dark with slight gradient)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.primaryCyan.withOpacity(0.08),
          AppTheme.background.withOpacity(0.9),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fillPaint);

    final linePaint = Paint()
      ..color = AppTheme.primaryCyan.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Latitude lines (horizontal ellipses)
    for (int i = -2; i <= 2; i++) {
      final latFraction = i / 3.0;
      final y = center.dy + latFraction * radius;
      final halfWidth = radius * cos(asin(latFraction.abs().clamp(0.0, 1.0)));
      final rect = Rect.fromCenter(
        center: Offset(center.dx, y),
        width: halfWidth * 2,
        height: halfWidth * 0.12,
      );
      canvas.drawOval(rect, linePaint);
    }

    // Longitude lines (vertical ellipses that rotate)
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6.0) * pi + rotation * 2 * pi;
      final xScale = cos(angle);

      if (xScale.abs() < 0.05) continue;

      final rect = Rect.fromCenter(
        center: center,
        width: (radius * 2 * xScale).abs(),
        height: radius * 2,
      );

      canvas.save();
      canvas.clipRect(
          Rect.fromCircle(center: center, radius: radius - 1));
      canvas.drawOval(rect, linePaint);
      canvas.restore();
    }

    // Equator (brighter)
    final equatorPaint = Paint()
      ..color = AppTheme.primaryCyan.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: 4),
      equatorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

/// Draws rotating orbital rings around the globe
class _OrbitalRingsPainter extends CustomPainter {
  final double progress;
  _OrbitalRingsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final angle = progress * 2 * pi + (i * pi / 3);
      final ringRadius = 85.0 + i * 12.0;
      final opacity = 0.15 - i * 0.04;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle * (i.isEven ? 1 : -0.7));

      final paint = Paint()
        ..color = AppTheme.primaryCyan.withOpacity(opacity.clamp(0.05, 0.2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: ringRadius * 2,
          height: ringRadius * 0.35,
        ),
        paint,
      );

      // Small dot on ring
      final dotAngle = angle * 2;
      final dotX = cos(dotAngle) * ringRadius;
      final dotY = sin(dotAngle) * ringRadius * 0.175;
      final dotPaint = Paint()
        ..color = AppTheme.primaryCyan.withOpacity(0.6);
      canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Custom progress arc instead of default CircularProgressIndicator
class _ProgressArcPainter extends CustomPainter {
  final double progress;
  _ProgressArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Background track
    final trackPaint = Paint()
      ..color = AppTheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Cyan arc
    final arcPaint = Paint()
      ..color = AppTheme.primaryCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      progress * 2 * pi,
      false,
      arcPaint,
    );

    // Red accent dot at tip
    if (progress > 0.01) {
      final tipAngle = -pi / 2 + progress * 2 * pi;
      final tipX = center.dx + cos(tipAngle) * radius;
      final tipY = center.dy + sin(tipAngle) * radius;
      final dotPaint = Paint()..color = AppTheme.emergencyRed;
      canvas.drawCircle(Offset(tipX, tipY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Floating star/particle field background
class _StarFieldPainter extends CustomPainter {
  final double progress;
  _StarFieldPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(12345);
    final paint = Paint();

    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.2 + random.nextDouble() * 0.8;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.3 + random.nextDouble() * 1.8;
      final twinkle =
          (sin(progress * 2 * pi * (1 + random.nextDouble()) + i) + 1) / 2;
      final opacity = 0.05 + twinkle * 0.25;

      if (i % 8 == 0) {
        paint.color = AppTheme.primaryCyan.withOpacity(opacity);
      } else if (i % 13 == 0) {
        paint.color = AppTheme.emergencyRed.withOpacity(opacity * 0.5);
      } else {
        paint.color = Colors.white.withOpacity(opacity);
      }

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}