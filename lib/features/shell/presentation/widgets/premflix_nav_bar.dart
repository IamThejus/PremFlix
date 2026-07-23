import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/models/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/premflix_wordmark.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../nav_metrics.dart';

/// The five primary destinations, in nav order. Branch index == [index].
enum PremFlixTab {
  home('Home', Icons.home_rounded),
  movies('Movies', Icons.movie_rounded),
  tv('TV Shows', Icons.tv_rounded),
  collections('Collections', Icons.collections_bookmark_rounded),
  search('Search', Icons.search_rounded);

  const PremFlixTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Floating top navigation bar (tablet / desktop / TV).
///
/// Transparent-with-scrim over a hero, frosting to a tinted blur once the
/// active page scrolls. Every element — tabs, settings, avatar — is
/// focusable for D-pad use; the active tab autofocuses on TV so there is
/// always a deterministic initial focus.
class PremFlixTopNav extends StatelessWidget {
  const PremFlixTopNav({
    super.key,
    required this.session,
    required this.currentIndex,
    required this.scrolled,
    required this.onSelect,
    required this.onSettings,
    required this.onSignOut,
  });

  final AuthSession session;
  final int currentIndex;
  final bool scrolled;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final tv = context.isTv;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: scrolled ? 18 : 0,
          sigmaY: scrolled ? 18 : 0,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          height: topPadding + kPremFlixNavBarHeight,
          padding: EdgeInsets.only(
            top: topPadding,
            left: context.pageInset,
            right: context.pageInset,
          ),
          decoration: BoxDecoration(
            color: scrolled
                ? AppColors.background.withValues(alpha: 0.78)
                : Colors.transparent,
            gradient: scrolled
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xB3000000), Colors.transparent],
                  ),
            border: Border(
              bottom: BorderSide(
                color: scrolled ? AppColors.border : Colors.transparent,
              ),
            ),
          ),
          child: FocusTraversalGroup(
            child: Row(
              children: [
                _WordmarkButton(onTap: () => onSelect(PremFlixTab.home.index)),
                const SizedBox(width: 34),
                for (final tab in PremFlixTab.values) ...[
                  _TopNavItem(
                    label: tab.label,
                    active: currentIndex == tab.index,
                    autofocus: tv && currentIndex == tab.index,
                    onTap: () => onSelect(tab.index),
                  ),
                  const SizedBox(width: 22),
                ],
                const Spacer(),
                _NavIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onPressed: onSettings,
                ),
                const SizedBox(width: 8),
                _AvatarMenu(session: session, onSignOut: onSignOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation bar (phones). Thumb-reachable, five focusable
/// destinations with icon + label and an accent-tinted active state.
class PremFlixBottomNav extends StatelessWidget {
  const PremFlixBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding, top: 6),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: FocusTraversalGroup(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final tab in PremFlixTab.values)
              _BottomNavItem(
                tab: tab,
                active: currentIndex == tab.index,
                onTap: () => onSelect(tab.index),
              ),
          ],
        ),
      ),
    );
  }
}

/// A top-nav tab: label + animated accent underline, focus/hover scale.
class _TopNavItem extends StatefulWidget {
  const _TopNavItem({
    required this.label,
    required this.active,
    required this.autofocus,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  State<_TopNavItem> createState() => _TopNavItemState();
}

class _TopNavItemState extends State<_TopNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = widget.active || _focused;
    final scale = _focused ? (context.isTv ? 1.08 : 1.05) : 1.0;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: theme.textTheme.titleMedium!.copyWith(
                  fontSize: 16,
                  color: highlighted ? AppColors.text : AppColors.textSecondary,
                  fontWeight:
                      widget.active ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(widget.label),
              ),
              const SizedBox(height: 5),
              // Animated tab indicator.
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 3,
                width: widget.active ? 22 : (_focused ? 12 : 0),
                decoration: BoxDecoration(
                  gradient: context.accentGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bottom-nav destination: icon + label, accent when active/focused.
class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final PremFlixTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _focused;
    final color = highlighted ? context.accent : AppColors.textTertiary;

    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _focused ? 1.1 : 1,
          duration: const Duration(milliseconds: 160),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.tab.icon, size: 24, color: color),
                const SizedBox(height: 4),
                Text(
                  widget.tab.label,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: color,
                        letterSpacing: 0.2,
                        fontWeight:
                            widget.active ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Focusable wordmark that returns to the Home tab.
class _WordmarkButton extends StatelessWidget {
  const _WordmarkButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      actions: {
        ActivateIntent:
            CallbackAction<ActivateIntent>(onInvoke: (_) => onTap()),
      },
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const PremFlixWordmark(fontSize: 24),
      ),
    );
  }
}

/// Focusable icon button with focus/hover scale (no hover-only feedback,
/// so it works identically under a remote).
class _NavIconButton extends StatefulWidget {
  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _active = value),
        onShowHoverHighlight: (value) => setState(() => _active = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed(),
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _active ? AppColors.cardHighlight : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 24,
              color: _active ? AppColors.text : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar with a focusable sign-out menu.
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({required this.session, required this.onSignOut});

  final AuthSession session;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.card),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            session.userName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(
            Icons.logout_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: onSignOut,
          child: Text(
            'Sign out',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
      builder: (context, controller, child) => GestureDetector(
        onTap: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: UserAvatar(session: session),
      ),
    );
  }
}
