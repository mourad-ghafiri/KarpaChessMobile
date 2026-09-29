import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A row of choices you scan sideways: the app's one horizontal picker.
///
/// A picker is a filmstrip — it keeps its section to a fixed height however
/// many options ship, which is what lets Settings hold ten palettes and the
/// Studio twenty-four collections in the same space on a phone.
///
/// Given [columns], it lays the same choices out as a grid instead. That is
/// for a surface roomy enough to show every choice at once — Settings on a
/// tablet — where the strip hid half the palettes past its edge for no
/// saving at all: the dialog around it scrolls anyway.
class PickerStrip extends StatelessWidget {
  const PickerStrip({super.key, required this.children, this.columns});

  final List<Widget> children;

  /// A grid of this many columns instead of a strip; null keeps the strip.
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final columns = this.columns;
    if (columns != null) return _grid(columns);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Lets a card sit flush with the section edge while the row still
      // scrolls past it.
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            child,
          ],
        ],
      ),
    );
  }

  /// Equal cells, each choice centred in its own, so rows of cards narrower
  /// than their cell still span the section edge to edge. A card wider than
  /// its cell scales down to fit rather than overflow: a 720dp Android tablet
  /// gives Settings' dialog 104dp cells, and a selected piece-set card, whose
  /// accent border is thicker, needed 0.4dp more. Cards that fit keep their
  /// exact size.
  Widget _grid(int columns) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var row = 0; row * columns < children.length; row++) ...[
        if (row > 0) const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: row * columns + c < children.length
                    ? Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: children[row * columns + c],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ],
    ],
  );
}
