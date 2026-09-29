import 'package:dartchess/dartchess.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/engine_service.dart';

/// Scripted engine for feature tests: answers by FEN lookup or a fallback.
class FakeEngineService implements EngineService {
  FakeEngineService({this.onSearch});

  /// Returns the reply for a fen; when null, replies with the first legal-ish
  /// scripted default. A [bestMove] is looked up by the FEN its history
  /// reaches.
  EngineMove Function(String fen)? onSearch;

  /// FENs analysed, in order.
  final List<String> analysed = [];

  /// The move history of every [bestMove] request, in order.
  final List<List<String>> histories = [];

  int newGameCalls = 0;
  int suspendCalls = 0;
  int resumeCalls = 0;

  static const defaultMove = EngineMove(
    uci: 'e2e4',
    lines: [EngineLine(depth: 10, score: EvalScore.cp(30), pvUci: ['e2e4']),
    ],
  );

  @override
  Future<EngineMove> analyse(
    String fen, {
    SearchLimit limit = const SearchLimit.movetime(300),
    EnginePriority priority = EnginePriority.interactive,
    CancellationToken? token,
    int multiPv = 1,
  }) async {
    if (token?.isCancelled ?? false) throw const EngineRequestCancelled();
    analysed.add(fen);
    return onSearch?.call(fen) ?? defaultMove;
  }

  @override
  Future<EngineMove> bestMove(
    String startFen,
    List<String> moves,
    EngineStrength strength, {
    CancellationToken? token,
  }) async {
    if (token?.isCancelled ?? false) throw const EngineRequestCancelled();
    histories.add(List.of(moves));
    Position position = Chess.fromSetup(Setup.parseFen(startFen));
    for (final uci in moves) {
      position = position.play(NormalMove.fromUci(uci));
    }
    analysed.add(position.fen);
    return onSearch?.call(position.fen) ?? defaultMove;
  }

  @override
  Future<void> newGame() async {
    newGameCalls++;
  }

  @override
  void suspend() => suspendCalls++;

  @override
  void resume() => resumeCalls++;

  @override
  Future<void> dispose() async {}
}
