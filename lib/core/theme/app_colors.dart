import 'package:flutter/material.dart';

/// Material 3 palette, light and dark.
///
/// Colors are exposed as getters that switch on [dark] — set once by
/// [AppTheme] when it builds a `ThemeData` for a given `Brightness`. That
/// means these can't be used in `const` expressions; call sites that need a
/// fixed color regardless of theme should use the `const` fields below
/// instead (category colors, and the intentionally-inverse surfaces).
class AppColors {
  AppColors._();

  /// Set by [AppTheme] before building light/dark `ThemeData`. Every
  /// non-const getter below reads this — one flip here re-themes every call
  /// site that references `AppColors.*` directly.
  static bool dark = false;

  static Color _c(int light, int darkValue) =>
      Color(dark ? darkValue : light);

  // --- Surfaces ----------------------------------------------------------
  static Color get bg => _c(0xFFFDFCFA, 0xFF0B0B0E);
  static Color get bgSunken => _c(0xFFF3F1ED, 0xFF121216);
  static Color get bgDeep => _c(0xFFE9E7E1, 0xFF1A1A20);
  static Color get surface => _c(0xFFFFFFFF, 0xFF16161B);

  // Inverted surfaces for purposeful dark accents (virtual ID, highlight
  // bar) — intentionally theme-stable, always dark regardless of [dark].
  static const Color surfaceInverse = Color(0xFF262624);
  static const Color surfaceInverseRaised = Color(0xFF30302E);

  // --- Accent: terracotta -----------------------------------------------------
  static Color get accent => _c(0xFFD97757, 0xFFE08A6C);
  static Color get accentPressed => _c(0xFFC4633F, 0xFFC4633F);
  static Color get accentDeep => _c(0xFF9A4B2C, 0xFFE8A489);
  static Color get accentWash => _c(0xFFFBEAE2, 0xFF2B1D17);
  static Color get accentWashBorder => _c(0xFFF3CEBF, 0xFF4A3128);

  // --- Text --------------------------------------------------------------------
  static Color get textPrimary => _c(0xFF1C1B1F, 0xFFF5F5F7);
  static Color get textSecondary => _c(0xFF49454F, 0xFFA5A5B0);
  static Color get textTertiary => _c(0xFF79747E, 0xFF70707C);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color textOnInverse = Color(0xFFFAF9F5);
  static const Color textOnInverseMuted = Color(0xFFB8B6AD);

  // --- Borders & dividers --------------------------------------------------------
  static Color get border => _c(0xFFE3E1D7, 0xFF232329);
  static Color get borderStrong => _c(0xFFCFCDC1, 0xFF35353E);
  static Color get divider => _c(0xFFECEAE1, 0xFF1C1C22);

  // --- Semantic ---------------------------------------------------------------
  static Color get success => _c(0xFF38A36A, 0xFF7DB587);
  static Color get successWash => _c(0xFFE7F4EC, 0xFF16241C);
  static Color get warning => _c(0xFFB8862D, 0xFFD9AC5C);
  static Color get warningWash => _c(0xFFF8EFDC, 0xFF262012);
  static Color get error => _c(0xFFB3261E, 0xFFE08379);
  static Color get errorWash => _c(0xFFF9EDEA, 0xFF2C1815);
  static Color get info => _c(0xFF5B8BB0, 0xFF8FB0C2);
  static Color get infoWash => _c(0xFFE7F0F6, 0xFF17222A);

  // --- Navigation -----------------------------------------------------------------
  static Color get navActive => textPrimary;
  static Color get navInactive => _c(0xFFA3A29A, 0xFF5C5C66);

  // --- Category colors (stable across themes — they carry meaning) ---------------
  static const Color categoryIdentity = Color(0xFFD97757); // terracotta
  static const Color categoryEducation = Color(0xFF6A8CAF); // slate blue
  static const Color categoryFinance = Color(0xFF5E8D66); // moss green
  static const Color categoryMedical = Color(0xFFC25B4E); // clay red
  static const Color categoryTravel = Color(0xFFB8862D); // ochre
  static const Color categoryFamily = Color(0xFF9C6B9E); // muted plum
  static const Color categoryOther = Color(0xFF87867F); // warm gray

  /// 14% wash of a category color for icon chips / tag backgrounds.
  static Color wash(Color c) => c.withValues(alpha: 0.14);

  /// 30% border of a category color.
  static Color washBorder(Color c) => c.withValues(alpha: 0.30);

  // --- Shadows ---------------------------------------------------------------
  /// Card: one soft ambient shadow, barely-there in light, deeper in dark
  /// (shadows do little on a true-black ground unless they're stronger).
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.45 : 0.05),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  /// Floating elements (FAB, bottom bar, sheets).
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.6 : 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Ergonomic access to the M3 color roles from any widget:
/// `context.scheme.primary` instead of `Theme.of(context).colorScheme.primary`.
///
/// Prefer these roles over the static [AppColors] getters in new widgets —
/// they resolve from the inherited theme.
extension SchemeOnContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
