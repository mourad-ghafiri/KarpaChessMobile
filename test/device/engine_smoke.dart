import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karpa_engine/karpa_engine.dart';
import 'package:karpachess/engine/data/karpa_engine_transport.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/uci_engine_service.dart';

/// On-device smoke test: boots the real Stockfish, checks it is the version
/// the app claims, that NNUE search works at every strength tier, that a
/// position Stockfish would refuse never reaches it, and that a batch of
/// evaluations completes without a dropped bestmove.
///
/// Runs on a device, through `flutter drive` (see `driver.dart` for why it
/// has no `_test.dart` suffix):
///
///     flutter drive --driver=test/device/driver.dart \
///       --target=test/device/engine_smoke.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const italianFen =
      'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3';
  const italian = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4'];
  const mateInOneFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1'; // Ra8#

  late UciEngineService engine;

  setUpAll(() {
    engine = UciEngineService(KarpaEngineTransport());
  });

  tearDownAll(() async {
    await engine.dispose();
  });

  // First, before the service boots: the bridge runs one engine at a time.
  test('the shipped engine is Stockfish 19', () async {
    final raw = KarpaEngine();
    final id = raw.lines.firstWhere((line) => line.startsWith('id name '));
    await raw.start();
    expect(await id, 'id name Stockfish 19');
    await raw.close();
  });

  test('boots and answers from the start position', () async {
    final move = await engine.analyse(startFen);
    expect(move.uci, isNotNull);
    expect(move.line, isNotNull);
    expect(move.line!.depth, greaterThan(1));
  });

  test('finds mate in one at full strength', () async {
    final move = await engine.analyse(
      mateInOneFen,
      limit: const SearchLimit.movetime(500),
    );
    expect(move.uci, 'a1a8');
    expect(move.score!.mateIn, 1);
  });

  test('a position Stockfish would refuse is turned away, and the engine '
      'keeps answering', () async {
    // Stockfish 19 exits its process — here, the app — on a lone king.
    await expectLater(engine.analyse('8/8/8/8/8/8/8/K7 w - - 0 1'),
        throwsA(isA<EngineRejectedPosition>()));
    expect((await engine.analyse(startFen)).uci, isNotNull);
  });

  test('all four strength tiers produce legal-looking moves, handicapped '
      'ones from their pick depth', () async {
    for (final strength in EngineStrength.values) {
      final move = await engine.bestMove(startFen, italian, strength);
      expect(move.uci, isNotNull, reason: 'strength ${strength.name}');
      expect(move.uci!.length, inInclusiveRange(4, 5));
      final skill = strength.skillLevel;
      if (skill != null) {
        expect(move.line!.depth, lessThanOrEqualTo(1 + skill),
            reason: 'strength ${strength.name}');
      }
    }
  });

  test('a game history with castling is accepted', () async {
    final move = await engine.bestMove(
      startFen,
      const ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'e1g1'],
      EngineStrength.beginner,
    );
    expect(move.uci, isNotNull);
  });

  test('a 20-eval batch completes with no dropped bestmove', () async {
    final futures = [
      for (var i = 0; i < 20; i++)
        engine.analyse(
          i.isEven ? startFen : italianFen,
          limit: const SearchLimit.movetime(80),
          priority: EnginePriority.batch,
        ),
    ];
    final results = await Future.wait(futures);
    expect(results.every((r) => r.uci != null), isTrue);
  });
}
