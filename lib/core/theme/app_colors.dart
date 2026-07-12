import 'package:flutter/material.dart';

/// Claude / Anthropic design language.
///
/// Light: warm ivory surfaces, near-black warm text, terracotta ("book
/// cloth") accent. Dark: warm near-black surfaces (Claude's own dark
/// ground), the same terracotta accent tuned brighter so it holds up on a
/// dark field. Nothing neon, nothing gradient-heavy — paper and ink, then
/// the same room with the lights off.
///
/// Colors are exposed as getters that switch on [dark]. That means they
/// can't be used in `const` expressions — call sites that used to write
/// `const BoxDecoration(color: AppColors.bg)` drop the `const`.
class AppColors {
  AppColors._();

  /// Set once per build from the dark-mode setting (see AIFormVaultApp).
  static bool dark = false;

  static Color _c(int light, int dark_) => Color(dark ? dark_ : light);

  // --- Surfaces ----------------------------------------------------------
  static Color get bg => _c(0xFFFAF9F5, 0xFF1A1915);
  static Color get bgSunken => _c(0xFFF0EEE6, 0xFF262521);
  static Color get bgDeep => _c(0xFFE8E6DC, 0xFF33322C);
  static Color get surface => _c(0xFFFFFFFF, 0xFF232220);
  static Color get surfaceInverse => _c(0xFF262624, 0xFF302F2C);
  static Color get surfaceInverseRaised => _c(0xFF30302E, 0xFF3A3934);

  // --- Accent: terracotta "book cloth" ------------------------------------
  static Color get accent => _c(0xFFD97757, 0xFFE08a6c);
  static Color get accentPressed => _c(0xFFC4633F, 0xFFC4633F);
  static Color get accentDeep => _c(0xFFA54E2C, 0xFFE8A489);
  static Color get accentWash => _c(0xFFF6E3DB, 0xFF3A2C25);
  static Color get accentWashBorder => _c(0xFFEBC7B8, 0xFF553F33);

  // --- Text ---------------------------------------------------------------
  static Color get textPrimary => _c(0xFF141413, 0xFFF2F0E9);
  static Color get textSecondary => _c(0xFF5E5D59, 0xFFB2B0A7);
  static Color get textTertiary => _c(0xFF87867F, 0xFF807E75);
  static Color get textOnAccent => const Color(0xFFFFFFFF);
  static Color get textOnInverse => const Color(0xFFFAF9F5);
  static Color get textOnInverseMuted => const Color(0xFFB8B6AD);

  // --- Borders & dividers ---------------------------------------------------
  static Color get border => _c(0xFFE3E1D7, 0xFF33322C);
  static Color get borderStrong => _c(0xFFCFCDC1, 0xFF474640);
  static Color get divider => _c(0xFFECEAE1, 0xFF2C2B26);

  // --- Semantic (muted, paper-friendly) ------------------------------------
  static Color get success => _c(0xFF4C8055, 0xFF7DB587);
  static Color get successWash => _c(0xFFE4EEE5, 0xFF23302A);
  static Color get warning => _c(0xFFB8862D, 0xFFD9AC5C);
  static Color get warningWash => _c(0xFFF5EBD7, 0xFF332B1B);
  static Color get error => _c(0xFFBF4D43, 0xFFE08379);
  static Color get errorWash => _c(0xFFF6E2E0, 0xFF3A2420);
  static Color get info => _c(0xFF5B7A8C, 0xFF8FB0C2);
  static Color get infoWash => _c(0xFFE3EBF0, 0xFF232D33);

  // --- Navigation ------------------------------------------------------------
  static Color get navActive => textPrimary;
  static Color get navInactive => _c(0xFFA3A29A, 0xFF6D6C64);

  // --- Category colors (kept stable across themes — they carry meaning) ----
  static const Color categoryIdentity = Color(0xFFD97757); // terracotta
  static const Color categoryEducation = Color(0xFF6A8CAF); // slate blue
  static const Color categoryFinance = Color(0xFF5E8D66); // moss green
  static const Color categoryMedical = Color(0xFFC25B4E); // clay red
  static const Color categoryTravel = Color(0xFFB8862D); // ochre
  static const Color categoryFamily = Color(0xFF9C6B9E); // muted plum
  static const Color categoryOther = Color(0xFF87867F); // warm gray

  /// 12% wash of a category color for icon chips / tag backgrounds.
  /// A touch stronger in dark mode so the tint still reads.
  static Color wash(Color c) => c.withValues(alpha: dark ? 0.20 : 0.12);

  /// 24% border of a category color.
  static Color washBorder(Color c) => c.withValues(alpha: dark ? 0.34 : 0.24);

  // --- Shadows ---------------------------------------------------------------
  /// Cards: one soft ambient shadow, barely-there. Paper, not plastic.
  /// Shadows do little on a dark ground, so they deepen slightly there.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.24 : 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  /// Floating elements (FAB, bottom bar, sheets).
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.4 : 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
