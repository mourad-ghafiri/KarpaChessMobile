// The translation seams the responders are built against. Re-exported so
// `coach_service.dart` stays the single import for the coach domain, while
// the definitions live in a Flutter-free leaf.
export '../../../core/i18n/translate.dart' show Translate, Pluralize;

/// Contract for every coach implementation (built-in heuristic or remote AI).
abstract interface class CoachService {
  /// Answer a question [intent] about the position in [ctx]. Never throws.
  Future<CoachAnswer> askIntent(CoachIntent intent, CoachContext ctx);
}

/// A single coach reply, expressed in the KarpaChess markdown dialect
/// ({{san}} chips allowed).
class CoachAnswer {
  const CoachAnswer(this.markdown);

  final String markdown;
}

/// The question families the coach can answer.
///
/// Every member here must be offered by `coachMenuFor`; an intent no menu
/// returns is answerable only from a test, and its strings ship to twelve
/// languages for nobody to read.
enum CoachIntent {
  bestMove,
  tactics,
  plan,
  lastMove,
  evaluation,
  kingSafety,
}

/// Snapshot of the game the coach reasons about.
/// One engine candidate: the move plus its evaluation.
class CandidateLine {
  const CandidateLine({required this.san, this.evalCp});

  final String san;

  /// Centipawns from the side-to-move perspective.
  final int? evalCp;
}

class CoachContext {
  const CoachContext({
    required this.fen,
    this.sanHistory = const [],
    this.lastMoveSan,
    this.bestMoveHint,
    this.evalCp,
    this.topLines = const [],
    this.threat,
  });

  final String fen;

  /// Full game SANs from the starting position; may be empty.
  final List<String> sanHistory;

  final String? lastMoveSan;

  /// Engine best move in SAN, if available.
  final String? bestMoveHint;

  /// Stockfish's top candidate moves (MultiPV), best first.
  final List<CandidateLine> topLines;

  /// What the opponent would play if it were their turn (threat scan).
  final CandidateLine? threat;

  /// Centipawns from the SIDE-TO-MOVE perspective: the white-relative score
  /// is negated when Black is to move.
  final int? evalCp;

}
