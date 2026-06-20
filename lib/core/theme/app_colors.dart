import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFFAFAFA);
  static const Color bgTertiary = Color(0xFFE8E8ED);
  static const Color surface = Color(0xFFFFFFFF);

  // Accent — Indigo
  static const Color accent = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);
  static const Color accentDark = Color(0xFF4F46E5);
  static Color accentGlow = accent.withValues(alpha: 0.15);

  // Semantic
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF5AC8FA);

  // Text (iOS label colors)
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF6C6C70);
  static const Color textTertiary = Color(0xFFAEAEB2);

  // Borders & Dividers
  static const Color border = Color(0xFFD1D1D6);
  static const Color borderLight = Color(0xFFE5E5EA);
  static const Color divider = Color(0xFFE5E5EA);

  // Cards
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgElevated = Color(0xFFFFFFFF);

  // Nav
  static Color navBg = Colors.white.withValues(alpha: 0.85);
  static const Color navActive = accent;
  static const Color navInactive = Color(0xFF8E8E93);

  // Gradients — subtle, used sparingly for Apple-like feel
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFAFAFA), Color(0xFFF0F0F2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Category colors (iOS vibrancy)
  static const Color categoryIdentity = Color(0xFF6366F1);
  static const Color categoryEducation = Color(0xFF5856D6);
  static const Color categoryFinance = Color(0xFF34C759);
  static const Color categoryMedical = Color(0xFFFF3B30);
  static const Color categoryTravel = Color(0xFFFF9500);
  static const Color categoryFamily = Color(0xFFFF2D55);
  static const Color categoryOther = Color(0xFF8E8E93);
}
