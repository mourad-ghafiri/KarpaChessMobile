import 'dart:math' as math;

import '../../../content/domain/models.dart';

/// Chooses which puzzle to serve next.
///
/// Pure functions over a pool, so what the trainer will do next is decided
/// in one readable place rather than inside a widget.
abstract final class PuzzlePicker {
  /// How far either side of the reader's rating counts as "about right".
  /// Wide enough that the band is never empty in a 240-puzzle corpus,
  /// narrow enough that a 1900 puzzle never lands on a 900 reader.
  static const band = 150;

  /// The next puzzle for the rated stream: near [rating], never one of
  /// [exclude], and randomised inside the band so two sessions at the same
  /// rating do not replay the same order.
  ///
  /// Widens the band, then drops the rating filter entirely, rather than
  /// returning null while playable puzzles remain — a trainer that says
  /// "nothing for you" is worse than one that stretches.
  static Puzzle? rated(
    List<Puzzle> pool, {
    required int rating,
    required Set<String> exclude,
    required math.Random random,
  }) {
    final fresh = [for (final p in pool) if (!exclude.contains(p.id)) p];
    if (fresh.isEmpty) return null;

    for (final width in [band, band * 2, band * 4]) {
      final inBand = [
        for (final p in fresh)
          if (((p.rating ?? rating) - rating).abs() <= width) p,
      ];
      if (inBand.isNotEmpty) return inBand[random.nextInt(inBand.length)];
    }
    // Nothing near the reader: give them the closest thing that exists.
    fresh.sort((a, b) => ((a.rating ?? rating) - rating)
        .abs()
        .compareTo(((b.rating ?? rating) - rating).abs()));
    return fresh.first;
  }

  /// The next puzzle in a pack: packs are authored in ascending difficulty,
  /// so they are walked in order and the first not-excluded one is next.
  /// What "excluded" means (lifetime solves, this session's serves) is the
  /// caller's policy — a failed puzzle is deliberately not excluded, so it
  /// is served again first.
  static Puzzle? inPack(List<Puzzle> pack, {required Set<String> exclude}) {
    for (final puzzle in pack) {
      if (!exclude.contains(puzzle.id)) return puzzle;
    }
    return null;
  }

  /// The same puzzle for the whole calendar day, chosen without a server.
  ///
  /// Derived from the date alone, so every device agrees and nothing has to
  /// be stored.
  static Puzzle? daily(List<Puzzle> pool, DateTime day) {
    if (pool.isEmpty) return null;
    final key = day.year * 10000 + day.month * 100 + day.day;
    return pool[key % pool.length];
  }
}
