import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AI Smart SOS — Futuristic Dark Emergency Theme System
class AppTheme {
  AppTheme._();

  // ── Core Palette ──────────────────────────────────────────────────────
  static const Color background = Color(0xFF0A0E21);
  static const Color surface = Color(0xFF1A1F36);
  static const Color surfaceLight = Color(0xFF242B4A);
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryCyanDark = Color(0xFF00B8D4);
  static const Color emergencyRed = Color(0xFFFF1744);
  static const Color emergencyRedDark = Color(0xFFD50000);
  static const Color warningAmber = Color(0xFFFFAB00);
  static const Color successGreen = Color(0xFF00E676);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF546E7A);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [primaryCyan, Color(0xFF0288D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [emergencyRed, Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0E21), Color(0xFF141B3D), Color(0xFF0A0E21)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Text Styles ───────────────────────────────────────────────────────
  static TextStyle headingLarge = GoogleFonts.orbitron(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 3,
  );

  static TextStyle headingMedium = GoogleFonts.orbitron(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 2,
  );

  static TextStyle headingSmall = GoogleFonts.orbitron(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 1.5,
  );

  static TextStyle bodyLarge = GoogleFonts.rajdhani(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle bodyMedium = GoogleFonts.rajdhani(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle bodySmall = GoogleFonts.rajdhani(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );

  static TextStyle buttonText = GoogleFonts.rajdhani(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 2,
  );

  // ── Glassmorphism Decoration ──────────────────────────────────────────
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    Color? borderColor,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? glassBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: primaryCyan.withValues(alpha: 0.05),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ],
    );
  }

  // ── Neon Glow Box Shadow ──────────────────────────────────────────────
  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.3 * intensity),
        blurRadius: 15,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.15 * intensity),
        blurRadius: 40,
        spreadRadius: 5,
      ),
    ];
  }

  // ── Input Decoration ──────────────────────────────────────────────────
  static InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: bodyMedium.copyWith(color: textMuted),
      prefixIcon: Icon(icon, color: primaryCyan, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surface.withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryCyan, width: 1.5),
      ),
    );
  }

  // ── MaterialApp ThemeData ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: emergencyRed,
        surface: surface,
      ),
      textTheme: TextTheme(
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: headingSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
      ),
    );
  }
}
