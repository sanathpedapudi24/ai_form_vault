import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography presets for the app.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _baseStyle => GoogleFonts.inter();

  // Headlines
  static TextStyle headlineLarge = _baseStyle.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static TextStyle headlineMedium = _baseStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static TextStyle headlineSmall = _baseStyle.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  // Titles
  static TextStyle titleLarge = _baseStyle.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static TextStyle titleMedium = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static TextStyle titleSmall = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // Body
  static TextStyle bodyLarge = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static TextStyle bodyMedium = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static TextStyle bodySmall = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  // Labels
  static TextStyle labelLarge = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static TextStyle labelMedium = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static TextStyle labelSmall = _baseStyle.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // Special
  static TextStyle statNumber = _baseStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
  );

  static TextStyle completenessPercent = _baseStyle.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w800,
  );

  static TextStyle greeting = _baseStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );
}
