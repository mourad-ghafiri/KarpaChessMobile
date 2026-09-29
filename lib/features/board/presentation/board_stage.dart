import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../prefs/application/prefs_controller.dart';

/// The centerpiece of every mode: the board in its frame, with the overlay
/// layers (drawing, banners, confetti) stacked on top of it.
///
/// The frame is the point. Painted edge to edge a board dissolves into a
/// light-theme page — tournament's light square lands within 2 L\* of ivory
/// paper — and in a dark theme it reads as a pattern printed on the
/// background rather than a thing sitting in front of it. The bezel is cut
/// from the colorway's own dark square, so it belongs to the wood.
class BoardStage extends ConsumerWidget {
  const BoardStage({
    super.key,
    required this.size,
    required this.builder,
    this.sideline = false,
  });

  /// How far the bezel travels from the wood toward [AppTokens.info] while
  /// [sideline]. Short of the whole way: the frame has to keep enough of its
  /// own darkness to still separate the board from the page.
  static const _sidelineBlend = 0.62;

  /// The ring that traces the frame's outer edge while [sideline].
  static const _sidelineRing = 2.0;

  /// Strength of the square wash a side line paints UNDER the pieces
  /// (80% transparent — the wood takes the hue, the pieces stay crisp).
  /// Screens compose it as `tokens.info.withValues(alpha: sidelineWash)`
  /// and hand it to `KarpaBoard.wash`, so board and bezel speak the same
  /// color at matched intensity.
  static const sidelineWash = 0.2;

  /// The stage's total footprint, frame included.
  final double size;

  /// Builds the layers, given the edge length left for the board itself
  /// once the frame is taken out. Every layer fills that square, so the
  /// drawing overlay stays aligned to the squares under it.
  final List<Widget> Function(double board) builder;

  /// The board is showing a **side line** — a what-if the reader walked into —
  /// rather than the game that was actually played.
  ///
  /// Said in colour and nothing else: the bezel leaves the wood for the
  /// theme's `info` hue, a ring traces it, and the shadow turns into a halo of
  /// the same colour. That is the app's reserved meaning for `info` —
  /// assisting rather than real — and it reads at a glance where the old
  /// uniform fade read as "this screen is disabled".
  final bool sideline;

  /// The frame's thickness at a given footprint: enough to read as a frame
  /// on a phone, never so much that it eats the squares on a tablet.
  ///
  /// Constant across [sideline]: the frame is subtracted from [size], so
  /// growing it would resize the squares under an in-progress annotation.
  static double frameFor(double size) => (size * 0.018).clamp(4.0, 10.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorway =
        BoardColorTheme.fromId(ref.watch(prefsControllerProvider).boardTheme);
    final frame = frameFor(size);
    final board = size - frame * 2;

    final layers = Padding(
      padding: EdgeInsets.all(frame),
      child: SizedBox(
        width: board,
        height: board,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final layer in builder(board)) Positioned.fill(child: layer),
          ],
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      // The blur-34 shadow is expensive to rasterize; the boundary keeps
      // sibling repaints (clock text, panel chrome) from re-rendering it.
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: sideline ? 1.0 : 0.0),
          duration: Motion.base,
          curve: Motion.enter,
          // The board rides along as `child`: only the frame is rebuilt per
          // frame of the wood↔info transition, never the squares.
          child: layers,
          builder: (context, amount, child) => DecoratedBox(
            decoration: _frame(colorway, context.tokens, amount),
            child: child,
          ),
        ),
      ),
    );
  }

  /// The bezel, [amount] of the way from the colorway's wood (0) to the
  /// side-line treatment (1). One function so the two states cannot drift
  /// apart, and so the transition between them is a plain colour lerp.
  BoxDecoration _frame(
    BoardColorTheme colorway,
    AppTokens tokens,
    double amount,
  ) {
    final bezel = Color.lerp(
      colorway.bezel,
      Color.lerp(colorway.bezel, tokens.info, _sidelineBlend),
      amount,
    )!;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      // A gradient rather than a flat fill: the top edge catches the
      // light, which is what makes the frame read as a raised lip
      // instead of a printed border. The rim survives the blend, so a
      // side-line frame is still a frame — just a different material.
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.alphaBlend(colorway.bezelRim, bezel), bezel],
        stops: const [0, 0.35],
      ),
      // Painted inside the bounds, so the ring costs the board no squares —
      // a `DecoratedBox` does not inset its child by its border.
      border: amount <= 0
          ? null
          : Border.all(
              color: tokens.info.withValues(alpha: tokens.info.a * amount),
              width: _sidelineRing * amount,
            ),
      boxShadow: [
        // The halo. Centered and unoffset, so it reads as light coming off
        // the frame rather than as a second, coloured shadow under it. Absent
        // entirely on the main line, which is what makes it a signal.
        if (amount > 0)
          BoxShadow(
            color: tokens.info.withValues(alpha: tokens.info.a * 0.45 * amount),
            blurRadius: 26,
            spreadRadius: 4 * amount,
          ),
        // Ambient: the board's weight on the page. Neutral in both states —
        // a side line is still a board sitting on a table.
        BoxShadow(
          color: colorway.bezelShadow.withValues(alpha: 0.42),
          blurRadius: 34,
          spreadRadius: 1,
          offset: const Offset(0, 16),
        ),
        // Contact: the tight dark line directly under the frame, without
        // which the ambient blur reads as fog rather than a shadow.
        BoxShadow(
          color: colorway.bezelShadow.withValues(alpha: 0.34),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
