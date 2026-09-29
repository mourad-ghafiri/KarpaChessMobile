import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens_context.dart';

/// Shakes its child horizontally once per change of [tick].
///
/// The academy's answer to a wrong move. Both the lesson player and Sharpen
/// need it, and both used to carry a private byte-identical copy — so a
/// mistake could come to feel different depending on which screen you made it
/// on. Bump [tick] to replay.
class ShakeOnMiss extends StatelessWidget {
  const ShakeOnMiss({super.key, required this.tick, required this.child});

  /// A monotonically increasing counter; 0 means "never shaken".
  final int tick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tick == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(tick),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      builder: (context, value, inner) => Transform.translate(
        offset: Offset(sin(value * pi * 4) * 8 * (1 - value), 0),
        child: inner,
      ),
      child: child,
    );
  }
}

/// A green wash over the board confirming a correct answer.
///
/// Non-interactive by construction, so it can sit anywhere in an overlay
/// stack without stealing the taps that advance the lesson.
class SuccessFlash extends StatelessWidget {
  const SuccessFlash({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.fast,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.tokens.success.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// A slow accent pulse around the board while it waits for the learner.
///
/// A lesson board looks identical whether it is playing a sequence at you or
/// waiting for you to move. This is the difference, on the board itself,
/// where the learner is already looking. It stops the moment the beat is
/// solved so the board never nags.
class AwaitingMove extends StatefulWidget {
  const AwaitingMove({super.key, required this.waiting});

  final bool waiting;

  @override
  State<AwaitingMove> createState() => _AwaitingMoveState();
}

class _AwaitingMoveState extends State<AwaitingMove>
    with SingleTickerProviderStateMixin {
  // Created here, not lazily: a board that never waited used to build its
  // controller for the first time inside dispose(), asking a torn-down
  // element for its TickerMode.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.waiting) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AwaitingMove old) {
    super.didUpdateWidget(old);
    if (widget.waiting == old.waiting) return;
    if (widget.waiting) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.waiting) return const SizedBox.shrink();
    final accent = context.tokens.accent;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.30 + 0.35 * _pulse.value),
              width: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}
