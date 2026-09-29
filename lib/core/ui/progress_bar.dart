import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens_context.dart';

/// A linear progress bar that travels to its new value instead of jumping.
///
/// Every bar in the app tracks something the reader just earned — a level,
/// a lesson, a run. A bare [LinearProgressIndicator] repaints at the next
/// frame and the reader never sees the gain they were shown the bar for.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
  });

  /// 0..1.
  final double value;
  final double height;

  /// Defaults to the theme accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: Motion.slow,
        curve: Motion.enter,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: tokens.raised,
          color: color ?? tokens.accent,
        ),
      ),
    );
  }
}
