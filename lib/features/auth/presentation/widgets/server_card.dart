import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/models/discovered_server.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// A discovered-server row rendered as a premium glass card.
///
/// Focusable for D-pad use with no hover dependency: focus (or hover, or
/// press) lifts it to 1.05×, adds an accent glow and a white ring, in a
/// ~180ms curve — the living-room focus treatment used across PremFlix.
class ServerCard extends StatefulWidget {
  const ServerCard({
    super.key,
    required this.server,
    required this.onSelect,
    this.autofocus = false,
  });

  final DiscoveredServer server;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  State<ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<ServerCard> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  bool get _active => (_focused || _hovered) && !_pressed;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final theme = Theme.of(context);

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onSelect(),
        ),
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onSelect,
        child: AnimatedScale(
          scale: _active ? 1.05 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _active ? Colors.white : AppColors.border,
                width: _active ? 1.6 : 1,
              ),
              boxShadow: [
                if (_active)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 26,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  color: AppColors.card.withValues(alpha: 0.55),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: context.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.dns_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.server.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.server.displayAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 180),
                        offset: _active ? Offset.zero : const Offset(-0.25, 0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: _active ? accent : AppColors.textTertiary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
