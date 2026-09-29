import 'dart:math' as math;

/// The trainer's rating maths: a puzzle is an opponent, solving it is a win,
/// failing it is a loss, and your rating is an Elo that chases your real
/// strength.
///
/// Pure Dart and deliberately small — a rating that moves in ways the reader
/// cannot predict is worse than no rating at all, so it is one readable
/// formula with no hidden terms.
abstract final class PuzzleRating {
  /// Where a new solver starts: low enough that the first few puzzles are
  /// solvable, high enough that the ladder has somewhere to go down to.
  static const initial = 800;

  /// The band the corpus covers. Ratings clamp here so a bad run cannot
  /// strand a reader below every puzzle that exists.
  static const floor = 500;
  static const ceiling = 2200;

  /// How far one result can move you, from how many puzzles have had a
  /// first attempt resolved (solved or failed). It shrinks with experience:
  /// the first results should find your level fast, later ones should not
  /// swing it.
  static int kFor(int solvedCount) {
    if (solvedCount < 10) return 40;
    if (solvedCount < 50) return 24;
    return 16;
  }

  /// The classic Elo expectation that [player] beats [puzzle].
  static double expectedScore(int player, int puzzle) =>
      1 / (1 + math.pow(10, (puzzle - player) / 400));

  /// The reader's new rating after meeting [puzzle].
  ///
  /// A puzzle solved only after a wrong move scores a half point: you found
  /// it, but not the way you would have had to over the board.
  static int updated({
    required int player,
    required int puzzle,
    required bool solved,
    required bool firstTry,
    required int solvedCount,
  }) {
    final score = solved ? (firstTry ? 1.0 : 0.5) : 0.0;
    final delta = kFor(solvedCount) * (score - expectedScore(player, puzzle));
    return (player + delta.round()).clamp(floor, ceiling);
  }
}
