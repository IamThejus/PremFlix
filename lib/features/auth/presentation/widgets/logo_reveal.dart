import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glow.dart';

/// Cinematic PREMFLIX boot ident.
///
/// Sequence (times as fractions of the ~3 s timeline):
///
/// | t (s)     | phase                                                |
/// |-----------|------------------------------------------------------|
/// | 0.0–0.9   | a monumental "P" draws itself: the stem strikes      |
/// |           | downward, the bowl sweeps around — original vector   |
/// |           | art, not a glyph — with crimson depth + glow         |
/// | 1.0–1.44  | the P shrinks to wordmark scale at screen center     |
/// | 1.44–1.74 | it glides left into the first-letter slot            |
/// | 1.68–2.34 | a light beam launches from the P and forges          |
/// |           | R-E-M-F-L-I-X letter by letter as it passes; the     |
/// |           | painted P dissolves into its typeset twin            |
/// | 2.46–2.7  | one subtle sweep across the finished mark            |
/// | 2.7–2.8   | glow settles, confident hold                         |
/// | 2.8       | [onCompleted] fires (host fades to the app)          |
///
/// The structure follows classic ident grammar — big mark, shrink,
/// slide, wordmark reveal — but every element is original: the P is
/// drawn geometry animated via [ui.PathMetric] draw-on, the reveal is
/// the PremFlix forging beam (feathered additive light, never a matte),
/// and all easing curves are custom.
///
/// Performance: one controller, one AnimatedBuilder, two CustomPainters
/// with value-comparing `shouldRepaint`, additive gradients, no
/// BackdropFilter; the whole mark sits in a [RepaintBoundary].
class LogoReveal extends StatefulWidget {
  const LogoReveal({
    super.key,
    this.text = 'PREMFLIX',
    required this.color,
    this.fontSize = 84,
    this.duration = const Duration(milliseconds: 3000),
    this.onCompleted,
  });

  final String text;

  /// Brand color for the mark, glow, and light (crimson by default via
  /// the active theme accent).
  final Color color;
  final double fontSize;
  final Duration duration;

  /// Fires at the 2.8 s mark — the moment the host should begin its
  /// fade into the app.
  final VoidCallback? onCompleted;

  @override
  State<LogoReveal> createState() => _LogoRevealState();
}

class _LogoRevealState extends State<LogoReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  // ---- Timeline (fractions of the full duration) -----------------------
  static const double _stemStart = 0.02, _stemEnd = 0.16;
  static const double _bowlStart = 0.13, _bowlEnd = 0.30;
  static const double _shrinkStart = 0.34, _shrinkEnd = 0.48;
  static const double _slideStart = 0.48, _slideEnd = 0.58;
  static const double _beamStart = 0.56, _beamEnd = 0.78;
  static const double _crossfadeStart = 0.58, _crossfadeEnd = 0.66;
  static const double _sweepStart = 0.82, _sweepEnd = 0.90;
  static const double _settleEnd = 0.933; // 2.8 s

  /// First-letter slot center as a fraction of the row width (first of
  /// eight condensed glyphs), and the beam's overshoot past the edge.
  static const double _pSlot = 0.0625;
  static const double _beamOvershoot = 1.05;

  /// How many glyph-heights tall the monumental P stands.
  static const double _bigScale = 3.2;

  /// Shrink easing: committed start, soft landing — deliberately not a
  /// stock curve.
  static const Curve _shrinkCurve = Cubic(0.62, 0.0, 0.28, 1.0);
  static const Curve _slideCurve = Cubic(0.55, 0.0, 0.22, 1.0);

  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_maybeNotify)
      ..forward();
  }

  void _maybeNotify() {
    if (!_notified && _controller.value >= _settleEnd) {
      _notified = true;
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Eased 0→1 progress of [t] through the window [a, b].
  static double _ramp(double t, double a, double b,
      [Curve curve = Curves.easeInOut]) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    return curve.transform((t - a) / (b - a));
  }

  /// When the beam's x-position reaches letter [index]'s column — the
  /// moment that letter starts to exist.
  double _letterStart(int index) {
    final letterCenter = (index + 0.5) / widget.text.length;
    final travel =
        ((letterCenter - _pSlot) / (_beamOvershoot - _pSlot)).clamp(0.0, 1.0);
    return _beamStart + (_beamEnd - _beamStart) * travel;
  }

  /// Opacity / arrival progress for a letter. The typeset "P" fades in
  /// under the dissolving painted P; the rest follow the beam.
  double _letterReveal(double t, int index) {
    if (index == 0) {
      return _ramp(t, _crossfadeStart, _crossfadeEnd, Curves.easeInOut);
    }
    final start = _letterStart(index);
    return _ramp(t, start, start + 0.06, Curves.easeOutCubic);
  }

  /// White-hot ignition as the beam crosses a letter, ~120 ms decay.
  double _letterFlash(double t, int index) {
    if (index == 0) return 0;
    final start = _letterStart(index);
    final rise = _ramp(t, start, start + 0.015, Curves.easeOut);
    final fall = _ramp(t, start + 0.015, start + 0.055, Curves.easeIn);
    return rise * (1 - fall);
  }

  /// Glow envelope: swells as the bowl completes, calms through the
  /// shrink, lifts when the wordmark completes, crests gently with the
  /// sweep, then settles for the hold.
  double _baseGlow(double t) {
    final buildSwell = 0.25 * _ramp(t, _bowlEnd - 0.04, _bowlEnd + 0.02);
    final calm = 0.15 * _ramp(t, _shrinkStart, _shrinkEnd);
    final complete = 0.15 * _ramp(t, _beamEnd, _beamEnd + 0.04);
    final crest = 0.10 *
        _ramp(t, _sweepStart, _sweepStart + 0.04) *
        (1 - _ramp(t, _sweepEnd - 0.02, _sweepEnd + 0.02));
    final settle = 0.15 * _ramp(t, _sweepEnd, _settleEnd);
    return 0.4 + buildSwell - calm + complete + crest - settle;
  }

  TextStyle get _style => GoogleFonts.anton(
        fontSize: widget.fontSize,
        height: 1,
        letterSpacing: widget.fontSize * 0.02,
        color: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    final color = widget.color;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // Painted P: build → shrink → slide → dissolve.
        final stem = _ramp(t, _stemStart, _stemEnd, Curves.easeInOutCubic);
        final bowl = _ramp(t, _bowlStart, _bowlEnd, Curves.easeOutCubic);
        final scale = ui.lerpDouble(
          _bigScale,
          1.0,
          _ramp(t, _shrinkStart, _shrinkEnd, _shrinkCurve),
        )!;
        final xFrac = ui.lerpDouble(
          0.5,
          _pSlot,
          _ramp(t, _slideStart, _slideEnd, _slideCurve),
        )!;
        final pOpacity = (1 - _ramp(t, _crossfadeStart, _crossfadeEnd)) *
            _ramp(t, 0.0, 0.05);

        return Glow(
          color: color,
          intensity: _baseGlow(t) + 0.15,
          radius: widget.fontSize * 2.2,
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The final wordmark row — always laid out in full so
                    // the geometry (and the P slot) is stable; letters
                    // simply don't exist until the beam forges them.
                    _buildWordmark(t, reflection: false),
                    // The monumental painted P, above the row so its
                    // dissolve covers the typeset P's arrival.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ForgedPPainter(
                            color: color,
                            stem: stem,
                            bowl: bowl,
                            scale: scale,
                            xFrac: xFrac,
                            opacity: pOpacity,
                            glow: _baseGlow(t),
                          ),
                        ),
                      ),
                    ),
                    // Light on top of everything it illuminates.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _LightBeamPainter(
                            color: color,
                            // Linear: the beam's position must match the
                            // letter-start mapping exactly.
                            beam: _ramp(
                                t, _beamStart, _beamEnd, Curves.linear),
                            sweep: _ramp(
                                t, _sweepStart, _sweepEnd, Curves.easeInOut),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Faint mirrored reflection — appears with the wordmark,
                // so the finished mark stands on black glass.
                _buildWordmark(t, reflection: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordmark(double t, {required bool reflection}) {
    Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < widget.text.length; index++)
          _buildLetter(t, index, reflection: reflection),
      ],
    );

    if (!reflection) return row;

    return Opacity(
      opacity: 0.14,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.diagonal3Values(1, -1, 1),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.white, Colors.transparent],
            stops: [0, 0.45],
          ).createShader(bounds),
          child: row,
        ),
      ),
    );
  }

  /// One glyph: slides in from the right (12 px) as it fades, ignites
  /// white-hot while the beam crosses it, settles into the metallic
  /// face. Per-letter ShaderMask so the flash affects that letter alone.
  Widget _buildLetter(double t, int index, {required bool reflection}) {
    final reveal = _letterReveal(t, index);
    if (reveal == 0) {
      // Invisible but laid out, so the row's width is stable.
      return Opacity(
        opacity: 0,
        child: Text(widget.text[index], style: _style),
      );
    }

    final color = widget.color;
    final flash = _letterFlash(t, index);
    final glow = _baseGlow(t) + (1 - _baseGlow(t)) * flash;

    final crown = Color.lerp(
        Color.lerp(color, Colors.white, 0.28)!, Colors.white, flash)!;
    final mid = Color.lerp(color, Colors.white, 0.85 * flash)!;
    final base = Color.lerp(
        Color.lerp(color, Colors.black, 0.35)!, Colors.white, 0.7 * flash)!;

    Widget letter = Text(
      widget.text[index],
      style: _style.copyWith(
        shadows: reflection
            ? null
            : [
                Shadow(
                  color: Colors.white
                      .withValues(alpha: (0.55 * glow).clamp(0.0, 1.0)),
                  blurRadius: 16 * glow,
                ),
              ],
      ),
    );

    letter = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [crown, mid, base],
        stops: const [0, 0.55, 1],
      ).createShader(bounds),
      child: letter,
    );

    return Opacity(
      opacity: reveal,
      child: Transform.translate(
        offset: Offset(12 * (1 - reveal), 0),
        child: letter,
      ),
    );
  }
}

/// Draws the monumental "P" as original vector geometry — a stem and a
/// bowl stroked in brand crimson — and animates it building itself:
/// the stem strikes downward, then the bowl sweeps around and closes
/// into the stem, both as true draw-on via [ui.PathMetric].
///
/// Rendered in three passes for depth without any image effects:
///  1. a darker offset understroke (dimensional shadow, like ink laid
///     over ink),
///  2. an additive blurred overstroke (the glow hugging the letterform),
///  3. the face: a vertical crown→base crimson gradient.
class _ForgedPPainter extends CustomPainter {
  const _ForgedPPainter({
    required this.color,
    required this.stem,
    required this.bowl,
    required this.scale,
    required this.xFrac,
    required this.opacity,
    required this.glow,
  });

  final Color color;

  /// Draw-on progress of the two strokes.
  final double stem;
  final double bowl;

  /// 1.0 = wordmark glyph height; the intro starts at ~3.2×.
  final double scale;

  /// Horizontal center of the P as a fraction of the row width.
  final double xFrac;
  final double opacity;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || stem <= 0) return;

    // Glyph box at scale 1 matches the wordmark: height = row height,
    // condensed width, heavy stroke.
    final h = size.height;
    final w = h * 0.52;
    final th = w * 0.34;

    canvas.save();
    canvas.translate(size.width * xFrac, size.height / 2);
    canvas.scale(scale);

    // ---- Geometry (centered box, y down) ------------------------------
    final stemX = -w / 2 + th / 2;
    final top = -h / 2;

    final stemPath = Path()
      ..moveTo(stemX, top)
      ..lineTo(stemX, top + h * stem);

    // Bowl: from the stem's top, a clockwise half-turn out to the right
    // edge and back level with mid-height, then home into the stem.
    final bowlRadius = (h * 0.56 - th) / 2;
    final bowlCenter = Offset(w / 2 - bowlRadius - th / 2, top + h * 0.28);
    Path? bowlDrawn;
    if (bowl > 0) {
      final full = Path()
        ..moveTo(stemX, top + th / 2)
        ..lineTo(bowlCenter.dx, top + th / 2)
        ..addArc(
          Rect.fromCircle(center: bowlCenter, radius: bowlRadius),
          -math.pi / 2,
          math.pi,
        )
        ..lineTo(stemX, bowlCenter.dy + bowlRadius);
      bowlDrawn = Path();
      for (final metric in full.computeMetrics()) {
        bowlDrawn.addPath(
          metric.extractPath(0, metric.length * bowl),
          Offset.zero,
        );
      }
    }

    void strokeBoth(Paint paint) {
      canvas.drawPath(stemPath, paint);
      if (bowlDrawn != null) canvas.drawPath(bowlDrawn, paint);
    }

    // ---- Pass 1: dimensional understroke ------------------------------
    canvas.save();
    canvas.translate(th * 0.14, th * 0.14);
    strokeBoth(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = th
        ..strokeCap = StrokeCap.butt
        ..color = Color.lerp(color, Colors.black, 0.45)!
            .withValues(alpha: 0.85 * opacity),
    );
    canvas.restore();

    // ---- Pass 2: additive glow hugging the stroke ---------------------
    strokeBoth(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = th * 1.5
        ..strokeCap = StrokeCap.butt
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = color.withValues(
          alpha: (0.30 * glow * opacity).clamp(0.0, 1.0),
        ),
    );

    // ---- Pass 3: the face -------------------------------------------
    strokeBoth(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = th
        ..strokeCap = StrokeCap.butt
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.25)!
                .withValues(alpha: opacity),
            color.withValues(alpha: opacity),
            Color.lerp(color, Colors.black, 0.30)!
                .withValues(alpha: opacity),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ForgedPPainter oldDelegate) =>
      oldDelegate.stem != stem ||
      oldDelegate.bowl != bowl ||
      oldDelegate.scale != scale ||
      oldDelegate.xFrac != xFrac ||
      oldDelegate.opacity != opacity ||
      oldDelegate.glow != glow ||
      oldDelegate.color != color;
}

/// The forging light: a thin tilted beam — white-hot core inside a
/// feathered crimson body inside a soft bloom, all additively blended —
/// that travels across the wordmark creating letters, plus one subtle
/// final sweep. Every layer is a transparent-edged gradient: falloff,
/// never a rectangle, never a matte.
class _LightBeamPainter extends CustomPainter {
  const _LightBeamPainter({
    required this.color,
    required this.beam,
    required this.sweep,
  });

  final Color color;
  final double beam;
  final double sweep;

  /// Beam tilt: ~20° reads as cinema light, not a scanner.
  static const double _tilt = -0.35;

  @override
  void paint(Canvas canvas, Size size) {
    if (beam > 0 && beam < 1) {
      final intensity =
          _smooth(beam / 0.08) * (1 - _smooth((beam - 0.9) / 0.1));
      final x = size.width *
          (_LogoRevealState._pSlot +
              (_LogoRevealState._beamOvershoot - _LogoRevealState._pSlot) *
                  beam);
      _drawBeam(canvas, size, x: x, intensity: intensity, trail: true);
    }

    if (sweep > 0 && sweep < 1) {
      final intensity = math.sin(sweep * math.pi) * 0.55;
      _drawBeam(
        canvas,
        size,
        x: size.width * (-0.1 + 1.2 * sweep),
        intensity: intensity,
        trail: false,
      );
    }
  }

  void _drawBeam(
    Canvas canvas,
    Size size, {
    required double x,
    required double intensity,
    required bool trail,
  }) {
    if (intensity <= 0) return;
    final beamHeight = size.height * 2.6;

    canvas.save();
    canvas.translate(x, size.height / 2);
    canvas.rotate(_tilt);

    if (trail) {
      // ~130 ms of travel distance, decaying smoothly to nothing.
      final trailWidth = size.width * 0.16;
      final rect = Rect.fromLTWH(
        -trailWidth - 4,
        -beamHeight / 2,
        trailWidth,
        beamHeight,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            colors: [
              color.withValues(alpha: 0),
              color.withValues(alpha: 0.20 * intensity),
            ],
          ).createShader(rect),
      );
    }

    _gradientStripe(canvas,
        width: 84,
        height: beamHeight,
        core: color.withValues(alpha: 0.14 * intensity),
        blurSigma: 6);
    _gradientStripe(canvas,
        width: 30,
        height: beamHeight,
        core: color.withValues(alpha: 0.38 * intensity),
        blurSigma: 3);
    _gradientStripe(canvas,
        width: 6,
        height: beamHeight,
        core: Colors.white.withValues(alpha: 0.55 * intensity),
        blurSigma: 2.5);

    canvas.restore();
  }

  void _gradientStripe(
    Canvas canvas, {
    required double width,
    required double height,
    required Color core,
    required double blurSigma,
  }) {
    final rect =
        Rect.fromCenter(center: Offset.zero, width: width, height: height);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma)
        ..shader = LinearGradient(
          colors: [core.withValues(alpha: 0), core, core.withValues(alpha: 0)],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  static double _smooth(double t) =>
      Curves.easeInOut.transform(t.clamp(0.0, 1.0));

  @override
  bool shouldRepaint(_LightBeamPainter oldDelegate) =>
      oldDelegate.beam != beam ||
      oldDelegate.sweep != sweep ||
      oldDelegate.color != color;
}
