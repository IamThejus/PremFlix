import 'package:flutter/widgets.dart';

/// The device class the current layout is targeting.
///
/// Breakpoints are width-based rather than platform-based so a resized
/// desktop window, a tablet in portrait, and a phone all get the layout
/// that actually fits — the same approach responsive web apps use.
enum ScreenSize {
  /// Phones (portrait) — single-column layouts, compact paddings.
  compact,

  /// Large phones (landscape) and small tablets.
  medium,

  /// Tablets, small desktop windows.
  expanded,

  /// Desktop and TV — widest paddings, most columns, focus navigation.
  large;

  static ScreenSize fromWidth(double width) => switch (width) {
        < 600 => ScreenSize.compact,
        < 905 => ScreenSize.medium,
        < 1400 => ScreenSize.expanded,
        _ => ScreenSize.large,
      };
}

/// Responsive helpers, exposed as a context extension so call sites stay
/// terse: `context.screenSize`, `context.pagePadding`, `context.isTv`.
extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize =>
      ScreenSize.fromWidth(MediaQuery.sizeOf(this).width);

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isLargeScreen =>
      screenSize == ScreenSize.expanded || screenSize == ScreenSize.large;

  /// Horizontal padding for page content at this size. Rows bleed to the
  /// edge but their content starts at this inset, mirroring the gutters
  /// used by cinematic streaming UIs.
  double get pageInset => switch (screenSize) {
        ScreenSize.compact => 16,
        ScreenSize.medium => 24,
        ScreenSize.expanded => 40,
        ScreenSize.large => 56,
      };

  /// Poster width for standard media cards at this size.
  double get posterWidth => switch (screenSize) {
        ScreenSize.compact => 116,
        ScreenSize.medium => 132,
        ScreenSize.expanded => 150,
        ScreenSize.large => 168,
      };

  /// Whether the app is being driven by a remote / d-pad rather than
  /// touch or pointer. Android TV reports no touchscreen, which is the
  /// most reliable runtime signal without a platform channel.
  bool get isTv =>
      MediaQuery.of(this).navigationMode == NavigationMode.directional;
}

/// Picks a value per [ScreenSize] with sensible fallbacks: sizes without
/// an explicit value inherit from the next smaller defined size.
T responsiveValue<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
  T? large,
}) =>
    switch (context.screenSize) {
      ScreenSize.compact => compact,
      ScreenSize.medium => medium ?? compact,
      ScreenSize.expanded => expanded ?? medium ?? compact,
      ScreenSize.large => large ?? expanded ?? medium ?? compact,
    };
