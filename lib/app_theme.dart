import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeNotifier extends ValueNotifier<bool> {
  static final ThemeNotifier instance = ThemeNotifier(false);
  ThemeNotifier(super.value);
}

/// AI Smart SOS — Clean Professional Emergency Theme System
class AppTheme {
  AppTheme._();

  static bool get _isDark => ThemeNotifier.instance.value;

  // ── Core Palette ──────────────────────────────────────────────────────
  static Color get background => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F9FC);
  static Color get surface => _isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get surfaceLight => _isDark ? const Color(0xFF334155) : const Color(0xFFF0F4F8);
  
  static const Color primaryCyan = Color(0xFF2563EB); // Blue for service icons
  static const Color primaryCyanDark = Color(0xFF1D4ED8);
  
  static const Color emergencyRed = Color(0xFFFF4B4B); // Coral/Red
  static const Color emergencyRedDark = Color(0xFFDC2626);
  
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF10B981);
  
  static Color get textPrimary => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  static Color get textMuted => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  
  static Color get glassWhite => _isDark ? const Color(0x1AFFFFFF) : const Color(0xE6FFFFFF);
  static Color get glassBorder => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

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

  static LinearGradient get backgroundGradient => LinearGradient(
    colors: _isDark 
        ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF0F172A)]
        : [const Color(0xFFF7F9FC), const Color(0xFFF1F5F9), const Color(0xFFF7F9FC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Text Styles ───────────────────────────────────────────────────────
  static TextStyle get headingLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get headingMedium => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.25,
  );

  static TextStyle get headingSmall => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );

  static TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  // ── Glassmorphism / Card Decoration ───────────────────────────────────
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    Color? borderColor,
    double opacity = 1.0, 
  }) {
    return BoxDecoration(
      color: _isDark ? surface.withOpacity(opacity) : surface.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? glassBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: _isDark ? const Color(0x00000000) : const Color(0xFF0F172A).withOpacity(0.04),
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
        color: color.withOpacity(0.2 * intensity),
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
        borderSide: BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryCyan, width: 1.5),
      ),
    );
  }

  // ── MaterialApp ThemeData ─────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.light(
        primary: primaryCyan,
        secondary: emergencyRed,
        surface: Color(0xFFFFFFFF),
        error: emergencyRed,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        headlineSmall: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        bodyLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
        bodyMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
        bodySmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFF64748B)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        iconTheme: const IconThemeData(color: primaryCyan),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: emergencyRed,
        surface: Color(0xFF1E293B),
        error: emergencyRed,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFFF8FAFC)),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFFF8FAFC)),
        headlineSmall: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFF8FAFC)),
        bodyLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: const Color(0xFFCBD5E1)),
        bodyMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFFCBD5E1)),
        bodySmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFF94A3B8)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFFF8FAFC)),
        iconTheme: const IconThemeData(color: primaryCyan),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
    );
  }
}
