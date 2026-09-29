import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/application/content_providers.dart';
import '../../../content/domain/models.dart';
import '../data/imported_games_store.dart';
import '../domain/imported_game.dart';
import '../domain/move_tree.dart';

/// The reader's own games, newest first.
final importedGamesProvider =
    AsyncNotifierProvider<ImportedGamesController, List<ImportedGame>>(
  ImportedGamesController.new,
);

class ImportedGamesController extends AsyncNotifier<List<ImportedGame>> {
  ImportedGamesStore get _store => ref.read(importedGamesStoreProvider);

  /// Loads the library, dropping anything that no longer parses.
  ///
  /// That filter is the feature's load-bearing invariant: everything this
  /// controller hands out is known-openable, so no screen downstream has to
  /// defend itself against a game it cannot show.
  @override
  Future<List<ImportedGame>> build() async {
    final stored = await _store.load();
    final usable = [
      for (final game in stored)
        if (_parses(game)) game,
    ];
    // Rewrite only when something was actually dropped, so a healthy library
    // is never touched on startup.
    if (usable.length != stored.length) await _store.save(usable);
    return usable;
  }

  static bool _parses(ImportedGame game) {
    try {
      MoveTree.fromPgn(game.pgn);
      return true;
    } on Object {
      return false;
    }
  }

  /// Parses [pgn], stores the game it describes, and returns it.
  ///
  /// Throws [FormatException] when the text is not a game — the one failure
  /// the reader can do something about, so it is reported to them rather than
  /// swallowed into a state field.
  Future<ImportedGame> import({
    required String pgn,
    required String name,
    required DateTime now,
  }) async {
    final tree = MoveTree.fromPgn(pgn);
    final current = await future;
    final game = ImportedGame.fromTree(
      tree,
      id: _freeId(current, now),
      name: name,
      pgn: pgn,
      importedAt: now,
    );
    final next = [game, ...current];
    state = AsyncData(next);
    await _store.save(next);
    return game;
  }

  Future<void> remove(String id) async {
    final next = [
      for (final game in await future)
        if (game.id != id) game,
    ];
    state = AsyncData(next);
    await _store.save(next);
  }

  /// `imported-<millis>`, nudged forward on the vanishingly rare collision of
  /// two imports inside one millisecond.
  static String _freeId(List<ImportedGame> existing, DateTime now) {
    final taken = {for (final game in existing) game.id};
    var stamp = now.millisecondsSinceEpoch;
    while (taken.contains('$importedShelf-$stamp')) {
      stamp += 1;
    }
    return '$importedShelf-$stamp';
  }
}

/// Everything the Studio's library screen shows: the games themselves, the
/// bundled collections that become filter chips, and how many of the games are
/// the reader's own.
class StudyLibrary {
  const StudyLibrary({
    required this.games,
    required this.collections,
    required this.importedCount,
  });

  /// Imports first (newest first), then the bundled corpus in its own order —
  /// so the game you just added is at the top of the list you land back on.
  final List<StudyGame> games;

  final List<GameCollection> collections;
  final int importedCount;
}

/// The bundled corpus and the reader's imports as one list.
final studyLibraryProvider = FutureProvider<StudyLibrary>((ref) async {
  final bundled = await ref.watch(gameLibraryProvider.future);
  final mine = await ref.watch(importedGamesProvider.future);
  return StudyLibrary(
    games: [...mine, ...bundled.games],
    collections: bundled.collections,
    importedCount: mine.length,
  );
});
