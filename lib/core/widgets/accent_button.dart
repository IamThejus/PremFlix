import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// PremFlix's primary call-to-action button.
///
/// A gradient-filled pill with custom feedback instead of Material ink:
/// it scales down slightly on press, lifts with a soft accent glow on
/// hover/focus (pointer *and* d-pad — the same treatment doubles as the
/// TV focus indicator), and morphs its label into a spinner while
/// [loading]. Width follows the parent, so forms can make it full-bleed.
class AccentButton extends StatefulWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;

  /// Disabled (dimmed, non-interactive) when null or while [loading].
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  State<AccentButton> createState() => _AccentButtonState();
}

class _AccentButtonState extends State<AccentButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;
  bool get _lifted => _enabled && (_hovered || _focused);

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;

    return FocusableActionDetector(
      enabled: _enabled,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed?.call(),
        ),
      },
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 52,
            decoration: BoxDecoration(
              gradient: context.accentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _lifted ? 0.45 : 0.2),
                  blurRadius: _lifted ? 26 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _enabled || widget.loading ? 1 : 0.45,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: widget.loading
                      ? const SizedBox(
                          key: ValueKey('spinner'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          key: const ValueKey('label'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: Theme.of(context).textTheme.labelLarge,
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
