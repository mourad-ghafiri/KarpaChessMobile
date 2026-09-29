import 'engine_models.dart';

/// Quality tiers for a played move, in descending order of quality.
/// [brilliant] is only awarded by the commentator flow (engine-best AND a
/// material sacrifice); review flows top out at [best].
enum MoveQuality { brilliant, best, good, inaccuracy, mistake, blunder }

/// Centipawn-loss based move classification, shared by Match Review and
/// Commentator Studio — port of the (duplicated) web thresholds in
/// review-controller.js / commentator-controller.js, unified here.
abstract final class MoveClassifier {
  /// Loss thresholds in centipawns (upper-exclusive bounds).
  static const bestMax = 20;
  static const goodMax = 60;
  static const inaccuracyMax = 150;
  static const mistakeMax = 300;

  /// A move "concedes material" when the mover ends the exchange at least
  /// this many centipawns down — 1.5 pawns catches real sacrifices while
  /// ignoring even trades.
  static const sacrificeThresholdCp = 150;

  /// Quality points per tier, used for the per-side Accuracy%.
  static const qualityScore = {
    MoveQuality.brilliant: 100,
    MoveQuality.best: 100,
    MoveQuality.good: 85,
    MoveQuality.inaccuracy: 60,
    MoveQuality.mistake: 30,
    MoveQuality.blunder: 10,
  };

  /// Centipawns the mover lost versus the engine's best move.
  ///
  /// [best] is the position eval assuming the engine's best move, [after] is
  /// the eval after the actually played move — both from White's perspective
  /// (as produced by the engine layer). [moverColor] is 'w' or 'b'.
  /// Never negative: an "improvement" over the engine line counts as 0 loss.
  static int deltaCp({
    required EvalScore best,
    required EvalScore after,
    required String moverColor,
  }) {
    final delta = moverColor == 'w'
        ? best.asCp - after.asCp
        : after.asCp - best.asCp;
    return delta < 0 ? 0 : delta;
  }

  /// Classifies a centipawn loss.
  static MoveQuality classify(int deltaCp) {
    if (deltaCp < bestMax) return MoveQuality.best;
    if (deltaCp < goodMax) return MoveQuality.good;
    if (deltaCp < inaccuracyMax) return MoveQuality.inaccuracy;
    if (deltaCp < mistakeMax) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }

  /// Whether a played engine-best move qualifies as brilliant: the mover's
  /// non-king material (centipawns) after the opponent's best reply is at
  /// least [sacrificeThresholdCp] below what it was before the move.
  static bool isSacrifice({
    required int moverMaterialBeforeCp,
    required int moverMaterialAfterReplyCp,
  }) =>
      moverMaterialBeforeCp - moverMaterialAfterReplyCp >=
      sacrificeThresholdCp;

  /// Upgrades [quality] to brilliant when it is engine-best and sacrificial.
  static MoveQuality withBrilliancy(MoveQuality quality,
          {required bool sacrifice}) =>
      quality == MoveQuality.best && sacrifice
          ? MoveQuality.brilliant
          : quality;

  /// Average quality score (0-100) over a side's classified moves.
  /// Returns null when [qualities] is empty.
  static double? accuracy(Iterable<MoveQuality> qualities) {
    var total = 0;
    var count = 0;
    for (final q in qualities) {
      total += qualityScore[q]!;
      count++;
    }
    return count == 0 ? null : total / count;
  }
}
