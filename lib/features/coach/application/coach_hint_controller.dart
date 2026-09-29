import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/chess/tolerant_position.dart';
import '../../../engine/domain/engine_models.dart';
import '../../commentator/application/commentator_controller.dart';
import '../../commentator/domain/move_tree.dart';
import '../../practice/application/practice_controller.dart';
import '../domain/coach_menu.dart';
import '../domain/coach_service.dart';
import 'coach_providers.dart';

/// One mode's hint conversation: pick a question, read the answer.
class CoachHintState {
  const CoachHintState({
    this.open = false,
    this.intent,
    this.loading = false,
    this.answer,
    this.evalCp,
    this.bestSan,
  });

  /// Whether the hint surface is showing at all.
  final bool open;

  /// Null while the question menu is up.
  final CoachIntent? intent;
  final bool loading;

  /// Coach reply in the app's markdown dialect (html-lite allowed).
  final String? answer;

  /// Side-to-move centipawns for the answer's eval chip.
  final int? evalCp;
  final String? bestSan;

  CoachHintState copyWith({
    bool? open,
    CoachIntent? Function()? intent,
    bool? loading,
    String? Function()? answer,
    int? Function()? evalCp,
    String? Function()? bestSan,
  }) =>
      CoachHintState(
        open: open ?? this.open,
        intent: intent != null ? intent() : this.intent,
        loading: loading ?? this.loading,
        answer: answer != null ? answer() : this.answer,
        evalCp: evalCp != null ? evalCp() : this.evalCp,
        bestSan: bestSan != null ? bestSan() : this.bestSan,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachHintState &&
          other.open == open &&
          other.intent == intent &&
          other.loading == loading &&
          other.answer == answer &&
          other.evalCp == evalCp &&
          other.bestSan == bestSan;

  @override
  int get hashCode =>
      Object.hash(open, intent, loading, answer, evalCp, bestSan);
}

final coachHintControllerProvider = NotifierProvider.family<CoachHintController,
    CoachHintState, HintScope>(CoachHintController.new);

/// Drives the hint surface for one mode: reads that mode's board, runs one
/// Stockfish scan per question, and hands the position to the offline
/// coach. Answers are text only — no board arrows are ever produced here.
class CoachHintController
    extends FamilyNotifier<CoachHintState, HintScope> {
  CancellationToken? _token;

  HintScope get scope => arg;

  @override
  CoachHintState build(HintScope arg) {
    ref.onDispose(() => _token?.cancel());
    return const CoachHintState();
  }

  @override
  bool updateShouldNotify(CoachHintState previous, CoachHintState next) =>
      previous != next;

  /// Opens the question menu, or closes the surface when already open.
  void toggle() =>
      state.open ? close() : state = const CoachHintState(open: true);

  void close() {
    _token?.cancel();
    if (state != const CoachHintState()) state = const CoachHintState();
  }

  /// Back to the question menu, keeping the surface open.
  void back() {
    _token?.cancel();
    state = const CoachHintState(open: true);
  }

  /// Answers [intent] for the board this scope watches.
  Future<void> ask(CoachIntent intent) async {
    _token?.cancel();
    final token = _token = CancellationToken();
    state = CoachHintState(open: true, intent: intent, loading: true);

    final (position, sanHistory, lastMoveSan) = _boardSnapshot();
    final insight =
        await ref.read(insightBuilderProvider).scan(position, token: token);
    if (token.isCancelled || state.intent != intent) return;

    final answer = await ref.read(coachServiceProvider).askIntent(
          intent,
          CoachContext(
            fen: position.fen,
            sanHistory: sanHistory,
            lastMoveSan: lastMoveSan,
            bestMoveHint: insight.bestSan,
            evalCp: insight.evalCp,
            topLines: insight.topLines,
            threat: insight.threat,
          ),
        );
    if (token.isCancelled || state.intent != intent) return;
    state = state.copyWith(
      loading: false,
      answer: () => answer.markdown,
      evalCp: () => insight.evalCp,
      bestSan: () => insight.bestSan,
    );
  }


  /// The board this scope reasons about.
  (Position, List<String>, String?) _boardSnapshot() {
    switch (scope) {
      case HintScope.studio:
        final studio = ref.read(commentatorControllerProvider);
        final node = studio.currentNode;
        if (studio.hasGame && node != null) {
          final sans = <String>[];
          for (MoveTreeNode? n = node; n != null && n.san != null;
              n = n.parent) {
            sans.insert(0, n.san!);
          }
          return (positionFromFen(node.positionFen), sans, node.san);
        }
        return (Chess.initial, const [], null);
      case HintScope.practice:
        final practice = ref.read(practiceControllerProvider);
        return (
          practice.position,
          [for (final m in practice.moves) m.san],
          practice.moves.isNotEmpty ? practice.moves.last.san : null,
        );
    }
  }
}
