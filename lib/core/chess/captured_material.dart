import 'package:dartchess/dartchess.dart';

/// What each side has taken off the board, read from the board itself.
///
/// The board rather than a move list, deliberately. The Studio's `MoveTreeNode`
/// carries no captured piece, and once a reader steps into a side line the
/// node's position is the only thing that is true — a list of moves played
/// describes a game that, on screen, is not the one being shown. Reading the
/// board also survives a practice game restored from disk whose move list was
/// truncated, and it gives both screens one answer instead of two.
///
/// **Promotion is approximated, and only in the glyphs.** A pawn that promoted
/// is counted as captured, because it genuinely is no longer on the board and
/// nothing on the board says where it went. [leadFor] is exact regardless: it
/// weighs what is actually standing, so a new queen is worth nine whatever
/// became of the pawn. Every mainstream client makes the same trade.
class CapturedMaterial {
  const CapturedMaterial._(this._byWhite, this._byBlack, this._pawnsAhead);

  /// Reads [board] against the complement both sides started with.
  factory CapturedMaterial.of(Board board) {
    final white = board.materialCount(Side.white);
    final black = board.materialCount(Side.black);
    return CapturedMaterial._(
      _missingFrom(black),
      _missingFrom(white),
      _pointsOf(white) - _pointsOf(black),
    );
  }

  /// Black pieces White has taken, and White pieces Black has taken. Ordered
  /// most valuable first, which is the order they are read in.
  final List<Role> _byWhite;
  final List<Role> _byBlack;

  /// Material balance in pawns, positive when White is ahead.
  final int _pawnsAhead;

  /// The pieces [side] has captured — the opponent's losses, which is the
  /// side of the ledger every chess interface shows next to a player.
  List<Role> capturedBy(Side side) =>
      side == Side.white ? _byWhite : _byBlack;

  /// How many pawns [side] is ahead by; zero when level or behind, so only the
  /// side that is actually winning material shows a number.
  int leadFor(Side side) {
    final lead = side == Side.white ? _pawnsAhead : -_pawnsAhead;
    return lead > 0 ? lead : 0;
  }

  /// The king is absent on purpose: it is never captured, so it can never be
  /// missing, and it would only ever contribute zero to the balance.
  static const _value = {
    Role.queen: 9,
    Role.rook: 5,
    Role.bishop: 3,
    Role.knight: 3,
    Role.pawn: 1,
  };

  /// What each side sets out with. Iterated in [_value] order, so the result
  /// comes out sorted by worth without a second pass.
  static const _initial = {
    Role.queen: 1,
    Role.rook: 2,
    Role.bishop: 2,
    Role.knight: 2,
    Role.pawn: 8,
  };

  /// The pieces this side no longer has. Clamped at zero because a side can
  /// hold *more* than it started with — three knights after a promotion is a
  /// deficit of minus one, and nobody has captured a negative knight.
  static List<Role> _missingFrom(ByRole<int> count) => [
        for (final entry in _initial.entries)
          for (var i = 0; i < entry.value - (count[entry.key] ?? 0); i++)
            entry.key,
      ];

  static int _pointsOf(ByRole<int> count) {
    var total = 0;
    for (final entry in _value.entries) {
      total += (count[entry.key] ?? 0) * entry.value;
    }
    return total;
  }
}
