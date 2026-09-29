/// Built-in offline heuristic coach. Parses the FEN, computes real position features (material,
/// king safety, pawn structure, loose pieces, phase, named opening) and
/// answers position-specific questions through the injected [Translate].
library;

import 'coach_service.dart';
import 'position_features.dart';
import 'responders.dart';

class BuiltinCoach implements CoachService {
  BuiltinCoach(Translate t, Pluralize p)
      : _t = t,
        _responders = CoachResponders(t, p);

  final Translate _t;
  final CoachResponders _responders;
  @override
  Future<CoachAnswer> askIntent(CoachIntent intent, CoachContext ctx) async {
    try {
      return CoachAnswer(_answer(intent, ctx));
    } on Object {
      // Contract: never throws. A malformed FEN already degrades to an empty
      // board inside ParsedPosition, so this is a last-resort guard.
      return const CoachAnswer('');
    }
  }

  String _answer(CoachIntent intent, CoachContext ctx) {
    final pos = ParsedPosition.fromFen(ctx.fen);
    final moves = ctx.sanHistory;
    final mr = materialReport(pos);
    final ph = phaseKey(pos, moves.length);
    final ksW = kingSafety(pos, 'w', ph, _t);
    final ksB = kingSafety(pos, 'b', ph, _t);
    final psW = pawnStructure(pos, 'w');
    final psB = pawnStructure(pos, 'b');
    final loose = loosePieces(pos, pos.turn == 'w' ? 'b' : 'w');
    final r = _responders;

    return switch (intent) {
      CoachIntent.bestMove =>
        r.respondBestMove(ctx, pos, mr, ph, ksW, ksB, psW, psB, loose),
      CoachIntent.tactics => r.respondTactics(ctx, pos, loose),
      CoachIntent.plan =>
        r.respondPlan(ctx, pos, mr, ph, ksW, ksB, psW, psB),
      CoachIntent.lastMove => r.respondLastMove(ctx, pos),
      CoachIntent.evaluation =>
        r.respondEvaluation(ctx, pos, mr, ph, ksW, ksB, psW, psB),
      CoachIntent.kingSafety => r.respondKingSafety(ksW, ksB, pos.turn),
    };
  }
}
