import 'dart:convert';
import 'dart:ui';

import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/features/commentator/domain/drawing_shapes.dart';

/// Round-trips [shape] through encoded JSON (as the store would) and expects
/// an equal value back.
void expectRoundTrip(DrawShape shape) {
  final encoded = json.encode(shape.toJson());
  final decoded = json.decode(encoded) as Map<String, dynamic>;
  final restored = DrawShape.fromJson(Map<String, Object?>.from(decoded));
  expect(restored, shape);
}

void main() {
  group('palette', () {
    test('ports all 7 web DRAW_COLORS in order', () {
      expect(drawColors.map((c) => c.id), [
        'red',
        'orange',
        'yellow',
        'green',
        'blue',
        'purple',
        'white',
      ]);
      expect(drawColors.map((c) => c.hex), [
        '#c25a3c',
        '#d88a3d',
        '#e5b445',
        '#3b7a55',
        '#2f4a6b',
        '#7a4f8a',
        '#fbf6e8',
      ]);
    });

    test('colorFromHex parses and falls back on garbage', () {
      expect(colorFromHex('#3b7a55'), const Color(0xFF3B7A55));
      expect(colorFromHex('fbf6e8'), const Color(0xFFFBF6E8));
      expect(colorFromHex('nope'), const Color(0xFFC25A3C));
    });
  });

  group('JSON round-trip', () {
    test('arrow', () {
      expectRoundTrip(ArrowShape(
        points: const [Offset(1.5, 7.5), Offset(1.5, 5.5), Offset(2.5, 5.5)],
        color: '#3b7a55',
        stroke: 0.16,
      ));
    });

    test('line', () {
      expectRoundTrip(const LineShape(
        a: Offset(0.5, 0.5),
        b: Offset(7.5, 7.5),
        color: '#2f4a6b',
        stroke: 0.05,
      ));
    });

    test('highlight', () {
      expectRoundTrip(const HighlightShape(
        square: BoardSquare(3, 4),
        color: '#e5b445',
        stroke: 0.08,
      ));
    });

    test('rect', () {
      expectRoundTrip(const RectShape(
        a: Offset(2.2, 1.1),
        b: Offset(5.9, 4.4),
        color: '#c25a3c',
        stroke: 0.12,
      ));
    });

    test('circle', () {
      expectRoundTrip(const CircleShape(
        a: Offset(3, 3),
        b: Offset(5, 6),
        color: '#7a4f8a',
        stroke: 0.08,
      ));
    });

    test('pen', () {
      expectRoundTrip(PenShape(
        points: const [
          Offset(1, 1),
          Offset(1.25, 1.5),
          Offset(2, 2.75),
          Offset(3.5, 3),
        ],
        color: '#d88a3d',
        stroke: 0.03,
      ));
    });

    test('text', () {
      expectRoundTrip(const TextShape(
        at: Offset(4.5, 4.5),
        text: 'Zugzwang!',
        color: '#fbf6e8',
        stroke: 0.24,
      ));
    });

    test('tolerates unknown kinds and malformed geometry', () {
      expect(DrawShape.fromJson({'kind': 'sparkles'}), isNull);
      expect(
        DrawShape.fromJson({'kind': 'arrow', 'points': []}),
        isNull,
      );
      expect(
        DrawShape.fromJson({
          'kind': 'arrow',
          'points': [
            ['x', 'y'],
            [1, 2],
          ],
        }),
        isNull,
      );
      expect(DrawShape.fromJson({'kind': 'highlight', 'sq': 'e4'}), isNull);
      expect(
        DrawShape.fromJson({
          'kind': 'text',
          'points': [
            [1, 1]
          ],
          'text': '',
        }),
        isNull,
      );
    });
  });

  group('knight-bend geometry', () {
    // Board coords: row 0 = rank 8, col 0 = file a.
    const b1 = BoardSquare(7, 1);
    const c3 = BoardSquare(5, 2);
    const d2 = BoardSquare(6, 3);
    const a1 = BoardSquare(7, 0);

    test('b1->c3 bends with the longer (vertical) leg first', () {
      expect(isKnightDisplacement(b1, c3), isTrue);
      expect(arrowPointsBetween(b1, c3), const [
        Offset(1.5, 7.5), // b1
        Offset(1.5, 5.5), // b3 corner
        Offset(2.5, 5.5), // c3
      ]);
    });

    test('b1->d2 bends with the longer (horizontal) leg first', () {
      expect(isKnightDisplacement(b1, d2), isTrue);
      expect(arrowPointsBetween(b1, d2), const [
        Offset(1.5, 7.5), // b1
        Offset(3.5, 7.5), // d1 corner
        Offset(3.5, 6.5), // d2
      ]);
    });

    test('a1->c3 is a straight diagonal (no bend)', () {
      expect(isKnightDisplacement(a1, c3), isFalse);
      expect(arrowPointsBetween(a1, c3), const [
        Offset(0.5, 7.5),
        Offset(2.5, 5.5),
      ]);
    });
  });

  group('orientation transform', () {
    test('White orientation is the identity', () {
      expect(orientPoint(const Offset(1.5, 2.5), Side.white),
          const Offset(1.5, 2.5));
    });

    test('Black orientation rotates 180 degrees', () {
      expect(orientPoint(const Offset(1.5, 2.5), Side.black),
          const Offset(6.5, 5.5));
      expect(orientPoint(const Offset(0, 0), Side.black), const Offset(8, 8));
    });

    test('is an involution (view->board == board->view)', () {
      const p = Offset(3.25, 6.75);
      expect(orientPoint(orientPoint(p, Side.black), Side.black), p);
    });

    test('squareAt maps board points and rejects off-board', () {
      expect(squareAt(const Offset(4.5, 4.5)), const BoardSquare(4, 4)); // e4
      expect(squareAt(const Offset(0.1, 7.9)), const BoardSquare(7, 0)); // a1
      expect(squareAt(const Offset(-0.2, 4)), isNull);
      expect(squareAt(const Offset(4, 8.2)), isNull);
    });
  });

  group('hit testing', () {
    test('finds the topmost shape near the point', () {
      final arrow = ArrowShape(
        points: const [Offset(0.5, 0.5), Offset(4.5, 0.5)],
        color: '#c25a3c',
        stroke: 0.08,
      );
      const highlight = HighlightShape(
        square: BoardSquare(0, 2),
        color: '#3b7a55',
        stroke: 0.08,
      );
      final shapes = <DrawShape>[arrow, highlight];
      // Over the highlight square (which also lies on the arrow): topmost wins.
      expect(hitTestShapes(shapes, const Offset(2.5, 0.5)), 1);
      // On the arrow shaft only.
      expect(hitTestShapes(shapes, const Offset(1.2, 0.55)), 0);
      // Far away from both.
      expect(hitTestShapes(shapes, const Offset(6, 6)), isNull);
    });
  });
}
