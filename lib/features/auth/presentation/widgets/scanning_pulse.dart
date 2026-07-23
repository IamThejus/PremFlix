import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Radar-style scanning animation: three accent rings expand outward and
/// fade, on a continuous loop, behind [child].
///
/// Painted with a single [CustomPainter] on one repeating controller — no
/// blur layers or particles — so it stays smooth on TV hardware.
class ScanningPulse extends StatefulWidget {
  const ScanningPulse({super.key, required this.child, this.size = 200});

  final Widget child;
  final double size;

  @override
  State<ScanningPulse> createState() => _ScanningPulseState();
}

class _ScanningPulseState extends State<ScanningPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _PulsePainter(
                progress: _controller.value,
                color: context.accent,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const int _rings = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;

    for (var i = 0; i < _rings; i++) {
      // Stagger the rings evenly across the loop.
      final t = (progress + i / _rings) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1 - t) * 0.5;
      if (opacity <= 0) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: opacity),
      );
    }

    // Soft core glow behind the child.
    canvas.drawCircle(
      center,
      maxRadius * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(
          center: center,
          radius: maxRadius * 0.34,
        )),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
