import 'package:flutter/material.dart';

/// Claude / Anthropic design language.
///
/// Warm ivory surfaces, near-black warm text, terracotta ("book cloth")
/// accent, muted supporting colors. Nothing neon, nothing gradient-heavy —
/// the palette should feel like paper and ink.
class AppColors {
  AppColors._();

  // --- Surfaces ----------------------------------------------------------
  /// Page background — Claude's signature warm ivory.
  static const Color bg = Color(0xFFFAF9F5);

  /// Recessed panels, input fills, chips at rest.
  static const Color bgSunken = Color(0xFFF0EEE6);

  /// Slightly deeper wash for pressed states / skeleton shimmer base.
  static const Color bgDeep = Color(0xFFE8E6DC);

  /// Cards and sheets sit on white.
  static const Color surface = Color(0xFFFFFFFF);

  /// Dark inverse surface (dark cards, the Digital ID card, toasts).
  static const Color surfaceInverse = Color(0xFF262624);
  static const Color surfaceInverseRaised = Color(0xFF30302E);

  // --- Accent: terracotta "book cloth" ------------------------------------
  static const Color accent = Color(0xFFD97757);
  static const Color accentPressed = Color(0xFFC4633F);
  static const Color accentDeep = Color(0xFFA54E2C);

  /// Light terracotta washes for selected states and icon chips.
  static const Color accentWash = Color(0xFFF6E3DB);
  static const Color accentWashBorder = Color(0xFFEBC7B8);

  // --- Text ---------------------------------------------------------------
  static const Color textPrimary = Color(0xFF141413);
  static const Color textSecondary = Color(0xFF5E5D59);
  static const Color textTertiary = Color(0xFF87867F);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color textOnInverse = Color(0xFFFAF9F5);
  static const Color textOnInverseMuted = Color(0xFFB8B6AD);

  // --- Borders & dividers ---------------------------------------------------
  static const Color border = Color(0xFFE3E1D7);
  static const Color borderStrong = Color(0xFFCFCDC1);
  static const Color divider = Color(0xFFECEAE1);

  // --- Semantic (muted, paper-friendly) ------------------------------------
  static const Color success = Color(0xFF4C8055);
  static const Color successWash = Color(0xFFE4EEE5);
  static const Color warning = Color(0xFFB8862D);
  static const Color warningWash = Color(0xFFF5EBD7);
  static const Color error = Color(0xFFBF4D43);
  static const Color errorWash = Color(0xFFF6E2E0);
  static const Color info = Color(0xFF5B7A8C);
  static const Color infoWash = Color(0xFFE3EBF0);

  // --- Navigation ------------------------------------------------------------
  static const Color navActive = textPrimary;
  static const Color navInactive = Color(0xFFA3A29A);

  // --- Category colors (muted, harmonious with ivory) ----------------------
  static const Color categoryIdentity = Color(0xFFD97757); // terracotta
  static const Color categoryEducation = Color(0xFF6A8CAF); // slate blue
  static const Color categoryFinance = Color(0xFF5E8D66); // moss green
  static const Color categoryMedical = Color(0xFFC25B4E); // clay red
  static const Color categoryTravel = Color(0xFFB8862D); // ochre
  static const Color categoryFamily = Color(0xFF9C6B9E); // muted plum
  static const Color categoryOther = Color(0xFF87867F); // warm gray

  /// 12% wash of a category color for icon chips / tag backgrounds.
  static Color wash(Color c) => c.withValues(alpha: 0.12);

  /// 24% border of a category color.
  static Color washBorder(Color c) => c.withValues(alpha: 0.24);

  // --- Shadows ---------------------------------------------------------------
  /// Cards: one soft ambient shadow, barely-there. Paper, not plastic.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF141413).withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  /// Floating elements (FAB, bottom bar, sheets).
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: const Color(0xFF141413).withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
