import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/move_classifier.dart';
import 'package:karpachess/features/practice/application/practice_controller.dart';
import 'package:karpachess/features/review/application/review_controller.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';

import '../practice/fake_engine_service.dart';
import '../practice/practice_controller_test.dart'
    show MemoryPrefsRepository, firstLegalReply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('review classifies user plies against scripted engine evals',
      () async {
    // Script: every position evaluates to +100 for White except the position
    // after the user's second move, which evaluates -100 → user (White)
    // lost 200cp on that move → mistake.
    final engine = FakeEngineService();
    engine.onSearch = (fen) {
      final position = Chess.fromSetup(Setup.parseFen(fen));
      final best = firstLegalReply(fen);
      // Position after 2 full moves (user's 2nd move committed): fullmove
      // counter is 2 and it's black to move once white played move 2.
      final isAfterUserSecond =
          position.fullmoves == 2 && position.turn == Side.black;
      return EngineMove(
        uci: best.uci,
        lines: [EngineLine(
          depth: 10,
          score: EvalScore.cp(isAfterUserSecond ? -100 : 100),
          pvUci: const [],
        ),
    ],
  );
    };

    final container = ProviderContainer(overrides: [
      engineServiceProvider.overrideWithValue(engine),
      soundServiceProvider.overrideWithValue(const SilentSoundService()),
      prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
    ]);
    addTearDown(container.dispose);

    // Play a short game: user (White) e4, engine reply, user d4, engine reply.
    final practice = container.read(practiceControllerProvider.notifier);
    practice.newGame();
    practice.userMove(NormalMove.fromUci('e2e4'));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    practice.userMove(NormalMove.fromUci('d2d4'));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(container.read(practiceControllerProvider).moves, hasLength(4));

    final review = container.read(reviewControllerProvider.notifier);
    await review.start();

    final state = container.read(reviewControllerProvider);
    expect(state.done, isTrue);
    expect(state.moves, hasLength(4));

    final userMoves =
        state.moves.where((m) => m.isUserTurn).toList();
    expect(userMoves, hasLength(2));
    // First user move: parent +100, child +100 → delta 0 → best.
    expect(userMoves[0].quality, MoveQuality.best);
    // Second user move: parent +100, child -100 → delta 200 → mistake.
    expect(userMoves[1].quality, MoveQuality.mistake);
    expect(userMoves[1].deltaCp, 200);
    expect(userMoves[1].bestSan, isNotNull);

    final tallies = state.tallies;
    expect(tallies['good'], 1);
    expect(tallies['mistake'], 1);

    // Engine plies are never classified.
    expect(
      state.moves.where((m) => !m.isUserTurn).every((m) => m.quality == null),
      isTrue,
    );
  });
}
