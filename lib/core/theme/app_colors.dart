import 'package:flutter/material.dart';

/// Material 3 light-theme palette.
///
/// All values are fixed light-theme M3-role-aligned colors. Deriving the full
/// M3 role set (primary/secondary/tertiary/surface/.../outline) from a single
/// terracotta seed happens in [app_theme.dart] via `ColorScheme.fromSeed`.
/// This class only bridges static colors the older widgets still reference
/// directly, so a full-field refactor isn't required to switch themes.
class AppColors {
  AppColors._();

  // --- Surfaces (light) ------------------------------------------------------
  static const Color bg = Color(0xFFFDFCFA); // scaffold / M3 surface
  static const Color bgSunken = Color(0xFFF3F1ED); // M3 surface-container-low
  static const Color bgDeep = Color(0xFFE9E7E1); // M3 surface-container-high
  static const Color surface = Color(0xFFFFFFFF); // elevated cards / sheets

  // Inverted surfaces for purposeful dark accents (virtual ID, highlight bar).
  static const Color surfaceInverse = Color(0xFF262624);
  static const Color surfaceInverseRaised = Color(0xFF30302E);

  // --- Accent: terracotta -----------------------------------------------------
  static const Color accent = Color(0xFFD97757); // M3 primary
  static const Color accentPressed = Color(0xFFC4633F);
  static const Color accentDeep = Color(0xFF9A4B2C); // M3 on-primary-container
  static const Color accentWash = Color(0xFFFBEAE2); // M3 primary-container
  static const Color accentWashBorder = Color(0xFFF3CEBF);

  // --- Text --------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1C1B1F); // M3 on-surface
  static const Color textSecondary = Color(0xFF49454F); // M3 on-surface-variant
  static const Color textTertiary = Color(0xFF79747E); // M3 outline-variant
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color textOnInverse = Color(0xFFFAF9F5);
  static const Color textOnInverseMuted = Color(0xFFB8B6AD);

  // --- Borders & dividers --------------------------------------------------------
  static const Color border = Color(0xFFE3E1D7);
  static const Color borderStrong = Color(0xFFCFCDC1);
  static const Color divider = Color(0xFFECEAE1);

  // --- Semantic (M3 light) ---------------------------------------------------------
  static const Color success = Color(0xFF38A36A);
  static const Color successWash = Color(0xFFE7F4EC);
  static const Color warning = Color(0xFFB8862D);
  static const Color warningWash = Color(0xFFF8EFDC);
  static const Color error = Color(0xFFB3261E);
  static const Color errorWash = Color(0xFFF9EDEA);
  static const Color info = Color(0xFF5B8BB0);
  static const Color infoWash = Color(0xFFE7F0F6);

  // --- Navigation -----------------------------------------------------------------
  static const Color navActive = textPrimary;
  static const Color navInactive = Color(0xFFA3A29A);

  // --- Category colors (stable across themes — they carry meaning) ---------------
  static const Color categoryIdentity = Color(0xFFD97757); // terracotta
  static const Color categoryEducation = Color(0xFF6A8CAF); // slate blue
  static const Color categoryFinance = Color(0xFF5E8D66); // moss green
  static const Color categoryMedical = Color(0xFFC25B4E); // clay red
  static const Color categoryTravel = Color(0xFFB8862D); // ochre
  static const Color categoryFamily = Color(0xFF9C6B9E); // muted plum
  static const Color categoryOther = Color(0xFF87867F); // warm gray

  /// 14% wash of a category color for icon chips / tag backgrounds (light).
  static Color wash(Color c) => c.withValues(alpha: 0.14);

  /// 30% border of a category color.
  static Color washBorder(Color c) => c.withValues(alpha: 0.30);

  // --- Shadows ---------------------------------------------------------------
  /// Card: one soft ambient shadow, barely-there.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  /// Floating elements (FAB, bottom bar, sheets).
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // Backwards-compat: card visual helpers now resolve to flat M3 surfaces.
  // The CRED gradient look is retired in favor of clean tonal surfaces.
  static LinearGradient cardGradientFor(bool dark) => LinearGradient(
    colors: [surface, surface],
  );

  static Color cardBorderFor(bool dark) => border;

  static List<BoxShadow> cardShadowFor(bool dark) => cardShadow;
}

/// Ergonomic access to the M3 color roles from any widget:
/// `context.scheme.primary` instead of `Theme.of(context).colorScheme.primary`.
///
/// Prefer these roles over the static [AppColors] getters in new widgets —
/// they resolve from the inherited theme.
extension SchemeOnContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
}