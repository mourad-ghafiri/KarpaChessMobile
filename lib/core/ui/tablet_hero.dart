import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// The top of a tablet's home page: the profile card and the page's big
/// actions (Learn: Sharpen and Continue; Puzzles: Keep going and the daily
/// puzzle), composed as one block.
///
/// A phone stacks them at full width, which is right for a phone. On a tablet
/// the same stack made each action a 600–1000dp slab, so here the actions
/// sit beside the profile on a wide page ([beside]) and side by side under
/// it on a narrower one. Everything in a row shares one height, so the block
/// reads as one object rather than cards of three different heights.
class TabletHero extends StatelessWidget {
  const TabletHero({
    super.key,
    required this.profile,
    required this.actions,
    required this.beside,
  }) : assert(actions.length == 1 || actions.length == 2);

  /// A page at least this wide (its content, padding excluded) takes the
  /// actions beside the profile.
  static const besideAt = 960.0;

  final Widget profile;

  /// One or two actions, in reading order.
  final List<Widget> actions;

  /// The actions stack beside the profile rather than pairing under it.
  final bool beside;

  @override
  Widget build(BuildContext context) {
    if (beside) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: profile),
            const SizedBox(width: AppInsets.gridGap),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (i, action) in actions.indexed) ...[
                    if (i > 0) const SizedBox(height: AppInsets.gridGap),
                    action,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        profile,
        const SizedBox(height: AppSpacing.md),
        if (actions.length == 1)
          actions.single
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: actions[0]),
                const SizedBox(width: AppInsets.gridGap),
                Expanded(child: actions[1]),
              ],
            ),
          ),
      ],
    );
  }
}
