import 'package:flutter/material.dart';

/// Soft volumetric glow behind [child].
///
/// Implemented as a radial gradient layer, not a blur filter — gradients
/// rasterize in a single pass with no saveLayer, so animating
/// [intensity] every frame stays cheap on Android TV hardware.
///
/// The bloom uses two stops (a hot core and a wide falloff) to read as
/// light rather than a flat colored disc.
class Glow extends StatelessWidget {
  const Glow({
    super.key,
    required this.child,
    required this.color,
    this.intensity = 1.0,
    this.radius = 180,
  });

  final Widget child;
  final Color color;

  /// 0 (off) → 1 (full bloom). Values above 1 overdrive the core.
  final double intensity;

  /// Radius of the glow field in logical pixels.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final clamped = intensity.clamp(0.0, 2.0);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (clamped > 0)
          IgnorePointer(
            child: Container(
              width: radius * 2.4,
              height: radius * 1.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(
                      alpha: (0.34 * clamped).clamp(0.0, 1.0),
                    ),
                    color.withValues(
                      alpha: (0.12 * clamped).clamp(0.0, 1.0),
                    ),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
