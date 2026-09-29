import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/chess/castling_moves.dart';
import '../../../core/chess/tolerant_position.dart';
import '../../../core/layout/mode_shell.dart';
import '../../../engine/application/engine_providers.dart';
import '../../../engine/domain/engine_models.dart';
import '../../../engine/domain/engine_service.dart';
import '../../../engine/domain/move_classifier.dart';
import '../data/commentator_store.dart';
import '../domain/move_tree.dart';

/// Per-side display metadata (renameable name, picked photo).
class PlayerInfo {
  const PlayerInfo({this.name = '', this.photoPath});

  final String name;
  final String? photoPath;

  PlayerInfo copyWith({String? name, String? Function()? photoPath}) =>
      PlayerInfo(
        name: name ?? this.name,
        photoPath: photoPath != null ? photoPath() : this.photoPath,
      );
}

/// How the studied game ended (drives the recap headline).
enum GameResultKind { checkmate, stalemate, draw, whiteWins, blackWins }

/// Outcome of the game: [kind] plus the winner for checkmates.
class GameResult {
  const GameResult(this.kind, {this.winner});

  final GameResultKind kind;

  /// 'w' or 'b' for checkmate results.
  final String? winner;
}

/// The recap modal's data: null result headline is impossible — the recap
/// only exists for finished games (or on explicit request with a PGN result).
class RecapState {
  const RecapState({
    required this.computing,
    this.result,
    this.analyzedCount = 0,
    this.totalCount = 0,
    this.whiteAccuracy,
    this.blackAccuracy,
  });

  final bool computing;
  final GameResult? result;
  final int analyzedCount;
  final int totalCount;
  final double? whiteAccuracy;
  final double? blackAccuracy;
}

/// Immutable UI state. The [tree] is a mutable aggregate (nodes cache their
/// analysis in place); every mutation goes through the controller, which
/// bumps [version] so listeners rebuild. This keeps analysis caching cheap
/// (no tree copies per engine result) while state transitions stay explicit
/// and testable.
class CommentatorState {
  const CommentatorState({
    this.tree,
    this.currentNodeId = 0,
    this.version = 0,
    this.white = const PlayerInfo(),
    this.black = const PlayerInfo(),
    this.orientation = Side.white,
    this.recap,
  });

  final MoveTree? tree;
  final int currentNodeId;
  final int version;
  final PlayerInfo white;
  final PlayerInfo black;
  final Side orientation;

  /// Non-null while the recap modal is open.
  final RecapState? recap;


  bool get hasGame => tree != null;

  MoveTreeNode? get currentNode => tree?.nodeById(currentNodeId);

  bool get offMainline {
    final node = currentNode;
    return node != null && !(tree?.onMainline(node) ?? true);
  }

  CommentatorState copyWith({
    MoveTree? Function()? tree,
    int? currentNodeId,
    int? version,
    PlayerInfo? white,
    PlayerInfo? black,
    Side? orientation,
    RecapState? Function()? recap,
  }) =>
      CommentatorState(
        tree: tree != null ? tree() : this.tree,
        currentNodeId: currentNodeId ?? this.currentNodeId,
        version: version ?? this.version,
        white: white ?? this.white,
        black: black ?? this.black,
        orientation: orientation ?? this.orientation,
        recap: recap != null ? recap() : this.recap,
      );

  /// Field-wise equality so no-op state copies skip listener rebuilds.
  /// Replaced-not-mutated aggregates (tree, players, recap) compare
  /// by identity; in-place tree mutations are carried by [version].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentatorState &&
          identical(tree, other.tree) &&
          currentNodeId == other.currentNodeId &&
          version == other.version &&
          identical(white, other.white) &&
          identical(black, other.black) &&
          orientation == other.orientation &&
          identical(recap, other.recap);

  @override
  int get hashCode => Object.hash(
        identityHashCode(tree),
        currentNodeId,
        version,
        identityHashCode(white),
        identityHashCode(black),
        orientation,
        identityHashCode(recap),
      );
}

final commentatorControllerProvider =
    NotifierProvider<CommentatorController, CommentatorState>(
        CommentatorController.new);

/// Orchestrates the Commentator Studio: PGN import, tree navigation and
/// forking, per-node auto-analysis, the end-of-game recap, and persistence
/// through [CommentatorStore].
class CommentatorController extends Notifier<CommentatorState> {
  CancellationToken? _navToken;
  CancellationToken? _recapToken;
  int? _recapShownFor;
  Completer<void> _restored = Completer<void>();

  /// Position-eval memo: ply N's post-move eval is ply N+1's parent eval,
  /// so caching each result halves the steady-state analysis cost. Keyed by
  /// full FEN; crudely capped (cleared) to bound memory.
  static const _evalCacheCap = 256;
  final Map<String, ({EvalScore score, String? bestUci})> _evalCache = {};

  /// Nodes whose analysis reached a terminal state — including "engine gave
  /// no usable scores", which leaves [MoveTreeNode.quality] null. Keeps the
  /// UI from spinning forever on such nodes.
  final Set<int> _analyzedNodeIds = {};

  /// Completes when the latest navigation-triggered analysis has finished
  /// (or was cancelled). Exposed for tests.
  @visibleForTesting
  Future<void> analysisDone = Future.value();

  /// Completes when the latest recap accuracy computation has finished.
  @visibleForTesting
  Future<void> recapDone = Future.value();

  /// Completes once the initial session restore attempt has finished.
  @visibleForTesting
  Future<void> get restored => _restored.future;

  @override
  CommentatorState build() {
    _restored = Completer<void>();
    ref.onDispose(() {
      _navToken?.cancel();
      _recapToken?.cancel();
    });
    Future.microtask(_restore);
    return const CommentatorState();
  }

  @override
  bool updateShouldNotify(
          CommentatorState previous, CommentatorState next) =>
      previous != next;

  EngineService get _engine => ref.read(engineServiceProvider);
  CommentatorStore get _store => ref.read(commentatorStoreProvider);

  // ============ import / close ============

  /// Parses [text] and loads it as the studied game.
  ///
  /// Throws [FormatException] when the text is not a game. It used to catch
  /// that into an error field on the state, which no screen reads any more:
  /// the library's import sheet parses before it stores, so it is the one
  /// caller that can be handed bad input, and it is the one place a person
  /// can be told. Everything else here — a bundled game, a game already in
  /// the library — was parsed before it got this far.
  void loadPgn(String text) {
    final tree = MoveTree.fromPgn(text);
    _recapShownFor = null;
    _navToken?.cancel();
    _recapToken?.cancel();
    _resetAnalysisCaches();
    state = CommentatorState(
      tree: tree,
      currentNodeId: tree.root.id,
      version: state.version + 1,
      white: PlayerInfo(name: tree.header('White')),
      black: PlayerInfo(name: tree.header('Black')),
    );
    _persist();
  }

  /// Back to the import view (confirm-free) and clears the saved session.
  void closeGame() {
    _navToken?.cancel();
    _recapToken?.cancel();
    _recapShownFor = null;
    _resetAnalysisCaches();
    state = CommentatorState(version: state.version + 1);
    unawaited(_store.clear());
  }

  /// Drops the FEN-eval memo and the terminal-analysis markers — required
  /// whenever the studied tree is replaced.
  void _resetAnalysisCaches() {
    _evalCache.clear();
    _analyzedNodeIds.clear();
  }

  // ============ navigation ============

  void goToStart() {
    final tree = state.tree;
    if (tree != null) _navigateTo(tree.root);
  }

  void back() {
    final parent = state.currentNode?.parent;
    if (parent != null) _navigateTo(parent);
  }

  void forward() {
    final node = state.currentNode;
    if (node != null && node.children.isNotEmpty) {
      _navigateTo(node.children.first);
    }
  }

  void goToEnd() {
    var node = state.currentNode;
    if (node == null) return;
    while (node!.children.isNotEmpty) {
      node = node.children.first;
    }
    _navigateTo(node);
  }

  /// Pops back to the deepest mainline ancestor of the current node.
  void returnToMainline() {
    final tree = state.tree;
    final node = state.currentNode;
    if (tree == null || node == null) return;
    _navigateTo(tree.mainlineAncestor(node));
  }

  void goToNode(int id) {
    final node = state.tree?.nodeById(id);
    if (node != null) _navigateTo(node);
  }

  void flipOrientation() {
    state = state.copyWith(
      orientation:
          state.orientation == Side.white ? Side.black : Side.white,
    );
  }

  // ============ board moves (explore / fork) ============

  /// A move played on the board: navigate into a matching child, or create a
  /// new variation node and enter it.
  void playMove(NormalMove move) {
    final tree = state.tree;
    final node = state.currentNode;
    if (tree == null || node == null) return;
    final position = positionFromFen(node.positionFen);
    if (!position.isLegal(move)) return;
    // The tree's one canonical form: castling says where the KING went, so
    // the badge and the last-move highlight land on the king.
    final landed = kingCastlingForm(position, move);
    final (nextPosition, san) = position.makeSan(landed);

    final existing = tree.childBySan(node, san);
    if (existing != null) {
      _navigateTo(existing);
      return;
    }
    final child = tree.addChild(
      node,
      move: landed,
      san: san,
      positionFen: nextPosition.fen,
      mover: position.turn == Side.white ? 'w' : 'b',
    );
    _navigateTo(child);
  }

  // ============ players ============

  void setPlayerName(String side, String name) {
    final info = PlayerInfo(name: name.trim());
    state = side == 'w'
        ? state.copyWith(
            white: state.white.copyWith(name: info.name))
        : state.copyWith(
            black: state.black.copyWith(name: info.name));
    _persist();
  }

  /// Copies a freshly picked image into app storage and shows it.
  Future<void> setPlayerPhoto(String side, String sourcePath) async {
    try {
      final stored = await _store.storePhoto(side, sourcePath);
      state = side == 'w'
          ? state.copyWith(white: state.white.copyWith(photoPath: () => stored))
          : state.copyWith(black: state.black.copyWith(photoPath: () => stored));
      _persist();
    } catch (_) {
      // Keep the previous photo when the copy fails.
    }
  }

  // ============ recap ============

  /// Opens the recap modal and lazily analyzes any unanalyzed mainline nodes
  /// (batch priority) before computing each side's Accuracy%.
  void openRecap() {
    final tree = state.tree;
    if (tree == null) return;
    _recapToken?.cancel();
    final token = _recapToken = CancellationToken();
    final mainlineMoves = tree.mainline().length - 1;
    state = state.copyWith(
      recap: () => RecapState(
        computing: true,
        result: gameResult(),
        totalCount: mainlineMoves,
        analyzedCount: tree
            .mainline()
            .where((n) => !n.isRoot && _isNodeAnalyzed(n))
            .length,
      ),
    );
    recapDone = _computeRecap(tree, token);
  }

  void closeRecap() {
    _recapToken?.cancel();
    if (state.recap != null) {
      state = state.copyWith(recap: () => null);
    }
  }

  Future<void> _computeRecap(MoveTree tree, CancellationToken token) async {
    final result = gameResult();
    final mainline = tree.mainline();
    final moves = mainline.where((n) => !n.isRoot).toList();
    for (final node in moves) {
      if (token.isCancelled) return;
      if (_isNodeAnalyzed(node)) continue;
      await _analyzeNode(node, token, EnginePriority.batch);
      if (token.isCancelled) return;
      state = state.copyWith(
        version: state.version + 1,
        recap: () => RecapState(
          computing: true,
          result: result,
          totalCount: moves.length,
          analyzedCount: moves.where(_isNodeAnalyzed).length,
        ),
      );
    }
    double? accuracyFor(String side) => MoveClassifier.accuracy([
          for (final n in moves)
            if (n.mover == side && n.quality != null) n.quality!,
        ]);
    if (token.isCancelled) return;
    state = state.copyWith(
      version: state.version + 1,
      recap: () => RecapState(
        computing: false,
        result: result,
        totalCount: moves.length,
        analyzedCount: moves.where(_isNodeAnalyzed).length,
        whiteAccuracy: accuracyFor('w'),
        blackAccuracy: accuracyFor('b'),
      ),
    );
  }

  /// The game's outcome: terminal final position first, else the PGN
  /// `[Result]` tag; null when the game simply stops mid-way.
  GameResult? gameResult() {
    final tree = state.tree;
    if (tree == null) return null;
    final last = tree.mainline().last;
    final position = positionFromFen(last.positionFen);
    if (position.isCheckmate) {
      return GameResult(GameResultKind.checkmate,
          winner: position.turn == Side.white ? 'b' : 'w');
    }
    if (position.isStalemate) return const GameResult(GameResultKind.stalemate);
    if (position.isGameOver) return const GameResult(GameResultKind.draw);
    return switch ((tree.headers['Result'] ?? '').trim()) {
      '1-0' => const GameResult(GameResultKind.whiteWins),
      '0-1' => const GameResult(GameResultKind.blackWins),
      '1/2-1/2' => const GameResult(GameResultKind.draw),
      _ => null,
    };
  }


  // ============ internals ============

  void _navigateTo(MoveTreeNode node, {bool persist = true}) {
    state = state.copyWith(
      currentNodeId: node.id,
      version: state.version + 1,
    );
    if (persist) _persist();
    _afterNavigate(node);
  }

  /// Whether [node]'s analysis reached a terminal state: a quality verdict,
  /// or a definitive "engine yielded no usable scores".
  bool _isNodeAnalyzed(MoveTreeNode node) =>
      node.analyzed || _analyzedNodeIds.contains(node.id);

  /// Kicks the current node's pending analysis (and the auto-recap check).
  /// Called by the studio screen when its tab becomes visible, since
  /// [_afterNavigate] skips all engine work while the tab is hidden.
  void ensureCurrentAnalyzed() {
    final node = state.currentNode;
    if (node == null || node.isRoot || _isNodeAnalyzed(node)) return;
    _afterNavigate(node);
  }

  void _afterNavigate(MoveTreeNode node) {
    // Engine work only while the Studio tab is showing — a restored session
    // or cross-tab navigation must not burn battery for an invisible view;
    // [ensureCurrentAnalyzed] catches up on the next activation.
    if (ref.read(activeTabProvider) != AppTab.studio) return;
    _navToken?.cancel();
    if (!node.isRoot && !_isNodeAnalyzed(node)) {
      final token = _navToken = CancellationToken();
      analysisDone = _analyzeNode(node, token, EnginePriority.interactive)
          .then((_) {
        if (!token.isCancelled && _isNodeAnalyzed(node)) {
          state = state.copyWith(version: state.version + 1);
        }
      });
    }
    _maybeAutoRecap(node);
  }

  /// Auto-open the recap once per final node when the user reaches the end
  /// of a finished mainline.
  void _maybeAutoRecap(MoveTreeNode node) {
    final tree = state.tree;
    if (tree == null || node.isRoot) return;
    if (node.children.isNotEmpty) return;
    if (!tree.onMainline(node)) return;
    if (gameResult() == null) return;
    if (_recapShownFor == node.id) return;
    _recapShownFor = node.id;
    openRecap();
  }

  /// Classifies [node]'s move: engine eval of the parent position (best move
  /// + score) vs the eval after the played move, delta through
  /// [MoveClassifier]; engine-best moves get the sacrifice check for the
  /// brilliant upgrade. Results are cached on the node, position evals in
  /// [_evalCache]. Every non-cancelled exit marks the node terminally
  /// analyzed — even when the engine yields no usable scores — so the UI
  /// never waits forever.
  Future<void> _analyzeNode(
    MoveTreeNode node,
    CancellationToken token,
    EnginePriority priority,
  ) async {
    final parent = node.parent;
    final mover = node.mover;
    if (parent == null || mover == null) return;
    // Read the engine before any await: the notifier may be disposed while
    // a search is in flight, and ref reads would then throw.
    final engine = _engine;
    try {
      EvalScore? best;
      String? bestUci;
      final cachedParent = _evalCache[parent.positionFen];
      if (cachedParent != null) {
        best = cachedParent.score;
        bestUci = cachedParent.bestUci;
      } else {
        final bestResult = await engine.analyse(
          parent.positionFen,
          limit: const SearchLimit.movetime(250),
          priority: priority,
          token: token,
        );
        best = bestResult.score;
        bestUci = bestResult.uci;
        if (best != null) {
          _cacheEval(parent.positionFen, best, bestUci);
        }
      }
      EvalScore? after = _evalCache[node.positionFen]?.score;
      if (after == null) {
        final afterResult = await engine.analyse(
          node.positionFen,
          limit: const SearchLimit.movetime(250),
          priority: priority,
          token: token,
        );
        after = afterResult.score;
        if (after != null) {
          _cacheEval(node.positionFen, after, afterResult.uci);
        }
        after ??= _terminalScore(node);
      }
      if (best == null || after == null) {
        // No usable scores — terminal anyway, or the spinner never stops.
        _analyzedNodeIds.add(node.id);
        return;
      }

      final delta =
          MoveClassifier.deltaCp(best: best, after: after, moverColor: mover);
      var quality = MoveClassifier.classify(delta);
      if (quality == MoveQuality.best && _offersMaterial(node)) {
        final sacrifice = await _isSacrifice(engine, node, token, priority);
        quality = MoveClassifier.withBrilliancy(quality, sacrifice: sacrifice);
      }
      node.quality = quality;
      node.evalBest = best;
      node.evalAfter = after;
      node.bestUci = bestUci;
      node.bestSan = _sanForUci(parent.positionFen, bestUci);
      _analyzedNodeIds.add(node.id);
    } on EngineRequestCancelled {
      // Superseded by a newer navigation — leave the node unanalyzed.
    } on EngineRejectedPosition {
      // A position Stockfish would refuse never reaches it; the import
      // already turns such games away, so this is the backstop. Terminal,
      // like "no usable scores": the spinner must stop.
      _analyzedNodeIds.add(node.id);
    }
  }

  void _cacheEval(String fen, EvalScore score, String? bestUci) {
    if (_evalCache.length >= _evalCacheCap) _evalCache.clear();
    _evalCache[fen] = (score: score, bestUci: bestUci);
  }

  /// Static pre-filter for the sacrifice probe: a genuine sacrifice always
  /// leaves a mover piece worth >= [MoveClassifier.sacrificeThresholdCp]
  /// capturable by the opponent's reply, so when no such capture exists the
  /// 60ms probe is skipped (the vast majority of quiet engine-best moves).
  static bool _offersMaterial(MoveTreeNode node) {
    final position = positionFromFen(node.positionFen);
    final moverSide = node.mover == 'w' ? Side.white : Side.black;
    for (final entry in position.legalMoves.entries) {
      for (final to in entry.value.squares) {
        final piece = position.board.pieceAt(to);
        if (piece != null &&
            piece.color == moverSide &&
            (_pieceValues[piece.role] ?? 0) >=
                MoveClassifier.sacrificeThresholdCp) {
          return true;
        }
      }
    }
    return false;
  }

  /// Synthetic eval for terminal positions the engine won't score: mate is a
  /// win for the mover, any other game end scores as equal.
  EvalScore? _terminalScore(MoveTreeNode node) {
    final position = positionFromFen(node.positionFen);
    if (position.isCheckmate) {
      return EvalScore.cp(node.mover == 'w' ? 100000 : -100000);
    }
    if (position.isGameOver) return const EvalScore.cp(0);
    return null;
  }

  /// True when the mover's non-king material after the opponent's engine
  /// reply (movetime 60 on the post-move position) drops by >= 150cp.
  Future<bool> _isSacrifice(
    EngineService engine,
    MoveTreeNode node,
    CancellationToken token,
    EnginePriority priority,
  ) async {
    final mover = node.mover!;
    final before =
        _materialCp(positionFromFen(node.parent!.positionFen).board, mover);
    var after = before;
    final reply = await engine.analyse(
      node.positionFen,
      limit: const SearchLimit.movetime(60),
      priority: priority,
      token: token,
    );
    final uci = reply.uci;
    if (uci != null) {
      try {
        final position = positionFromFen(node.positionFen);
        final move = NormalMove.fromUci(uci);
        if (position.isLegal(move)) {
          after = _materialCp(position.play(move).board, mover);
        }
      } on FormatException {
        // Unparseable reply — treat as no material change.
      }
    }
    return MoveClassifier.isSacrifice(
      moverMaterialBeforeCp: before,
      moverMaterialAfterReplyCp: after,
    );
  }

  static const _pieceValues = {
    Role.pawn: 100,
    Role.knight: 320,
    Role.bishop: 330,
    Role.rook: 500,
    Role.queen: 900,
  };

  static int _materialCp(Board board, String color) {
    final side = color == 'w' ? Side.white : Side.black;
    var total = 0;
    for (final entry in _pieceValues.entries) {
      total += board.piecesOf(side, entry.key).size * entry.value;
    }
    return total;
  }

  static String? _sanForUci(String fen, String? uci) {
    if (uci == null) return null;
    try {
      final position = positionFromFen(fen);
      final move = NormalMove.fromUci(uci);
      if (!position.isLegal(move)) return null;
      return position.makeSan(move).$2;
    } on FormatException {
      return null;
    }
  }

  // ============ persistence ============

  Future<void> _restore() async {
    try {
      final session = await _store.load();
      if (session == null) return;
      final tree = MoveTree.fromPgn(session.pgn);
      final node = tree.nodeAtPath(session.path);
      _resetAnalysisCaches();
      state = CommentatorState(
        tree: tree,
        currentNodeId: node.id,
        version: state.version + 1,
        white: PlayerInfo(
          name: session.whiteName.isNotEmpty
              ? session.whiteName
              : tree.header('White'),
          photoPath: session.whitePhotoPath,
        ),
        black: PlayerInfo(
          name: session.blackName.isNotEmpty
              ? session.blackName
              : tree.header('Black'),
          photoPath: session.blackPhotoPath,
        ),
      );
      // Deliberately no _afterNavigate here: a restored session (possibly a
      // finished game on another tab) must not start engine work at app
      // launch. StudioScreen calls [ensureCurrentAnalyzed] on activation.
    } on FormatException {
      // A saved game that no longer parses — one set up on a position the
      // engine refuses, say — can never load again: forget it rather than
      // keep it on disk.
      unawaited(_store.clear());
    } catch (_) {
      // Unreadable session — stay on the import view.
    } finally {
      _restored.complete();
    }
  }

  void _persist() {
    final tree = state.tree;
    final node = state.currentNode;
    if (tree == null || node == null) return;
    unawaited(_store.save(CommentatorSession(
      pgn: tree.toPgn(),
      whiteName: state.white.name,
      blackName: state.black.name,
      whitePhotoPath: state.white.photoPath,
      blackPhotoPath: state.black.photoPath,
      path: tree.pathIndices(node),
    )));
  }
}
