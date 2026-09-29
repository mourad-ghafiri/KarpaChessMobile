import 'dart:collection';

import '../../core/json/json_read.dart';

/// Where an unfinished lesson run stands, persisted so a card can show a
/// progress bar and reopening the lesson resumes where the learner left off.
/// The record lives only while the lesson is un-owned: completing the lesson
/// clears it (ownership supersedes progress).
class LessonProgress {
  LessonProgress({
    required this.beat,
    required this.beatCount,
    required Set<int> solvedBeats,
    required Set<int> awardedBeats,
  })  : solvedBeats = UnmodifiableSetView({...solvedBeats}),
        awardedBeats = UnmodifiableSetView({...awardedBeats});

  /// Furthest beat index the learner has entered — the resume point.
  final int beat;

  /// How many beats the lesson had when recorded. A mismatch with the
  /// current content means the lesson changed underneath the record, which
  /// is then discarded rather than resumed into the wrong beat.
  final int beatCount;

  /// Beat indices completed, so a resumed run re-enters them solved.
  final Set<int> solvedBeats;

  /// Beat indices whose XP already minted, so a resumed run cannot re-mint.
  final Set<int> awardedBeats;

  /// The same fraction the player's header bar shows for this beat.
  double get completion => beatCount == 0 ? 0 : (beat + 1) / beatCount;

  @override
  bool operator ==(Object other) =>
      other is LessonProgress &&
      other.beat == beat &&
      other.beatCount == beatCount &&
      other.solvedBeats.length == solvedBeats.length &&
      other.solvedBeats.containsAll(solvedBeats) &&
      other.awardedBeats.length == awardedBeats.length &&
      other.awardedBeats.containsAll(awardedBeats);

  @override
  int get hashCode => Object.hash(
      beat, beatCount, solvedBeats.length, awardedBeats.length);

  Map<String, Object?> toJson() => {
        'b': beat,
        'n': beatCount,
        's': solvedBeats.toList()..sort(),
        'a': awardedBeats.toList()..sort(),
      };

  /// Tolerant: a wrong-typed field reads as absent (see `json_read.dart`).
  factory LessonProgress.fromJson(Map<String, Object?> json) => LessonProgress(
        beat: readInt(json['b']) ?? 0,
        beatCount: readInt(json['n']) ?? 0,
        solvedBeats: readIntSet(json['s']),
        awardedBeats: readIntSet(json['a']),
      );
}
