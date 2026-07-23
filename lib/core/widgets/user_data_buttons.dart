import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../repositories/user_data_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Favorite (heart) toggle for an item.
///
/// Optimistic: the icon flips and pops immediately, the server call runs
/// behind it, and a failure quietly reverts — a toggle should never show
/// a spinner. Seeded from the item's `UserItemData`; the widget owns the
/// state afterwards so repeated toggles don't wait on refetches.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.itemId,
    required this.initialValue,
  });

  final String itemId;
  final bool initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OptimisticToggle(
      initialValue: initialValue,
      activeIcon: Icons.favorite_rounded,
      inactiveIcon: Icons.favorite_outline_rounded,
      activeColor: context.accent,
      tooltip: (active) =>
          active ? 'Remove from favorites' : 'Add to favorites',
      apply: (value) =>
          ref.read(userDataRepositoryProvider).setFavorite(itemId, value),
    );
  }
}

/// Watched (check) toggle for an item.
class WatchedButton extends ConsumerWidget {
  const WatchedButton({
    super.key,
    required this.itemId,
    required this.initialValue,
  });

  final String itemId;
  final bool initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OptimisticToggle(
      initialValue: initialValue,
      activeIcon: Icons.check_circle_rounded,
      inactiveIcon: Icons.check_circle_outline_rounded,
      activeColor: AppColors.success,
      tooltip: (active) => active ? 'Mark as unwatched' : 'Mark as watched',
      apply: (value) =>
          ref.read(userDataRepositoryProvider).setPlayed(itemId, value),
    );
  }
}

/// Shared optimistic-toggle chassis: frosted circle, icon swap with a
/// scale pop, hover lift, silent revert on failure.
class _OptimisticToggle extends StatefulWidget {
  const _OptimisticToggle({
    required this.initialValue,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    required this.tooltip,
    required this.apply,
  });

  final bool initialValue;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final String Function(bool active) tooltip;
  final Future<Object?> Function(bool value) apply;

  @override
  State<_OptimisticToggle> createState() => _OptimisticToggleState();
}

class _OptimisticToggleState extends State<_OptimisticToggle> {
  late bool _active = widget.initialValue;
  bool _hovered = false;

  Future<void> _toggle() async {
    final target = !_active;
    setState(() => _active = target);
    try {
      await widget.apply(target);
    } on ApiException {
      if (mounted) setState(() => _active = !target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip(_active),
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: _hovered ? 0.22 : 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hovered ? 0.5 : 0.2),
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  _active ? widget.activeIcon : widget.inactiveIcon,
                  key: ValueKey(_active),
                  size: 24,
                  color: _active ? widget.activeColor : AppColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
