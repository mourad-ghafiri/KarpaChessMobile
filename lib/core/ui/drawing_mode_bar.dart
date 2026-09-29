import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/commentator/application/commentator_controller.dart';
import '../../features/commentator/application/drawing_controller.dart';
import '../../features/commentator/domain/drawing_shapes.dart';
import '../../features/commentator/presentation/draw_text_dialog.dart';
import '../haptics/haptics.dart';
import '../i18n/i18n_service.dart';
import '../layout/mode_panes.dart';
import '../theme/app_radius.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tokens_context.dart';

/// The pencil button each mode places in its controls: enters drawing mode.
class DrawingModeButton extends ConsumerWidget {
  const DrawingModeButton({super.key, required this.scope, required this.t});

  final DrawingScope scope;
  final Translate t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
        drawingControllerProvider(scope).select((s) => s.active));
    final tokens = context.tokens;
    return IconButton(
      tooltip: t('draw.mode'),
      icon: Icon(
        Icons.draw_outlined,
        color: active ? tokens.accent : tokens.textDim,
      ),
      style: IconButton.styleFrom(
        backgroundColor: active ? tokens.accentSoft : null,
      ),
      onPressed: () {
        final controller =
            ref.read(drawingControllerProvider(scope).notifier);
        active ? controller.exitMode() : controller.enterMode();
      },
    );
  }
}

/// The full toolbar. One horizontal strip — select · undo/redo/clear ·
/// tools · colors · strokes · selection — that scrolls sideways, keeping the
/// bar a single 44dp row so it takes as little of the screen as possible while
/// open. Collapses to nothing when inactive (AnimatedSize handles the
/// reflow).
///
/// Two placements exist. Most drawing screens float it in `ModePanes`'
/// `overlayBar` slot, docked above the action bar. The Studio instead swaps
/// it INTO its pinned zone, in place of the replay row: drawing is modal
/// there — the board is annotation-only — so the navigation controls it
/// covers are exactly the ones that cannot be used anyway. A host that
/// embeds it owns the horizontal inset (the float slot used to provide it).
class DrawingModeBar extends ConsumerWidget {
  const DrawingModeBar({super.key, required this.scope, required this.t});

  /// The vertical budget the bar needs when open: one 44dp row, the box's
  /// own padding and its outer margin. BY REFERENCE the same number
  /// `ModePanes` books for it — the pair used to be `56`/`60` literals in
  /// different files with nothing linking them, which is how they drift.
  static const double height = ModePanes.defaultOverlayBarHeight;

  final DrawingScope scope;
  final Translate t;

  // Select leads, with undo · redo · clear right beside it, so the editing
  // controls sit together at the start of the row; the drawing tools and
  // their styles follow. Arrow stays the ARMED default on entry (row order is
  // visual, the first drag still produces an arrow).
  static const _select = (
    DrawTool.select,
    Icons.touch_app_outlined,
    'commentator.drawTools.select',
  );
  static const _tools = [
    (DrawTool.highlight, Icons.square_rounded, 'commentator.drawTools.circle'),
    (DrawTool.arrow, Icons.north_east, 'commentator.drawTools.arrow'),
    (DrawTool.pen, Icons.draw, 'commentator.drawTools.pen'),
    (DrawTool.text, Icons.text_fields, 'commentator.drawTools.text'),
    (DrawTool.rect, Icons.rectangle_outlined, 'commentator.drawTools.box'),
  ];

  static const _strokes = [0.05, 0.08, 0.14];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Drag-stable select: moveSelected replaces the shapes list on every
    // pointer frame, but none of these derived values change mid-drag —
    // so the toolbar (and its blur shadow) only rebuilds when the tool,
    // style or selection actually changes.
    final drawing = ref.watch(drawingControllerProvider(scope).select((s) {
      final selected = _selectedShape(ref, s);
      return (
        active: s.active,
        tool: s.tool,
        colorHex: s.colorHex,
        strokeWidth: s.strokeWidth,
        hasSelection: selected != null,
        selectedIsText: selected is TextShape,
      );
    }));
    final controller = ref.read(drawingControllerProvider(scope).notifier);
    final tokens = context.tokens;

    Widget toolButton((DrawTool, IconData, String) spec) {
      final (tool, icon, labelKey) = spec;
      return _BarButton(
        icon: icon,
        tooltip: t(labelKey),
        active: drawing.tool == tool,
        onTap: () {
          ref.hapticSelection();
          controller.toggleTool(tool);
        },
      );
    }

    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.enter,
      alignment: Alignment.bottomCenter,
      child: !drawing.active
          ? const SizedBox(width: double.infinity)
          : Container(
              height: height - 4,
              // Vertical breathing room only — `ModePanes` insets the whole
              // float stack horizontally, so a margin here would inset the
              // bar twice and misalign it with the action bar below.
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration:
                  tokens.surfaceAt(Elevation.floating).decoration(14).copyWith(
                        // The accent outline is the mode indicator: this bar
                        // only exists while drawing is armed.
                        border:
                            Border.all(color: tokens.accent, width: 1.4),
                      ),
              // No Done button: re-tapping the drawing icon (or Escape)
              // exits the mode — the bar is pure tools.
              child: _ToolRow(
                children: [
                  toolButton(_select),
                  _HistoryButtons(scope: scope, t: t),
                  _divider(tokens),
                  for (final spec in _tools) toolButton(spec),
                  _divider(tokens),
                  for (final color in drawColors)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      onTap: () => controller.setColor(color.hex),
                      // 40×44 hit area around the 22dp visual dot.
                      child: SizedBox(
                        width: 40,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: drawing.colorHex == color.hex
                                    ? tokens.text
                                    : tokens.edge,
                                width:
                                    drawing.colorHex == color.hex ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  _divider(tokens),
                  for (final stroke in _strokes)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.setStrokeWidth(stroke),
                      // 40×44 hit area; the visual swatch keeps its 26×34
                      // footprint.
                      child: SizedBox(
                        width: 40,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 26,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  (drawing.strokeWidth - stroke).abs() <
                                          0.015
                                      ? tokens.accentSoft
                                      : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Container(
                              width: 14,
                              height: 2 + stroke * 40,
                              decoration: BoxDecoration(
                                color: tokens.text,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (drawing.hasSelection) ...[
                    _divider(tokens),
                    if (drawing.selectedIsText)
                      _BarButton(
                        icon: Icons.edit_outlined,
                        tooltip: t('commentator.drawTools.editText'),
                        onTap: () {
                          final shape = _selectedShape(
                              ref, ref.read(drawingControllerProvider(scope)));
                          if (shape is TextShape) {
                            _editSelectedText(context, controller, shape);
                          }
                        },
                      ),
                    _BarButton(
                      icon: Icons.backspace_outlined,
                      tooltip: t('commentator.drawTools.deleteSelected'),
                      color: tokens.danger,
                      onTap: controller.deleteSelected,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  DrawShape? _selectedShape(WidgetRef ref, DrawingState drawing) {
    final index = drawing.selectedIndex;
    if (index == null) return null;
    final key = scope == DrawingScope.studio
        ? nodeKeyOf(ref.read(commentatorControllerProvider))
        : DrawingController.liveKey;
    final shapes = drawing.shapesFor(key);
    return index >= 0 && index < shapes.length ? shapes[index] : null;
  }

  Future<void> _editSelectedText(
    BuildContext context,
    DrawingController controller,
    TextShape shape,
  ) async {
    final text = await showDrawTextDialog(context, t, initial: shape.text);
    if (text != null && text.trim().isNotEmpty) {
      controller.editSelectedText(text);
    }
  }

  Widget _divider(AppTokens tokens) => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: tokens.edge,
      );
}

/// One 44dp toolbar row: centred while its content fits, its own horizontal
/// scroller once it does not. The `minWidth: maxWidth` constraint is what
/// makes both true at once — the Row is never narrower than the viewport, so
/// `center` alignment holds, and it grows past it only when the buttons do.
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Undo / redo / clear-all. Split out with its own watch on the shapes map
/// (identity) so their enablement refreshes on every committed change while
/// the expensive toolbar chrome above stays untouched — rebuilding three
/// icon buttons per drag frame is cheap; rebuilding the shadowed bar isn't.
class _HistoryButtons extends ConsumerWidget {
  const _HistoryButtons({required this.scope, required this.t});

  final DrawingScope scope;
  final Translate t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shapes = ref
        .watch(drawingControllerProvider(scope).select((s) => s.shapes));
    final controller = ref.read(drawingControllerProvider(scope).notifier);
    final key = scope == DrawingScope.studio
        ? nodeKeyOf(ref.read(commentatorControllerProvider))
        : DrawingController.liveKey;
    final hasShapes =
        key != null && (shapes[key] ?? const []).isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarButton(
          icon: Icons.undo,
          tooltip: t('commentator.drawTools.undo'),
          onTap: controller.canUndo ? controller.undo : null,
        ),
        _BarButton(
          icon: Icons.redo,
          tooltip: t('commentator.drawTools.redo'),
          onTap: controller.canRedo ? controller.redo : null,
        ),
        _BarButton(
          icon: Icons.delete_outline,
          tooltip: t('commentator.drawTools.clearAll'),
          color: context.tokens.danger,
          onTap: hasShapes ? controller.clearCurrentNode : null,
        ),
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? tokens.accentSoft : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? tokens.textFaint
                : active
                    ? tokens.accent
                    : color ?? tokens.textDim,
          ),
        ),
      ),
    );
  }
}
