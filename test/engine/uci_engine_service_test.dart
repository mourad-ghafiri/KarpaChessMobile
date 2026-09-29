import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/engine/data/uci_protocol.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/uci_engine_service.dart';

import 'fake_uci_transport.dart';

const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const blackFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1';

/// A lone king: Stockfish 19 exits its process on a position like this.
const loneKingFen = '8/8/8/8/8/8/8/K7 w - - 0 1';

/// Waits until [transport] has a search running.
Future<void> untilSearching(FakeUciTransport transport) async {
  for (var i = 0; i < 500 && !transport.searching; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(transport.searching, isTrue, reason: 'no search started');
}

void main() {
  group('UciProtocol', () {
    test('parses info with cp score, normalizing to White perspective', () {
      final white = UciProtocol.parseInfo(
          'info depth 12 seldepth 16 score cp 35 nodes 999 pv e2e4 e7e5', 'w');
      expect(white!.depth, 12);
      expect(white.score.cp, 35);
      expect(white.pvUci, ['e2e4', 'e7e5']);

      final black = UciProtocol.parseInfo(
          'info depth 12 score cp 35 pv e7e5', 'b');
      expect(black!.score.cp, -35);
    });

    test('parses mate scores with perspective', () {
      final line = UciProtocol.parseInfo('info depth 5 score mate 2 pv a1a2', 'b');
      expect(line!.score.mateIn, -2);
      expect(line.score.asCp, lessThan(-99000));
    });

    test('ignores score-less info lines', () {
      expect(UciProtocol.parseInfo('info currmove e2e4 currmovenumber 1', 'w'),
          isNull);
    });

    test('parses bestmove including (none)', () {
      expect(UciProtocol.parseBestMove('bestmove e2e4 ponder e7e5'), 'e2e4');
      expect(UciProtocol.parseBestMove('bestmove (none)'), '');
      expect(UciProtocol.parseBestMove('info depth 1'), isNull);
    });
  });

  group('EvalScore', () {
    test('mate maps onto the cp axis preserving order', () {
      expect(const EvalScore.mate(1).asCp, greaterThan(const EvalScore.mate(3).asCp));
      expect(const EvalScore.mate(-1).asCp, lessThan(const EvalScore.mate(-3).asCp));
      expect(const EvalScore.mate(1).asCp, greaterThan(const EvalScore.cp(5000).asCp));
    });
  });

  group('SearchLimit and EngineStrength', () {
    test('go arguments carry a depth, a movetime, or both', () {
      expect(const SearchLimit.movetime(300).uciGoArguments, 'movetime 300');
      expect(const SearchLimit.depth(20).uciGoArguments, 'depth 20');
      expect(const SearchLimit.depth(5, movetimeMs: 1000).uciGoArguments,
          'depth 5 movetime 1000');
    });

    test('the handicapped ladder is monotonic and searches to its pick depth',
        () {
      final handicapped =
          EngineStrength.values.where((s) => s.skillLevel != null).toList()
            ..sort((a, b) => a.level.compareTo(b.level));
      for (var i = 1; i < handicapped.length; i++) {
        expect(handicapped[i].skillLevel,
            greaterThan(handicapped[i - 1].skillLevel!));
      }
      for (final strength in handicapped) {
        // Stockfish picks the handicapped move at depth 1 + level.
        expect(strength.limit.depth, 1 + strength.skillLevel!);
        expect(strength.limit.movetimeMs, isNotNull);
      }
      expect(EngineStrength.master.skillLevel, isNull);
      expect(EngineStrength.master.limit.uciGoArguments, 'movetime 1200');
    });
  });

  group('UciEngineService', () {
    test('boots with handshake and returns a best move', () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      final move = await service.analyse(startFen);
      expect(move.uci, 'e2e4');
      expect(move.score!.cp, 34);
      expect(transport.sent, contains('uci'));
      expect(transport.sent, contains('setoption name Threads value 2'));
      expect(transport.sent, contains('position fen $startFen'));
    });

    test('serializes concurrent requests — never overlapping go', () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(milliseconds: 10);
      var maxConcurrent = 0;
      var current = 0;
      transport.onGo = (fen, args) {
        current++;
        if (current > maxConcurrent) maxConcurrent = current;
        current--;
        return ['info depth 8 score cp 10 pv e2e4', 'bestmove e2e4'];
      };
      final service = UciEngineService(transport);

      await Future.wait([
        service.analyse(startFen),
        service.analyse(blackFen),
        service.analyse(startFen),
      ]);
      expect(maxConcurrent, 1);
      expect(transport.goCount, 3);
    });

    test('interactive requests jump ahead of queued batch requests', () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(milliseconds: 5);
      final order = <String>[];
      transport.onGo = (fen, args) {
        order.add(fen == blackFen ? 'interactive' : 'batch');
        return ['bestmove e2e4'];
      };
      final service = UciEngineService(transport);

      // Prime: first request occupies the engine.
      final first = service.analyse(startFen, priority: EnginePriority.batch);
      final batch2 = service.analyse(startFen, priority: EnginePriority.batch);
      final interactive = service.analyse(blackFen);
      await Future.wait([first, batch2, interactive]);

      expect(order.first, anyOf('batch', 'interactive'));
      // The interactive request must not run last.
      expect(order.last, 'batch');
    });

    test('cancelled queued request completes with EngineRequestCancelled',
        () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(milliseconds: 20);
      final service = UciEngineService(transport);

      final token = CancellationToken();
      final running = service.analyse(startFen);
      final cancelled = service.analyse(blackFen, token: token);
      token.cancel();

      await running;
      await expectLater(cancelled, throwsA(isA<EngineRequestCancelled>()));
    });

    test('cancelling a running search sends stop and reports cancellation',
        () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(seconds: 5); // would hang without stop
      final service = UciEngineService(transport);

      final token = CancellationToken();
      final future = service.analyse(startFen, token: token);
      // Let the search start, then cancel.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();

      await expectLater(future, throwsA(isA<EngineRequestCancelled>()));
      expect(transport.sent, contains('stop'));
    });

    test('handicapped replies search to their pick depth on one thread',
        () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      await service.bestMove(startFen, const [], EngineStrength.beginner);
      expect(transport.sent, contains('setoption name Skill Level value 0'));
      expect(transport.sent, contains('setoption name Threads value 1'));
      expect(transport.sent, contains('go depth 1 movetime 1000'));

      await service.bestMove(startFen, const [], EngineStrength.club);
      expect(transport.sent, contains('setoption name Skill Level value 4'));
      expect(transport.sent, contains('go depth 5 movetime 1000'));

      await service.bestMove(startFen, const [], EngineStrength.master);
      expect(transport.sent.last, 'go movetime 1200');
      expect(
          transport.sent.lastIndexOf('setoption name Skill Level value 20'),
          greaterThan(
              transport.sent.lastIndexOf('setoption name Skill Level value 4')));
      expect(transport.sent.lastIndexOf('setoption name Threads value 2'),
          greaterThan(transport.sent.lastIndexOf('setoption name Threads value 1')));
      // One scale only: Elo limiting is never switched on.
      expect(
          transport.sent.where(
              (l) => l.contains('UCI_LimitStrength') || l.contains('UCI_Elo')),
          isEmpty);
    });

    test('terminal position maps bestmove (none) to null uci', () async {
      final transport = FakeUciTransport();
      transport.onGo = (fen, args) => ['bestmove (none)'];
      final service = UciEngineService(transport);

      final move = await service.analyse(startFen);
      expect(move.uci, isNull);
    });

    test('a failed boot fails every waiting request instead of hanging',
        () async {
      final transport = FakeUciTransport()..failStarts = 1;
      final service = UciEngineService(transport);

      // Both are queued behind the same boot; neither may wait forever.
      final first = service.analyse(startFen);
      final second =
          service.bestMove(startFen, const [], EngineStrength.beginner);
      await expectLater(first, throwsA(isA<StateError>()));
      await expectLater(second, throwsA(isA<StateError>()));
    });

    test('after a failed boot the next request boots again', () async {
      final transport = FakeUciTransport()..failStarts = 1;
      final service = UciEngineService(transport);

      await expectLater(service.analyse(startFen), throwsA(isA<StateError>()));
      // The dead boot was forgotten rather than cached for the session.
      final move = await service.analyse(startFen);
      expect(move.uci, 'e2e4');
    });

    test('newGame recovers from a failed boot too', () async {
      final transport = FakeUciTransport()..failStarts = 1;
      final service = UciEngineService(transport);

      await expectLater(service.newGame(), throwsA(isA<StateError>()));
      await service.newGame();
      expect(transport.sent, contains('ucinewgame'));
    });
  });

  group('positions Stockfish would refuse', () {
    test('never reach the engine — not even a boot', () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      await expectLater(
          service.analyse(loneKingFen), throwsA(isA<EngineRejectedPosition>()));
      expect(transport.sent, isEmpty);
    });

    test('do not preempt a running batch search', () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(milliseconds: 30);
      final service = UciEngineService(transport);

      final batch = service.analyse(startFen, priority: EnginePriority.batch);
      await untilSearching(transport);
      // Black to move with its king on a8 while White's queen on h1 gives
      // check: the side NOT to move is in check.
      await expectLater(service.analyse('k7/8/8/8/8/8/8/K6Q w - - 0 1'),
          throwsA(isA<EngineRejectedPosition>()));
      await batch;
      expect(transport.sent, isNot(contains('stop')));
    });

    test("send dartchess's FEN, never the caller's", () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      // An en passant square on the wrong rank: dartchess drops it, and
      // Stockfish would have exited on it.
      await service.analyse(
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e4 0 1');
      expect(transport.lastFen,
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
    });

    test('an illegal move history is refused before anything is sent',
        () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      await expectLater(
          service.bestMove(startFen, const ['e2e5'], EngineStrength.beginner),
          throwsA(isA<EngineRejectedPosition>()));
      expect(transport.sent, isEmpty);
    });
  });

  group('game history', () {
    test('is sent after the start, castling in the king form', () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      // 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.O-O, the castle written king-takes-rook.
      await service.bestMove(
        startFen,
        const ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'e1h1'],
        EngineStrength.beginner,
      );
      expect(transport.lastFen, startFen);
      expect(transport.lastMoves,
          ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'e1g1']);
    });

    test('scores are read from the side to move after the history', () async {
      final transport = FakeUciTransport()
        ..onGo = (fen, args) =>
            ['info depth 5 score cp 35 pv e7e5', 'bestmove e7e5'];
      final service = UciEngineService(transport);

      // After 1.e4 Black is to move, so "+35" is Black's view.
      final move =
          await service.bestMove(startFen, const ['e2e4'], EngineStrength.master);
      expect(move.score!.cp, -35);
    });
  });

  group('suspend / resume', () {
    test('stops the running search and runs it again in full on resume',
        () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(milliseconds: 50);
      final service = UciEngineService(transport);

      final future = service.analyse(startFen);
      await untilSearching(transport);
      service.suspend();
      expect(transport.sent.last, 'stop');

      var answered = false;
      future.then((_) => answered = true, onError: (_) => answered = true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // Held — not answered with the truncated result of the stopped search.
      expect(answered, isFalse);
      expect(transport.goCount, 1);

      service.resume();
      final move = await future;
      expect(transport.goCount, 2);
      expect(move.uci, 'e2e4');
    });

    test('a resume before the stopped search answers reruns it exactly once',
        () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(milliseconds: 30);
      final service = UciEngineService(transport);

      final future = service.analyse(startFen);
      await untilSearching(transport);
      service.suspend();
      service.resume(); // the stop's bestmove has not been delivered yet
      await future;
      expect(transport.goCount, 2);
    });

    test('nothing boots or searches while suspended', () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      service.suspend();
      final future = service.analyse(startFen);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.sent, isEmpty);

      service.resume();
      expect((await future).uci, 'e2e4');
    });

    test('resume with nothing queued does not boot the engine', () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      service.suspend();
      service.resume();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.sent, isEmpty);
    });

    test('a request cancelled while held fails at once', () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      service.suspend();
      final token = CancellationToken();
      final future = service.analyse(startFen, token: token);
      token.cancel();
      await expectLater(future, throwsA(isA<EngineRequestCancelled>()));
      expect(transport.sent, isEmpty);
    });

    test('an interactive request made while held runs before the stopped '
        'batch search, and preempts nothing', () async {
      final transport = FakeUciTransport()
        ..searchDelay = const Duration(milliseconds: 40);
      final order = <String>[];
      transport.onGo = (fen, args) {
        order.add(fen == blackFen ? 'interactive' : 'batch');
        return ['bestmove e2e4'];
      };
      final service = UciEngineService(transport);

      final batch = service.analyse(startFen, priority: EnginePriority.batch);
      await untilSearching(transport);
      service.suspend();
      final interactive = service.analyse(blackFen);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // The suspend's stop only: a held engine is never preempted.
      expect(transport.sent.where((l) => l == 'stop'), hasLength(1));

      service.resume();
      await Future.wait([batch, interactive]);
      expect(order.first, 'interactive');
      expect(order.last, 'batch');
    });

    test('a boot that fails while held keeps the work for resume', () async {
      final transport = FakeUciTransport()..failStarts = 1;
      final service = UciEngineService(transport);

      final future = service.analyse(startFen);
      service.suspend(); // before the failed boot is noticed
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.resume();
      expect((await future).uci, 'e2e4');
    });

    test('dispose while held fails every request', () async {
      final transport = FakeUciTransport();
      final service = UciEngineService(transport);

      service.suspend();
      final expectation = expectLater(
          service.analyse(startFen), throwsA(isA<EngineRequestCancelled>()));
      await service.dispose();
      await expectation;
    });
  });
}
