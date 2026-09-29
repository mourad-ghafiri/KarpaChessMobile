import 'dart:async';

import '../data/uci_protocol.dart';
import 'engine_models.dart';
import 'engine_position.dart';
import 'engine_service.dart';
import 'uci_transport.dart';

/// [EngineService] implementation that serializes searches over a single
/// UCI engine (UCI engines run one search at a time).
///
/// Scheduling rules:
/// - A position is checked by [EnginePosition] when it is requested, so a
///   refused one never queues, preempts, or boots the engine.
/// - Requests run strictly one at a time; a `go` is never issued while a
///   `bestmove` is outstanding.
/// - [EnginePriority.interactive] requests are queued ahead of batch ones,
///   and a running batch search is preempted with `stop` (it still completes
///   normally with its best-so-far result).
/// - Cancelling a token stops a running search, drops a queued one at once,
///   and completes its future with [EngineRequestCancelled].
/// - [suspend] holds everything; the search it stopped runs again in full
///   after [resume].
class UciEngineService implements EngineService {
  UciEngineService(
    this._transport, {
    this.threads = 2,
    this.hashMb = 32,
    this.depthSearchTimeout = const Duration(minutes: 10),
  });

  final UciTransport _transport;

  /// Threads for interactive full-strength work. Batch work and handicapped
  /// replies run on one.
  final int threads;
  final int hashMb;

  /// Hang backstop for a depth search with no movetime cap of its own. The
  /// app always caps; the content gates search by bare depth, where a deep
  /// position can legitimately take minutes and must not be cut short.
  final Duration depthSearchTimeout;

  /// Stockfish's `Skill Level` for full strength (also its default).
  static const _fullSkill = 20;

  final List<_SearchJob> _queue = [];
  _SearchJob? _running;
  bool _pumping = false;
  bool _disposed = false;
  bool _suspended = false;
  Future<void>? _ready;

  int _appliedSkill = _fullSkill;
  int _appliedMultiPv = 1;
  int _appliedThreads = 0;

  /// Boots once. A boot that fails (no engine library, no `uciok` in time)
  /// is forgotten, so the next request boots from scratch instead of
  /// re-awaiting the same dead future for the rest of the session.
  Future<void> _ensureReady() => _ready ??= _boot().catchError(
        (Object error, StackTrace stack) {
          _ready = null;
          Error.throwWithStackTrace(error, stack);
        },
      );

  Future<void> _boot() async {
    await _transport.start();
    final uciok = _waitFor('uciok');
    _transport.send('uci');
    await uciok;
    _appliedSkill = _fullSkill;
    _appliedMultiPv = 1;
    _appliedThreads = threads;
    _transport.send('setoption name Threads value $threads');
    _transport.send('setoption name Hash value $hashMb');
    await _sync();
  }

  /// Sends `isready` and waits for `readyok`.
  Future<void> _sync() async {
    final readyok = _waitFor('readyok');
    _transport.send('isready');
    await readyok;
  }

  Future<void> _waitFor(String token) {
    final completer = Completer<void>();
    late final StreamSubscription<String> sub;
    sub = _transport.lines.listen((line) {
      if (line.trim() == token) {
        sub.cancel();
        completer.complete();
      }
    });
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      sub.cancel();
      throw TimeoutException('Engine did not answer "$token"');
    });
  }

  @override
  Future<EngineMove> analyse(
    String fen, {
    SearchLimit limit = const SearchLimit.movetime(300),
    EnginePriority priority = EnginePriority.interactive,
    CancellationToken? token,
    int multiPv = 1,
  }) {
    final EnginePosition position;
    try {
      position = EnginePosition.of(fen);
    } on EngineRejectedPosition catch (error, stack) {
      return Future.error(error, stack);
    }
    return _enqueue(_SearchJob(
      position: position,
      limit: limit,
      skillLevel: _fullSkill, // analysis is always full strength
      // Background analysis (recap/review/coach scans) runs single-threaded:
      // at 150-350ms movetimes the strength difference is negligible and the
      // thermal footprint halves. Interactive work keeps the full budget.
      threads: priority == EnginePriority.batch ? 1 : threads,
      priority: priority,
      token: token,
      multiPv: multiPv,
    ));
  }

  @override
  Future<EngineMove> bestMove(
    String startFen,
    List<String> moves,
    EngineStrength strength, {
    CancellationToken? token,
  }) {
    final EnginePosition position;
    try {
      position = EnginePosition.of(startFen, moves: moves);
    } on EngineRejectedPosition catch (error, stack) {
      return Future.error(error, stack);
    }
    final skill = strength.skillLevel;
    return _enqueue(_SearchJob(
      position: position,
      limit: strength.limit,
      skillLevel: skill ?? _fullSkill,
      // A handicapped reply is the main thread's pick alone — with Skill
      // enabled Stockfish never consults the other threads — so a helper
      // would only churn the hash. It also keeps a game at a handicapped
      // level from rebuilding the thread pool between replies and hints.
      threads: skill == null ? threads : 1,
      priority: EnginePriority.interactive,
      token: token,
    ));
  }

  @override
  Future<void> newGame() async {
    await _ensureReady();
    _transport.send('ucinewgame');
    await _sync();
  }

  Future<EngineMove> _enqueue(_SearchJob job) {
    if (_disposed) {
      return Future.error(StateError('Engine service is disposed'));
    }
    if (job.token?.isCancelled ?? false) {
      return Future.error(const EngineRequestCancelled());
    }
    _insert(job);
    // Preempt a running batch search so interactive work starts sooner —
    // unless the engine is held, when the running search is already being
    // stopped and nothing may start before resume().
    final running = _running;
    if (job.priority == EnginePriority.interactive &&
        !_suspended &&
        running != null &&
        running.priority == EnginePriority.batch &&
        !running.interrupted) {
      _transport.send('stop');
    }
    _pump();
    return job.future;
  }

  /// Queues [job]: interactive work ahead of batch work, and a [resumed]
  /// search back at the head of its own class. While queued, cancelling
  /// its token drops it at once rather than at its turn.
  void _insert(_SearchJob job, {bool resumed = false}) {
    final firstBatch =
        _queue.indexWhere((j) => j.priority == EnginePriority.batch);
    final batchStart = firstBatch == -1 ? _queue.length : firstBatch;
    _queue.insert(
      switch (job.priority) {
        EnginePriority.interactive => resumed ? 0 : batchStart,
        EnginePriority.batch => resumed ? batchStart : _queue.length,
      },
      job,
    );
    final token = job.token;
    if (token != null) {
      void drop() {
        if (_queue.remove(job)) job.fail(const EngineRequestCancelled());
      }

      job.dropWhenCancelled = drop;
      token.addListener(drop);
    }
  }

  _SearchJob _dequeue() {
    final job = _queue.removeAt(0);
    final drop = job.dropWhenCancelled;
    if (drop != null) job.token?.removeListener(drop);
    job.dropWhenCancelled = null;
    return job;
  }

  Future<void> _pump() async {
    if (_pumping || _disposed || _suspended || _queue.isEmpty) return;
    _pumping = true;
    try {
      try {
        await _ensureReady();
      } on Object catch (error, stack) {
        // A boot that failed while the app was in the background is the
        // OS's doing — it may freeze the process mid-handshake — so the work
        // is kept and the boot is retried on resume().
        if (_suspended) return;
        // Otherwise nothing queued may wait forever on an engine that never
        // came up — Play would show "thinking" until the app was killed.
        // Every waiting request learns why; the next request retries.
        while (_queue.isNotEmpty) {
          _dequeue().fail(error, stack);
        }
        return;
      }
      while (_queue.isNotEmpty && !_disposed && !_suspended) {
        final job = _dequeue();
        if (job.token?.isCancelled ?? false) {
          job.fail(const EngineRequestCancelled());
          continue;
        }
        _running = job;
        try {
          await _runSearch(job);
        } finally {
          _running = null;
        }
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _runSearch(_SearchJob job) async {
    final position = job.position;
    _applySkill(job.skillLevel);
    _applyMultiPv(job.multiPv);
    _applyThreads(job.threads);

    // Deepest line seen per MultiPV rank.
    final deepestByRank = <int, EngineLine>{};
    final bestMove = Completer<String>();
    final sub = _transport.lines.listen((line) {
      // Cheap prefix dispatch — most lines are chatter and never reach
      // a parser.
      if (line.startsWith('bestmove')) {
        final best = UciProtocol.parseBestMove(line);
        if (best != null && !bestMove.isCompleted) bestMove.complete(best);
        return;
      }
      if (!line.startsWith('info ')) return;
      final info = UciProtocol.parseInfo(line, position.sideToMove);
      if (info != null) deepestByRank[info.multiPv] = info;
    });

    void stopOnCancel() => _transport.send('stop');
    job.token?.addListener(stopOnCancel);

    _transport.send(position.command);
    _transport.send('go ${job.limit.uciGoArguments}');

    try {
      // `bestmove` is guaranteed after `go` (or after our `stop`); the
      // timeout is a hang backstop only.
      //
      // A capped search knows when it will finish, so the backstop is its
      // movetime plus slack. A bare DEPTH search does not — it used to
      // inherit a flat 60 s that looked like a movetime, so a deep search was
      // `stop`ped early and silently returned a shallower answer than the
      // caller asked for.
      final movetimeMs = job.limit.movetimeMs;
      final budget = movetimeMs != null
          ? Duration(milliseconds: movetimeMs + 10000)
          : depthSearchTimeout;
      final uci = await bestMove.future.timeout(
        budget,
        onTimeout: () {
          _transport.send('stop');
          return bestMove.future
              .timeout(const Duration(seconds: 5), onTimeout: () => '');
        },
      );
      if (job.token?.isCancelled ?? false) {
        job.fail(const EngineRequestCancelled());
      } else if (job.interrupted) {
        // Stopped by suspend(), not for an answer: its truncated result is
        // not what was asked for. Re-queued here, once its bestmove has been
        // consumed, so it runs again in full — never twice at once.
        job.interrupted = false;
        if (_disposed) {
          job.fail(const EngineRequestCancelled());
        } else {
          _insert(job, resumed: true);
        }
      } else {
        final ranks = deepestByRank.keys.toList()..sort();
        job.succeed(EngineMove(
          uci: uci.isEmpty ? null : uci,
          lines: [for (final rank in ranks) deepestByRank[rank]!],
        ));
      }
    } catch (e, st) {
      job.fail(e, st);
    } finally {
      job.token?.removeListener(stopOnCancel);
      await sub.cancel();
    }
  }

  void _applySkill(int level) {
    if (_appliedSkill == level) return;
    _transport.send('setoption name Skill Level value $level');
    _appliedSkill = level;
  }

  void _applyMultiPv(int multiPv) {
    final clamped = multiPv < 1 ? 1 : multiPv;
    if (_appliedMultiPv == clamped) return;
    _transport.send('setoption name MultiPV value $clamped');
    _appliedMultiPv = clamped;
  }

  /// Every change rebuilds Stockfish's thread pool and clears its hash, so
  /// it is only sent when the count actually differs.
  void _applyThreads(int count) {
    if (_appliedThreads == count) return;
    _transport.send('setoption name Threads value $count');
    _appliedThreads = count;
  }

  @override
  void suspend() {
    if (_suspended || _disposed) return;
    _suspended = true;
    final running = _running;
    if (running != null && !running.interrupted) {
      running.interrupted = true;
      _transport.send('stop');
    }
  }

  @override
  void resume() {
    if (!_suspended || _disposed) return;
    _suspended = false;
    _pump();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    while (_queue.isNotEmpty) {
      _dequeue().fail(const EngineRequestCancelled());
    }
    final running = _running;
    if (running != null) {
      running.fail(const EngineRequestCancelled());
      _transport.send('stop');
    }
    await _transport.dispose();
  }
}

class _SearchJob {
  _SearchJob({
    required this.position,
    required this.limit,
    required this.skillLevel,
    required this.threads,
    required this.priority,
    this.token,
    this.multiPv = 1,
  });

  final EnginePosition position;
  final SearchLimit limit;
  final int skillLevel;
  final int threads;
  final EnginePriority priority;
  final CancellationToken? token;
  final int multiPv;

  final Completer<EngineMove> _completer = Completer<EngineMove>();
  Future<EngineMove> get future => _completer.future;

  /// Set by [UciEngineService.suspend]: the search was stopped because the
  /// app left the foreground, not for an answer. Its result is discarded and
  /// it runs again after resume.
  bool interrupted = false;

  /// Registered on [token] while the job waits in the queue.
  void Function()? dropWhenCancelled;

  void succeed(EngineMove move) {
    if (!_completer.isCompleted) _completer.complete(move);
  }

  void fail(Object error, [StackTrace? stack]) {
    if (!_completer.isCompleted) _completer.completeError(error, stack);
  }
}
