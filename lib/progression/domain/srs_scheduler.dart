import '../../core/json/json_read.dart';

/// Spaced-repetition scheduling for owned patterns — the engine of the
/// Sharpen loop. Fixed expanding intervals (evidence-based spacing without
/// per-item tuning): 1, 3, 7 and 21 days. Each successful spaced review
/// raises the pattern's star (0 → bronze 1 → silver 2 → gold 3);
/// a failed review drops one interval and keeps the pattern due tomorrow.
class SrsScheduler {
  const SrsScheduler._();

  static const intervalsDays = [1, 3, 7, 21];

  static const maxStars = 3;

  /// A freshly owned pattern: due tomorrow, no stars yet.
  static PatternMastery mint(int today) => PatternMastery(
        intervalIndex: 0,
        dueDay: today + intervalsDays.first,
      );

  static PatternMastery reviewSuccess(PatternMastery m, int today) {
    final nextIndex =
        (m.intervalIndex + 1).clamp(0, intervalsDays.length - 1);
    return PatternMastery(
      intervalIndex: nextIndex,
      dueDay: today + intervalsDays[nextIndex],
    );
  }

  static PatternMastery reviewFail(PatternMastery m, int today) {
    final nextIndex = (m.intervalIndex - 1).clamp(0, intervalsDays.length - 1);
    return PatternMastery(
      intervalIndex: nextIndex,
      dueDay: today + 1,
    );
  }
}

/// Mastery record for one owned pattern. Days are epoch days
/// (`DateTime.millisecondsSinceEpoch ~/ 86400000` of local midnight — see
/// [PatternMastery.epochDay]).
class PatternMastery {
  const PatternMastery({required this.intervalIndex, required this.dueDay});

  final int intervalIndex;
  final int dueDay;

  @override
  bool operator ==(Object other) =>
      other is PatternMastery &&
      other.intervalIndex == intervalIndex &&
      other.dueDay == dueDay;

  @override
  int get hashCode => Object.hash(intervalIndex, dueDay);

  /// 0 (just owned) → 3 (gold): one star per successful spaced review.
  int get stars => intervalIndex.clamp(0, SrsScheduler.maxStars);

  bool isDue(int today) => today >= dueDay;

  /// Visual dullness 0 (crisp) → 1 (fully dull), driven by how far past
  /// due the pattern is relative to its interval.
  double dullness(int today) {
    if (today < dueDay) return 0;
    final interval = SrsScheduler.intervalsDays[intervalIndex];
    return ((today - dueDay + 1) / interval).clamp(0.0, 1.0);
  }

  /// Local calendar day number for SRS math (timezone-stable per device).
  static int epochDay(DateTime time) {
    final local = time.toLocal();
    final midnight = DateTime(local.year, local.month, local.day);
    return midnight.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  Map<String, Object?> toJson() => {'i': intervalIndex, 'd': dueDay};

  /// Tolerant: a wrong-typed field reads as absent (see `json_read.dart`).
  factory PatternMastery.fromJson(Map<String, Object?> json) => PatternMastery(
        intervalIndex: readInt(json['i']) ?? 0,
        dueDay: readInt(json['d']) ?? 0,
      );
}
