import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/application/engine_providers.dart';
import '../../../engine/domain/engine_models.dart';
import '../../../engine/domain/move_classifier.dart';
import '../../practice/application/practice_controller.dart';
import '../../practice/domain/practice_models.dart';

/// One analyzed ply of the finished practice game.
class ReviewedMove {
  const ReviewedMove({
    required this.index,
    required this.played,
    required this.isUserTurn,
    this.quality,
    this.bestSan,
    this.bestMove,
    this.deltaCp = 0,
    this.evalBeforeCp,
    this.evalAfterCp,
  });

  final int index;
  final PlayedMove played;
  final bool isUserTurn;

  /// null for engine plies (not classified).
  final MoveQuality? quality;
  final String? bestSan;
  final NormalMove? bestMove;
  final int deltaCp;

  /// White-perspective evals of the positions before/after this ply,
  /// retained from the batch searches (mate scores cp-collapsed). Null
  /// until analyzed or when the search returned no score.
  final int? evalBeforeCp;
  final int? evalAfterCp;

  /// The review label key for this quality: 'good'/'ok' correspond to the
  /// best/good tiers.
  String? get labelKey => switch (quality) {
        MoveQuality.brilliant || MoveQuality.best => 'good',
        MoveQuality.good => 'ok',
        MoveQuality.inaccuracy => 'inaccuracy',
        MoveQuality.mistake => 'mistake',
        MoveQuality.blunder => 'blunder',
        null => null,
      };
}

class ReviewState {
  const ReviewState({
    this.moves = const [],
    this.analyzedCount = 0,
    this.totalCount = 0,
    this.running = false,
    this.done = false,
    this.selectedIndex,
    this.startFen = kInitialFEN,
    this.orientation = Side.white,
  });

  final List<ReviewedMove> moves;
  final int analyzedCount;
  final int totalCount;
  final bool running;
  final bool done;
  final int? selectedIndex;

  /// The position the game started from — the board before move 1.
  final String startFen;

  /// The side the user played, so the board faces them.
  final Side orientation;

  ReviewedMove? get selected =>
      selectedIndex != null ? moves[selectedIndex!] : null;

  /// The FEN the board shows: the start position until a ply is selected,
  /// then the position AFTER that ply — studio semantics, so the quality badge
  /// rides on the piece that just moved.
  ///
  /// This used to be a conditional in the screen whose "no ply selected" arm
  /// read the *practice* controller's current position. Practice keeps the
  /// finished game loaded until a new one starts, so its current position is
  /// the LAST one — the first stop of the scrubber showed the end of the game.
  /// Review carries its own start now and asks practice nothing.
  String get boardFen {
    final index = selectedIndex;
    return index == null ? startFen : moves[index].played.fenAfter;
  }

  /// Tally of the user's classified moves keyed by the web label keys.
  Map<String, int> get tallies {
    final counts = {'good': 0, 'ok': 0, 'inaccuracy': 0, 'mistake': 0, 'blunder': 0};
    for (final m in moves) {
      final key = m.labelKey;
      if (m.isUserTurn && key != null) counts[key] = counts[key]! + 1;
    }
    return counts;
  }

  /// Field-wise equality with identity for [moves] — the list is replaced,
  /// never mutated, so identity is exact change detection and `.select`
  /// guards actually short-circuit (the performance contract every state
  /// class in the app carries).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewState &&
          identical(other.moves, moves) &&
          other.analyzedCount == analyzedCount &&
          other.totalCount == totalCount &&
          other.running == running &&
          other.done == done &&
          other.selectedIndex == selectedIndex &&
          other.startFen == startFen &&
          other.orientation == orientation;

  @override
  int get hashCode => Object.hash(identityHashCode(moves), analyzedCount,
      totalCount, running, done, selectedIndex, startFen, orientation);

  ReviewState copyWith({
    List<ReviewedMove>? moves,
    int? analyzedCount,
    int? totalCount,
    bool? running,
    bool? done,
    int? Function()? selectedIndex,
  }) {
    return ReviewState(
      moves: moves ?? this.moves,
      analyzedCount: analyzedCount ?? this.analyzedCount,
      totalCount: totalCount ?? this.totalCount,
      running: running ?? this.running,
      done: done ?? this.done,
      selectedIndex:
          selectedIndex != null ? selectedIndex() : this.selectedIndex,
      startFen: startFen,
      orientation: orientation,
    );
  }
}

final reviewControllerProvider =
    NotifierProvider.autoDispose<ReviewController, ReviewState>(
        ReviewController.new);

/// Batch-analyzes the finished practice game and classifies every user ply
/// against Stockfish's preference, with one engine search per position
/// instead of two per ply. Auto-disposed:
/// the batch lives exactly as long as the review screen watches it.
class ReviewController extends AutoDisposeNotifier<ReviewState> {
  CancellationToken? _token;
  int _generation = 0;

  @override
  bool updateShouldNotify(ReviewState previous, ReviewState next) =>
      previous != next;

  @override
  ReviewState build() {
    ref.onDispose(() => _token?.cancel());
    return const ReviewState();
  }

  /// Stops the in-flight batch (screen pop): later results are dropped and
  /// no further state is written. Safe to call repeatedly.
  void cancel() {
    _generation++;
    _token?.cancel();
  }

  /// (Re)runs the analysis over the current practice game.
  Future<void> start() async {
    _generation++;
    final generation = _generation;
    _token?.cancel();
    final token = _token = CancellationToken();

    final practice = ref.read(practiceControllerProvider);
    final moves = practice.moves;
    final playAs = practice.playAs;
    final engine = ref.read(engineServiceProvider);

    state = ReviewState(
      totalCount: moves.length,
      running: true,
      // Derived from the game rather than assumed, so both ends of the
      // scrubber are FENs the game itself produced.
      startFen: moves.isEmpty ? kInitialFEN : moves.first.fenBefore,
      orientation: playAs == 'b' ? Side.black : Side.white,
      moves: [
        for (var i = 0; i < moves.length; i++)
          ReviewedMove(
            index: i,
            played: moves[i],
            isUserTurn: moves[i].moverColor == playAs,
          ),
      ],
    );

    if (moves.isEmpty) {
      state = state.copyWith(running: false, done: true);
      return;
    }

    // One search per distinct position: fenBefore[0] + every fenAfter.
    // (fenAfter[i] == fenBefore[i+1], so this covers every parent too.)
    final scores = <String, EngineMove>{};
    Future<EngineMove?> analyzed(String fen) async {
      if (scores.containsKey(fen)) return scores[fen];
      try {
        final result = await engine.analyse(
          fen,
          limit: const SearchLimit.movetime(150),
          priority: EnginePriority.batch,
          token: token,
        );
        // A search preempted mid-run can still resolve with a truncated
        // result — never cache it as a full-quality verdict.
        if (token.isCancelled) return null;
        scores[fen] = result;
        return result;
      } on EngineRequestCancelled {
        return null;
      }
    }

    final reviewed = List.of(state.moves);
    for (var i = 0; i < moves.length; i++) {
      final played = moves[i];
      final parent = await analyzed(played.fenBefore);
      final child = await analyzed(played.fenAfter);
      if (generation != _generation) return;
      if (parent == null || child == null) return; // cancelled

      // Retain the evals for every ply (user and engine alike) — the
      // explainer renders swings from them at zero extra engine cost.
      final evalBeforeCp = parent.score?.asCp;
      final evalAfterCp = child.score?.asCp;

      if (reviewed[i].isUserTurn &&
          parent.score != null &&
          child.score != null) {
        final delta = MoveClassifier.deltaCp(
          best: parent.score!,
          after: child.score!,
          moverColor: played.moverColor,
        );
        String? bestSan;
        NormalMove? bestMove;
        if (parent.uci != null) {
          final position = Chess.fromSetup(Setup.parseFen(played.fenBefore));
          final candidate = NormalMove.fromUci(parent.uci!);
          if (position.isLegal(candidate)) {
            bestMove = candidate;
            bestSan = position.makeSan(candidate).$2;
          }
        }
        reviewed[i] = ReviewedMove(
          index: i,
          played: played,
          isUserTurn: true,
          quality: MoveClassifier.classify(delta),
          bestSan: bestSan,
          bestMove: bestMove,
          deltaCp: delta,
          evalBeforeCp: evalBeforeCp,
          evalAfterCp: evalAfterCp,
        );
      } else {
        reviewed[i] = ReviewedMove(
          index: i,
          played: played,
          isUserTurn: reviewed[i].isUserTurn,
          evalBeforeCp: evalBeforeCp,
          evalAfterCp: evalAfterCp,
        );
      }
      state = state.copyWith(
        moves: List.of(reviewed),
        analyzedCount: i + 1,
      );
    }

    state = state.copyWith(running: false, done: true);
  }

  void select(int? index) {
    state = state.copyWith(selectedIndex: () => index);
  }
}
