import '../../../core/i18n/translate.dart';
import 'position_features.dart';

/// Builds the insight lines shown in the hint card — the coaching content
/// that used to arrive as unsolicited whispers, now delivered only when the
/// player asks for a hint: an eval one-liner plus tactical awareness notes
/// computed from the position (reusing the offline coach's pure features).
List<String> composeHintInsights({
  required Translate t,
  required Pluralize p,
  required String fen,
  required int? evalCpWhite,
}) {
  final insights = <String>[];
  final pos = ParsedPosition.fromFen(fen);
  final mover = pos.turn;
  final opponent = mover == 'w' ? 'b' : 'w';

  // 1 — evaluation one-liner (White-positive cp → side-relative prose).
  if (evalCpWhite != null) {
    final cp = mover == 'w' ? evalCpWhite : -evalCpWhite;
    final side = t(mover == 'w' ? 'game.side.white' : 'game.side.black');
    final value = cp == 0
        ? '0.0'
        : '${cp > 0 ? '+' : ''}${(cp / 100).toStringAsFixed(1)}';
    insights.add('$value · $side');
  }

  String pieceCap(String piece) => t('chess.pieceCapital.$piece');
  String listOf(List<LoosePiece> loose) => loose
      .map((l) => t('coach.builtin.pieceOn',
          {'piece': pieceCap(l.piece), 'square': l.square}))
      .join(', ');

  // 2 — opponent's hanging material: concrete targets.
  //
  // The same message the tactics responder uses, now with the noun inside it.
  // The two call sites used to fill its {pieceWord} from different keys, so
  // this card said "2 undefended loose pieces" where the coach said
  // "2 undefended pieces".
  final theirs = loosePieces(pos, opponent);
  if (theirs.isNotEmpty) {
    insights.add(p('coach.builtin.tactics.loose', theirs.length,
        {'list': listOf(theirs)}));
  }

  // 3 — own loose pieces: a defensive nudge.
  final mine = loosePieces(pos, mover);
  if (mine.isNotEmpty) {
    insights.add(t('coach.whisper.tip5'));
  }

  return insights;
}
