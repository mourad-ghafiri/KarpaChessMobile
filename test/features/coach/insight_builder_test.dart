import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';
import 'package:karpachess/features/coach/domain/insight_builder.dart';

import '../practice/fake_engine_service.dart';

// The threat scan flips the side to move. Flipping a position whose mover
// is IN CHECK produces a board where the king can be captured — a position
// Stockfish 19 refuses by exiting its process, which is the app's (asking
// for a hint while in check once closed the whole app in Play). The engine
// service now turns such positions away (EnginePosition); scanThreat's own
// contract is not to ask at all. The tolerant positionFromFen accepts
// opposite-check setups by design, so that must be the explicit isCheck
// test, never the parse.

void main() {
  // 1.e4 e5 2.Qh5 Nc6 3.Qxf7+ — Black to move, in check.
  const inCheckFen =
      'r1bqkbnr/pppp1Qpp/2n5/4p3/4P3/8/PPPP1PPP/RNB1KBNR b KQkq - 0 3';

  test('threat scan is skipped while the mover is in check', () async {
    final engine = FakeEngineService();
    final builder = InsightBuilder(engine);

    final insight = await builder.scan(positionFromFen(inCheckFen));

    expect(insight.threat, isNull);
    // Only the position itself was searched — the king-en-prise flip was
    // never asked for.
    expect(engine.analysed, [inCheckFen]);
  });

  test('threat scan still runs when the mover is not in check', () async {
    final engine = FakeEngineService();
    final builder = InsightBuilder(engine);
    const startFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    await builder.scan(positionFromFen(startFen));

    expect(engine.analysed, hasLength(2));
    expect(engine.analysed.last.split(' ')[1], 'b'); // the flipped scan
  });

  test('scanThreat alone refuses an in-check position', () async {
    final engine = FakeEngineService();
    final builder = InsightBuilder(engine);

    final threat = await builder.scanThreat(positionFromFen(inCheckFen));

    expect(threat, isNull);
    expect(engine.analysed, isEmpty);
  });
}
