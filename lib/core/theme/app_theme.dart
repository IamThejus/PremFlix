import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the single dark [ThemeData] used across the app.
///
/// PremFlix deliberately avoids the stock Material look: ripples are
/// disabled in favor of custom hover/press animations, surfaces are
/// tinted charcoal instead of elevation-tinted, and every accent-aware
/// property is derived from the active [AccentPreset] so switching
/// accents restyles the whole app in one frame.
abstract final class AppTheme {
  /// System chrome that matches the dark canvas (transparent status bar,
  /// dark navigation bar). Applied once at startup.
  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build(AccentPreset accent) {
    final colorScheme = ColorScheme.dark(
      primary: accent.color,
      secondary: accent.companion,
      surface: AppColors.card,
      onPrimary: Colors.white,
      onSurface: AppColors.text,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: AppTypography.textTheme,
      // Custom widgets provide their own feedback; Material ink effects
      // would make the app feel like a stock Material product.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: AppColors.cardHighlight,
      focusColor: accent.color.withValues(alpha: 0.25),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.text, size: 24),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: overlayStyle,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent.color,
        selectionColor: accent.color.withValues(alpha: 0.35),
        selectionHandleColor: accent.color,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle:
            AppTypography.body.copyWith(color: AppColors.textTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(accent.color, width: 1.6),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.6),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          Colors.white.withValues(alpha: 0.2),
        ),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardHighlight,
        contentTextStyle: AppTypography.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Suppress default platform transitions; go_router supplies
          // PremFlix's custom transitions per route instead.
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Convenience accessors so widgets can write `context.accent` instead of
/// threading `Theme.of(context).colorScheme.primary` everywhere.
extension ThemeContext on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get accentCompanion => Theme.of(this).colorScheme.secondary;

  /// The active accent gradient (primary → companion).
  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentCompanion],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
