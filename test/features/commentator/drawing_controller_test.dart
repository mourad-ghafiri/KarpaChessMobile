import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/features/commentator/application/commentator_controller.dart';
import 'package:karpachess/features/commentator/application/drawing_controller.dart';
import 'package:karpachess/features/commentator/data/commentator_store.dart';
import 'package:karpachess/features/commentator/domain/drawing_shapes.dart';

import 'fakes.dart';

ProviderContainer makeContainer(MemoryCommentatorStore store) {
  final container = ProviderContainer(overrides: [
    engineServiceProvider.overrideWithValue(FakeEngineService()),
    commentatorStoreProvider.overrideWithValue(store),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Boots both controllers, loads a small game, and returns (commentator,
/// drawing) notifiers ready for use.
Future<(CommentatorController, DrawingController)> boot(
  ProviderContainer container, {
  String pgn = '1. e4 e5 2. Nf3 *',
}) async {
  final commentator = container.read(commentatorControllerProvider.notifier);
  final drawing = container.read(drawingControllerProvider(DrawingScope.studio).notifier);
  await commentator.restored;
  await drawing.restored;
  commentator.loadPgn(pgn);
  return (commentator, drawing);
}

ArrowShape arrow({String color = '#c25a3c'}) => ArrowShape(
      points: const [Offset(4.5, 6.5), Offset(4.5, 4.5)],
      color: color,
      stroke: 0.08,
    );

void main() {
  test('drawing mode gates the tools; re-toggle falls back to select',
      () async {
    final container = makeContainer(MemoryCommentatorStore());
    final (_, drawing) = await boot(container);

    DrawingState read() =>
        container.read(drawingControllerProvider(DrawingScope.studio));

    // Tools are inert outside drawing mode.
    expect(read().active, isFalse);
    drawing.toggleTool(DrawTool.pen);
    expect(read().tool, isNull);

    // Entering the mode arms the arrow — the tool people open it to use.
    drawing.enterMode();
    expect(read().active, isTrue);
    expect(read().tool, DrawTool.arrow);

    drawing.toggleTool(DrawTool.pen);
    expect(read().tool, DrawTool.pen);
    // Re-toggling the armed tool falls back to select (the mode always
    // keeps a usable tool).
    drawing.toggleTool(DrawTool.pen);
    expect(read().tool, DrawTool.select);

    // armTool has no toggle semantics.
    drawing.armTool(DrawTool.rect);
    expect(read().tool, DrawTool.rect);

    drawing.exitMode();
    expect(read().active, isFalse);
    expect(read().tool, isNull);
  });

  test('shapes are scoped per node key and switch with navigation', () async {
    final container = makeContainer(MemoryCommentatorStore());
    final (commentator, drawing) = await boot(container);

    // Root ('' key): one arrow.
    expect(nodeKeyOf(container.read(commentatorControllerProvider)), '');
    drawing.addShape(arrow());
    expect(drawing.currentShapes, hasLength(1));

    // After 1. e4 ('0' key): a highlight; the arrow is not visible here.
    commentator.forward();
    expect(nodeKeyOf(container.read(commentatorControllerProvider)), '0');
    expect(drawing.currentShapes, isEmpty);
    drawing.toggleHighlight(const BoardSquare(4, 4));
    expect(drawing.currentShapes, hasLength(1));
    expect(drawing.currentShapes.single, isA<HighlightShape>());

    // Back at the root the arrow set is visible again.
    commentator.back();
    expect(drawing.currentShapes.single, isA<ArrowShape>());
    await commentator.analysisDone;
  });

  test('toggleHighlight removes a same-square same-color highlight', () async {
    final container = makeContainer(MemoryCommentatorStore());
    final (_, drawing) = await boot(container);

    drawing.toggleHighlight(const BoardSquare(3, 3));
    expect(drawing.currentShapes, hasLength(1));
    // Different color stacks instead of toggling off.
    drawing.setColor('#3b7a55');
    drawing.toggleHighlight(const BoardSquare(3, 3));
    expect(drawing.currentShapes, hasLength(2));
    // Same color + square toggles off.
    drawing.toggleHighlight(const BoardSquare(3, 3));
    expect(drawing.currentShapes, hasLength(1));
  });

  test('undo/redo per node with a 30-frame cap', () async {
    final container = makeContainer(MemoryCommentatorStore());
    final (_, drawing) = await boot(container);

    for (var i = 0; i < 35; i++) {
      drawing.toggleHighlight(BoardSquare(i ~/ 8, i % 8));
    }
    expect(drawing.currentShapes, hasLength(35));

    var undos = 0;
    while (drawing.canUndo) {
      drawing.undo();
      undos++;
    }
    expect(undos, DrawingController.maxUndoFrames);
    expect(drawing.currentShapes, hasLength(5));

    expect(drawing.canRedo, isTrue);
    drawing.redo();
    expect(drawing.currentShapes, hasLength(6));

    // A fresh write clears the redo stack.
    drawing.addShape(arrow());
    expect(drawing.canRedo, isFalse);
  });

  test('clearCurrentNode empties the node and is undoable', () async {
    final container = makeContainer(MemoryCommentatorStore());
    final (_, drawing) = await boot(container);

    drawing.addShape(arrow());
    drawing.toggleHighlight(const BoardSquare(0, 0));
    drawing.clearCurrentNode();
    expect(drawing.currentShapes, isEmpty);
    drawing.undo();
    expect(drawing.currentShapes, hasLength(2));
  });

  test('deleteShapeAt removes exactly the indexed shape', () async {
    final container = makeContainer(MemoryCommentatorStore());
    final (_, drawing) = await boot(container);

    drawing.addShape(arrow());
    drawing.addShape(arrow(color: '#2f4a6b'));
    drawing.deleteShapeAt(0);
    expect(drawing.currentShapes.single.color, '#2f4a6b');
  });

  test('shapes persist through the store keyed by path and reload', () async {
    final store = MemoryCommentatorStore();
    final container = makeContainer(store);
    final (commentator, drawing) = await boot(container);
    await pumpEventQueue(); // let loadPgn's unawaited session save land

    drawing.addShape(arrow());
    commentator.forward();
    drawing.toggleHighlight(const BoardSquare(4, 4));
    await commentator.analysisDone;
    await pumpEventQueue();

    final saved = store.session!.drawings!;
    expect(saved.keys, containsAll(['', '0']));
    expect(saved['']!.single['kind'], 'arrow');
    expect(saved['0']!.single['kind'], 'highlight');

    // The commentator's own saves (navigation persists the session) must not
    // wipe the drawings.
    commentator.back();
    await commentator.analysisDone;
    await pumpEventQueue();
    expect(store.session!.drawings!.keys, containsAll(['', '0']));

    // A fresh container over the same store restores the shape sets.
    final container2 = makeContainer(store);
    final commentator2 = container2.read(commentatorControllerProvider.notifier);
    final drawing2 = container2.read(drawingControllerProvider(DrawingScope.studio).notifier);
    await commentator2.restored;
    await drawing2.restored;
    final state2 = container2.read(drawingControllerProvider(DrawingScope.studio));
    expect(state2.shapesFor(''), [arrow()]);
    expect(state2.shapesFor('0').single, isA<HighlightShape>());
    await commentator2.analysisDone;
  });

  test('loading a different game wipes the previous drawings', () async {
    final store = MemoryCommentatorStore();
    final container = makeContainer(store);
    final (commentator, drawing) = await boot(container);

    drawing.addShape(arrow());
    await pumpEventQueue();
    expect(store.session!.drawings, isNotEmpty);

    commentator.loadPgn('1. d4 d5 *');
    await pumpEventQueue();
    expect(drawing.currentShapes, isEmpty);
    expect(container.read(drawingControllerProvider(DrawingScope.studio)).shapes, isEmpty);
    expect(store.session!.drawings, isEmpty);
  });

  test('closing the game clears shapes and the saved session', () async {
    final store = MemoryCommentatorStore();
    final container = makeContainer(store);
    final (commentator, drawing) = await boot(container);

    drawing.toggleTool(DrawTool.pen);
    drawing.addShape(arrow());
    commentator.closeGame();
    await pumpEventQueue();

    final state = container.read(drawingControllerProvider(DrawingScope.studio));
    expect(state.shapes, isEmpty);
    expect(state.tool, isNull);
    expect(store.session, isNull);
  });

  test('sessions saved without drawings still load (tolerant fromJson)', () {
    final session = CommentatorSession.fromJson(const {
      'pgn': '1. e4 *',
      'whiteName': 'A',
      'blackName': 'B',
      'path': [0],
    });
    expect(session.drawings, isNull);
    expect(session.pgn, '1. e4 *');

    final withDrawings = CommentatorSession.fromJson(const {
      'pgn': '1. e4 *',
      'drawings': {
        '0': [
          {'kind': 'highlight', 'color': '#c25a3c', 'stroke': 0.08, 'sq': [4, 4]},
        ],
        'bad': 'not-a-list',
      },
    });
    expect(withDrawings.drawings!['0']!.single['kind'], 'highlight');
    expect(withDrawings.drawings!['bad'], isEmpty);
  });

  test('mutations without a loaded game are ignored', () async {
    final container = makeContainer(MemoryCommentatorStore());
    final drawing = container.read(drawingControllerProvider(DrawingScope.studio).notifier);
    await drawing.restored;

    drawing.addShape(arrow());
    drawing.toggleHighlight(const BoardSquare(0, 0));
    drawing.undo();
    expect(container.read(drawingControllerProvider(DrawingScope.studio)).shapes, isEmpty);
    expect(drawing.canUndo, isFalse);
  });

  group('text selection, move and edit', () {
    test('select, drag as one undo frame, edit and deselect', () async {
      final container = makeContainer(MemoryCommentatorStore());
      final (_, controller) = await boot(container);
      controller.enterMode();
      controller.addShape(const TextShape(
        at: Offset(4, 4),
        text: 'idea',
        color: '#c25a3c',
        stroke: 0.08,
      ));

      controller.selectShape(0);
      expect(
        container
            .read(drawingControllerProvider(DrawingScope.studio))
            .selectedIndex,
        0,
      );

      // One drag with many updates = a single undo frame. Deltas are
      // cumulative from the drag start, applied to the start snapshot.
      controller.beginShapeDrag();
      controller.moveSelected(const Offset(1, 1));
      controller.moveSelected(const Offset(2, 2));
      controller.endShapeDrag();
      var shapes = container
          .read(drawingControllerProvider(DrawingScope.studio))
          .shapesFor(nodeKeyOf(container.read(commentatorControllerProvider)));
      expect((shapes.single as TextShape).at, const Offset(6, 6));

      controller.undo();
      shapes = container
          .read(drawingControllerProvider(DrawingScope.studio))
          .shapesFor(nodeKeyOf(container.read(commentatorControllerProvider)));
      expect((shapes.single as TextShape).at, const Offset(4, 4));
      controller.redo();

      // Edit rewrites the text as its own undo frame.
      controller.editSelectedText('better idea');
      shapes = container
          .read(drawingControllerProvider(DrawingScope.studio))
          .shapesFor(nodeKeyOf(container.read(commentatorControllerProvider)));
      expect((shapes.single as TextShape).text, 'better idea');

      // Deleting the selected shape clears the selection.
      controller.deleteShapeAt(0);
      expect(
        container
            .read(drawingControllerProvider(DrawingScope.studio))
            .selectedIndex,
        isNull,
      );
    });

    test('drag-to-trash deletes as one undo frame; cancel snaps back',
        () async {
      final container = makeContainer(MemoryCommentatorStore());
      final (_, controller) = await boot(container);
      DrawingState read() =>
          container.read(drawingControllerProvider(DrawingScope.studio));
      String? key() =>
          nodeKeyOf(container.read(commentatorControllerProvider));
      controller.enterMode();
      controller.addShape(const TextShape(
        at: Offset(4, 4),
        text: 'idea',
        color: '#c25a3c',
        stroke: 0.08,
      ));
      controller.selectShape(0);

      // The drag raises the transient flag; hovering the trash toggles.
      controller.beginShapeDrag();
      expect(read().draggingSelection, isTrue);
      expect(read().overTrash, isFalse);
      controller.moveSelected(const Offset(1, 1));
      controller.setDragOverTrash(true);
      expect(read().overTrash, isTrue);
      final before = read();
      controller.setDragOverTrash(true); // no-op keeps identity
      expect(identical(read(), before), isTrue);

      // Dropping in the trash deletes the shape and clears the selection…
      controller.endShapeDrag();
      expect(read().draggingSelection, isFalse);
      expect(read().overTrash, isFalse);
      expect(read().shapesFor(key()), isEmpty);
      expect(read().selectedIndex, isNull);

      // …as ONE undo frame that restores it at its pre-drag spot.
      controller.undo();
      expect(
        (read().shapesFor(key()).single as TextShape).at,
        const Offset(4, 4),
      );

      // Cancel: the shape snaps back and no undo frame is written.
      controller.selectShape(0);
      controller.beginShapeDrag();
      controller.moveSelected(const Offset(2, 2));
      controller.setDragOverTrash(true);
      controller.cancelShapeDrag();
      expect(read().draggingSelection, isFalse);
      expect(read().overTrash, isFalse);
      expect(
        (read().shapesFor(key()).single as TextShape).at,
        const Offset(4, 4),
      );
      // setDragOverTrash outside a drag is ignored.
      controller.setDragOverTrash(true);
      expect(read().overTrash, isFalse);
    });

    test('setColor and setStrokeWidth restyle the selected shape', () async {
      final container = makeContainer(MemoryCommentatorStore());
      final (commentator, controller) = await boot(container);
      controller.enterMode();
      controller.addShape(arrow(), select: true);

      List<DrawShape> shapes() => container
          .read(drawingControllerProvider(DrawingScope.studio))
          .shapesFor(nodeKeyOf(container.read(commentatorControllerProvider)));

      controller.setColor('#2f4a6b');
      expect(shapes().single.color, '#2f4a6b');
      // The recolor is one undoable frame and keeps the selection.
      expect(
        container
            .read(drawingControllerProvider(DrawingScope.studio))
            .selectedIndex,
        0,
      );
      controller.undo();
      expect(shapes().single.color, '#c25a3c');

      controller.setStrokeWidth(0.14);
      expect(shapes().single.stroke, 0.14);
      await commentator.analysisDone;
    });

    test('moveSelected translates every shape kind from its snapshot',
        () async {
      final container = makeContainer(MemoryCommentatorStore());
      final (commentator, controller) = await boot(container);
      controller.enterMode();
      controller.addShape(arrow());
      controller.addShape(const RectShape(
        a: Offset(1, 1),
        b: Offset(2, 2),
        color: '#c25a3c',
        stroke: 0.08,
      ));

      List<DrawShape> shapes() => container
          .read(drawingControllerProvider(DrawingScope.studio))
          .shapesFor(nodeKeyOf(container.read(commentatorControllerProvider)));

      controller.selectShape(0);
      controller.beginShapeDrag();
      controller.moveSelected(const Offset(1, -1));
      controller.endShapeDrag();
      expect(
        (shapes()[0] as ArrowShape).points.first,
        const Offset(5.5, 5.5),
      );

      controller.selectShape(1);
      controller.beginShapeDrag();
      controller.moveSelected(const Offset(0.5, 0.5));
      controller.endShapeDrag();
      expect((shapes()[1] as RectShape).a, const Offset(1.5, 1.5));
      expect((shapes()[1] as RectShape).b, const Offset(2.5, 2.5));

      // deleteSelected removes the selection's shape.
      controller.deleteSelected();
      expect(shapes(), hasLength(1));
      await commentator.analysisDone;
    });

    test('navigating to another node clears the selection', () async {
      final container = makeContainer(MemoryCommentatorStore());
      final (commentator, controller) = await boot(container);
      controller.enterMode();
      controller.addShape(arrow(), select: true);
      expect(
        container
            .read(drawingControllerProvider(DrawingScope.studio))
            .selectedIndex,
        0,
      );

      commentator.forward();
      await pumpEventQueue();
      expect(
        container
            .read(drawingControllerProvider(DrawingScope.studio))
            .selectedIndex,
        isNull,
      );
      await commentator.analysisDone;
    });

    test('exitMode clears selection and hides nothing from storage', () async {
      final container = makeContainer(MemoryCommentatorStore());
      final (_, controller) = await boot(container);
      controller.enterMode();
      controller.addShape(const TextShape(
        at: Offset(2, 2),
        text: 'note',
        color: '#c25a3c',
        stroke: 0.08,
      ));
      controller.selectShape(0);
      controller.exitMode();
      final state =
          container.read(drawingControllerProvider(DrawingScope.studio));
      expect(state.active, isFalse);
      expect(state.selectedIndex, isNull);
      // Shapes stay stored for the next drawing session.
      expect(
        state.shapesFor(
            nodeKeyOf(container.read(commentatorControllerProvider))),
        hasLength(1),
      );
    });
  });
}
