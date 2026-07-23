import 'package:flutter/material.dart';

/// Fades and slides its child in after [delay] — the building block for
/// staggered entrances (login form fields, home rows appearing in
/// sequence).
///
/// Stateless from the caller's perspective: give each item in a column an
/// increasing delay and the group choreographs itself. Uses a single
/// controller per instance; for list-length staggering prefer modest
/// delays (60–90 ms steps) so the whole sequence stays under ~600 ms.
class EntranceReveal extends StatefulWidget {
  const EntranceReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting offset as a fraction of the child's size (default: slide
  /// up from 8% below).
  final Offset offset;

  @override
  State<EntranceReveal> createState() => _EntranceRevealState();
}

class _EntranceRevealState extends State<EntranceReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: widget.offset, end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}
