import 'package:flutter/material.dart';

/// Claude / Anthropic design language, with a CRED-inspired dark mode.
///
/// Light: warm ivory surfaces, near-black warm text, terracotta ("book
/// cloth") accent. Dark: deep true-black ground with cool graphite cards,
/// hairline borders, and crisp near-white text — the CRED look — with the
/// same terracotta accent as the single saturated pop against the black.
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
  static Color get bg => _c(0xFFFAF9F5, 0xFF0B0B0E);
  static Color get bgSunken => _c(0xFFF0EEE6, 0xFF121216);
  static Color get bgDeep => _c(0xFFE8E6DC, 0xFF1A1A20);
  static Color get surface => _c(0xFFFFFFFF, 0xFF16161B);
  static Color get surfaceInverse => _c(0xFF262624, 0xFF1F1F26);
  static Color get surfaceInverseRaised => _c(0xFF30302E, 0xFF28282F);

  // --- Accent: terracotta "book cloth" ------------------------------------
  static Color get accent => _c(0xFFD97757, 0xFFE08a6c);
  static Color get accentPressed => _c(0xFFC4633F, 0xFFC4633F);
  static Color get accentDeep => _c(0xFFA54E2C, 0xFFE8A489);
  static Color get accentWash => _c(0xFFF6E3DB, 0xFF2B1D17);
  static Color get accentWashBorder => _c(0xFFEBC7B8, 0xFF4A3128);

  // --- Text ---------------------------------------------------------------
  static Color get textPrimary => _c(0xFF141413, 0xFFF5F5F7);
  static Color get textSecondary => _c(0xFF5E5D59, 0xFFA5A5B0);
  static Color get textTertiary => _c(0xFF87867F, 0xFF70707C);
  static Color get textOnAccent => const Color(0xFFFFFFFF);
  static Color get textOnInverse => const Color(0xFFFAF9F5);
  static Color get textOnInverseMuted => const Color(0xFFB8B6AD);

  // --- Borders & dividers ---------------------------------------------------
  static Color get border => _c(0xFFE3E1D7, 0xFF232329);
  static Color get borderStrong => _c(0xFFCFCDC1, 0xFF35353E);
  static Color get divider => _c(0xFFECEAE1, 0xFF1C1C22);

  // --- CRED-style card surface --------------------------------------------
  // Cards read as a single lit slab of obsidian: a soft top-to-bottom
  // gradient (lighter at the top, as if catching light) over a hairline
  // edge that's brighter than the surrounding ground. In light mode this
  // stays near-flat white so the paper aesthetic is preserved.
  static Color get cardGradientTop => _c(0xFFFFFFFF, 0xFF20202A);
  static Color get cardGradientBottom => _c(0xFFFBFAF7, 0xFF141419);

  /// Hairline that rims each card — a touch brighter than the card so the
  /// edge catches light (the CRED "lifted glass" look).
  static Color get cardBorder => _c(0xFFE7E5DB, 0xFF2E2E39);

  /// The card fill as a gradient, for [BoxDecoration.gradient].
  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardGradientTop, cardGradientBottom],
  );

  // Brightness-parameterized variants of the card tokens. These take the
  // dark flag explicitly so a widget can resolve them from its inherited
  // Theme (reactive across a live dark-mode toggle) instead of the global
  // [dark] flag (which only re-resolves on a full rebuild).
  static Color _cc(bool d, int light, int dark_) => Color(d ? dark_ : light);

  /// Three-stop gradient: a distinctly brighter sliver at the very top (the
  /// light-catching edge), fading fast into the card body which then deepens
  /// toward the bottom. This is the CRED signature — a slab that looks lit
  /// from above with real depth, not a flat rectangle.
  static LinearGradient cardGradientFor(bool d) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.0, 0.10, 1.0],
    colors: [
      _cc(d, 0xFFFFFFFF, 0xFF3A3A47),
      _cc(d, 0xFFFCFBF8, 0xFF20202A),
      _cc(d, 0xFFF1EEE6, 0xFF131318),
    ],
  );

  /// A visibly brighter rim — pronounced in dark so the card edge reads as a
  /// lifted pane, and a clear warm hairline in light.
  static Color cardBorderFor(bool d) => _cc(d, 0xFFDFDCCF, 0xFF3C3C4A);

  static List<BoxShadow> cardShadowFor(bool d) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: d ? 0.55 : 0.07),
      blurRadius: d ? 20 : 14,
      offset: const Offset(0, 6),
    ),
  ];

  // --- Semantic (muted, paper-friendly) ------------------------------------
  static Color get success => _c(0xFF4C8055, 0xFF7DB587);
  static Color get successWash => _c(0xFFE4EEE5, 0xFF16241C);
  static Color get warning => _c(0xFFB8862D, 0xFFD9AC5C);
  static Color get warningWash => _c(0xFFF5EBD7, 0xFF262012);
  static Color get error => _c(0xFFBF4D43, 0xFFE08379);
  static Color get errorWash => _c(0xFFF6E2E0, 0xFF2C1815);
  static Color get info => _c(0xFF5B7A8C, 0xFF8FB0C2);
  static Color get infoWash => _c(0xFFE3EBF0, 0xFF17222A);

  // --- Navigation ------------------------------------------------------------
  static Color get navActive => textPrimary;
  static Color get navInactive => _c(0xFFA3A29A, 0xFF5C5C66);

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
      color: Colors.black.withValues(alpha: dark ? 0.45 : 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  /// Floating elements (FAB, bottom bar, sheets).
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.6 : 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
