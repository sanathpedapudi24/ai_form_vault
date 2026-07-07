import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography: serif display (Source Serif 4 — closest Google Font to
/// Anthropic's Tiempos/Copernicus) for headings and large numbers,
/// Inter for UI and body text.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _serif({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.sourceSerif4(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle _sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  // --- Serif display -------------------------------------------------------
  /// Hero greeting / page-level statements.
  static TextStyle get display =>
      _serif(size: 32, weight: FontWeight.w600, letterSpacing: -0.5, height: 1.15);

  /// Screen titles ("Vault", "Search").
  static TextStyle get title =>
      _serif(size: 26, weight: FontWeight.w600, letterSpacing: -0.3, height: 1.2);

  /// Card titles / sheet headers.
  static TextStyle get titleSmall =>
      _serif(size: 20, weight: FontWeight.w600, height: 1.25);

  /// Large stat numbers.
  static TextStyle get statNumber =>
      _serif(size: 30, weight: FontWeight.w600, letterSpacing: -0.5);

  // --- Sans UI ---------------------------------------------------------------
  static TextStyle get headline =>
      _sans(size: 17, weight: FontWeight.w600, letterSpacing: -0.2);

  static TextStyle get itemTitle =>
      _sans(size: 15, weight: FontWeight.w600, letterSpacing: -0.1);

  static TextStyle get body =>
      _sans(size: 15, height: 1.45, color: AppColors.textPrimary);

  static TextStyle get bodySecondary =>
      _sans(size: 14, height: 1.45, color: AppColors.textSecondary);

  static TextStyle get caption =>
      _sans(size: 12.5, color: AppColors.textTertiary, height: 1.35);

  static TextStyle get label =>
      _sans(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary);

  /// Small all-caps section markers ("RECENT", "IDENTITY").
  static TextStyle get overline => _sans(
    size: 11,
    weight: FontWeight.w600,
    color: AppColors.textTertiary,
    letterSpacing: 1.1,
  );

  static TextStyle get button =>
      _sans(size: 15, weight: FontWeight.w600, letterSpacing: -0.1);

  static TextStyle get buttonSmall =>
      _sans(size: 13.5, weight: FontWeight.w600);

  /// Monospaced for ID numbers (PAN, Aadhaar) — tabular, trustworthy.
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );
}
