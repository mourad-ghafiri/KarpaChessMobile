/// Evaluation from White's perspective. Exactly one of [cp] or [mateIn] is
/// set. [mateIn] > 0 means White mates in that many moves; < 0 means Black.
class EvalScore {
  const EvalScore.cp(int this.cp) : mateIn = null;
  const EvalScore.mate(int this.mateIn) : cp = null;

  final int? cp;
  final int? mateIn;

  /// Collapses mate scores onto the centipawn axis so deltas are computable:
  /// a mate in n maps to ±(100000 - n).
  int get asCp {
    final mate = mateIn;
    if (mate == null) return cp!;
    return mate > 0 ? 100000 - mate : -100000 - mate;
  }

  /// The same score seen from the mover's side ('w' or 'b').
  int cpFor(String color) => color == 'w' ? asCp : -asCp;

  EvalScore get negated => mateIn != null
      ? EvalScore.mate(-mateIn!)
      : EvalScore.cp(-cp!);

  @override
  String toString() => mateIn != null ? '#$mateIn' : '${cp}cp';
}

/// One `info` line of a running search: principal variation at some depth.
class EngineLine {
  const EngineLine({
    required this.depth,
    required this.score,
    required this.pvUci,
    this.multiPv = 1,
  });

  final int depth;

  /// Normalized to White's perspective.
  final EvalScore score;

  /// Principal variation as UCI moves ('e2e4', 'e7e8q', ...).
  final List<String> pvUci;

  /// 1-based candidate rank when searching with MultiPV (1 = best line).
  final int multiPv;
}

/// Final result of a search.
class EngineMove {
  const EngineMove({this.uci, this.lines = const []});

  /// Best move in UCI notation; null when the position is terminal
  /// (engine replied `bestmove (none)`).
  final String? uci;

  /// Deepest line per MultiPV rank, best first. Single-PV searches carry
  /// exactly one entry.
  final List<EngineLine> lines;

  /// The principal (best) line.
  EngineLine? get line => lines.isNotEmpty ? lines.first : null;

  EvalScore? get score => line?.score;
}

/// How long/deep to search: a movetime, or a depth with an optional movetime
/// cap. Stockfish stops at whichever limit it reaches first.
class SearchLimit {
  const SearchLimit.movetime(int this.movetimeMs) : depth = null;
  const SearchLimit.depth(int this.depth, {this.movetimeMs});

  final int? movetimeMs;
  final int? depth;

  String get uciGoArguments => [
        if (depth != null) 'depth $depth',
        if (movetimeMs != null) 'movetime $movetimeMs',
      ].join(' ');
}

/// The four practice difficulty levels.
///
/// The three handicapped levels are Stockfish `Skill Level`s — one scale, so
/// the ladder is monotonic by construction. (Club used to be `UCI_Elo 1700`,
/// which Stockfish maps to skill ≈2.8: weaker than Casual's skill 4.) On
/// Stockfish's own Elo scale 0 · 2 · 4 are ≈1350 · 1570 · 1950.
enum EngineStrength {
  beginner(1, skillLevel: 0),
  casual(2, skillLevel: 2),
  club(3, skillLevel: 4),
  master(4);

  const EngineStrength(this.level, {this.skillLevel});

  /// 1..4, matching the persisted difficulty pref.
  final int level;

  /// Stockfish `Skill Level` (0-20); null plays at full strength.
  final int? skillLevel;

  /// How a reply at this strength is searched.
  ///
  /// A handicapped Stockfish picks its weakened move once, when the search
  /// completes depth `1 + level` (`search.h` `Skill::time_to_pick`), and
  /// every deeper iteration is discarded. So the search stops exactly there —
  /// the same pick at a fraction of the CPU — with a time cap for slow
  /// devices. Full strength searches by time.
  SearchLimit get limit {
    final skill = skillLevel;
    return skill == null
        ? const SearchLimit.movetime(1200)
        : SearchLimit.depth(1 + skill, movetimeMs: 1000);
  }

  static EngineStrength fromLevel(int level) => EngineStrength.values
      .firstWhere((s) => s.level == level, orElse: () => EngineStrength.beginner);
}

/// Scheduling class for engine requests: [interactive] requests preempt
/// running [batch] searches and jump the queue.
enum EnginePriority { interactive, batch }

/// Cooperative cancellation for queued/running engine requests.
class CancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  /// [listener] runs on cancel — immediately if already cancelled.
  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);
}

/// Thrown into a request's future when its token is cancelled, or when the
/// engine service is disposed with the request still pending.
class EngineRequestCancelled implements Exception {
  const EngineRequestCancelled();

  @override
  String toString() => 'EngineRequestCancelled';
}

/// Thrown into a request's future when Stockfish would refuse its position —
/// see `EnginePosition`. Such a request never reaches the engine.
class EngineRejectedPosition implements Exception {
  const EngineRejectedPosition(this.reason);

  /// What Stockfish would object to, for diagnostics.
  final String reason;

  @override
  String toString() => 'EngineRejectedPosition: $reason';
}
