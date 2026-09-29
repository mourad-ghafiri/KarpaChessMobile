import 'package:dartchess/dartchess.dart';

import '../../../core/i18n/translate.dart';

/// Builds the localized hint-card explanation for a suggested move —
/// port of HintView#describe (src/ui/hint-view.js).
String describeHint({
  required Translate t,
  required Position position,
  required NormalMove move,
  required String san,
}) {
  String pieceName(Role role) => t('chess.piece.${role.letter}');

  if (san.contains('#')) return t('hint.checkmate');

  if (san.startsWith('O-O')) {
    final dir = t(san.startsWith('O-O-O')
        ? 'chess.direction.queenside'
        : 'chess.direction.kingside');
    return t('hint.castle', {'dir': dir});
  }

  if (move.promotion != null) {
    return t('hint.promote', {'piece': pieceName(move.promotion!)});
  }

  final role = position.board.pieceAt(move.from)?.role ?? Role.pawn;
  final piece = pieceName(role);
  final captured = position.board.pieceAt(move.to)?.role;
  final to = move.to.name;

  final parts = <String>[];
  if (captured != null) {
    parts.add(t('hint.capture', {'piece': piece, 'target': pieceName(captured)}));
  } else if (role == Role.knight || role == Role.bishop) {
    parts.add(t('hint.develop', {'piece': piece, 'square': to}));
  } else if (role == Role.pawn) {
    parts.add(t('hint.pawn', {'square': to}));
  } else if (role == Role.rook) {
    parts.add(t('hint.rook', {'square': to}));
  } else if (role == Role.queen) {
    parts.add(t('hint.queen', {'square': to}));
  } else {
    parts.add(t('hint.quiet', {'piece': piece, 'square': to}));
  }
  if (san.endsWith('+')) parts.add(t('hint.checkSuffix').trim());
  return parts.join(' ');
}
