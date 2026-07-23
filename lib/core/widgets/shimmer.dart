import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Custom shimmer: sweeps a soft highlight across its child, used to
/// animate loading skeletons.
///
/// Implemented with a [ShaderMask] whose gradient translates across the
/// child each cycle — no third-party package, and one ticker animates an
/// entire skeleton subtree (a whole row shimmers in sync, which looks
/// deliberate rather than busy).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Slide the highlight from off-screen left to off-screen right.
        final dx = -1.5 + 3.0 * _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(dx - 1, -0.2),
            end: Alignment(dx + 1, 0.2),
            colors: [
              AppColors.card,
              AppColors.cardHighlight,
              AppColors.card,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A solid placeholder block. Compose inside a [Shimmer] for the loading
/// treatment; the shimmer's shader paints over these boxes.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}
