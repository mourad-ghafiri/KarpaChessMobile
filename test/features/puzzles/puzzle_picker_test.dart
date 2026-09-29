import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/features/puzzles/domain/puzzle_picker.dart';

Puzzle _puzzle(String id, int rating) =>
    Puzzle(id: id, fen: '8/8/8/8/8/8/8/8 w - - 0 1', solution: const ['e4'], rating: rating);

void main() {
  group('rated', () {
    test('serves inside the band and honours the exclude set', () {
      final pool = [_puzzle('near', 850), _puzzle('far', 1900)];
      final pick = PuzzlePicker.rated(
        pool,
        rating: 800,
        exclude: const {},
        random: math.Random(1),
      );
      expect(pick!.id, 'near');

      // With the near one excluded, the band widens until something fits —
      // an excluded puzzle is never served, a distant one is.
      final next = PuzzlePicker.rated(
        pool,
        rating: 800,
        exclude: const {'near'},
        random: math.Random(1),
      );
      expect(next!.id, 'far');
    });

    test('an exhausted pool returns null', () {
      expect(
        PuzzlePicker.rated(
          [_puzzle('a', 800)],
          rating: 800,
          exclude: const {'a'},
          random: math.Random(1),
        ),
        isNull,
      );
    });
  });

  group('inPack', () {
    test('walks authored order and serves the first not-excluded puzzle', () {
      final pack = [_puzzle('a', 600), _puzzle('b', 700), _puzzle('c', 800)];
      expect(PuzzlePicker.inPack(pack, exclude: const {})!.id, 'a');
      // A solved 'a' and 'c' leave 'b' — which is how a failed puzzle
      // (never excluded by the caller) comes back around first.
      expect(PuzzlePicker.inPack(pack, exclude: const {'a', 'c'})!.id, 'b');
      expect(
        PuzzlePicker.inPack(pack, exclude: const {'a', 'b', 'c'}),
        isNull,
      );
    });
  });

  group('daily', () {
    test('is deterministic for a date and moves with it', () {
      final pool = [for (var i = 0; i < 7; i++) _puzzle('p$i', 800)];
      final day = DateTime(2026, 8, 24);
      expect(
        PuzzlePicker.daily(pool, day)!.id,
        PuzzlePicker.daily(pool, day)!.id,
      );
      expect(
        PuzzlePicker.daily(pool, day)!.id,
        isNot(PuzzlePicker.daily(pool, day.add(const Duration(days: 1)))!.id),
      );
      expect(PuzzlePicker.daily(const [], day), isNull);
    });
  });
}
