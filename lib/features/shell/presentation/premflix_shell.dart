import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/auth_session.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/responsive.dart';
import 'widgets/premflix_nav_bar.dart';

/// The persistent navigation shell wrapping the five primary tabs.
///
/// Built on [StatefulShellRoute.indexedStack] so each tab keeps its own
/// navigator and scroll position — switching tabs is instant and never
/// reloads content. Layout adapts to the device:
///
///  * phones → a bottom navigation bar (thumb-reachable)
///  * tablets / desktop / TV → a floating top navigation bar
///
/// The bar frosts as the active page scrolls (a [ScrollNotification]
/// listener spans every branch), and Android back on a secondary tab
/// returns to Home before exiting.
class PremFlixShell extends ConsumerStatefulWidget {
  const PremFlixShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<PremFlixShell> createState() => _PremFlixShellState();
}

class _PremFlixShellState extends ConsumerState<PremFlixShell> {
  bool _scrolled = false;

  int get _index => widget.navigationShell.currentIndex;

  void _select(int index) {
    // Re-tapping the active tab pops it back to its root, like every
    // major streaming app.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == _index,
    );
    // A freshly shown branch may be at the top; drop the frost so the bar
    // doesn't stay tinted over a hero.
    if (_scrolled) setState(() => _scrolled = false);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final scrolled = notification.metrics.pixels > 24;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  Future<void> _signOut(AuthSession session) async {
    await ref.read(authRepositoryProvider).logout(session);
    await ref.read(sessionControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    if (session == null) return const Scaffold(body: SizedBox.shrink());

    // Bottom nav on touch phones; top nav on tablets, desktop, and TV.
    final useBottomNav = context.isCompact && !context.isTv;

    final content = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.navigationShell,
    );

    return PopScope(
      // Back from a secondary tab returns to Home instead of exiting.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: content),
            if (!useBottomNav)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: PremFlixTopNav(
                  session: session,
                  currentIndex: _index,
                  scrolled: _scrolled,
                  onSelect: _select,
                  onSettings: () => context.pushNamed(AppRoutes.settings),
                  onSignOut: () => _signOut(session),
                ),
              ),
          ],
        ),
        bottomNavigationBar: useBottomNav
            ? PremFlixBottomNav(currentIndex: _index, onSelect: _select)
            : null,
      ),
    );
  }
}
