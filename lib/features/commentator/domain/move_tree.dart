import 'package:dartchess/dartchess.dart';

import '../../../core/chess/san_moves.dart';
import '../../../engine/domain/engine_models.dart';
import '../../../engine/domain/engine_position.dart';
import '../../../engine/domain/move_classifier.dart';

/// One position in the studied game. The root carries no move; every other
/// node is reached by playing [move] ([san]) from its [parent].
///
/// Analysis results ([quality], [bestUci], [bestSan], [evalBest], [evalAfter])
/// are mutable and cached in place: the tree is a mutable aggregate owned by
/// the commentator controller, which bumps a version counter in its immutable
/// state whenever the tree changes (see commentator_controller.dart).
class MoveTreeNode {
  MoveTreeNode({
    required this.id,
    required this.positionFen,
    this.parent,
    this.san,
    this.move,
    this.mover,
    this.clk,
    this.comments = const [],
    this.nags = const [],
  });

  /// Stable id (monotonic counter, 0 = root).
  final int id;

  /// FEN of the position AFTER [move] (for the root: the starting position).
  final String positionFen;

  final MoveTreeNode? parent;

  /// SAN of the move leading here (null on root), including +/# suffixes.
  final String? san;

  /// The move leading here (null on root), always in the form that says where
  /// the piece LANDED — castling is the king's own move, never dartchess's
  /// king-takes-rook normalization. The quality badge and the last-move
  /// highlight both anchor on its `to`.
  final NormalMove? move;

  /// 'w' or 'b': who played [move] (null on root).
  final String? mover;

  /// Remaining clock from a `[%clk]` comment on this move, if any.
  final Duration? clk;

  /// Text comments attached to the move in the PGN.
  final List<String> comments;

  /// Numeric Annotation Glyphs imported from the PGN.
  final List<int> nags;

  /// First child = mainline continuation; the rest are variations.
  final List<MoveTreeNode> children = [];

  // ---- mutable analysis cache ----
  MoveQuality? quality;
  String? bestUci;
  String? bestSan;

  /// Eval of the parent position assuming the engine's best move (White POV).
  EvalScore? evalBest;

  /// Eval of this node's position, after the played move (White POV).
  EvalScore? evalAfter;

  bool get isRoot => move == null;
  bool get analyzed => quality != null;
}

/// Why a text is not a game the Studio can open — what the import sheet tells
/// the reader, in their language, instead of leaving Import greyed out.
enum PgnProblem {
  /// dartchess could not read the text as PGN at all.
  unreadable,

  /// The text read as PGN but held no moves ("not a chess game" does).
  noMoves,

  /// A move is not legal where the game plays it ([PgnImportError.detail]).
  illegalMove,

  /// The `[FEN]` tag sets up a position Stockfish would refuse.
  refusedPosition,
}

/// A [FormatException] that says which [PgnProblem] stopped the import.
///
/// Still a [FormatException], so every caller that only needs "did it parse"
/// keeps catching what it always caught.
class PgnImportError extends FormatException {
  const PgnImportError(this.problem, String message, {this.detail})
      : super(message);

  final PgnProblem problem;

  /// The offending SAN for [PgnProblem.illegalMove]; null otherwise.
  final String? detail;
}

/// The imported game as a tree of positions, plus its PGN headers.
///
/// Pure domain object: no engine, no I/O. Building replays every SAN through
/// dartchess, so an unparseable or illegal movetext throws [PgnImportError].
class MoveTree {
  MoveTree._(this.root, this.headers, this._nextId) {
    _index(root);
  }

  final MoveTreeNode root;

  /// PGN tag pairs (White, Black, Event, Result, FEN...).
  final Map<String, String> headers;

  final Map<int, MoveTreeNode> _byId = {};
  int _nextId;

  /// Parses [pgnText] (a full PGN or a bare move list) into a tree.
  ///
  /// Throws [FormatException] when no legal moves can be extracted, or when
  /// a `[FEN]` tag sets up a position Stockfish would refuse. A study is
  /// analysed by the engine, and Stockfish 19 exits the app's process on a
  /// position it refuses — so such a game is turned away at the door,
  /// where the import sheet can say so, instead of in the Studio.
  factory MoveTree.fromPgn(String pgnText) {
    final trimmed = pgnText.trim();
    if (trimmed.isEmpty) {
      throw const PgnImportError(PgnProblem.noMoves, 'Empty input');
    }
    final PgnGame<PgnNodeData> game;
    try {
      game = PgnGame.parsePgn(trimmed);
    } catch (e) {
      throw PgnImportError(PgnProblem.unreadable, '$e');
    }
    final headers = Map<String, String>.from(game.headers);
    final Position startPos;
    try {
      startPos = headers.containsKey('FEN')
          ? engineAcceptedPosition(headers['FEN']!)
          : Chess.initial;
    } on EngineRejectedPosition catch (e) {
      throw PgnImportError(PgnProblem.refusedPosition, e.reason);
    }

    var nextId = 0;
    final root =
        MoveTreeNode(id: nextId++, positionFen: startPos.fen);

    void walk(
        PgnNode<PgnNodeData> pgnNode, MoveTreeNode parent, Position pos) {
      for (final child in pgnNode.children) {
        final data = child.data;
        final move = legalMoveFromSan(pos, data.san);
        if (move == null) {
          throw PgnImportError(
            PgnProblem.illegalMove,
            'Illegal move: ${data.san}',
            detail: data.san,
          );
        }
        final (nextPos, san) = pos.makeSan(move);
        Duration? clk;
        final texts = <String>[];
        for (final raw in [...?data.startingComments, ...?data.comments]) {
          final parsed = PgnComment.fromPgn(raw);
          clk ??= parsed.clock;
          final text = parsed.text?.trim();
          if (text != null && text.isNotEmpty) texts.add(text);
        }
        final node = MoveTreeNode(
          id: nextId++,
          positionFen: nextPos.fen,
          parent: parent,
          san: san,
          move: move,
          mover: pos.turn == Side.white ? 'w' : 'b',
          clk: clk,
          comments: texts,
          nags: data.nags ?? const [],
        );
        parent.children.add(node);
        walk(child, node, nextPos);
      }
    }

    walk(game.moves, root, startPos);
    if (root.children.isEmpty) {
      throw const PgnImportError(PgnProblem.noMoves, 'No moves found');
    }
    return MoveTree._(root, headers, nextId);
  }

  void _index(MoveTreeNode node) {
    _byId[node.id] = node;
    for (final child in node.children) {
      _index(child);
    }
  }

  MoveTreeNode? nodeById(int id) => _byId[id];

  /// A tag pair's value, trimmed, with the PGN standard's `?` placeholder read
  /// as absent.
  ///
  /// dartchess supplies `?` defaults for Event, Site, Round, White and Black
  /// whenever the input is a bare move list, so a game pasted as `1. e4 e5`
  /// arrives claiming to be "? – ?". Every reader of [headers] needs that rule
  /// and none of them should carry its own copy.
  String header(String key) {
    final value = (headers[key] ?? '').trim();
    return value == '?' ? '' : value;
  }

  /// Root plus every mainline descendant (always following children.first).
  List<MoveTreeNode> mainline() {
    final out = <MoveTreeNode>[root];
    var cur = root;
    while (cur.children.isNotEmpty) {
      cur = cur.children.first;
      out.add(cur);
    }
    return out;
  }

  /// True when [node] is reached from the root using only first children.
  bool onMainline(MoveTreeNode node) {
    var cur = node;
    while (cur.parent != null) {
      if (cur.parent!.children.first != cur) return false;
      cur = cur.parent!;
    }
    return true;
  }

  /// The deepest ancestor of [node] (possibly itself) on the mainline.
  MoveTreeNode mainlineAncestor(MoveTreeNode node) {
    var cur = node;
    while (!onMainline(cur)) {
      cur = cur.parent!;
    }
    return cur;
  }

  /// Ply of [node] (0 = root, 1 = after the first move...).
  int plyOf(MoveTreeNode node) {
    var ply = 0;
    for (var cur = node; cur.parent != null; cur = cur.parent!) {
      ply++;
    }
    return ply;
  }

  /// The moves that lead from the start to [node], in play order, the root
  /// excluded — the line on the board, and nothing past it. Inside a side
  /// line that is the mainline up to the branch, then the branch.
  List<MoveTreeNode> lineTo(MoveTreeNode node) {
    final line = <MoveTreeNode>[];
    for (var cur = node; cur.parent != null; cur = cur.parent!) {
      line.add(cur);
    }
    return line.reversed.toList();
  }

  /// Fullmove number of the move leading to [node] (from the parent's FEN,
  /// so it is correct for games starting from an arbitrary FEN).
  int moveNumberOf(MoveTreeNode node) {
    final parentFen = node.parent?.positionFen;
    if (parentFen == null) return 0;
    final fields = parentFen.split(' ');
    return fields.length >= 6 ? (int.tryParse(fields[5]) ?? 1) : 1;
  }

  /// The child of [node] whose SAN matches [san] (ignoring +/# suffixes).
  MoveTreeNode? childBySan(MoveTreeNode node, String san) {
    final want = cleanSan(san);
    for (final child in node.children) {
      if (cleanSan(child.san!) == want) return child;
    }
    return null;
  }

  /// Appends a new child under [parent] (mainline continuation when [parent]
  /// has no children yet, a variation otherwise) and returns it.
  MoveTreeNode addChild(
    MoveTreeNode parent, {
    required NormalMove move,
    required String san,
    required String positionFen,
    required String mover,
  }) {
    final node = MoveTreeNode(
      id: _nextId++,
      positionFen: positionFen,
      parent: parent,
      san: san,
      move: move,
      mover: mover,
    );
    parent.children.add(node);
    _byId[node.id] = node;
    return node;
  }

  // ---- clocks ----

  /// The most recent `[%clk]` value for [side] ('w'/'b') on the path from the
  /// root down to [node].
  Duration? clockFor(MoveTreeNode node, String side) {
    for (MoveTreeNode? cur = node; cur != null; cur = cur.parent) {
      if (cur.mover == side && cur.clk != null) return cur.clk;
    }
    return null;
  }

  // ---- node path (persistence) ----

  /// Child-index path from the root to [node] ([] = root).
  List<int> pathIndices(MoveTreeNode node) {
    final path = <int>[];
    for (var cur = node; cur.parent != null; cur = cur.parent!) {
      path.add(cur.parent!.children.indexOf(cur));
    }
    return path.reversed.toList();
  }

  /// Follows [path] from the root, stopping early if an index is out of
  /// range (e.g. the tree changed since the path was saved).
  MoveTreeNode nodeAtPath(List<int> path) {
    var cur = root;
    for (final index in path) {
      if (index < 0 || index >= cur.children.length) break;
      cur = cur.children[index];
    }
    return cur;
  }

  // ---- serialization ----

  /// Serializes the tree (including user-created variations, comments, NAGs
  /// and clocks) back to PGN, so a persisted session survives a restart.
  String toPgn() {
    final buffer = StringBuffer();
    headers.forEach((key, value) {
      if (value.isEmpty) return;
      buffer.writeln('[$key "${value.replaceAll('"', "'")}"]');
    });
    if (headers.isNotEmpty) buffer.writeln();
    final moves = StringBuffer();
    _writeContinuation(moves, root, forceNumber: true);
    moves.write(headers['Result'] ?? '*');
    buffer.writeln(moves.toString().trim());
    return buffer.toString();
  }

  void _writeContinuation(StringBuffer b, MoveTreeNode parent,
      {required bool forceNumber}) {
    if (parent.children.isEmpty) return;
    final main = parent.children.first;
    var interrupted = _writeMove(b, main, forceNumber: forceNumber);
    for (var i = 1; i < parent.children.length; i++) {
      final variation = parent.children[i];
      b.write('(');
      _writeMove(b, variation, forceNumber: true);
      _writeContinuation(b, variation, forceNumber: false);
      b.write(') ');
      interrupted = true;
    }
    _writeContinuation(b, main, forceNumber: interrupted);
  }

  /// Writes one move token (number, SAN, NAGs, comment). Returns true when a
  /// comment was emitted (the next black move then needs a number).
  bool _writeMove(StringBuffer b, MoveTreeNode node,
      {required bool forceNumber}) {
    final white = node.mover == 'w';
    final number = moveNumberOf(node);
    if (white) {
      b.write('$number. ');
    } else if (forceNumber) {
      b.write('$number... ');
    }
    b.write('${node.san} ');
    for (final nag in node.nags) {
      b.write('\$$nag ');
    }
    final parts = <String>[
      ...node.comments.map((c) => c.replaceAll(RegExp(r'[{}]'), ' ').trim()),
      if (node.clk != null) '[%clk ${_formatClk(node.clk!)}]',
    ];
    if (parts.isEmpty) return false;
    b.write('{${parts.join(' ')}} ');
    return true;
  }

  static String _formatClk(Duration d) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
}
