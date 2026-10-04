import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens_context.dart';

/// Circular progress ring used by journey nodes and chapter headers.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
    this.strokeWidth = 4,
    this.color,
    this.child,
  });

  /// 0..1.
  final double progress;
  final double size;
  final double strokeWidth;

  /// Defaults to the theme accent.
  final Color? color;

  /// Drawn in the ring's middle (a count, a crest).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // A ring said nothing to a screen reader; it now reads as the share it
    // draws, merged with whatever its middle says.
    return Semantics(
      value: '${(progress.clamp(0.0, 1.0) * 100).round()}%',
      child: _ring(context),
    );
  }

  Widget _ring(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      // The arc sweeps to its new value rather than jumping. Progress that
      // moves is the whole reward for finishing a lesson, and a repaint at
      // the next frame throws that away.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1)),
        duration: Motion.slow,
        curve: Motion.enter,
        child: Center(child: child),
        builder: (context, value, inner) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            strokeWidth: strokeWidth,
            color: color ?? context.tokens.accent,
            trackColor: context.tokens.track,
          ),
          child: inner,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
