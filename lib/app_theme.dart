import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AI Smart SOS — Clean Professional Light Emergency Theme System
class AppTheme {
  AppTheme._();

  // ── Core Palette ──────────────────────────────────────────────────────
  static const Color background = Color(0xFFF7F9FC); // Light gray background
  static const Color surface = Color(0xFFFFFFFF); // White cards
  static const Color surfaceLight = Color(0xFFF0F4F8);
  
  // Service icons / Action color
  static const Color primaryCyan = Color(0xFF2563EB); // Blue for service icons
  static const Color primaryCyanDark = Color(0xFF1D4ED8);
  
  // Emergency / SOS
  static const Color emergencyRed = Color(0xFFFF4B4B); // Coral/Red
  static const Color emergencyRedDark = Color(0xFFDC2626);
  
  static const Color warningAmber = Color(0xFFF59E0B);
  
  // Safe / Protected
  static const Color successGreen = Color(0xFF10B981);
  
  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Dark slate
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  
  // Glass / Borders
  static const Color glassWhite = Color(0xE6FFFFFF);
  static const Color glassBorder = Color(0xFFE2E8F0); // Subtle light border

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFFF4B4B), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF7F9FC), Color(0xFFF1F5F9), Color(0xFFF7F9FC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Text Styles ───────────────────────────────────────────────────────
  static TextStyle headingLarge = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle headingMedium = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.25,
  );

  static TextStyle headingSmall = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );

  static TextStyle buttonText = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  // ── Glassmorphism / Card Decoration ───────────────────────────────────
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    Color? borderColor,
    double opacity = 1.0, // Mostly solid white cards for light theme
  }) {
    return BoxDecoration(
      color: surface.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? glassBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04), // Soft shadow
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ── Glow / Shadow ─────────────────────────────────────────────────────
  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.2 * intensity),
        blurRadius: 16,
        spreadRadius: 2,
        offset: const Offset(0, 6),
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
      fillColor: surfaceLight,
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
  // Keeping the name 'darkTheme' to avoid breaking main.dart right now, 
  // but it actually returns a light theme. Better yet, we can rename it and fix main.dart.
  // Let's provide both and fix main.dart.
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.light(
        primary: primaryCyan,
        secondary: emergencyRed,
        surface: surface,
        error: emergencyRed,
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
        centerTitle: true,
        titleTextStyle: headingMedium,
        iconTheme: const IconThemeData(color: primaryCyan),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
      ),
    );
  }
  
  // Legacy getter so things don't immediately break if we miss one
  static ThemeData get darkTheme => lightTheme;
}
