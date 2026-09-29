import '../../../core/chess/tolerant_position.dart';
import '../../../core/i18n/translate.dart';
import '../../../engine/domain/move_classifier.dart';
import '../../coach/domain/hint_composer.dart';
import '../../coach/domain/hint_describer.dart';
import '../application/review_controller.dart';

/// Everything the review's "explain" toast needs about one ply, fully
/// composed as localized strings — pure domain, no widgets.
///
/// Classified (user) plies carry the full story: verdict, eval swing,
/// the engine's preference and why, positional insights, and a narrative
/// sentence. Engine plies get the light form — just the SAN and swing.
class ReviewExplanation {
  const ReviewExplanation({
    required this.quality,
    required this.verdictLabelKey,
    required this.playedSan,
    required this.evalSwing,
    required this.betterLine,
    required this.bestWhy,
    required this.insights,
    required this.narrativeKey,
    required this.narrativeParams,
  });

  /// Lighter form for unclassified (engine) plies: SAN + eval swing only.
  const ReviewExplanation.light({
    required this.playedSan,
    required this.evalSwing,
  })  : quality = null,
        verdictLabelKey = null,
        betterLine = null,
        bestWhy = null,
        insights = const [],
        narrativeKey = null,
        narrativeParams = const {};

  /// Null for engine plies (not classified).
  final MoveQuality? quality;

  /// i18n key for the verdict word, e.g. 'review.verdict.good'.
  final String? verdictLabelKey;
  final String playedSan;

  /// White-POV swing like '+0.6 → -1.4' (pawns, one decimal); null when no
  /// eval was retained for this ply.
  final String? evalSwing;

  /// Localized "Better was {san}." — only when the engine disagreed.
  final String? betterLine;

  /// One localized sentence about the engine's preferred move.
  final String? bestWhy;

  /// Positional insight bullets for the position after the move.
  final List<String> insights;

  /// i18n key of the narrative sentence ('review.takeaway.*').
  final String? narrativeKey;
  final Map<String, Object?> narrativeParams;
}

/// White-POV eval text from raw centipawns (mate-collapsed values → '#').
String _evalCpText(int cp) {
  if (cp.abs() > 90000) return cp > 0 ? '#' : '#-';
  final pawns = cp / 100;
  return '${pawns >= 0 ? '+' : ''}${pawns.toStringAsFixed(1)}';
}

String? _evalSwing(int? beforeCp, int? afterCp) {
  if (beforeCp == null && afterCp == null) return null;
  if (beforeCp == null) return _evalCpText(afterCp!);
  if (afterCp == null) return _evalCpText(beforeCp);
  return '${_evalCpText(beforeCp)} → ${_evalCpText(afterCp)}';
}

/// Composes the explanation for one reviewed ply. Engine plies (no
/// [ReviewedMove.quality]) get the light form.
ReviewExplanation explainMove(ReviewedMove move, Translate t, Pluralize p) {
  final played = move.played;
  final quality = move.quality;
  final swing = _evalSwing(move.evalBeforeCp, move.evalAfterCp);
  if (quality == null) {
    return ReviewExplanation.light(playedSan: played.san, evalSwing: swing);
  }

  final disagrees = move.bestSan != null && move.bestSan != played.san;
  String? betterLine;
  String? bestWhy;
  if (disagrees) {
    betterLine = t('review.betterWas', {'san': move.bestSan});
    final bestMove = move.bestMove;
    if (bestMove != null) {
      bestWhy = describeHint(
        t: t,
        position: positionFromFen(played.fenBefore),
        move: bestMove,
        san: move.bestSan!,
      );
    }
  }

  final narrativeKey = switch (quality) {
    MoveQuality.brilliant ||
    MoveQuality.best =>
      'review.takeaway.great',
    MoveQuality.good => 'review.takeaway.good',
    MoveQuality.inaccuracy => 'review.takeaway.slip',
    MoveQuality.mistake ||
    MoveQuality.blunder =>
      'review.takeaway.bad',
  };

  return ReviewExplanation(
    quality: quality,
    verdictLabelKey: 'review.verdict.${quality.name}',
    playedSan: played.san,
    evalSwing: swing,
    betterLine: betterLine,
    bestWhy: bestWhy,
    insights: composeHintInsights(
      t: t,
      p: p,
      fen: played.fenAfter,
      evalCpWhite: move.evalAfterCp,
    ),
    narrativeKey: narrativeKey,
    narrativeParams: {
      'played': played.san,
      'best': move.bestSan ?? played.san,
    },
  );
}
