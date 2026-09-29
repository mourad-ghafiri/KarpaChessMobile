import '../../../core/json/json_read.dart';
import 'chess_clock.dart';

/// A game in progress, as written to disk.
///
/// The line is UCI and nothing else — see [replayMoves]. The time control
/// rides along inside [clock] rather than being re-read from prefs on
/// restore, because the reader may well have changed it between sessions and
/// the game must come back on the clock it was actually played with.
class PracticeSession {
  const PracticeSession({
    required this.uciMoves,
    required this.playAs,
    required this.orientationIsWhite,
    required this.clock,
  });

  final List<String> uciMoves;

  /// 'w' | 'b' — the resolved side the user plays (never 'random').
  final String playAs;

  /// Which way the board was facing; the reader may have flipped it.
  final bool orientationIsWhite;

  final ClockSnapshot clock;

  Map<String, Object?> toJson() => {
        'uciMoves': uciMoves,
        'playAs': playAs,
        'orientationIsWhite': orientationIsWhite,
        'clock': clock.toJson(),
      };

  factory PracticeSession.fromJson(Map<String, Object?> json) =>
      PracticeSession(
        uciMoves: readStringList(json['uciMoves']),
        playAs: json['playAs'] == 'b' ? 'b' : 'w',
        orientationIsWhite: readBool(json['orientationIsWhite']) ?? true,
        clock: ClockSnapshot.fromJson(readStringMap(json['clock'])),
      );
}
