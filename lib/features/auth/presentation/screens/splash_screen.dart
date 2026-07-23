import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/logo_reveal.dart';

/// Boot screen: pure black canvas hosting the [LogoReveal] ident.
///
/// Navigation is not triggered here — the router redirects when the
/// session restore resolves, and `SessionController` holds that resolve
/// until the ident's settle point (2.8 s), so the route-level fade
/// transition doubles as the ident's fade-out. Keeping the splash dumb
/// means deep links, sign-out bounces, and cold starts all share one
/// navigation path.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scale the wordmark to the viewport: eight condensed glyphs should
    // span roughly 70% of the width on phones without overflowing TVs.
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = (width * 0.105).clamp(44.0, 96.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: LogoReveal(color: context.accent, fontSize: fontSize),
      ),
    );
  }
}
