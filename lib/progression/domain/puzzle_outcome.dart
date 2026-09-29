/// The best result a trainer puzzle has ever produced, ordered worst → best
/// so an upgrade is an index comparison. A best only ever goes up: replaying
/// can turn [failed] into [solved] or [solved] into [flawless], never back.
enum PuzzleOutcome {
  /// The solution was shown — the reader gave up on the first attempt.
  failed,

  /// Found, but after at least one wrong move.
  solved,

  /// Found first try, the way it would have to be found over the board.
  flawless;

  bool get isSolved => this != failed;

  /// Whether achieving this outcome beats [prior] (no prior = any result
  /// is news).
  bool improvesOn(PuzzleOutcome? prior) => prior == null || index > prior.index;

  String toJson() => name;

  static PuzzleOutcome? fromJson(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
