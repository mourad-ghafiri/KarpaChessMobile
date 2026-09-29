import 'dart:convert';
import 'dart:io';

// `File` is dartchess's board-file enum (a-h); this file wants dart:io's.
import 'package:dartchess/dartchess.dart' hide File;
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/uci_engine_service.dart';

import 'chess_proofs.dart';
import 'corpus.dart';
import 'findings.dart';
import 'process_uci_transport.dart';

/// The evaluative half of the corpus audit, made repeatable.
///
/// `docs/content-audit.md:16` states the protocol this project already works
/// to: *"Board facts with python-chess; evaluative claims with Stockfish."*
/// Until now that second half was a person driving inline `python3` heredocs —
/// the same file says *"no scripts are written to disk"* — so the guarantee
/// could not be re-run, and editing a puzzle could silently introduce a second
/// solution that nothing would catch.
///
/// This asks the **same engine the app ships**, through the **same UCI client
/// the app uses** (`UciEngineService`), over one subprocess. It never falls
/// back to a search of its own: a gate that guesses is worse than no gate,
/// which is what the deleted `rivals()` proved.
///
/// Two thresholds, both taken from the audit's own rules:
/// - a puzzle's first move must be the only good one — **no rival within
///   [rivalCp]** of it;
/// - a lesson play beat's accepted answers must be **within [beatCp]** of best.
///
/// Proven mates are skipped. `chess_proofs.dart` settles those by exhaustion,
/// which is strictly stronger than an engine opinion — and the audit drew the
/// same seam, excluding proven ≤5-ply mates "since the prover covers them".
class EngineScreen {
  EngineScreen(
    this._engine, {
    this.limit = const SearchLimit.depth(20),
    this.multiPv = 5,
    this.rivalCp = 50,
    this.beatCp = 30,
  });

  final UciEngineService _engine;

  /// How hard to look. The audit used depth ≥ 24; depth 20 is the documented
  /// floor for the per-beat screen and is what makes a whole-corpus run
  /// finish in a sitting.
  final SearchLimit limit;

  final int multiPv;

  /// A second move this close to the best one means the puzzle has two
  /// answers, and the app accepts only one.
  final int rivalCp;

  /// A lesson play beat may accept several moves; each must be this close.
  final int beatCp;

  /// Themes whose puzzles deliberately have more than one good move.
  ///
  /// `CLAUDE.md` is explicit: *"a setup must name the goal whenever the
  /// position has more than one good move — openings, plans, notation and
  /// castling drills all do."* An opening puzzle asks for a specific
  /// theoretical move among several playable ones; a strategy puzzle asks for
  /// a plan. Holding those to "no rival within 50cp" measures them against a
  /// rule they were never written to, and buries the tactical findings that
  /// matter under a pile of expected ones.
  ///
  /// `endgames` is here for the reason `docs/content-audit.md` already
  /// records as an accepted exception: a won Lucena has several winning
  /// methods, and the proof names the method rather than the move.
  static const goalNamed = {
    'openings',
    'strategy',
    'history',
    'culture',
    'endgames',
  };

  /// Screens every puzzle's FIRST move — the one the solver must find.
  ///
  /// Later plies are not screened: once the first move is unique the line is
  /// the author's to script, and the forced-reply rules already cover whether
  /// the opponent had a choice.
  ///
  /// [skip] names puzzles whose prompt states the goal instead of demanding
  /// one move; they are not screened for rivals.
  Future<List<Finding>> screenPuzzles(
    Map<String, PuzzleFile> files, {
    Set<String> skip = const {},
    void Function(String id, int done, int total)? onProgress,
  }) async {
    final out = <Finding>[];
    final ids = files.keys.where((id) => !skip.contains(id)).toList()..sort();
    var done = 0;
    for (final id in ids) {
      final file = files[id]!;
      onProgress?.call(id, ++done, ids.length);
      out.addAll(await _screenFirstMove(id, file.puzzle.fen, file.puzzle.solution));
    }
    return out;
  }

  /// The puzzle ids under [goalNamed] themes, read from the corpus index.
  static Set<String> goalNamedIds({String root = 'assets/data'}) {
    final raw = json.decode(
        File('$root/puzzles/index.json').readAsStringSync()) as Map<String, dynamic>;
    final themes = raw['themes'] as List<dynamic>;
    return {
      for (final theme in themes.cast<Map<String, dynamic>>())
        if (goalNamed.contains(theme['id']))
          for (final file in (theme['puzzles'] as List<dynamic>).cast<String>())
            file.replaceAll('.json', ''),
      // The notation and board drills resolve by filename, not by theme:
      // they ask the reader to NAME a square, so every legal move "rivals".
      'board-proof',
      'notation-proof',
      // Two more whose prompt names the move outright, reviewed one at a
      // time rather than assumed:
      //   tactics-mix-05 "offering a second center pawn TO YOUR E-PAWN.
      //                   Take the pawn Black has just offered."  (Nxe5 is a
      //                   different pawn taken by a different piece)
      //   tactics-mix-13 "Castle toward the rook on a1." — a castling drill,
      //                   which CLAUDE.md lists among the goal-named kinds.
      'tactics-mix-05',
      'tactics-mix-13',
    };
  }

  Future<List<Finding>> _screenFirstMove(
    String id,
    String fen,
    List<String> solution,
  ) async {
    if (solution.isEmpty) return const [];
    // Tolerant, like the app: lesson and puzzle FENs may be pedagogical.
    final position = positionFromFen(fen);

    // The prover owns short mates, and proves more than the engine can.
    final mate = forcedMateIn(position, maxPlies: 5);
    if (!mate.exhausted && mate.plies != null) return const [];

    final authored = legalMoveFromSan(position, solution.first);
    if (authored == null) return const []; // legality is another gate's job

    final EngineMove result;
    try {
      result = await _engine.analyse(
        fen,
        limit: limit,
        priority: EnginePriority.batch,
        multiPv: multiPv,
      );
    } on EngineRejectedPosition catch (e) {
      // A teaching board no game can reach (one king, a check on the side
      // not to move): Stockfish would refuse it, so it is never sent.
      return [
        Finding.flag(id, 'Stockfish refuses the position (${e.reason}) — '
            'not screened'),
      ];
    }
    if (result.lines.isEmpty) {
      return [Finding.flag(id, 'engine returned no line — not screened')];
    }

    final mover = position.turn == Side.white ? 'w' : 'b';
    final scored = <String, int>{
      for (final line in result.lines)
        if (line.pvUci.isNotEmpty) line.pvUci.first: line.score.cpFor(mover),
    };

    final bestCp = scored.values.reduce((a, b) => a > b ? a : b);
    final authoredCp = scored[authored.uci];

    if (authoredCp == null) {
      return [
        Finding.flag(
            id,
            'the authored move ${solution.first} is not in the engine\'s top '
            '$multiPv — its best is ${_san(position, scored, bestCp)}'),
      ];
    }

    // Mates are not comparable on the centipawn axis: #9 and #13 sit four
    // "centipawns" apart, so a flat threshold would call every multi-mate
    // position a near-tie. But neither is every mate a rival — in a winning
    // position almost any sane move mates *eventually*, and a mate in 9 is
    // not a second solution to a mate in 4. The rule that matches the
    // prover's own (`movesForcingMateIn(plies)` asks for exactly that
    // length) is: a mating rival must mate at least as fast.
    final authoredMates = authoredCp > 90000;
    final rivals = <String>[];
    for (final entry in scored.entries) {
      if (entry.key == authored.uci) continue;
      final rivalMates = entry.value > 90000;
      final counts = authoredMates
          // asCp is 100000 - distance, so "at least as fast" is ">=".
          ? rivalMates && entry.value >= authoredCp
          : rivalMates || entry.value >= authoredCp - rivalCp;
      if (counts) {
        rivals.add('${_sanOf(position, entry.key)} (${_cp(entry.value)})');
      }
    }
    if (rivals.isEmpty) return const [];
    final why = authoredMates
        ? '${rivals.length} other move(s) mate at least as fast'
        : '${rivals.length} rival(s) within ${rivalCp}cp';
    return [
      Finding.flag(id,
          '${solution.first} (${_cp(authoredCp)}): $why — ${rivals.join(', ')}'),
    ];
  }

  /// Mates render as `#3`, not as a centipawn number — "mate" alone hides
  /// whether a rival mates faster than the authored move, which is the first
  /// thing a triage needs to know.
  static String _cp(int cp) {
    if (cp.abs() > 90000) {
      return '#${(100000 - cp.abs()) * (cp > 0 ? 1 : -1)}';
    }
    return '${cp > 0 ? '+' : ''}${(cp / 100).toStringAsFixed(2)}';
  }

  static String _san(Position position, Map<String, int> scored, int cp) {
    final uci = scored.entries.firstWhere((e) => e.value == cp).key;
    return _sanOf(position, uci);
  }

  static String _sanOf(Position position, String uci) {
    for (final move in legalMovesOf(position)) {
      if (move.uci == uci) return position.makeSan(move).$2;
    }
    return uci;
  }
}

/// Boots ONE engine, runs [body] against it, and always shuts it down.
///
/// One process for the whole corpus — never one per puzzle, never two at once.
Future<T> withEngine<T>(
  Future<T> Function(UciEngineService engine, String identity) body, {
  int threads = 2,
  int hashMb = 256,
}) async {
  final path = StockfishBinary.require();
  final transport = ProcessUciTransport(path);
  final engine = UciEngineService(transport, threads: threads, hashMb: hashMb);
  try {
    // Boot it before announcing, so the identity line is available.
    await engine.analyse(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      limit: const SearchLimit.movetime(1),
    );
    final identity = transport.identity ?? path;
    stdout.writeln('engine: $identity  ($path)');
    return await body(engine, identity);
  } finally {
    await engine.dispose();
  }
}
