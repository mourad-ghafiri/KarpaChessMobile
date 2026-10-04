import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/board_themes.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/alpha_filter.dart';
import '../../../prefs/application/prefs_controller.dart';
import '../../board/presentation/board_theme_mapper.dart';
import '../../board/presentation/piece_sets.dart';
import '../application/academy_providers.dart';

/// Side to move encoded in [fen] (defaults to white on malformed input).
Side sideToMoveOf(String fen) {
  final parts = fen.split(' ');
  return parts.length > 1 && parts[1] == 'b' ? Side.black : Side.white;
}

/// Mini non-interactive board showing a concept's signature position,
/// faded by SRS dullness (1.0 crisp → 0.45 fully dull).
class PatternThumb extends ConsumerWidget {
  const PatternThumb({
    super.key,
    required this.conceptId,
    required this.size,
    this.dullness = 0,
  });

  final String conceptId;
  final double size;

  /// 0 (crisp) → 1 (fully dull).
  final double dullness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final fen = ref.watch(conceptKeyFenProvider(conceptId)).valueOrNull;
    final boardTheme = ref.watch(
      prefsControllerProvider.select((p) => p.boardTheme),
    );
    final pieces = ref.watch(pieceAssetsProvider);

    if (fen == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.edge),
        ),
        // The outline pawn: ♟ is drawn as the system's black emoji.
        child: Text(
          '♙',
          style: TextStyle(fontSize: size * 0.4, color: tokens.textFaint),
        ),
      );
    }

    // An alpha-scaling color matrix fades the thumb like Opacity would,
    // without the per-cell saveLayer an Opacity over a whole board costs.
    final fade = (1.0 - 0.55 * dullness.clamp(0.0, 1.0))
        .clamp(0.45, 1.0)
        .toDouble();
    return ColorFiltered(
      colorFilter: alphaFilter(fade),
      child: StaticChessboard(
        size: size,
        fen: fen,
        orientation: sideToMoveOf(fen),
        settings: StaticChessboardSettings(
          colorScheme: boardColorScheme(
            BoardColorTheme.fromId(boardTheme),
            tokens,
          ),
          pieceAssets: pieces,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          animationDuration: Duration.zero,
        ),
      ),
    );
  }
}

/// Three star pips (0–3 earned through spaced reviews).
class StarPips extends StatelessWidget {
  const StarPips({super.key, required this.stars});

  static const _size = 14.0;

  final int stars;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // One node for a screen reader — "2 / 3" — rather than three silent
    // glyphs.
    return Semantics(
      value: '$stars / 3',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: _size,
              color: i < stars ? tokens.best : tokens.textFaint,
            ),
        ],
      ),
    );
  }
}
