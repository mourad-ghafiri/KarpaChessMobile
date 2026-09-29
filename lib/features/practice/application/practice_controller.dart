import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sound_providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/haptics/haptics.dart';
import '../../../engine/application/engine_providers.dart';
import '../../../engine/domain/engine_models.dart';
import '../../../prefs/application/prefs_controller.dart' as prefs_;
import '../data/practice_store.dart';
import '../domain/chess_clock.dart';
import '../domain/practice_models.dart';
import '../domain/practice_session.dart';

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeState>(PracticeController.new);

/// Where the Play tab is in its own lifecycle.
///
/// This belongs to the controller rather than to the screen: it used to be a
/// `bool` inside `_PlayScreenState`, which a rotation destroyed (the shell
/// rebuilds the tab subtree when it switches between the bottom bar and the
/// rail) and which no restart could ever restore.
enum PracticeStatus {
  /// Asking the store whether a game was left behind. The screen shows
  /// neither setup nor board until this settles, so a restored game never
  /// flashes past the setup screen.
  restoring,

  /// No game: the setup screen.
  idle,

  /// A game exists. `result != null` means it is over but still on screen.
  active,
}

class PracticeState {
  const PracticeState({
    required this.position,
    this.moves = const [],
    this.playAs = 'w',
    this.orientation = Side.white,
    this.result,
    this.engineThinking = false,
    this.whiteMs = 0,
    this.blackMs = 0,
    this.timedGame = false,
    this.status = PracticeStatus.restoring,
  });

  final Chess position;
  final List<PlayedMove> moves;

  /// 'w' | 'b' — resolved side the user plays this game.
  final String playAs;
  final Side orientation;
  final GameResult? result;
  final bool engineThinking;

  /// Clock display values: remaining ms in a timed game, accumulated
  /// thinking ms in an unlimited one. [timedGame] says which way to read
  /// them (and which icon the card shows).
  final int whiteMs;
  final int blackMs;
  final bool timedGame;

  final PracticeStatus status;

  /// Whether the board — rather than the setup screen — should be on show.
  bool get hasGame => status == PracticeStatus.active;

  NormalMove? get lastMove => moves.isNotEmpty ? moves.last.move : null;

  String get turn => position.turn == Side.white ? 'w' : 'b';

  bool get isUserTurn => result == null && turn == playAs && !engineThinking;

  bool get userWon => result?.winner != null && result!.winner == playAs;
  bool get userLost => result?.winner != null && result!.winner != playAs;

  PracticeState copyWith({
    Chess? position,
    List<PlayedMove>? moves,
    String? playAs,
    Side? orientation,
    GameResult? Function()? result,
    bool? engineThinking,
    int? whiteMs,
    int? blackMs,
    bool? timedGame,
    PracticeStatus? status,
  }) {
    return PracticeState(
      position: position ?? this.position,
      moves: moves ?? this.moves,
      playAs: playAs ?? this.playAs,
      orientation: orientation ?? this.orientation,
      result: result != null ? result() : this.result,
      engineThinking: engineThinking ?? this.engineThinking,
      whiteMs: whiteMs ?? this.whiteMs,
      blackMs: blackMs ?? this.blackMs,
      timedGame: timedGame ?? this.timedGame,
      status: status ?? this.status,
    );
  }

  /// Field-identity equality so no-op `copyWith` emissions don't notify
  /// watchers (position/moves are replaced, never mutated, so identity is
  /// exact change detection).
  @override
  bool operator ==(Object other) =>
      other is PracticeState &&
      identical(other.position, position) &&
      identical(other.moves, moves) &&
      other.playAs == playAs &&
      other.orientation == orientation &&
      identical(other.result, result) &&
      other.engineThinking == engineThinking &&
      other.whiteMs == whiteMs &&
      other.blackMs == blackMs &&
      other.timedGame == timedGame &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
    identityHashCode(position),
    identityHashCode(moves),
    playAs,
    orientation,
    engineThinking,
    whiteMs,
    blackMs,
    timedGame,
    status,
  );
}

/// Orchestrates the practice game: user moves, Stockfish replies, clock and
/// game-over handling. Coaching is not its concern — the hint surface asks
/// the coach directly.
class PracticeController extends Notifier<PracticeState> {
  final _random = Random();
  ChessClock? _clock;
  Timer? _clockTimer;
  CancellationToken _gameToken = CancellationToken();
  int _generation = 0;
  Completer<void> _restored = Completer<void>();

  /// Completes once the initial restore attempt has finished.
  @visibleForTesting
  Future<void> get restored => _restored.future;

  @override
  PracticeState build() {
    _restored = Completer<void>();
    ref.onDispose(() {
      _clockTimer?.cancel();
      _gameToken.cancel();
    });
    Future.microtask(_restore);
    return PracticeState(position: Chess.initial);
  }

  /// Riverpod's default is identity — use the state's field equality so
  /// no-op copies don't fan out rebuilds.
  @override
  bool updateShouldNotify(PracticeState previous, PracticeState next) =>
      previous != next;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// The whole-second value the clock UI renders (null = unlimited).
  static int _shownSeconds(int ms) => (ms / 1000).ceil();

  // ============ Game lifecycle ============

  void newGame() {
    _generation++;
    _gameToken.cancel();
    _gameToken = CancellationToken();
    _clockTimer?.cancel();

    final prefs = ref.read(prefs_.prefsControllerProvider);
    final playAs = switch (prefs.playAs) {
      'b' => 'b',
      'w' => 'w',
      _ => _random.nextBool() ? 'w' : 'b',
    };

    final minutes = prefs.timeControlMinutes;
    _clock = ChessClock(
      initialMs: minutes == null ? null : minutes * 60000,
      incrementMs: prefs.timeControlIncrement * 1000,
    );

    ref.read(engineServiceProvider).newGame();

    state = PracticeState(
      position: Chess.initial,
      playAs: playAs,
      orientation: playAs == 'b' ? Side.black : Side.white,
      whiteMs: minutes == null ? 0 : minutes * 60000,
      blackMs: minutes == null ? 0 : minutes * 60000,
      timedGame: minutes != null,
      status: PracticeStatus.active,
    );

    if (playAs == 'b') {
      _scheduleEngineMove(delayMs: 500);
    }
    // Unlimited games run the clock too — counting thinking time up instead
    // of remaining time down — under the same tick and pause contracts.
    _clock!.start('w', _now);
    _scheduleClockTick();
    _persist();
  }

  /// Drops the game in progress without a result and returns to the setup
  /// screen: stops the clock and all engine work, and forgets the save so a
  /// restart does not bring it back. The old game must not keep ticking
  /// toward a phantom timeout.
  void abandon() {
    _clockTimer?.cancel();
    _clock?.stop();
    _clock = null;
    _gameToken.cancel();
    _gameToken = CancellationToken();
    unawaited(ref.read(practiceStoreProvider).clear());
    state = PracticeState(position: Chess.initial, status: PracticeStatus.idle);
  }

  /// Freezes the clock (app backgrounded). Battery contract: no timers run
  /// while the app is hidden or drawing mode owns the board.
  void pauseClock() {
    if (_clock?.runningSide == null) return;
    _clockTimer?.cancel();
    _clock!.pause(_now);
    // The clock has moved since the last ply, and backgrounding is the last
    // moment we are told about before the app may be killed.
    _persist();
  }

  /// Resumes a clock frozen by [pauseClock].
  void resumeClock() {
    final clock = _clock;
    if (clock == null || !clock.isPaused || state.result != null) return;
    clock.resume(_now);
    _scheduleClockTick();
  }

  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation == Side.white ? Side.black : Side.white,
    );
    _persist();
  }

  /// Undo the user's last move (two plies when the engine already replied).
  void undo() {
    if (state.moves.isEmpty) return;
    var moves = List.of(state.moves);
    var undone = moves.removeLast();
    if (moves.isNotEmpty && undone.moverColor != state.playAs) {
      undone = moves.removeLast();
    }
    final position = Chess.fromSetup(Setup.parseFen(undone.fenBefore));
    state = state.copyWith(
      position: position,
      moves: moves,
      result: () => null,
    );
    _clock?.start(position.turn == Side.white ? 'w' : 'b', _now);
    // Without this a restart would resurrect the move just taken back.
    _persist();
  }

  // ============ Moves ============

  /// A move chosen by the user on the board (promotion already resolved).
  void userMove(NormalMove move) {
    if (!state.isUserTurn) return;
    _commit(move);
    if (state.result == null && state.turn != state.playAs) {
      _scheduleEngineMove(delayMs: 180);
    }
  }

  void _commit(NormalMove move) {
    final built = PlayedMove.build(state.position, move);
    if (built == null) return;
    final (played, chess) = built;
    final moverColor = played.moverColor;
    final captured = played.captured;

    if (played.isCastle) {
      ref.playSound(AppSound.castle);
    } else if (move.promotion != null) {
      ref.playSound(AppSound.promote);
    } else if (captured != null) {
      ref.playSound(AppSound.capture);
    } else {
      ref.playSound(AppSound.move);
    }

    // The single haptic source for moves: a light tick when the user's
    // own move commits, a medium thud when it captures.
    if (moverColor == state.playAs) {
      captured != null ? ref.hapticMedium() : ref.hapticLight();
    }

    // A restored game comes back frozen; the first move of either side is
    // what starts it running again.
    resumeClock();
    _clock?.onMoveCompleted(moverColor, _now);
    // Re-arm the adaptive cadence for the side now on the move.
    _scheduleClockTick();

    final moves = [...state.moves, played];
    final result = terminalResult(chess, moves);
    state = state.copyWith(
      position: chess,
      moves: moves,
      result: () => result,
      whiteMs: _clock?.whiteMs,
      blackMs: _clock?.blackMs,
    );

    if (result != null) {
      _onGameOver(result);
    } else {
      if (chess.isCheck) ref.playSound(AppSound.check);
      _persist();
    }
  }

  void _scheduleEngineMove({required int delayMs}) {
    final generation = _generation;
    final token = _gameToken;
    // Read once, so the pause and the search agree on the level.
    final strength = EngineStrength.fromLevel(
      ref.read(prefs_.prefsControllerProvider).difficulty,
    );
    state = state.copyWith(engineThinking: true);
    Future<void>.delayed(
        Duration(milliseconds: delayMs) + replyPace(strength), () async {
      if (generation != _generation || state.result != null) return;
      try {
        // The whole game, not just the board: Stockfish sees repetitions
        // only through the moves that led here.
        final reply = await ref.read(engineServiceProvider).bestMove(
          kInitialFEN,
          [for (final m in state.moves) m.move.uci],
          strength,
          token: token,
        );
        if (generation != _generation || reply.uci == null) return;
        final move = NormalMove.fromUci(reply.uci!);
        if (!state.position.isLegal(move)) return;
        _commit(move);
      } on EngineRequestCancelled {
        // superseded by a new game — nothing to do
      } finally {
        if (generation == _generation) {
          state = state.copyWith(engineThinking: false);
        }
      }
    });
  }

  // ============ Clock ============

  /// One-shot adaptive cadence: 1s ticks normally (the UI renders whole
  /// seconds), tightening to 200ms under ten seconds so flagging stays
  /// sharp. The clock itself is epoch-anchored, so accuracy never depends
  /// on tick frequency.
  void _scheduleClockTick() {
    _clockTimer?.cancel();
    final clock = _clock;
    final side = clock?.runningSide;
    if (clock == null || side == null) return;
    final remaining = clock.msFor(side);
    // The 200ms flag-sharpness tier only matters when a flag exists.
    _clockTimer = Timer(
      Duration(
        milliseconds: !clock.isUnlimited && remaining <= 10000 ? 200 : 1000,
      ),
      _onClockTick,
    );
  }

  void _onClockTick() {
    final clock = _clock;
    if (clock == null || clock.runningSide == null) return;
    final shownBefore = (
      _shownSeconds(state.whiteMs),
      _shownSeconds(state.blackMs),
    );
    final flagged = clock.tick(_now);
    // Emit only when the rendered whole-second value actually changed —
    // identical frames are not worth a rebuild.
    if (shownBefore !=
        (_shownSeconds(clock.whiteMs), _shownSeconds(clock.blackMs))) {
      state = state.copyWith(
        whiteMs: clock.whiteMs,
        blackMs: clock.blackMs,
      );
    }
    _scheduleClockTick();
    if (flagged != null && state.result == null) {
      final result = GameResult(
        GameResultKind.timeout,
        winner: flagged == 'w' ? 'b' : 'w',
      );
      state = state.copyWith(result: () => result);
      _gameToken.cancel();
      _gameToken = CancellationToken();
      _onGameOver(result);
    }
  }

  void _onGameOver(GameResult result) {
    _clockTimer?.cancel();
    _clock?.stop();
    // Only games still in progress are worth restoring; a finished one is
    // forgotten so the next launch opens on a fresh setup screen. It stays
    // on screen for this session, so Review is still reachable.
    unawaited(ref.read(practiceStoreProvider).clear());
    switch (result.kind) {
      case GameResultKind.checkmate || GameResultKind.timeout:
        if (state.userWon) {
          ref.playSound(AppSound.win);
        } else if (state.userLost) {
          ref.playSound(AppSound.lose);
        }
      case GameResultKind.stalemate:
        ref.playSound(AppSound.bad);
      case GameResultKind.draw50 ||
            GameResultKind.drawMaterial ||
            GameResultKind.repetition:
        break;
    }
  }

  // ============ Persistence ============

  /// Writes the game in progress. Fire-and-forget, like the studio's
  /// `_persist` — a save must never make a move wait.
  void _persist() {
    final clock = _clock;
    if (state.status != PracticeStatus.active || state.result != null) return;
    unawaited(
      ref
          .read(practiceStoreProvider)
          .save(
            PracticeSession(
              uciMoves: [for (final m in state.moves) m.move.uci],
              playAs: state.playAs,
              orientationIsWhite: state.orientation == Side.white,
              // The clock's own fields, not the display echoes: those only refresh
              // when the rendered second changes.
              clock:
                  clock?.snapshot() ??
                  const ClockSnapshot(incrementMs: 0, whiteMs: 0, blackMs: 0),
            ),
          ),
    );
  }

  void _markRestored() {
    if (!_restored.isCompleted) _restored.complete();
  }

  /// Brings back the game the reader left, frozen. Runs once, from [build];
  /// nothing here starts a clock — the first move does that.
  ///
  /// The disk read is a microtask, so the reader can reach the setup screen
  /// and start a game before it answers. [PracticeStatus.restoring] is the
  /// interlock: restore may only ever move the status *out of* it, so a
  /// restore that lost the race retires rather than replacing the game now
  /// being played.
  Future<void> _restore() async {
    PracticeSession? session;
    try {
      session = await ref.read(practiceStoreProvider).load();
    } catch (_) {
      session = null; // Unreadable session — open on the setup screen.
    }
    if (state.status != PracticeStatus.restoring) {
      _markRestored();
      return;
    }

    final (position, moves) = session == null
        ? (Chess.initial, const <PlayedMove>[])
        : replayMoves(session.uciMoves);
    if (session == null || moves.isEmpty) {
      state = state.copyWith(status: PracticeStatus.idle);
      _markRestored();
      return;
    }

    final clock = ChessClock.fromSnapshot(session.clock);
    _clock = clock;
    state = PracticeState(
      position: position,
      moves: moves,
      playAs: session.playAs,
      orientation: session.orientationIsWhite ? Side.white : Side.black,
      whiteMs: clock.whiteMs,
      blackMs: clock.blackMs,
      timedGame: !clock.isUnlimited,
      status: PracticeStatus.active,
    );
    // Closed on Stockfish's turn: pick the search back up, otherwise the
    // game comes back to a position nobody is going to move from.
    if (state.turn != state.playAs && terminalResult(position, moves) == null) {
      _scheduleEngineMove(delayMs: 500);
    }
    _markRestored();
  }
}
