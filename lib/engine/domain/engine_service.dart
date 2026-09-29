import 'engine_models.dart';

/// The single seam between the app and the chess engine. Implemented by
/// [UciEngineService] over Stockfish; replaced by fakes in tests.
///
/// Every position passes `EnginePosition` before it is queued: one Stockfish
/// would refuse completes the request with [EngineRejectedPosition] and never
/// reaches the engine, which would otherwise exit the app's process.
abstract interface class EngineService {
  /// Full-strength analysis of [fen]. Returns the best move + evaluation.
  ///
  /// [priority] decides queue placement: interactive requests preempt
  /// running batch searches. A cancelled [token] completes the future with
  /// [EngineRequestCancelled].
  Future<EngineMove> analyse(
    String fen, {
    SearchLimit limit = const SearchLimit.movetime(300),
    EnginePriority priority = EnginePriority.interactive,
    CancellationToken? token,
    int multiPv = 1,
  });

  /// An opponent reply at [strength] in the game that began at [startFen]
  /// and has since seen [moves] (UCI, oldest first). The history, not just
  /// the current position, is what lets the engine see repetitions.
  Future<EngineMove> bestMove(
    String startFen,
    List<String> moves,
    EngineStrength strength, {
    CancellationToken? token,
  });

  /// Signals a fresh game (clears engine state/hash relevance).
  Future<void> newGame();

  /// Holds all engine work — the battery gate for the app leaving the
  /// foreground. The running search is stopped and its truncated result is
  /// discarded; it and everything queued wait for [resume], where the
  /// interrupted search runs again in full. Callers only see their futures
  /// complete later.
  void suspend();

  /// Releases [suspend]'s hold.
  void resume();

  Future<void> dispose();
}
