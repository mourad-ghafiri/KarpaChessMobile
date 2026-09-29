import '../domain/engine_models.dart';

/// Stateless parsing of UCI engine output lines.
///
/// Search output is high-volume (one PV line per depth iteration × rank),
/// so the hot path avoids per-call RegExp construction and skips lines
/// that cannot carry a usable score cheaply.
abstract final class UciProtocol {
  /// Cached tokenizer — Dart does not intern RegExp literals, and this
  /// runs for every PV line of every search.
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Parses an `info ... score ... pv ...` line into an [EngineLine].
  ///
  /// [sideToMove] ('w'|'b') is the mover of the searched position; UCI scores
  /// are from the mover's perspective and are normalized here to White's.
  /// Returns null for info lines without a score/depth (currmove chatter etc).
  static EngineLine? parseInfo(String line, String sideToMove) {
    // Cheap pre-filters: only `info depth … score …` lines are usable;
    // currmove / nps / hashfull chatter never reaches the tokenizer.
    if (!line.startsWith('info depth ')) return null;
    if (!line.contains(' score ')) return null;
    final tokens = line.split(_whitespace);

    int? depth;
    EvalScore? score;
    List<String>? pv;
    var multiPv = 1;

    for (var i = 0; i < tokens.length; i++) {
      switch (tokens[i]) {
        case 'depth':
          depth = int.tryParse(tokens.elementAtOrNull(i + 1) ?? '');
        case 'multipv':
          multiPv = int.tryParse(tokens.elementAtOrNull(i + 1) ?? '') ?? 1;
        case 'score':
          final kind = tokens.elementAtOrNull(i + 1);
          final value = int.tryParse(tokens.elementAtOrNull(i + 2) ?? '');
          if (value != null) {
            final moverScore = kind == 'mate'
                ? EvalScore.mate(value)
                : EvalScore.cp(value);
            score = sideToMove == 'w' ? moverScore : moverScore.negated;
          }
        case 'pv':
          pv = tokens.sublist(i + 1);
      }
    }

    if (depth == null || score == null) return null;
    return EngineLine(
      depth: depth,
      score: score,
      pvUci: pv ?? const [],
      multiPv: multiPv,
    );
  }

  /// Parses a `bestmove <uci> [ponder ...]` line; returns the move, or null
  /// if the line is not a bestmove line. `(none)` maps to an empty string.
  static String? parseBestMove(String line) {
    if (!line.startsWith('bestmove')) return null;
    final tokens = line.split(_whitespace);
    final move = tokens.elementAtOrNull(1);
    if (move == null || move == '(none)') return '';
    return move;
  }
}
