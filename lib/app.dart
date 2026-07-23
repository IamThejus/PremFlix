import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

/// Root widget: wires the dynamic theme and the router together.
///
/// Watching [themeControllerProvider] here means an accent change rebuilds
/// [MaterialApp.router] with a fresh [ThemeData] — every screen picks up
/// the new accent in a single frame with no per-widget plumbing.
class PremFlixApp extends ConsumerWidget {
  const PremFlixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'PremFlix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(accent),
      routerConfig: router,
      // Smooth scrolling everywhere, including mouse-wheel on desktop.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      ),
    );
  }
}
