import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens_context.dart';
import '../application/commentator_controller.dart';
import '../application/drawing_controller.dart';
import '../domain/drawing_shapes.dart';
import 'draw_text_dialog.dart';

/// Head tip stops this far (in squares) short of the target square's center,
/// so the arrow reads as pointing AT the square instead of covering it.
const _kArrowTipShrink = 0.22;

// ===================================================================
// Overlay (painter + gestures), layered over KarpaBoard in a Stack
// ===================================================================

/// The annotation layer for the Commentator study board.
///
/// With no tool armed it is a pure [IgnorePointer] painting the current
/// node's shapes — the board keeps every gesture, including chessground's
/// native two-finger draw. With a tool armed, one-finger gestures create
/// shapes; dragging a selected shape shows a trash target at the board's
/// bottom center, and dropping the shape there deletes it (one undo frame,
/// so undo restores it where it stood).
class DrawingOverlay extends ConsumerStatefulWidget {
  const DrawingOverlay({
    super.key,
    required this.size,
    required this.t,
    this.scope = DrawingScope.studio,
    this.orientation,
  });

  /// Board edge length in logical pixels.
  final double size;

  final Translate t;

  /// Which mode's drawing layer this overlay renders/edits.
  final DrawingScope scope;

  /// Board orientation. Defaults to the studio's orientation for the studio
  /// scope; other scopes must pass their own.
  final Side? orientation;

  @override
  ConsumerState<DrawingOverlay> createState() => _DrawingOverlayState();
}

/// In-progress one-finger gesture, in board-frame units.
class _DrawDrag {
  _DrawDrag(this.start)
      : current = start,
        penPoints = [start];

  final Offset start;
  Offset current;
  final List<Offset> penPoints;
}

class _DrawingOverlayState extends ConsumerState<DrawingOverlay> {
  _DrawDrag? _drag;

  Side get _orientation =>
      widget.orientation ??
      ref.read(commentatorControllerProvider).orientation;

  String? get _shapeKey => widget.scope == DrawingScope.studio
      ? nodeKeyOf(ref.read(commentatorControllerProvider))
      : DrawingController.liveKey;

  /// Local pixels → board-frame units (White frame, a8 top-left).
  Offset _boardPoint(Offset local) {
    final scale = widget.size / 8;
    final view = Offset(
      (local.dx / scale).clamp(-0.5, 8.5),
      (local.dy / scale).clamp(-0.5, 8.5),
    );
    return orientPoint(view, _orientation);
  }

  DrawingController get _controller =>
      ref.read(drawingControllerProvider(widget.scope).notifier);

  // ---- gestures ----

  void _onTapUp(TapUpDetails details) {
    final drawing = ref.read(drawingControllerProvider(widget.scope));
    final pt = _boardPoint(details.localPosition);
    final shapes = drawing.shapesFor(_shapeKey);
    final hit = hitTestShapes(shapes, pt);

    // Select tool: tap picks any shape; tapping the selected text again
    // opens the editor; tapping empty board deselects.
    if (drawing.tool == DrawTool.select) {
      if (hit == null) {
        if (drawing.selectedIndex != null) _controller.selectShape(null);
        return;
      }
      if (drawing.selectedIndex == hit && shapes[hit] is TextShape) {
        _editSelectedText(shapes[hit] as TextShape);
      } else {
        _controller.selectShape(hit);
      }
      return;
    }

    // Creation tools: text elements stay tap-selectable so labels remain
    // editable without switching back to select.
    if (hit != null && shapes[hit] is TextShape) {
      if (drawing.selectedIndex == hit) {
        _editSelectedText(shapes[hit] as TextShape);
      } else {
        _controller.selectShape(hit);
      }
      return;
    }
    if (drawing.selectedIndex != null) {
      _controller.selectShape(null);
      return;
    }

    switch (drawing.tool) {
      case DrawTool.highlight || DrawTool.arrow:
        final sq = squareAt(pt);
        if (sq != null) _controller.toggleHighlight(sq);
      case DrawTool.text:
        _promptText(pt);
      case DrawTool.select || DrawTool.pen || DrawTool.rect || null:
        break;
    }
  }

  bool _movingSelection = false;
  Offset _panStartPt = Offset.zero;

  /// The trash drop target, in the overlay's own pixel space: a circle at
  /// the board's bottom center. Purely visual+geometric — it is never hit-
  /// tested (the pan gesture owns the pointer), so it needs no widget hits.
  Rect get _trashRect => Rect.fromCircle(
        center: Offset(widget.size / 2, widget.size - 40),
        radius: 28,
      );

  void _beginMove(Offset pt) {
    _movingSelection = true;
    _panStartPt = pt;
    _controller.beginShapeDrag();
  }

  void _onPanStart(DragStartDetails details) {
    final pt = _boardPoint(details.localPosition);
    final drawing = ref.read(drawingControllerProvider(widget.scope));
    final shapes = drawing.shapesFor(_shapeKey);

    // Select tool: press-and-drag grabs whatever is under the finger.
    if (drawing.tool == DrawTool.select) {
      final hit = hitTestShapes(shapes, pt);
      if (hit != null) {
        _controller.selectShape(hit);
        _beginMove(pt);
      }
      return;
    }

    // Creation tools: a drag starting on the selected shape moves it;
    // anywhere else starts a new drawing.
    final selected = drawing.selectedIndex;
    if (selected != null &&
        selected < shapes.length &&
        hitTestShapes(shapes, pt) == selected) {
      _beginMove(pt);
      return;
    }
    setState(() => _drag = _DrawDrag(pt));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_movingSelection) {
      _controller.moveSelected(
          _boardPoint(details.localPosition) - _panStartPt);
      // A little forgiveness around the circle: dropping "at" the trash
      // should not demand pixel accuracy.
      _controller.setDragOverTrash(
          _trashRect.inflate(6).contains(details.localPosition));
      return;
    }
    final drag = _drag;
    if (drag == null) return;
    setState(() {
      drag.current = _boardPoint(details.localPosition);
      drag.penPoints.add(drag.current);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_movingSelection) {
      _movingSelection = false;
      final deleted =
          ref.read(drawingControllerProvider(widget.scope)).overTrash;
      _controller.endShapeDrag();
      if (deleted) ref.hapticMedium();
      return;
    }
    final drag = _drag;
    if (drag == null) return;
    setState(() => _drag = null);
    final drawing = ref.read(drawingControllerProvider(widget.scope));
    switch (drawing.tool) {
      case DrawTool.arrow:
        final from = squareAt(drag.start);
        final to = squareAt(drag.current);
        if (from == null || to == null) return;
        if (from == to) {
          // Drag ending on the start square = toggle a highlight (the web's
          // right-click semantics).
          _controller.toggleHighlight(from);
        } else {
          _controller.addShape(ArrowShape(
            points: arrowPointsBetween(from, to),
            color: drawing.colorHex,
            stroke: drawing.strokeWidth,
          ));
        }
      case DrawTool.pen:
        if (drag.penPoints.length > 1) {
          _controller.addShape(PenShape(
            points: drag.penPoints,
            color: drawing.colorHex,
            stroke: drawing.strokeWidth,
          ));
        }
      case DrawTool.rect:
        if ((drag.current - drag.start).distance >= 0.1) {
          _controller.addShape(RectShape(
            a: drag.start,
            b: drag.current,
            color: drawing.colorHex,
            stroke: drawing.strokeWidth,
          ));
        }
      case DrawTool.select || DrawTool.highlight || DrawTool.text || null:
        break;
    }
  }

  Future<void> _editSelectedText(TextShape shape) async {
    final text = await showDrawTextDialog(context, widget.t,
        initial: shape.text);
    if (text != null && text.trim().isNotEmpty) {
      _controller.editSelectedText(text);
    }
  }

  Future<void> _promptText(Offset at) async {
    final text = await showDrawTextDialog(context, widget.t);
    final value = text?.trim() ?? '';
    if (value.isNotEmpty) {
      final drawing = ref.read(drawingControllerProvider(widget.scope));
      _controller.addShape(
        TextShape(
          at: at,
          text: value,
          color: drawing.colorHex,
          stroke: drawing.strokeWidth,
        ),
        select: true,
      );
      // Hand over to the select tool with the fresh label selected, so it
      // is instantly movable/editable (and a stray tap can't spawn another
      // editor).
      _controller.armTool(DrawTool.select);
    }
  }

  // ---- preview ----

  DrawShape? _previewShape(DrawingState drawing) {
    final drag = _drag;
    if (drag == null) return null;
    switch (drawing.tool) {
      case DrawTool.arrow:
        final from = squareAt(drag.start);
        final to = squareAt(drag.current);
        if (from == null || from == to) return null;
        return ArrowShape(
          points: to == null
              ? [squareCenter(from), drag.current]
              : arrowPointsBetween(from, to),
          color: drawing.colorHex,
          stroke: drawing.strokeWidth,
        );
      case DrawTool.pen:
        return drag.penPoints.length > 1
            ? PenShape(
                points: drag.penPoints,
                color: drawing.colorHex,
                stroke: drawing.strokeWidth,
              )
            : null;
      case DrawTool.rect:
        return RectShape(
          a: drag.start,
          b: drag.current,
          color: drawing.colorHex,
          stroke: drawing.strokeWidth,
        );
      case DrawTool.select || DrawTool.highlight || DrawTool.text || null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(
        drawingControllerProvider(widget.scope).select((s) => s.active));
    // Annotations live in drawing mode only: leaving it hides every shape
    // (they stay stored and reappear on re-entry).
    if (!active) return const SizedBox.shrink();

    final Side orientation;
    final String? key;
    if (widget.scope == DrawingScope.studio) {
      orientation = ref
          .watch(commentatorControllerProvider.select((s) => s.orientation));
      key = ref.watch(commentatorControllerProvider.select(nodeKeyOf));
    } else {
      orientation = widget.orientation ?? Side.white;
      key = DrawingController.liveKey;
    }
    final shapes = ref.watch(
        drawingControllerProvider(widget.scope).select((s) => s.shapesFor(key)));
    final tool =
        ref.watch(drawingControllerProvider(widget.scope).select((s) => s.tool));

    final selectedIndex = ref.watch(drawingControllerProvider(widget.scope)
        .select((s) => s.selectedIndex));
    final dragging = ref.watch(drawingControllerProvider(widget.scope)
        .select((s) => s.draggingSelection));
    final overTrash = ref.watch(
        drawingControllerProvider(widget.scope).select((s) => s.overTrash));
    // Isolated so per-frame shape repaints (drags, pen strokes) don't
    // re-rasterize the board underneath — and vice versa.
    final canvas = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: DrawingPainter(
          shapes: shapes,
          preview:
              _previewShape(ref.read(drawingControllerProvider(widget.scope))),
          orientation: orientation,
          textHalo: context.tokens.panel,
          // The rim that separates a drawn shape from the wood under it.
          // Themed rather than flat black, so it belongs to the palette.
          outline: context.tokens.shadow.withValues(alpha: 0.42),
          textFamily: context.type.font.display,
          selectedIndex: selectedIndex,
          selectionColor: context.tokens.accent,
          // "About to be deleted" reads on the shape itself.
          dimSelected: overTrash,
        ),
      ),
    );

    final layer = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        children: [
          canvas,
          _TrashTarget(rect: _trashRect, visible: dragging, hot: overTrash),
        ],
      ),
    );

    if (tool == null) {
      return IgnorePointer(child: layer);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: () {
        setState(() => _drag = null);
        if (_movingSelection) {
          _movingSelection = false;
          _controller.cancelShapeDrag();
        }
      },
      child: layer,
    );
  }
}

/// The delete drop-target: a circle at the board's bottom center, visible
/// only while a selection drag is in flight. Never hit-tested (the pan
/// gesture owns the pointer; the overlay does the geometry) — it is pure
/// feedback, on the same surface language as the header actions, flipping
/// to the danger tint while the shape hovers over it.
class _TrashTarget extends StatelessWidget {
  const _TrashTarget({
    required this.rect,
    required this.visible,
    required this.hot,
  });

  final Rect rect;
  final bool visible;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Motion.fast,
          curve: Motion.enter,
          child: AnimatedScale(
            scale: hot ? 1.15 : 1.0,
            duration: Motion.fast,
            curve: Motion.enter,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hot ? tokens.dangerSoft : tokens.raised,
                border: Border.all(
                  color: hot ? tokens.danger : tokens.edge,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.shadow.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.delete_outline,
                size: 22,
                color: hot ? tokens.danger : tokens.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// Painter
// ===================================================================

/// Paints the current node's shapes (plus the in-progress preview) in view
/// coordinates: board units scaled to pixels, orientation-flipped for Black.
class DrawingPainter extends CustomPainter {
  DrawingPainter({
    required this.shapes,
    required this.orientation,
    required this.textHalo,
    required this.outline,
    required this.textFamily,
    this.preview,
    this.selectedIndex,
    this.selectionColor,
    this.dimSelected = false,
  });

  final List<DrawShape> shapes;
  final Side orientation;

  /// Theme panel color used as the halo behind text annotations.
  final Color textHalo;

  /// The dark rim drawn under every stroke, keeping shapes legible on both
  /// the light and the dark squares of any colorway.
  final Color outline;

  /// Display family of the active typography — painters have no context.
  final String textFamily;

  final DrawShape? preview;

  /// Selected shape index (text elements) — outlined for move/edit.
  final int? selectedIndex;
  final Color? selectionColor;

  /// Ghosts the selected shape (drag hovering the trash target): drawn at
  /// reduced alpha so "about to be deleted" reads on the shape itself.
  final bool dimSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 8;
    for (var i = 0; i < shapes.length; i++) {
      final ghost = dimSelected && i == selectedIndex;
      if (ghost) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = const Color(0x66FFFFFF),
        );
      }
      _paintShape(canvas, shapes[i], scale, selected: i == selectedIndex);
      if (ghost) canvas.restore();
    }
    final inProgress = preview;
    if (inProgress != null) _paintShape(canvas, inProgress, scale);
  }

  Offset _view(Offset boardPt, double scale) =>
      orientPoint(boardPt, orientation) * scale;

  void _paintShape(Canvas canvas, DrawShape shape, double scale,
      {bool selected = false}) {
    switch (shape) {
      case ArrowShape():
        _paintArrow(canvas, shape, scale);
      case LineShape(:final a, :final b):
        canvas.drawLine(
          _view(a, scale),
          _view(b, scale),
          Paint()
            ..color = shape.uiColor
            ..strokeWidth = shape.stroke * scale
            ..strokeCap = StrokeCap.round,
        );
      case HighlightShape():
        _paintHighlight(canvas, shape, scale);
      case RectShape(:final a, :final b):
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromPoints(_view(a, scale), _view(b, scale)),
            Radius.circular(0.05 * scale),
          ),
          Paint()
            ..color = shape.uiColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = shape.stroke * scale,
        );
      case CircleShape(:final a, :final b):
        final va = _view(a, scale);
        final vb = _view(b, scale);
        final rx = ((vb.dx - va.dx).abs() / 2).clamp(0.15 * scale, double.infinity);
        final ry = ((vb.dy - va.dy).abs() / 2).clamp(0.15 * scale, double.infinity);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset((va.dx + vb.dx) / 2, (va.dy + vb.dy) / 2),
            width: rx * 2,
            height: ry * 2,
          ),
          Paint()
            ..color = shape.uiColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = shape.stroke * scale,
        );
      case PenShape(:final points):
        if (points.length < 2) return;
        final path = Path()
          ..moveTo(_view(points.first, scale).dx, _view(points.first, scale).dy);
        for (final p in points.skip(1)) {
          final v = _view(p, scale);
          path.lineTo(v.dx, v.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = shape.uiColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = shape.stroke * scale
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case TextShape():
        _paintText(canvas, shape, scale, selected: selected);
    }
  }

  /// Web's arrow geometry: polyline shaft (round joins carry the L-bend), a
  /// filled triangular head on the last segment, dark underlay for contrast.
  /// The tip is pulled [_kArrowTipShrink] squares back from the target center.
  void _paintArrow(Canvas canvas, ArrowShape shape, double scale) {
    final pts = [for (final p in shape.points) _view(p, scale)];
    if (pts.length < 2) return;

    var p1 = pts[pts.length - 2];
    var p2 = pts[pts.length - 1];
    var delta = p2 - p1;
    var len = delta.distance;
    if (len == 0) return;
    var dir = delta / len;

    // Shrink the tip back from the target center.
    final shrink = _kArrowTipShrink * scale;
    if (len > shrink * 2) {
      p2 = p2 - dir * shrink;
      delta = p2 - p1;
      len = delta.distance;
      dir = delta / len;
    }

    final head = (len * 0.3).clamp(0.0, 0.4 * scale);
    final headBase = p2 - dir * head;
    final shaftPts = [...pts.sublist(0, pts.length - 1), headBase];

    final path = Path()..moveTo(shaftPts.first.dx, shaftPts.first.dy);
    for (final p in shaftPts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Subtle dark underlay so the arrow reads on light and dark squares.
    canvas.drawPath(
        path, stroke(outline, (shape.stroke + 0.04) * scale));
    canvas.drawPath(path, stroke(shape.uiColor, shape.stroke * scale));

    final normal = Offset(-dir.dy, dir.dx);
    final w = head * 0.55;
    final tip = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(headBase.dx + normal.dx * w, headBase.dy + normal.dy * w)
      ..lineTo(headBase.dx - normal.dx * w, headBase.dy - normal.dy * w)
      ..close();
    canvas.drawPath(tip, Paint()..color = shape.uiColor);
    canvas.drawPath(
      tip,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025 * scale
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintHighlight(Canvas canvas, HighlightShape shape, double scale) {
    final view = orientation == Side.white
        ? shape.square
        : BoardSquare(7 - shape.square.row, 7 - shape.square.col);
    final rect = Rect.fromLTWH(
      (view.col + 0.05) * scale,
      (view.row + 0.05) * scale,
      0.9 * scale,
      0.9 * scale,
    );
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(0.08 * scale));
    canvas.drawRRect(
        rrect, Paint()..color = shape.uiColor.withValues(alpha: 0.35));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = shape.uiColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04 * scale,
    );
  }

  void _paintText(Canvas canvas, TextShape shape, double scale,
      {bool selected = false}) {
    final at = _view(shape.at, scale);
    final fontSize = (shape.stroke * 5).clamp(0.35, double.infinity) * scale;
    final painter = TextPainter(
      text: TextSpan(
        text: shape.text,
        style: TextStyle(
          color: shape.uiColor,
          fontSize: fontSize,
          fontFamily: textFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final topLeft =
        at - Offset(painter.width / 2, painter.height / 2);
    // Paper-colored halo behind the glyphs for legibility on any square.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          topLeft.dx - fontSize * 0.18,
          topLeft.dy - fontSize * 0.08,
          painter.width + fontSize * 0.36,
          painter.height + fontSize * 0.16,
        ),
        Radius.circular(fontSize * 0.2),
      ),
      Paint()..color = textHalo.withValues(alpha: 0.78),
    );
    if (selected && selectionColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            topLeft.dx - fontSize * 0.3,
            topLeft.dy - fontSize * 0.2,
            painter.width + fontSize * 0.6,
            painter.height + fontSize * 0.4,
          ),
          Radius.circular(fontSize * 0.25),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = selectionColor!,
      );
    }
    painter.paint(canvas, topLeft);
    painter.dispose();
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.dimSelected != dimSelected ||
      oldDelegate.shapes != shapes ||
      oldDelegate.preview != preview ||
      oldDelegate.orientation != orientation ||
      oldDelegate.textHalo != textHalo ||
      oldDelegate.outline != outline ||
      oldDelegate.textFamily != textFamily;
}
