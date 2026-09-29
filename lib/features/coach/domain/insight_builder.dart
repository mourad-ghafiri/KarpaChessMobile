import 'package:dartchess/dartchess.dart';

import '../../../core/chess/tolerant_position.dart';
import '../../../engine/domain/engine_models.dart';
import '../../../engine/domain/engine_service.dart';
import 'coach_service.dart';

/// Engine-derived facts about one position: the best move, the evaluation,
/// the top candidate lines, and the opponent's standing threat.
class PositionInsight {
  const PositionInsight({
    this.bestSan,
    this.evalCp,
    this.topLines = const [],
    this.threat,
  });

  /// Engine-best move for the side to move.
  final String? bestSan;

  /// Centipawns from the side-to-move perspective.
  final int? evalCp;

  /// Up to three candidates, best first (side-to-move perspective evals).
  final List<CandidateLine> topLines;

  /// What the opponent would play if it were their turn.
  final CandidateLine? threat;
}

/// The single source of multi-line + threat position scans, shared by the
/// coach chat and the studio's commentary insight (DRY over both features).
class InsightBuilder {
  const InsightBuilder(this._engine);

  final EngineService _engine;

  /// Scans [position]: one MultiPV-3 search plus a turn-flipped threat scan.
  /// Engine failures — a cancelled [token] included — degrade to an empty
  /// (or partial) insight; never throws.
  Future<PositionInsight> scan(
    Position position, {
    int movetimeMs = 350,
    EnginePriority priority = EnginePriority.batch,
    CancellationToken? token,
  }) async {
    String? bestSan;
    int? evalCp;
    final topLines = <CandidateLine>[];
    CandidateLine? threat;
    try {
      final analysis = await _engine.analyse(
        position.fen,
        limit: SearchLimit.movetime(movetimeMs),
        priority: priority,
        token: token,
        multiPv: 3,
      );
      final turn = position.turn == Side.white ? 'w' : 'b';
      if (analysis.uci != null) {
        final move = NormalMove.fromUci(analysis.uci!);
        if (position.isLegal(move)) {
          bestSan = position.makeSan(move).$2;
        }
      }
      evalCp = analysis.score?.cpFor(turn);
      for (final line in analysis.lines) {
        final first = line.pvUci.isNotEmpty ? line.pvUci.first : null;
        if (first == null) continue;
        final move = NormalMove.fromUci(first);
        if (!position.isLegal(move)) continue;
        topLines.add(CandidateLine(
          san: position.makeSan(move).$2,
          evalCp: line.score.cpFor(turn),
        ));
      }
      threat = await scanThreat(position, priority: priority, token: token);
    } catch (_) {
      // Engine busy/unavailable — callers degrade gracefully.
    }
    return PositionInsight(
      bestSan: bestSan,
      evalCp: evalCp,
      topLines: topLines,
      threat: threat,
    );
  }

  /// What the opponent would do on their turn: analyse the turn-flipped
  /// position. Skipped when the mover is in check — the flip then leaves a
  /// king that can simply be captured, which is not a chess position.
  /// Stockfish 19 exits the app's process on one (asking for a hint WHILE IN
  /// CHECK once closed the whole app); the engine service now turns such a
  /// position away before it is sent (`EnginePosition`), and this test keeps
  /// the request from being made at all.
  ///
  /// It must be the explicit `isCheck` test below: the tolerant
  /// [positionFromFen] deliberately accepts opposite-check setups for the
  /// lessons, so the parse further down can never be the thing that skips.
  Future<CandidateLine?> scanThreat(
    Position position, {
    EnginePriority priority = EnginePriority.batch,
    CancellationToken? token,
  }) async {
    if (position.isCheck) return null;
    final parts = position.fen.split(' ');
    if (parts.length < 6) return null;
    parts[1] = parts[1] == 'w' ? 'b' : 'w';
    parts[3] = '-'; // en-passant square is meaningless after the flip
    final flippedFen = parts.join(' ');
    final Position flipped;
    try {
      flipped = positionFromFen(flippedFen);
    } catch (_) {
      return null;
    }
    final analysis = await _engine.analyse(
      flippedFen,
      limit: const SearchLimit.movetime(150),
      priority: priority,
      token: token,
    );
    final uci = analysis.uci;
    if (uci == null) return null;
    final move = NormalMove.fromUci(uci);
    if (!flipped.isLegal(move)) return null;
    final turn = flipped.turn == Side.white ? 'w' : 'b';
    return CandidateLine(
      san: flipped.makeSan(move).$2,
      evalCp: analysis.score?.cpFor(turn),
    );
  }
}
