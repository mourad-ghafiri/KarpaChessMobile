import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/layout/mode_shell.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/move_classifier.dart';
import 'package:karpachess/features/commentator/application/commentator_controller.dart';
import 'package:karpachess/features/commentator/data/commentator_store.dart';

import 'fakes.dart';

/// Deterministic reply: the first legal move of the position, eval 0.
EngineMove firstLegalReply(String fen, SearchLimit limit) {
  final position = Chess.fromSetup(Setup.parseFen(fen));
  if (position.isGameOver) return const EngineMove();
  final entry = position.legalMoves.entries
      .firstWhere((e) => e.value.squares.isNotEmpty);
  final move = NormalMove(from: entry.key, to: entry.value.squares.first);
  return EngineMove(
    uci: move.uci,
    lines: [const EngineLine(depth: 8, score: EvalScore.cp(0), pvUci: []),
    ],
  );
}

ProviderContainer makeContainer(
  FakeEngineService engine, {
  MemoryCommentatorStore? store,
}) {
  final container = ProviderContainer(overrides: [
    engineServiceProvider.overrideWithValue(engine),
    commentatorStoreProvider
        .overrideWithValue(store ?? MemoryCommentatorStore()),
    // The Studio analyses only while its tab is showing; the shell's default
    // tab is Learn, where every navigation would skip the engine.
    activeTabProvider.overrideWith((ref) => AppTab.studio),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('navigation triggers analysis and stores the classification', () async {
    final replies = <String, EngineMove>{};
    final engine = FakeEngineService(
      onSearch: (fen, limit) => replies[fen] ?? firstLegalReply(fen, limit),
    );
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 *');
    final tree = container.read(commentatorControllerProvider).tree!;
    final e4 = tree.mainline()[1];

    // Engine prefers d4 (+40); e4 lands at +10 → delta 30 → "good", so no
    // sacrifice search runs.
    replies[tree.root.positionFen] = const EngineMove(
      uci: 'd2d4',
      lines: [EngineLine(depth: 8, score: EvalScore.cp(40), pvUci: []),
    ],
  );
    replies[e4.positionFen] = const EngineMove(
      uci: 'e7e5',
      lines: [EngineLine(depth: 8, score: EvalScore.cp(10), pvUci: []),
    ],
  );

    controller.forward();
    await controller.analysisDone;

    expect(e4.quality, MoveQuality.good);
    expect(e4.bestUci, 'd2d4');
    expect(e4.bestSan, 'd4');
    expect(e4.evalAfter?.asCp, 10);
    // Parent fen then node fen, both at the 250ms node-analysis budget.
    expect(engine.calls[0], (tree.root.positionFen, 250));
    expect(engine.calls[1], (e4.positionFen, 250));
    // Cached: navigating away and back re-runs nothing.
    engine.calls.clear();
    controller.back();
    controller.forward();
    await controller.analysisDone;
    expect(engine.calls, isEmpty);
  });

  test('engine-best sacrifice is promoted to brilliant', () async {
    // 1. e4 e5 2. Nf3 Nc6 3. Nxe5 — knight takes a pawn, and the scripted
    // reply Nxe5 wins the knight back: white ends 320cp down → sacrifice.
    final engine = FakeEngineService();
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 2. Nf3 Nc6 3. Nxe5 *');
    final tree = container.read(commentatorControllerProvider).tree!;
    final nxe5 = tree.mainline()[5];
    final parentFen = nxe5.parent!.positionFen;

    engine.onSearch = (fen, limit) {
      if (fen == parentFen) {
        // The engine's top choice IS the played move.
        return const EngineMove(
          uci: 'f3e5',
          lines: [EngineLine(depth: 8, score: EvalScore.cp(60), pvUci: []),
    ],
  );
      }
      if (fen == nxe5.positionFen) {
        // Same eval → delta 0 → best; uci doubles as the sacrifice reply:
        // black recaptures with the c6 knight.
        return const EngineMove(
          uci: 'c6e5',
          lines: [EngineLine(depth: 8, score: EvalScore.cp(60), pvUci: []),
    ],
  );
      }
      return firstLegalReply(fen, limit);
    };

    controller.goToNode(nxe5.id);
    await controller.analysisDone;

    expect(nxe5.quality, MoveQuality.brilliant);
    // The sacrifice-reply search used the 60ms budget on the node fen.
    expect(engine.calls, contains((nxe5.positionFen, 60)));
  });

  test('playing a new move forks a variation; an existing move navigates',
      () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 2. Nf3 Nc6 *');
    final tree = container.read(commentatorControllerProvider).tree!;

    // From the root, e4 already exists → navigate, no new node.
    controller.playMove(NormalMove.fromUci('e2e4'));
    var state = container.read(commentatorControllerProvider);
    expect(state.currentNode!.san, 'e4');
    expect(tree.root.children, hasLength(1));
    expect(state.offMainline, isFalse);

    // d5?! is new → creates a variation under e4 and enters it.
    controller.playMove(NormalMove.fromUci('d7d5'));
    await controller.analysisDone;
    state = container.read(commentatorControllerProvider);
    final e4 = tree.root.children.first;
    expect(e4.children, hasLength(2));
    expect(e4.children[0].san, 'e5'); // mainline preserved
    expect(e4.children[1].san, 'd5');
    expect(state.currentNode!.san, 'd5');
    expect(state.offMainline, isTrue);

    // Illegal moves are ignored.
    controller.playMove(NormalMove.fromUci('a1a8'));
    expect(container.read(commentatorControllerProvider).currentNode!.san,
        'd5');

    // Return to the mainline pops back to the branch point.
    controller.returnToMainline();
    state = container.read(commentatorControllerProvider);
    expect(state.currentNode, same(e4));
    expect(state.offMainline, isFalse);
    await controller.analysisDone;
  });

  test('recap analyzes remaining mainline nodes and computes accuracy',
      () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn(
        '1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0');
    controller.openRecap();
    await controller.recapDone;

    final recap = container.read(commentatorControllerProvider).recap!;
    expect(recap.computing, isFalse);
    expect(recap.result!.kind, GameResultKind.checkmate);
    expect(recap.result!.winner, 'w');
    expect(recap.totalCount, 7);
    expect(recap.analyzedCount, 7);
    // Every move scored eval 0 on both sides → delta 0 → best → 100%.
    expect(recap.whiteAccuracy, 100);
    expect(recap.blackAccuracy, 100);

    // Recap analysis runs at batch priority movetime 250 (plus 60ms
    // sacrifice probes); every mainline node ends up classified.
    final tree = container.read(commentatorControllerProvider).tree!;
    for (final node in tree.mainline().skip(1)) {
      expect(node.quality, isNotNull);
    }
  });

  test('recap accuracy averages the quality scores per side', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0');
    final tree = container.read(commentatorControllerProvider).tree!;
    // Pre-seed classifications so the recap only does the math:
    // white best/best/best/best=100; black best, good, blunder.
    final qualities = [
      MoveQuality.best, // e4
      MoveQuality.best, // e5
      MoveQuality.best, // Bc4
      MoveQuality.good, // Nc6
      MoveQuality.best, // Qh5
      MoveQuality.blunder, // Nf6
      MoveQuality.best, // Qxf7#
    ];
    final moves = tree.mainline().skip(1).toList();
    for (var i = 0; i < moves.length; i++) {
      moves[i].quality = qualities[i];
    }

    controller.openRecap();
    await controller.recapDone;
    final recap = container.read(commentatorControllerProvider).recap!;
    expect(recap.whiteAccuracy, 100);
    expect(recap.blackAccuracy, closeTo((100 + 85 + 10) / 3, 0.001));
    // Nothing left to analyze → no engine calls.
    expect(engine.calls, isEmpty);
  });

  test('reaching the final mainline node of a finished game auto-opens '
      'the recap once', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0');
    expect(container.read(commentatorControllerProvider).recap, isNull);

    controller.goToEnd();
    expect(container.read(commentatorControllerProvider).recap, isNotNull);
    await controller.recapDone;

    controller.closeRecap();
    expect(container.read(commentatorControllerProvider).recap, isNull);
    // Landing on the same node again does not re-open it.
    controller.back();
    controller.forward();
    await controller.analysisDone;
    expect(container.read(commentatorControllerProvider).recap, isNull);
  });

  test('session persists on changes and restores on build', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final store = MemoryCommentatorStore();
    final container = makeContainer(engine, store: store);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 2. Nf3 Nc6 *');
    controller.forward();
    controller.forward();
    controller.setPlayerName('w', 'Paul');
    await controller.analysisDone;
    await Future<void>.delayed(Duration.zero);

    expect(store.session, isNotNull);
    expect(store.session!.whiteName, 'Paul');
    expect(store.session!.path, [0, 0]);

    // A fresh container (same store) restores game, name and position.
    final container2 = makeContainer(engine, store: store);
    final controller2 =
        container2.read(commentatorControllerProvider.notifier);
    final state0 = container2.read(commentatorControllerProvider);
    expect(state0.hasGame, isFalse); // restore is async
    await controller2.restored;

    final state = container2.read(commentatorControllerProvider);
    expect(state.hasGame, isTrue);
    expect(state.white.name, 'Paul');
    expect(state.currentNode!.san, 'e5');
    expect(state.tree!.pathIndices(state.currentNode!), [0, 0]);
    await controller2.analysisDone;
  });

  test('closeGame returns to import and clears the stored session', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final store = MemoryCommentatorStore();
    final container = makeContainer(engine, store: store);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 *');
    await Future<void>.delayed(Duration.zero);
    expect(store.session, isNotNull);

    controller.closeGame();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(commentatorControllerProvider).hasGame, isFalse);
    expect(store.session, isNull);
  });

  test('a position the engine refuses ends the analysis instead of hanging',
      () async {
    final engine = FakeEngineService(
      onSearch: (fen, limit) =>
          throw const EngineRejectedPosition('scripted refusal'),
    );
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    controller.loadPgn('1. e4 e5 *');
    final e4 =
        container.read(commentatorControllerProvider).tree!.mainline()[1];
    controller.forward();
    await controller.analysisDone;

    // Terminal: no verdict, and a second visit does not ask again.
    expect(e4.quality, isNull);
    engine.calls.clear();
    controller.back();
    controller.forward();
    await controller.analysisDone;
    expect(engine.calls, isEmpty);
  });

  test('a PGN that is not a game throws and loads nothing', () async {
    final engine = FakeEngineService(onSearch: firstLegalReply);
    final container = makeContainer(engine);
    final controller = container.read(commentatorControllerProvider.notifier);
    await controller.restored;

    // The failure is raised, not stored: the import sheet parses before it
    // persists, so it is the one caller that can be handed bad input.
    expect(() => controller.loadPgn('this is not chess'),
        throwsA(isA<FormatException>()));
    expect(container.read(commentatorControllerProvider).hasGame, isFalse);

    controller.loadPgn('e4 e5');
    expect(container.read(commentatorControllerProvider).hasGame, isTrue);
  });
}
