import 'package:flutter/widgets.dart';

import '../layout/content_width.dart';

/// Holds prose to a reading measure, start-aligned.
///
/// A board mode's panel is 320–460dp in a side pane but ~770dp under a
/// portrait tablet's board, where a line of lesson text ran to about a
/// hundred characters. Capped at [ContentWidth.reading] and aligned to the
/// start, the text keeps the board's leading edge and a readable line. Where
/// the panel is narrower than the measure — every phone and side pane — this
/// changes nothing.
class ReadingMeasure extends StatelessWidget {
  const ReadingMeasure({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ContentWidth.reading),
      child: child,
    ),
  );
}

/// A lone primary button (Next, Start the pack): it fills a phone-sized slot,
/// and in anything wider it is exactly [ContentWidth.button], centred.
///
/// On a phone, or in a side pane, such a button has always filled the room
/// its row gives it, and still does. Under a portrait tablet's board or on a
/// tablet's browse page the same full-width button became a 600–1000dp slab.
/// The rule reads the slot, not the window: any slot wider than a phone's is
/// a tablet's.
class ButtonMeasure extends StatelessWidget {
  const ButtonMeasure({super.key, required this.child});

  /// The widest slot a phone or a side pane hands a button: the largest
  /// phone's row, or the two-pane side pane's 460dp ceiling.
  static const _fillUpTo = 460.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth <= _fillUpTo
        ? child
        // Exactly the measure, whatever the button's own minimum: a button
        // sized to its label read as a chip under a board-wide column.
        : Center(
            child: SizedBox(width: ContentWidth.button, child: child),
          ),
  );
}
