import 'package:flutter/material.dart';

/// Core color constants for the PremFlix design system.
///
/// The app is dark-first: [background] and [card] are fixed, while the
/// accent color is dynamic and provided through [AccentPreset]. Widgets
/// should read the accent via `Theme.of(context).colorScheme.primary`
/// (or the `context.accent` extension) rather than referencing a preset
/// directly, so dynamic theming works everywhere for free.
abstract final class AppColors {
  /// Near-black canvas behind all content. Slightly off pure black so
  /// gradients and blur layers have room to render below it.
  static const Color background = Color(0xFF0A0A0A);

  /// Elevated surface for cards, sheets, and dialogs.
  static const Color card = Color(0xFF171717);

  /// A step above [card]; used for hover / pressed states on surfaces.
  static const Color cardHighlight = Color(0xFF222222);

  /// Primary text.
  static const Color text = Colors.white;

  /// Secondary text: metadata, subtitles, captions.
  static const Color textSecondary = Color(0xFFBDBDBD);

  /// Tertiary text: hints, disabled labels.
  static const Color textTertiary = Color(0xFF757575);

  /// Hairline borders and dividers on dark surfaces.
  static const Color border = Color(0x14FFFFFF);

  /// Error / destructive actions.
  static const Color error = Color(0xFFFF5252);

  /// Success states (watched indicators, connection ok).
  static const Color success = Color(0xFF4CD97B);

  /// Scrim used under modals and at the base of hero gradients.
  static const Color scrim = Color(0xCC000000);
}

/// A selectable accent theme.
///
/// Each preset carries a primary accent plus a slightly shifted companion
/// used for gradients, so every accent gets a rich two-tone treatment
/// (glow rings, progress bars, focus outlines) without per-theme tuning.
enum AccentPreset {
  crimson('Crimson', Color(0xFFE50914), Color(0xFFFF4757)),
  amber('Amber', Color(0xFFFFA000), Color(0xFFFFC94D)),
  violet('Violet', Color(0xFF8B5CF6), Color(0xFFB794F6)),
  ocean('Ocean', Color(0xFF0EA5E9), Color(0xFF5EC8F8)),
  emerald('Emerald', Color(0xFF10B981), Color(0xFF5EEAD4)),
  rose('Rose', Color(0xFFF43F5E), Color(0xFFFB7185));

  const AccentPreset(this.label, this.color, this.companion);

  /// Human-readable name shown in settings.
  final String label;

  /// The primary accent color.
  final Color color;

  /// A lighter companion shade used as the second stop in accent gradients.
  final Color companion;

  /// The default accent when the user has never picked one.
  static const AccentPreset fallback = AccentPreset.crimson;

  /// Looks up a preset by its persisted [name], falling back to
  /// [fallback] when the stored value is unknown (e.g. after removing
  /// a preset in a future release).
  static AccentPreset fromName(String? name) => AccentPreset.values.firstWhere(
        (preset) => preset.name == name,
        orElse: () => fallback,
      );

  /// The two-stop gradient for this accent.
  LinearGradient get gradient => LinearGradient(
        colors: [color, companion],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
