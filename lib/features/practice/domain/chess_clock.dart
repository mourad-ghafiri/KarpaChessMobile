import '../../../core/json/json_read.dart';

/// Everything a clock needs to come back exactly as it was left.
///
/// The wall-clock anchor is deliberately absent: a game reopened tomorrow
/// resumes on the time it had when the app closed, never charged for the
/// hours in between.
class ClockSnapshot {
  const ClockSnapshot({
    this.initialMs,
    required this.incrementMs,
    required this.whiteMs,
    required this.blackMs,
    this.side,
  });

  final int? initialMs;
  final int incrementMs;
  final int whiteMs;
  final int blackMs;

  /// Whose clock was counting — running or merely paused. Null once the
  /// game is over or before the first move.
  final String? side;

  Map<String, Object?> toJson() => {
        'initialMs': initialMs,
        'incrementMs': incrementMs,
        'whiteMs': whiteMs,
        'blackMs': blackMs,
        'side': side,
      };

  factory ClockSnapshot.fromJson(Map<String, Object?> json) => ClockSnapshot(
        initialMs: readInt(json['initialMs']),
        incrementMs: readInt(json['incrementMs']) ?? 0,
        whiteMs: readInt(json['whiteMs']) ?? 0,
        blackMs: readInt(json['blackMs']) ?? 0,
        side: readString(json['side']),
      );
}

/// Pure, tick-driven chess clock with Fischer increment.
///
/// Time is injected (epoch ms) so
/// the class is fully unit-testable; the controller drives it with a Timer.
///
/// Timed games count DOWN toward a flag. Unlimited games count UP: the same
/// two fields then hold each side's accumulated thinking time, so the player
/// card always has a number, the snapshot machinery serialises it for free,
/// and the no-wall-anchor restore contract gains a second meaning — an
/// untimed game reopened tomorrow resumes on the thinking time it had, never
/// charged for the hours in between.
class ChessClock {
  ChessClock({this.initialMs, this.incrementMs = 0})
      : whiteMs = initialMs ?? 0,
        blackMs = initialMs ?? 0;

  /// Rebuilds a clock from [snapshot], **paused** on the side that was
  /// counting. It resumes on the next move rather than the moment the app
  /// reopens, so no time drains while the reader finds their place.
  ChessClock.fromSnapshot(ClockSnapshot snapshot)
      : initialMs = snapshot.initialMs,
        incrementMs = snapshot.incrementMs,
        whiteMs = snapshot.whiteMs,
        blackMs = snapshot.blackMs,
        _pausedSide = snapshot.side;

  /// null means unlimited: [whiteMs]/[blackMs] count elapsed thinking time
  /// upward instead of remaining time downward, and nobody ever flags.
  final int? initialMs;
  final int incrementMs;

  int whiteMs;
  int blackMs;

  /// 'w' | 'b' | null (paused).
  String? runningSide;
  int? _lastTickMs;

  bool get isUnlimited => initialMs == null;

  int msFor(String side) => side == 'w' ? whiteMs : blackMs;

  /// Starts (or resumes) counting [side]'s time from [nowMs] — down when
  /// timed, up when unlimited.
  void start(String side, int nowMs) {
    runningSide = side;
    _lastTickMs = nowMs;
  }

  void stop() {
    runningSide = null;
    _lastTickMs = null;
    _pausedSide = null;
  }

  String? _pausedSide;

  bool get isPaused => _pausedSide != null;

  /// The side the clock belongs to right now, whether it is counting or
  /// frozen. Persistence must ask for this rather than read [runningSide],
  /// which is null the moment the clock is paused.
  String? get heldSide => runningSide ?? _pausedSide;

  /// The state to write to disk. Reads the clock's own millisecond fields,
  /// never the controller's display echoes — those only refresh when the
  /// rendered second changes, so they can be a full second stale.
  ClockSnapshot snapshot() => ClockSnapshot(
        initialMs: initialMs,
        incrementMs: incrementMs,
        whiteMs: whiteMs,
        blackMs: blackMs,
        side: heldSide,
      );

  /// Freezes the countdown, remembering whose clock was running.
  void pause(int nowMs) {
    final side = runningSide;
    if (side == null) return;
    tick(nowMs);
    _pausedSide = runningSide; // may be null if the final tick flagged
    runningSide = null;
    _lastTickMs = null;
  }

  /// Resumes the side paused by [pause]; no-op if not paused.
  void resume(int nowMs) {
    final side = _pausedSide;
    _pausedSide = null;
    if (side != null) start(side, nowMs);
  }

  /// Advances the running side's count. Returns the side that flagged
  /// ('w'/'b') or null. Once a side flags the clock stops; an unlimited
  /// clock accumulates elapsed time and can never flag.
  String? tick(int nowMs) {
    final side = runningSide;
    final last = _lastTickMs;
    if (side == null || last == null) return null;
    final elapsed = nowMs - last;
    _lastTickMs = nowMs;
    if (isUnlimited) {
      if (side == 'w') {
        whiteMs += elapsed;
      } else {
        blackMs += elapsed;
      }
      return null;
    }
    if (side == 'w') {
      whiteMs -= elapsed;
      if (whiteMs <= 0) {
        whiteMs = 0;
        stop();
        return 'w';
      }
    } else {
      blackMs -= elapsed;
      if (blackMs <= 0) {
        blackMs = 0;
        stop();
        return 'b';
      }
    }
    return null;
  }

  /// The mover completed a move: credit their increment (timed games only)
  /// and hand the clock to the other side. No-op when stopped.
  void onMoveCompleted(String moverSide, int nowMs) {
    if (runningSide == null) return;
    tick(nowMs);
    if (runningSide == null) return; // flagged during the final tick
    if (!isUnlimited) {
      if (moverSide == 'w') {
        whiteMs += incrementMs;
      } else {
        blackMs += incrementMs;
      }
    }
    start(moverSide == 'w' ? 'b' : 'w', nowMs);
  }
}
