import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Ambient animated backdrop: two large accent-tinted radial glows drift
/// slowly across the dark canvas behind [child].
///
/// Painted with a [CustomPainter] (two radial gradients on an animated
/// controller) rather than blurred containers — no saveLayer, no
/// BackdropFilter — so it stays cheap enough to run continuously even on
/// low-powered TV hardware. Alpha is kept very low; the effect should be
/// felt, not noticed.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _AuroraPainter(
              progress: _controller.value,
              accent: context.accent,
              companion: context.accentCompanion,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({
    required this.progress,
    required this.accent,
    required this.companion,
  });

  final double progress;
  final Color accent;
  final Color companion;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(progress);

    _drawGlow(
      canvas,
      center: Offset(
        size.width * (0.15 + 0.25 * t),
        size.height * (0.2 + 0.1 * t),
      ),
      radius: size.longestSide * 0.45,
      color: accent.withValues(alpha: 0.10),
    );
    _drawGlow(
      canvas,
      center: Offset(
        size.width * (0.9 - 0.2 * t),
        size.height * (0.85 - 0.15 * t),
      ),
      radius: size.longestSide * 0.4,
      color: companion.withValues(alpha: 0.07),
    );
  }

  void _drawGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.companion != companion;
}
