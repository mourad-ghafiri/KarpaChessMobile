import 'dart:io';

import 'package:dartchess/dartchess.dart' show Chess, Setup, Side;
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';
import 'package:karpachess/features/commentator/domain/move_tree.dart';

import 'src/corpus.dart';
import 'src/findings.dart';

/// Integrity of everything bundled under `assets/data`.
///
/// Every lesson FEN parses and every `targetSan` is legal; every puzzle
/// solution replays; the manifests agree with what is actually on disk; every
/// game in the Studio's library loads in the Studio. Run it after touching
/// content.
///
///   dart run tool/content.dart
///
/// It runs against the app's
/// own models and its own tolerant FEN reader, so passing it means the app can
/// load what passed — not that a second implementation agreed.
///
/// `en/` is the canonical corpus. The translations mirror it file for file
/// and have their own gate, `tool/translations.dart`.
void main(List<String> args) {
  final corpus = Corpus();
  final findings = <Finding>[
    ..._strays(corpus),
    ..._manifests(corpus),
    ..._lessons(corpus),
    ..._puzzles(corpus),
    ..._studyGames(corpus),
  ];
  final games = corpus.gameLibrary().games.length;
  exit(report(findings, 'checked the English corpus and $games study games'));
}

/// A directory beside `en/` that is not a translated language is a leftover —
/// a stray one once turned this whole gate red with a hundred "missing
/// lesson" errors about a folder the app never reads. Worth a look, never
/// worth checking as content.
Iterable<Finding> _strays(Corpus corpus) sync* {
  for (final dir in corpus.strayDirectories()) {
    yield Finding.flag(
      'assets/data/$dir',
      'not part of the English corpus and not bundled — a leftover directory',
    );
  }
}

/// The manifest/disk contract: a lesson the manifest names must exist, and a
/// file on disk that no manifest names is dead weight in the bundle.
Iterable<Finding> _manifests(Corpus corpus) sync* {
  final manifest = corpus.lessonManifest();
  final named = <String>{
    for (final category in manifest.categories) ...category.lessonFiles,
  };

  final onDisk = corpus.lessons('en').keys.toSet();
  for (final file in named.difference(onDisk)) {
    yield Finding.error('lessons/en', 'manifest names $file, not on disk');
  }
  for (final file in onDisk.difference(named)) {
    yield Finding.flag('lessons/en', '$file is on disk but in no category');
  }

  final puzzles = corpus.puzzles();
  final themed = <String>{
    for (final theme in corpus.puzzleManifest().themes) ...theme.puzzleFiles,
  };
  final packed = corpus.packManifest().allPuzzleFiles.toSet();

  for (final file in themed) {
    final id = file.replaceAll('.json', '');
    if (!puzzles.containsKey(id)) {
      yield Finding.error('puzzles/index.json', '$file is not on disk');
    } else if (puzzles[id]!.isTrainer) {
      // The rule the corpus is built on: a trainer pack in the theme index
      // leaks into Sharpen's review pools.
      yield Finding.error('puzzles/index.json',
          '$file is a trainer puzzle and must not be listed here');
    }
  }
  for (final file in packed) {
    final id = file.replaceAll('.json', '');
    if (!puzzles.containsKey(id)) {
      yield Finding.error('puzzles/packs.json', '$file is not on disk');
    }
  }
}

/// Every lesson replays: the FEN of each step parses, and each play step's
/// accepted answers are legal in it.
Iterable<Finding> _lessons(Corpus corpus) sync* {
  for (final entry in corpus.lessons('en').entries) {
    final where = 'lessons/en/${entry.key}';
    for (final (index, step) in entry.value.steps.indexed) {
      final position = _parse(step.fen);
      if (position == null) {
        yield Finding.error(where, 'step ${index + 1}: FEN does not parse');
        continue;
      }
      if (step is! PlayStep) continue;
      if (step.targetSan.isEmpty) {
        yield Finding.error(where, 'step ${index + 1}: play step has no answer');
      }
      for (final san in step.targetSan) {
        if (legalMoveFromSan(position, san) == null) {
          yield Finding.error(where, 'step ${index + 1}: $san is illegal');
        }
      }
    }
  }
}

/// Every puzzle replays end to end — teaching puzzles included.
Iterable<Finding> _puzzles(Corpus corpus) sync* {
  for (final file in corpus.puzzles().values) {
    final where = 'puzzles/en/${file.fileId}';
    var position = _parse(file.puzzle.fen);
    if (position == null) {
      yield Finding.error(where, 'FEN does not parse');
      continue;
    }
    if (file.puzzle.solution.isEmpty) {
      yield Finding.error(where, 'no solution');
      continue;
    }
    for (final (index, san) in file.puzzle.solution.indexed) {
      final move = legalMoveFromSan(position, san);
      if (move == null) {
        yield Finding.error(where, 'ply ${index + 1} ($san) is illegal');
        break;
      }
      position = position.playUnchecked(move);
    }
  }
}

/// The Studio's library, through the Studio's own loader (`MoveTree.fromPgn`
/// on the PGN the library hands it): every game loads, writes its moves the
/// way the Studio will show them, names both players, is decisive — a
/// finished mate agreeing with the result — counts its plies right, sits in a
/// collection that counts it, and appears once.
///
/// "Every move replayed before it was kept" used to be a promise about how
/// the library was built, with nothing to keep it true afterwards.
Iterable<Finding> _studyGames(Corpus corpus) sync* {
  const file = 'games/games.json';
  final library = corpus.gameLibrary();
  final collections = {for (final c in library.collections) c.id};
  if (collections.contains(importedShelf)) {
    yield Finding.error(file,
        'a collection is called "$importedShelf", the imported games\' shelf');
  }
  final held = <String, int>{};
  final ids = <String>{};
  final lines = <String>{};
  for (final game in library.games) {
    final where = '$file ${game.id}';
    if (!ids.add(game.id)) yield Finding.error(where, 'duplicate id');
    if (!lines.add(game.moves.join(' '))) {
      yield Finding.error(where, 'the same moves as another game');
    }
    if (!collections.contains(game.collection)) {
      yield Finding.error(where, 'unknown collection "${game.collection}"');
    }
    held.update(game.collection, (n) => n + 1, ifAbsent: () => 1);
    if (game.white.trim().isEmpty || game.black.trim().isEmpty) {
      yield Finding.error(where, 'a player is not named');
    }
    // The site is what the library card cites ("Paris · 1858"), so it must
    // read as a place: not the PGN's `?`, and not a database's trailing FIDE
    // code ("Moscow RUS"). A tester read the old event codes ("Paris it") as
    // a typo on the card.
    final site = game.site.trim();
    if (site.isEmpty || site == '?') {
      yield Finding.error(where, 'no site: the card would cite no place');
    } else if (RegExp(r' [A-Z]{3}$').hasMatch(site)) {
      yield Finding.error(where, 'site "$site" ends in a country code');
    }
    if (game.result != '1-0' && game.result != '0-1') {
      yield Finding.error(where, 'not decisive (${game.result})');
    }
    if (game.plies != game.moves.length) {
      yield Finding.error(
          where, 'plies says ${game.plies}, the game has ${game.moves.length}');
    }

    final MoveTree tree;
    try {
      tree = MoveTree.fromPgn(game.toPgn());
    } on FormatException catch (e) {
      yield Finding.error(where, 'does not load in the Studio: ${e.message}');
      continue;
    }
    final mainline = tree.mainline().skip(1).toList();
    if (mainline.length != game.moves.length) {
      yield Finding.error(where,
          'the Studio loads ${mainline.length} of its ${game.moves.length} plies');
      continue;
    }
    for (final (index, node) in mainline.indexed) {
      if (node.san != game.moves[index]) {
        yield Finding.error(where,
            'ply ${index + 1} is written ${game.moves[index]}, the Studio '
            'writes ${node.san}');
        break;
      }
    }
    final end = Chess.fromSetup(Setup.parseFen(mainline.last.positionFen));
    if (end.isCheckmate) {
      final winner = end.turn == Side.white ? '0-1' : '1-0';
      if (winner != game.result) {
        yield Finding.error(where, 'ends in mate for $winner, says ${game.result}');
      }
    }
  }
  for (final collection in library.collections) {
    final count = held[collection.id] ?? 0;
    if (count != collection.count) {
      yield Finding.error(file,
          'collection ${collection.id} says ${collection.count} games, holds $count');
    }
  }
}

/// Lesson and puzzle FENs may be pedagogical — a lone king, an "impossible"
/// check — so they go through the app's tolerant reader, not `Chess.fromSetup`.
dynamic _parse(String fen) {
  try {
    return positionFromFen(fen);
  } on Object {
    return null;
  }
}
