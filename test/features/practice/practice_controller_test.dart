import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/features/practice/application/practice_controller.dart';
import 'package:karpachess/features/practice/domain/chess_clock.dart';
import 'package:karpachess/features/practice/domain/practice_models.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/prefs/domain/prefs.dart';
import 'package:karpachess/prefs/domain/prefs_repository.dart';

import 'fake_engine_service.dart';

class MemoryPrefsRepository implements PrefsRepository {
  Prefs? stored;

  @override
  Future<Prefs?> load() async => stored;

  @override
  Future<void> save(Prefs prefs) async => stored = prefs;

  @override
  Future<void> clear() async => stored = null;
}

/// Replies with the first legal move of the position (deterministic).
EngineMove firstLegalReply(String fen) {
  final position = Chess.fromSetup(Setup.parseFen(fen));
  final entry = position.legalMoves.entries
      .firstWhere((e) => e.value.squares.isNotEmpty);
  final move = NormalMove(from: entry.key, to: entry.value.squares.first);
  return EngineMove(
    uci: move.uci,
    lines: [const EngineLine(depth: 8, score: EvalScore.cp(12), pvUci: []),
    ],
  );
}

ProviderContainer makeContainer(FakeEngineService engine) {
  final container = ProviderContainer(overrides: [
    engineServiceProvider.overrideWithValue(engine),
    soundServiceProvider.overrideWithValue(const SilentSoundService()),
    prefsRepositoryProvider.overrideWithValue(MemoryPrefsRepository()),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('newGame resets and, when playing Black, the engine opens', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller =
        container.read(practiceControllerProvider.notifier);

    await container
        .read(prefsControllerProvider.notifier)
        .setPlayAs('b');
    controller.newGame();
    expect(container.read(practiceControllerProvider).playAs, 'b');

    // Engine opening move arrives after its 500ms scheduling delay.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final state = container.read(practiceControllerProvider);
    expect(state.moves, hasLength(1));
    expect(state.turn, 'b');
    expect(engine.newGameCalls, 1);
  });

  test('user move triggers an engine reply after ~180ms', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller =
        container.read(practiceControllerProvider.notifier);

    controller.newGame();
    controller.userMove(NormalMove.fromUci('e2e4'));
    expect(container.read(practiceControllerProvider).moves, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final state = container.read(practiceControllerProvider);
    expect(state.moves, hasLength(2));
    expect(state.moves[1].moverColor, 'b');
    expect(state.isUserTurn, isTrue);
  });

  test('illegal and out-of-turn moves are rejected', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller =
        container.read(practiceControllerProvider.notifier);

    controller.newGame();
    controller.userMove(NormalMove.fromUci('e2e5')); // illegal
    expect(container.read(practiceControllerProvider).moves, isEmpty);

    controller.userMove(NormalMove.fromUci('e2e4'));
    // Now it's the engine's turn — a second user move must be ignored.
    controller.userMove(NormalMove.fromUci('d2d4'));
    expect(container.read(practiceControllerProvider).moves, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });

  test('undo removes the full user+engine move pair', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller =
        container.read(practiceControllerProvider.notifier);

    controller.newGame();
    controller.userMove(NormalMove.fromUci('e2e4'));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(container.read(practiceControllerProvider).moves, hasLength(2));

    controller.undo();
    final state = container.read(practiceControllerProvider);
    expect(state.moves, isEmpty);
    expect(state.position.fen, Chess.initial.fen);
    expect(state.isUserTurn, isTrue);
  });

  test('scholars mate ends the game with a user win and stops play',
      () async {
    // Script the engine to walk into the scholar's mate.
    final replies = {
      // after 1.e4 → e5, after 2.Bc4 → Nc6, after 3.Qh5 → Nf6??
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1': 'e7e5',
      'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2':
          'b8c6',
      'r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 3 3':
          'g8f6',
    };
    final engine = FakeEngineService(onSearch: (fen) {
      final uci = replies[fen];
      if (uci == null) return firstLegalReply(fen);
      return EngineMove(
        uci: uci,
        lines: [const EngineLine(depth: 8, score: EvalScore.cp(0), pvUci: []),
    ],
  );
    });
    final container = makeContainer(engine);
    final controller =
        container.read(practiceControllerProvider.notifier);

    controller.newGame();
    Future<void> engineTurn() =>
        Future<void>.delayed(const Duration(milliseconds: 400));

    controller.userMove(NormalMove.fromUci('e2e4'));
    await engineTurn();
    controller.userMove(NormalMove.fromUci('f1c4'));
    await engineTurn();
    controller.userMove(NormalMove.fromUci('d1h5'));
    await engineTurn();
    controller.userMove(NormalMove.fromUci('h5f7')); // Qxf7#

    final state = container.read(practiceControllerProvider);
    expect(state.result?.kind, GameResultKind.checkmate);
    expect(state.result?.winner, 'w');
    expect(state.userWon, isTrue);
    expect(state.moves.last.san, 'Qxf7#');

    // No further engine reply after the game ended.
    await engineTurn();
    expect(container.read(practiceControllerProvider).moves, hasLength(7));
  });

  test('a threefold repetition ends the game drawn, and Stockfish sees the '
      'game that led there', () async {
    // Stockfish answers the knight shuffle in kind.
    final engine = FakeEngineService(
      onSearch: (fen) =>
          EngineMove(uci: fen.startsWith('rnbqkb1r') ? 'f6g8' : 'g8f6'),
    );
    final container = makeContainer(engine);
    final controller = container.read(practiceControllerProvider.notifier);

    controller.newGame();
    for (final uci in ['g1f3', 'f3g1', 'g1f3', 'f3g1']) {
      controller.userMove(NormalMove.fromUci(uci));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    // 4...Ng8 brings the start position back a third time.
    final state = container.read(practiceControllerProvider);
    expect(state.moves, hasLength(8));
    expect(state.result?.kind, GameResultKind.repetition);
    expect(state.result?.winner, isNull);
    expect(engine.histories, hasLength(4));
    expect(engine.histories.last,
        ['g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1']);
  });

  group('threefold repetition', () {
    bool threefoldAfter(List<String> uci) {
      final (position, moves) = replayMoves(uci);
      return isThreefold(position, moves);
    }

    /// The plies (1-based) after which [uci], played from the start, stands
    /// on a position for the third time.
    List<int> repeatsAt(List<String> uci) => [
          for (var ply = 1; ply <= uci.length; ply++)
            if (threefoldAfter(uci.sublist(0, ply))) ply,
        ];

    test('a knight shuffle repeats on the eighth ply, not before', () {
      const shuffle = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];
      expect(repeatsAt([...shuffle, ...shuffle]), [8]);
    });

    test('a lost castling right makes an earlier position count as different',
        () {
      const walk = ['e1e2', 'e8e7', 'e2e1', 'e7e8'];
      final hits = repeatsAt(['e2e4', 'e7e5', ...walk, ...walk, ...walk]);
      // Ignoring castling rights, the position after 1...e5 would come back
      // on plies 6 and 10 and draw there.
      expect(hits.first, 12);
    });

    test('an en passant right makes an otherwise identical position differ',
        () {
      const knights = ['g1f3', 'b8c6', 'f3g1', 'c6b8'];
      final hits = repeatsAt(
          ['e2e4', 'g8f6', 'e4e5', 'd7d5', ...knights, ...knights, ...knights]);
      // After 2...d5 White may take on d6 en passant; after the knights come
      // home it may not. Ignoring that, ply 12 would already be the third.
      expect(hits.first, 13);
    });

    test('terminalResult reports it as a draw', () {
      const shuffle = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];
      final (position, moves) = replayMoves([...shuffle, ...shuffle]);
      final result = terminalResult(position, moves);
      expect(result?.kind, GameResultKind.repetition);
      expect(result?.winner, isNull);
    });
  });

  group('ChessClock', () {
    test('counts down only the running side and applies increment', () {
      final clock = ChessClock(initialMs: 60000, incrementMs: 2000);
      clock.start('w', 0);
      expect(clock.tick(1000), isNull);
      expect(clock.whiteMs, 59000);
      expect(clock.blackMs, 60000);

      clock.onMoveCompleted('w', 1500);
      expect(clock.whiteMs, 58500 + 2000);
      expect(clock.runningSide, 'b');
    });

    test('flags at zero and stops', () {
      final clock = ChessClock(initialMs: 1000);
      clock.start('b', 0);
      expect(clock.tick(999), isNull);
      expect(clock.tick(1001), 'b');
      expect(clock.blackMs, 0);
      expect(clock.runningSide, isNull);
      expect(clock.tick(2000), isNull);
    });

    test('unlimited clock counts thinking time up and never flags', () {
      final clock = ChessClock(initialMs: null);
      clock.start('w', 0);
      expect(clock.runningSide, 'w');
      expect(clock.tick(5000), isNull); // no flag, ever
      expect(clock.whiteMs, 5000); // elapsed accumulated for the card
      clock.onMoveCompleted('w', 6000);
      expect(clock.whiteMs, 6000); // final second charged, no increment
      expect(clock.runningSide, 'b'); // handed over like a timed game
    });
  });
}
