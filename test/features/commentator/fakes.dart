import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/engine_service.dart';
import 'package:karpachess/features/commentator/data/commentator_store.dart';

/// Scripted engine: answers `analyse` by FEN lookup via [onSearch], which
/// may also throw — an [EngineRejectedPosition], say — to script a refusal.
class FakeEngineService implements EngineService {
  FakeEngineService({this.onSearch});

  EngineMove Function(String fen, SearchLimit limit)? onSearch;

  /// (fen, movetimeMs) of every analyse call, in order.
  final List<(String, int?)> calls = [];

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
    calls.add((fen, limit.movetimeMs));
    return onSearch?.call(fen, limit) ?? defaultMove;
  }

  @override
  Future<EngineMove> bestMove(
    String startFen,
    List<String> moves,
    EngineStrength strength, {
    CancellationToken? token,
  }) async =>
      defaultMove;

  @override
  Future<void> newGame() async {}

  @override
  void suspend() {}

  @override
  void resume() {}

  @override
  Future<void> dispose() async {}
}

/// In-memory store so tests never touch path_provider.
class MemoryCommentatorStore implements CommentatorStore {
  MemoryCommentatorStore({this.session});

  CommentatorSession? session;
  int saveCount = 0;
  int clearCount = 0;
  int drawingsSaveCount = 0;
  final List<(String, String)> storedPhotos = [];

  @override
  Future<CommentatorSession?> load() async => session;

  @override
  Future<void> save(CommentatorSession s) async {
    // Mirror FileCommentatorStore: a save without drawings preserves the
    // previously saved ones instead of wiping them.
    session = s.drawings == null && session?.drawings != null
        ? s.copyWith(drawings: session!.drawings)
        : s;
    saveCount++;
  }

  @override
  Future<void> saveDrawings(
      Map<String, List<Map<String, Object?>>> drawings) async {
    drawingsSaveCount++;
    final current = session;
    if (current == null) return;
    session = current.copyWith(drawings: drawings);
  }

  @override
  Future<void> clear() async {
    session = null;
    clearCount++;
  }

  @override
  Future<String> storePhoto(String side, String sourcePath) async {
    storedPhotos.add((side, sourcePath));
    return '/fake/photos/$side.jpg';
  }
}
