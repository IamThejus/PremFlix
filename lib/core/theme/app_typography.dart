import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// PremFlix type system.
///
/// Two families give the app a cinematic voice without feeling busy:
///  * **Outfit** — geometric display face for titles, hero text, and the
///    wordmark. Tight tracking at large sizes reads like film key art.
///  * **Inter** — highly legible workhorse for body copy, metadata, and
///    UI labels at small sizes on TV-distance screens.
abstract final class AppTypography {
  /// Hero banner titles and the largest on-screen text.
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.05,
        color: AppColors.text,
      );

  /// Detail page titles.
  static TextStyle get displayMedium => GoogleFonts.outfit(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.1,
        color: AppColors.text,
      );

  /// Section / row headers ("Continue Watching", "Trending").
  static TextStyle get headline => GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.text,
      );

  /// Card titles and dialog headers.
  static TextStyle get title => GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.text,
      );

  /// Primary body copy (overviews, descriptions).
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.text,
      );

  /// Secondary body copy.
  static TextStyle get bodySecondary =>
      body.copyWith(color: AppColors.textSecondary);

  /// Metadata rows: year, runtime, genres.
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.textSecondary,
      );

  /// Buttons and interactive labels.
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.text,
      );

  /// Tiny badges (quality tags, episode numbers).
  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      );

  /// The Material [TextTheme] derived from the styles above, so framework
  /// widgets that read the theme inherit PremFlix typography automatically.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        headlineMedium: headline,
        titleMedium: title,
        bodyLarge: body,
        bodyMedium: bodySecondary,
        bodySmall: caption,
        labelLarge: label,
        labelSmall: overline,
      );
}
