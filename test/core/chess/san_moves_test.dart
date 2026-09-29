import 'package:dartchess/dartchess.dart' show NormalMove, Square;
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';

/// Two rooks and an open back rank: Ra8# and Rb8# both mate.
const _twoMatesFen = '6k1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1';

const _ra8 = NormalMove(from: Square.a1, to: Square.a8);
const _rb8 = NormalMove(from: Square.b1, to: Square.b8);
const _ra7 = NormalMove(from: Square.a1, to: Square.a7);

void main() {
  group('acceptsAuthored', () {
    final position = positionFromFen(_twoMatesFen);

    test('the authored move is accepted, with or without its decoration', () {
      expect(acceptsAuthored(position, _ra8, 'Ra8#'), isTrue);
      expect(acceptsAuthored(position, _ra8, 'Ra8'), isTrue);
    });

    test('a different mate answers an authored mate', () {
      expect(acceptsAuthored(position, _rb8, 'Ra8#'), isTrue);
    });

    test('a move short of mate must be the authored one', () {
      expect(acceptsAuthored(position, _ra7, 'Ra8#'), isFalse);
    });

    test('a mate does not answer an authored move that is not mate', () {
      expect(acceptsAuthored(position, _ra8, 'Ra7'), isFalse);
    });

    test('an illegal authored move accepts only itself, never a mate', () {
      expect(acceptsAuthored(position, _rb8, 'Qh7#'), isFalse);
    });
  });
}
