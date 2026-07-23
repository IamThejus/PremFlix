import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/preferences_service.dart';
import 'app_colors.dart';

/// Holds the active [AccentPreset] and persists changes.
///
/// The whole app rebuilds its [ThemeData] when this changes, which is
/// how "dynamic accent colors" work: every widget reads the accent from
/// the theme, so a single state change restyles everything.
class ThemeController extends Notifier<AccentPreset> {
  @override
  AccentPreset build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return AccentPreset.fromName(
      prefs.getString(PreferencesService.accentKey),
    );
  }

  /// Applies [preset] immediately and persists it for the next launch.
  Future<void> setAccent(AccentPreset preset) async {
    state = preset;
    await ref
        .read(preferencesServiceProvider)
        .setString(PreferencesService.accentKey, preset.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AccentPreset>(ThemeController.new);
