import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';

import 'src/chess_proofs.dart';
import 'src/corpus.dart';
import 'src/findings.dart';
import 'src/pack_manifest.dart';
import 'src/engine_screen.dart';
import 'src/puzzle_rules.dart';

/// The trainer's own tooling. `check` is pure dartchess over the app's own
/// models — proofs and legality, seconds for the whole corpus. Judgements
/// about move QUALITY are not proofs and are not made here: they belong to
/// `--engine`, which asks Stockfish.
///
///   dart run tool/puzzles.dart check [pack…] [--engine]
///   dart run tool/puzzles.dart packs [--check]
///   dart run tool/puzzles.dart fen [--from `<fen>`] `<san san san>`
const _usage = '''
usage:
  dart run tool/puzzles.dart check [pack…] [--engine]
      The gate. Structure, ratings, duplicate positions, legality, forced
      replies, and a proof of what each line achieves.
      --engine adds the evaluative screen: one Stockfish process asks whether
      each first move is really the only good one. Minutes, not seconds.

  dart run tool/puzzles.dart packs [--check]
      Rewrites assets/data/puzzles/packs.json from the files on disk.
      --check fails instead of writing when it is out of date.

  dart run tool/puzzles.dart fen [--from "<fen>"] "<san san san>"
      Replays moves and prints the resulting FEN and board. Positions are
      DERIVED this way, never typed by hand.

  dart run tool/puzzles.dart prove "<fen>" [--plies N]
      Is there a forced mate, how long, and which first moves deliver it?
      The authoring loop: compose, prove, keep only what comes back unique.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.write(_usage);
    exit(64);
  }
  final command = args.first;
  final rest = args.skip(1).toList();
  switch (command) {
    case 'check':
      exit(await _check(rest));
    case 'packs':
      exit(_packs(rest));
    case 'fen':
      exit(_fen(rest));
    case 'prove':
      exit(_prove(rest));
    default:
      stderr.writeln('unknown command "$command"\n');
      stdout.write(_usage);
      exit(64);
  }
}

Future<int> _check(List<String> args) async {
  final only = args.where((a) => !a.startsWith('--')).toSet();
  final gate = PuzzleGate();
  final corpus = Corpus();
  final files = corpus.puzzles();
  final findings = gate.run(
    files,
    packs: only.isEmpty ? null : only,
    lessons: corpus.lessons('en'),
  );
  final packs = files.values
      .where((f) => f.isTrainer && (only.isEmpty || only.contains(f.pack)))
      .map((f) => f.pack)
      .toSet();
  final teaching =
      only.isEmpty ? ' and ${gate.checkedTeaching} teaching puzzles' : '';

  var summary =
      'checked ${gate.checked} trainer puzzles in ${packs.length} pack(s)$teaching';

  // The evaluative half. Opt-in because it is minutes rather than seconds,
  // and ONE engine process for the whole corpus.
  if (args.contains('--engine')) {
    final screened = only.isEmpty
        ? files
        : {
            for (final e in files.entries)
              if (only.contains(e.value.pack)) e.key: e.value
          };
    // Openings, strategy, history, culture and endgame drills state their
    // goal in the prompt because they deliberately have several good moves
    // (CLAUDE.md). Screening them for "no rival within 50cp" measures them
    // against a rule they were never written to.
    final skip = EngineScreen.goalNamedIds();
    final engineFindings = await withEngine((engine, identity) {
      final screen = EngineScreen(engine);
      return screen.screenPuzzles(screened, skip: skip,
          onProgress: (id, done, total) {
        stdout.write('\r  screening $done/$total  ${id.padRight(28)}');
        if (done == total) stdout.writeln();
      });
    });
    findings.addAll(engineFindings);
    final n = screened.keys.where((id) => !skip.contains(id)).length;
    summary += ', $n screened by engine '
        '(${screened.length - n} goal-named drills skipped)';
  }

  return report(findings, summary);
}

int _packs(List<String> args) {
  final builder = PackManifestBuilder(Corpus());
  final (:text, :pending) = builder.build();

  if (args.contains('--check')) {
    if (builder.read() != text) {
      stderr.writeln('packs.json is out of date — run '
          'dart run tool/puzzles.dart packs');
      return 1;
    }
    stdout.writeln('packs.json is up to date');
    return 0;
  }

  builder.write(text);
  final written = packOrder.length - pending.length;
  final total = Corpus().puzzles().values.where((p) => p.isTrainer).length;
  stdout.writeln('wrote $written packs, $total puzzles');
  if (pending.isNotEmpty) stdout.writeln('still to author: ${pending.join(", ")}');
  return 0;
}

int _fen(List<String> args) {
  var from = kInitialFEN;
  final moves = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--from') {
      from = args[++i];
    } else {
      moves.addAll(args[i].split(RegExp(r'\s+')).where((s) => s.isNotEmpty));
    }
  }

  Position position;
  try {
    position = positionFromFen(from);
  } on Object catch (e) {
    stderr.writeln('start FEN does not parse — $e');
    return 1;
  }

  // Move numbers and results are stripped so a PGN fragment can be pasted in
  // whole rather than picked apart by hand.
  for (final token in moves) {
    final san = token.replaceAll(RegExp(r'^\d+\.+'), '');
    if (san.isEmpty || RegExp(r'^(1-0|0-1|1/2-1/2|\*)$').hasMatch(san)) continue;
    final move = legalMoveFromSan(position, san);
    if (move == null) {
      stderr.writeln('$san is illegal in ${position.fen}');
      return 1;
    }
    position = position.playUnchecked(move);
  }

  stdout.writeln(_board(position));
  stdout.writeln('');
  stdout.writeln(position.fen);
  final mate = position.isCheckmate
      ? 'checkmate'
      : position.isStalemate
          ? 'stalemate'
          : '${position.turn == Side.white ? "White" : "Black"} to move, '
              '${legalMovesOf(position).length} legal moves';
  stdout.writeln(mate);
  return 0;
}

/// Answers the only question that matters while composing a mating puzzle: is
/// the intended blow forced, and is it the only one?
///
/// A position that comes back with one first move and one length is a puzzle
/// the gate will prove. Anything else — two solutions, a faster mate, no mate
/// at all — is a position to recompose, and better to learn now than after
/// twelve files are written.
int _prove(List<String> args) {
  var maxPlies = 5;
  final rest = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--plies') {
      maxPlies = int.parse(args[++i]);
    } else {
      rest.add(args[i]);
    }
  }
  if (rest.isEmpty) {
    stderr.writeln('prove needs a FEN');
    return 64;
  }

  final Position position;
  try {
    position = positionFromFen(rest.first);
  } on Object catch (e) {
    stderr.writeln('FEN does not parse — $e');
    return 1;
  }

  stdout.writeln(_board(position));
  stdout.writeln('');
  final mate = forcedMateIn(position, maxPlies: maxPlies);
  if (mate.exhausted) {
    stdout.writeln('search ran out of budget — inconclusive, not "no mate"');
    return 1;
  }
  final plies = mate.plies;
  if (plies == null) {
    stdout.writeln('no forced mate within $maxPlies plies');
    return 1;
  }
  final firsts = movesForcingMateIn(position, plies);
  if (firsts.exhausted) {
    stdout.writeln('forced mate in $plies plies, but the uniqueness search '
        'ran out of budget — the key move may not be the only one');
    return 1;
  }
  final sans = firsts.moves.map((m) => position.makeSan(m).$2).join(', ');
  stdout.writeln('forced mate in $plies plies (mate in ${(plies + 1) ~/ 2})');
  stdout.writeln('${firsts.moves.length} first move(s): $sans');
  return firsts.moves.length == 1 ? 0 : 1;
}

/// The position as eight rows, read from Black's back rank down, so a composed
/// study can be eyeballed before it is kept.
String _board(Position position) {
  final rows = <String>[];
  for (var rank = 7; rank >= 0; rank--) {
    final cells = <String>[];
    for (var file = 0; file < 8; file++) {
      final piece = position.board.pieceAt(Square(file + rank * 8));
      if (piece == null) {
        cells.add('.');
      } else {
        final letter = piece.role.letter;
        cells.add(piece.color == Side.white ? letter.toUpperCase() : letter);
      }
    }
    rows.add('${rank + 1}  ${cells.join(' ')}');
  }
  rows.add('   a b c d e f g h');
  return rows.join('\n');
}
