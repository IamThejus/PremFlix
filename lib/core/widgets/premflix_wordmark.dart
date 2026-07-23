import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// The PremFlix wordmark: "PREM" in white, "FLIX" filled with a slowly
/// sweeping accent gradient.
///
/// The sweep is a subtle idle animation — the gradient's stops drift back
/// and forth so the mark feels alive in app bars and on the splash screen
/// without demanding attention. Set [animated] to false for contexts where
/// motion would distract (screenshots, settings previews).
class PremFlixWordmark extends StatefulWidget {
  const PremFlixWordmark({
    super.key,
    this.fontSize = 28,
    this.animated = true,
  });

  final double fontSize;
  final bool animated;

  @override
  State<PremFlixWordmark> createState() => _PremFlixWordmarkState();
}

class _PremFlixWordmarkState extends State<PremFlixWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PremFlixWordmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animated && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle get _style => GoogleFonts.outfit(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: widget.fontSize * 0.06,
        height: 1,
      );

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final companion = context.accentCompanion;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Drift the gradient horizontally across the "FLIX" half.
        final shift = _controller.value * 0.6 - 0.3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PREM', style: _style.copyWith(color: Colors.white)),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [accent, companion, accent],
                begin: Alignment(-1 + shift, 0),
                end: Alignment(1 + shift, 0),
              ).createShader(bounds),
              child: Text(
                'FLIX',
                style: _style.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
