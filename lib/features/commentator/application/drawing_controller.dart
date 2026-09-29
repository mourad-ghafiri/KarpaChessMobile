import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/commentator_store.dart';
import '../domain/drawing_shapes.dart';
import '../domain/move_tree.dart';
import 'commentator_controller.dart';

/// The mobile drawing tools. [select] is the neutral pointer: tap shapes to
/// select, drag to move, tap a selected text again to edit. The rest create
/// shapes — unlike the web (where arrows/highlights ride on right-click),
/// touch has no second button, so arrow and highlight are explicit tools.
enum DrawTool { select, arrow, highlight, pen, text, rect }

/// Which mode owns a drawing layer. Studio scopes shapes per move-tree node
/// and persists them with the session; every other mode draws on a single
/// ephemeral layer that its screen resets when the position context changes.
enum DrawingScope { studio, play, journey, puzzles }

/// Stable per-node key for shape scoping and persistence: the node's
/// child-index path joined with '.' ('' = root). Deliberately NOT the
/// transient node id: ids are re-assigned when the PGN is re-parsed, so
/// keying by id loses every drawing on reload.
String? nodeKeyOf(CommentatorState state) {
  final tree = state.tree;
  final node = state.currentNode;
  if (tree == null || node == null) return null;
  return tree.pathIndices(node).join('.');
}

/// Immutable drawing-layer state: the armed tool, active style, and every
/// node's shape list (keyed by [nodeKeyOf]).
class DrawingState {
  const DrawingState({
    this.active = false,
    this.tool,
    this.colorHex = defaultColorHex,
    this.strokeWidth = defaultStrokeWidth,
    this.shapes = const {},
    this.selectedIndex,
    this.draggingSelection = false,
    this.overTrash = false,
  });

  /// The palette's first hue, at the default stroke width.
  static const defaultColorHex = '#c25a3c';
  static const defaultStrokeWidth = 0.08;

  /// Drawing mode: while true the board is annotation-only (no moves) and
  /// game timers are paused by the hosting screen.
  final bool active;

  /// Null = no tool armed: the board receives every gesture, as today.
  final DrawTool? tool;

  final String colorHex;

  /// Board units (0.03–0.24).
  final double strokeWidth;

  final Map<String, List<DrawShape>> shapes;

  /// Index (into the current key's list) of the selected shape, if any —
  /// selection exists only while drawing mode is active.
  final int? selectedIndex;

  /// A select-tool drag is in flight — the board's trash target shows only
  /// while this is true. Transient: never persisted.
  final bool draggingSelection;

  /// The in-flight drag is currently hovering the trash target; releasing
  /// now deletes the shape instead of committing the move. Transient.
  final bool overTrash;

  List<DrawShape> shapesFor(String? key) =>
      key == null ? const [] : shapes[key] ?? const [];

  DrawingState copyWith({
    bool? active,
    DrawTool? Function()? tool,
    String? colorHex,
    double? strokeWidth,
    Map<String, List<DrawShape>>? shapes,
    int? Function()? selectedIndex,
    bool? draggingSelection,
    bool? overTrash,
  }) =>
      DrawingState(
        active: active ?? this.active,
        tool: tool != null ? tool() : this.tool,
        colorHex: colorHex ?? this.colorHex,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        shapes: shapes ?? this.shapes,
        selectedIndex:
            selectedIndex != null ? selectedIndex() : this.selectedIndex,
        draggingSelection: draggingSelection ?? this.draggingSelection,
        overTrash: overTrash ?? this.overTrash,
      );

  /// Field-wise equality with identity for [shapes] — the map (and its
  /// lists) is replaced, never mutated, so identity is exact change
  /// detection and `.select` guards actually short-circuit.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawingState &&
          other.active == active &&
          other.tool == tool &&
          other.colorHex == colorHex &&
          other.strokeWidth == strokeWidth &&
          identical(other.shapes, shapes) &&
          other.selectedIndex == selectedIndex &&
          other.draggingSelection == draggingSelection &&
          other.overTrash == overTrash;

  @override
  int get hashCode => Object.hash(active, tool, colorHex, strokeWidth,
      identityHashCode(shapes), selectedIndex, draggingSelection, overTrash);
}

final drawingControllerProvider = NotifierProvider.family<DrawingController,
    DrawingState, DrawingScope>(DrawingController.new);

/// Owns one mode's annotation layer: armed tool + style, per-key shape sets
/// with undo/redo stacks (capped at [maxUndoFrames]). The studio scope keys
/// shapes by move-tree node and persists them via
/// [CommentatorStore.saveDrawings]; other scopes draw on a single transient
/// key and never persist.
class DrawingController extends FamilyNotifier<DrawingState, DrawingScope> {
  /// Undo/redo snapshots per node key. Newest frame last.
  final Map<String, List<List<DrawShape>>> _history = {};
  final Map<String, List<List<DrawShape>>> _future = {};

  static const maxUndoFrames = 30;

  var _generation = 0;
  Completer<void> _restored = Completer<void>();

  /// Completes once the initial drawings restore attempt has finished.
  @visibleForTesting
  Future<void> get restored => _restored.future;

  DrawingScope get scope => arg;
  bool get _isStudio => scope == DrawingScope.studio;

  /// The single shape key used by ephemeral (non-studio) scopes.
  static const liveKey = 'live';

  @override
  bool updateShouldNotify(DrawingState previous, DrawingState next) =>
      previous != next;

  @override
  DrawingState build(DrawingScope arg) {
    _history.clear();
    _future.clear();
    _generation++;
    _restored = Completer<void>();
    if (arg == DrawingScope.studio) {
      ref.listen<MoveTree?>(
        commentatorControllerProvider.select((s) => s.tree),
        _onTreeChanged,
      );
      // A selection index is only meaningful within one node's shape list —
      // drop it whenever the studio navigates to a different node.
      ref.listen<String?>(
        commentatorControllerProvider.select(nodeKeyOf),
        (previous, next) {
          if (previous != next && state.selectedIndex != null) {
            state = state.copyWith(selectedIndex: () => null);
          }
        },
      );
      Future.microtask(_restore);
    } else {
      _restored.complete();
    }
    return const DrawingState();
  }

  CommentatorStore get _store => ref.read(commentatorStoreProvider);

  String? get _currentKey => _isStudio
      ? nodeKeyOf(ref.read(commentatorControllerProvider))
      : liveKey;

  // ============ mode / tool / style ============

  /// Enters drawing mode with the ARROW armed: an arrow is what people open
  /// the tools to draw, so the first drag should produce one rather than a
  /// selection rectangle. Select stays one re-tap away (see [toggleTool]).
  /// The hosting screen reacts by locking the board and pausing timers.
  void enterMode() =>
      state = state.copyWith(active: true, tool: () => DrawTool.arrow);

  /// Leaves drawing mode entirely (shapes stay, selection clears).
  void exitMode() => state = state.copyWith(
        active: false,
        tool: () => null,
        selectedIndex: () => null,
      );

  /// Arms [tool]; arming the already-armed tool falls back to select
  /// (drawing mode always has a usable tool while active).
  void toggleTool(DrawTool tool) {
    if (!state.active) return;
    state = state.copyWith(
      tool: () => state.tool == tool ? DrawTool.select : tool,
    );
  }

  /// Arms [tool] directly (no toggle semantics).
  void armTool(DrawTool tool) {
    if (!state.active) return;
    state = state.copyWith(tool: () => tool);
  }

  /// Sets the active color. When a shape is selected, recolors it too
  /// (one undo frame) — the selection stays.
  void setColor(String hex) {
    state = state.copyWith(colorHex: hex);
    _restyleSelection((shape) => shape.withColor(hex));
  }

  /// Sets the active stroke width; a selected shape is restroked in place
  /// (one undo frame).
  void setStrokeWidth(double width) {
    final clamped = width.clamp(0.03, 0.24);
    state = state.copyWith(strokeWidth: clamped);
    _restyleSelection((shape) => shape.withStroke(clamped));
  }

  void _restyleSelection(DrawShape Function(DrawShape) restyle) {
    final key = _currentKey;
    final index = state.selectedIndex;
    if (key == null || index == null) return;
    final shapes = state.shapesFor(key);
    if (index < 0 || index >= shapes.length) return;
    final next = [...shapes];
    final restyled = restyle(shapes[index]);
    if (restyled == shapes[index]) return;
    next[index] = restyled;
    _write(key, next);
  }

  // ============ shape mutations (current node) ============

  List<DrawShape> get currentShapes => state.shapesFor(_currentKey);

  /// Adds [shape]; with [select] the new shape becomes the selection (used
  /// by text creation so the fresh label is instantly movable/editable).
  void addShape(DrawShape shape, {bool select = false}) {
    final key = _currentKey;
    if (key == null) return;
    final next = [...state.shapesFor(key), shape];
    _write(key, next);
    if (select) {
      state = state.copyWith(selectedIndex: () => next.length - 1);
    }
  }

  /// Deletes the selected shape (no-op without a selection).
  void deleteSelected() {
    final index = state.selectedIndex;
    if (index != null) deleteShapeAt(index);
  }

  void deleteShapeAt(int index) {
    final key = _currentKey;
    if (key == null) return;
    final shapes = state.shapesFor(key);
    if (index < 0 || index >= shapes.length) return;
    if (state.selectedIndex == index) {
      state = state.copyWith(selectedIndex: () => null);
    }
    _write(key, [...shapes]..removeAt(index));
  }

  /// Adds a highlight on [square] in the current color, or removes the
  /// matching one (same square, same color): tapping twice clears it.
  void toggleHighlight(BoardSquare square) {
    final key = _currentKey;
    if (key == null) return;
    final shapes = state.shapesFor(key);
    final existing = shapes.indexWhere((s) =>
        s is HighlightShape && s.square == square && s.color == state.colorHex);
    if (existing >= 0) {
      _write(key, [...shapes]..removeAt(existing));
    } else {
      _write(key, [
        ...shapes,
        HighlightShape(
          square: square,
          color: state.colorHex,
          stroke: state.strokeWidth,
        ),
      ]);
    }
  }

  void clearCurrentNode() {
    final key = _currentKey;
    if (key == null || state.shapesFor(key).isEmpty) return;
    _write(key, const []);
  }

  // ============ selection (text elements) ============

  /// Selects the shape at [index] of the current key (null deselects).
  void selectShape(int? index) =>
      state = state.copyWith(selectedIndex: () => index);

  List<DrawShape>? _dragBackup;

  /// Begins moving the selected shape; the undo frame is written once, at
  /// [endShapeDrag], so a whole drag is one undoable step. Raising
  /// [DrawingState.draggingSelection] is what shows the board's trash
  /// target for the drag's lifetime.
  void beginShapeDrag() {
    final key = _currentKey;
    if (key == null || state.selectedIndex == null) return;
    _dragBackup = state.shapesFor(key);
    state = state.copyWith(draggingSelection: true, overTrash: false);
  }

  /// Whether the in-flight drag currently hovers the trash target — set by
  /// the overlay from its own geometry; releasing while true deletes.
  void setDragOverTrash(bool over) {
    if (state.overTrash == over || !state.draggingSelection) return;
    state = state.copyWith(overTrash: over);
  }

  /// Live-updates the selected shape's position while dragging:
  /// [totalDelta] is the cumulative offset since [beginShapeDrag], applied
  /// to the drag-start snapshot so the move never accumulates rounding.
  void moveSelected(Offset totalDelta) {
    final key = _currentKey;
    final index = state.selectedIndex;
    final backup = _dragBackup;
    if (key == null || index == null || backup == null) return;
    if (index < 0 || index >= backup.length) return;
    final shapes = state.shapesFor(key);
    if (index >= shapes.length) return;
    final next = [...shapes];
    next[index] = backup[index].movedBy(totalDelta);
    _setShapes(key, next);
  }

  /// Ends the drag. Dropped on the trash, the shape is DELETED — removed
  /// from its pre-drag spot so no ghost lingers where it was released;
  /// anywhere else the move commits. Either way the pre-drag list becomes
  /// one undo frame, so undo restores the shape exactly where it stood.
  void endShapeDrag() {
    final key = _currentKey;
    final backup = _dragBackup;
    final dropInTrash = state.overTrash;
    final index = state.selectedIndex;
    _dragBackup = null;
    if (state.draggingSelection || state.overTrash) {
      state = state.copyWith(draggingSelection: false, overTrash: false);
    }
    if (key == null || backup == null) return;
    if (dropInTrash && index != null && index >= 0 && index < backup.length) {
      final next = [...backup]..removeAt(index);
      _setShapes(key, next);
      state = state.copyWith(selectedIndex: () => null);
    } else {
      final current = state.shapesFor(key);
      if (identical(backup, current)) return;
    }
    final hist = _history.putIfAbsent(key, () => []);
    hist.add(backup);
    if (hist.length > maxUndoFrames) hist.removeAt(0);
    _future.remove(key);
    _persist();
  }

  /// Abandons an in-flight drag (gesture cancel): the shape snaps back to
  /// its pre-drag spot and no undo frame is written.
  void cancelShapeDrag() {
    final key = _currentKey;
    final backup = _dragBackup;
    _dragBackup = null;
    if (state.draggingSelection || state.overTrash) {
      state = state.copyWith(draggingSelection: false, overTrash: false);
    }
    if (key == null || backup == null) return;
    if (!identical(backup, state.shapesFor(key))) _setShapes(key, backup);
  }

  /// Rewrites the selected TextShape's text (one undo frame).
  void editSelectedText(String text) {
    final key = _currentKey;
    final index = state.selectedIndex;
    if (key == null || index == null) return;
    final shapes = state.shapesFor(key);
    if (index < 0 || index >= shapes.length) return;
    final shape = shapes[index];
    if (shape is! TextShape) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == shape.text) return;
    final next = [...shapes];
    next[index] = TextShape(
      at: shape.at,
      text: trimmed,
      color: shape.color,
      stroke: shape.stroke,
    );
    _write(key, next);
  }

  // ============ undo / redo ============

  bool get canUndo => _history[_currentKey]?.isNotEmpty ?? false;
  bool get canRedo => _future[_currentKey]?.isNotEmpty ?? false;

  void undo() {
    final key = _currentKey;
    final hist = key == null ? null : _history[key];
    if (key == null || hist == null || hist.isEmpty) return;
    _future.putIfAbsent(key, () => []).add(state.shapesFor(key));
    _setShapes(key, hist.removeLast());
    _persist();
  }

  void redo() {
    final key = _currentKey;
    final future = key == null ? null : _future[key];
    if (key == null || future == null || future.isEmpty) return;
    _history.putIfAbsent(key, () => []).add(state.shapesFor(key));
    _setShapes(key, future.removeLast());
    _persist();
  }

  // ============ internals ============

  void _write(String key, List<DrawShape> next) {
    final hist = _history.putIfAbsent(key, () => []);
    hist.add(state.shapesFor(key));
    if (hist.length > maxUndoFrames) hist.removeAt(0);
    _future.remove(key);
    _setShapes(key, next);
    _persist();
  }

  void _setShapes(String key, List<DrawShape> shapes) {
    state = state.copyWith(shapes: {
      ...state.shapes,
      key: List.unmodifiable(shapes),
    });
  }

  /// Wipes the ephemeral layer (tool stays armed). Screens call this when
  /// their position context changes — new game, next lesson step, etc.
  void resetLayer() {
    if (_isStudio) return;
    _history.clear();
    _future.clear();
    if (state.shapes.isNotEmpty) {
      state = state.copyWith(shapes: const {});
    }
  }

  void _persist() {
    if (!_isStudio) return;
    unawaited(_store.saveDrawings({
      for (final entry in state.shapes.entries)
        if (entry.value.isNotEmpty)
          entry.key: [for (final shape in entry.value) shape.toJson()],
    }));
  }

  /// Game switches wipe the layer: a different game's node paths would
  /// otherwise inherit stale annotations. A game *appearing* (restore, or
  /// the first import) keeps any shapes [_restore] seeded. Closing the game
  /// resets in-memory only (the commentator controller cleared the store).
  void _onTreeChanged(MoveTree? previous, MoveTree? next) {
    if (identical(previous, next)) return;
    _history.clear();
    _future.clear();
    if (previous == null) return;
    _generation++;
    state = state.copyWith(tool: () => null, shapes: const {});
    if (next != null) {
      unawaited(_store.saveDrawings(const {}));
    }
  }

  Future<void> _restore() async {
    final generation = _generation;
    try {
      final session = await _store.load();
      final raw = session?.drawings;
      if (generation != _generation || raw == null || raw.isEmpty) return;
      final loaded = <String, List<DrawShape>>{};
      raw.forEach((key, jsonShapes) {
        final shapes = [
          for (final json in jsonShapes)
            if (DrawShape.fromJson(json) case final DrawShape shape) shape,
        ];
        if (shapes.isNotEmpty) loaded[key] = List.unmodifiable(shapes);
      });
      if (loaded.isEmpty) return;
      // Shapes drawn before the restore finished win over the loaded set.
      state = state.copyWith(shapes: {...loaded, ...state.shapes});
    } catch (_) {
      // Unreadable drawings — start with a clean layer.
    } finally {
      if (!_restored.isCompleted) _restored.complete();
    }
  }
}
