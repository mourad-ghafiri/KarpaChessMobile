import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/quality_style.dart';
import '../domain/move_tree.dart';

/// Renders the whole tree as rows of move chips: the mainline flows as
/// wrapped chips, each variation appears as an indented dimmed block right
/// after its branch point. Feeds the Studio's moves overlay (a `HintToast`
/// hosted by `ModePanes.toast`); tapping a chip navigates the study board.
List<Widget> moveLineRows({
  required MoveTree tree,
  required int currentNodeId,
  required void Function(int id) onSelect,
}) =>
    _rowsUnder(
      tree: tree,
      parent: tree.root,
      depth: 0,
      currentNodeId: currentNodeId,
      onSelect: onSelect,
    );

List<Widget> _rowsUnder({
  required MoveTree tree,
  required MoveTreeNode parent,
  required int depth,
  required int currentNodeId,
  required void Function(int id) onSelect,
  MoveTreeNode? seed,
}) {
  final rows = <Widget>[];
  var chips = <Widget>[];
  var force = true;
  var cur = parent;

  void flush() {
    if (chips.isEmpty) return;
    rows.add(Wrap(spacing: 4, runSpacing: 4, children: chips));
    chips = [];
  }

  void addChip(MoveTreeNode node) {
    chips.add(_MoveChip(
      tree: tree,
      node: node,
      depth: depth,
      forceNumber: force,
      selected: node.id == currentNodeId,
      onTap: () => onSelect(node.id),
    ));
    force = false;
  }

  if (seed != null) {
    addChip(seed);
    cur = seed;
  }

  while (cur.children.isNotEmpty) {
    final main = cur.children.first;
    addChip(main);
    if (cur.children.length > 1) {
      flush();
      for (final variation in cur.children.skip(1)) {
        rows.add(Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, top: 2, bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _rowsUnder(
              tree: tree,
              parent: variation,
              depth: depth + 1,
              currentNodeId: currentNodeId,
              onSelect: onSelect,
              seed: variation,
            ),
          ),
        ));
      }
      force = true;
    }
    cur = main;
  }
  flush();
  return rows;
}

class _MoveChip extends StatelessWidget {
  const _MoveChip({
    required this.tree,
    required this.node,
    required this.depth,
    required this.forceNumber,
    required this.selected,
    required this.onTap,
  });

  final MoveTree tree;
  final MoveTreeNode node;
  final int depth;
  final bool forceNumber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final white = node.mover == 'w';
    final prefix = white
        ? '${tree.moveNumberOf(node)}. '
        : forceNumber
            ? '${tree.moveNumberOf(node)}… '
            : '';
    final quality = node.quality;
    final baseColor = depth > 0 ? tokens.textDim : tokens.text;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              if (prefix.isNotEmpty)
                // Dim, not faint: on the moves toast's floating plane the
                // faint ink read 3.1:1.
                TextSpan(
                  text: prefix,
                  style: TextStyle(color: tokens.textDim),
                ),
              TextSpan(text: node.san),
              if (quality != null)
                TextSpan(
                  text: quality.glyph,
                  style: TextStyle(
                    color: tokens.legible(
                      quality.colorOf(tokens),
                      on: tokens.surfaceAt(Elevation.floating).fill,
                    ),
                  ),
                ),
            ],
          ),
          style: TextStyle(
            fontFamily: context.type.font.mono,
            fontSize: depth > 0 ? 11.5 : 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? tokens.accent : baseColor,
          ),
        ),
      ),
    );
  }
}
