import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/tokens_context.dart';

/// One action in an [ActionBar].
class BarAction {
  const BarAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final String tooltip;

  /// null renders the action disabled.
  final VoidCallback? onTap;
  final bool active;
  final String? badge;
}

/// Slim horizontal icon bar docked under the board — the only chrome
/// visible during play. Keeps the board in focus; labels live in tooltips.
///
/// Width-adaptive: targets never shrink below 44dp; the cluster spreads only
/// so far, the pill stops widening at [maxWidth], and when the targets do not
/// fit the row scrolls — the bar can never overflow.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.actions});

  final List<BarAction> actions;

  /// The widest the bar gets, its margins included. A portrait tablet's
  /// column is ~790dp, and a pill that wide around three icons read as a
  /// slab; capped, it stays the object it is on a phone, centred in its slot.
  /// Every phone and side pane hands the bar less than this, so there it
  /// fills its slot exactly as before.
  static const double maxWidth = 440;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: _bar(tokens),
      ),
    );
  }

  Widget _bar(AppTokens tokens) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      // The bar floats over the board, so it takes the floating plane —
      // lifted off the page rather than washed onto it.
      decoration: tokens
          .surfaceAt(Elevation.floating)
          .decoration(AppRadius.chip),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fit = actions.isEmpty
              ? 44.0
              : (constraints.maxWidth - 4) / actions.length;
          // HIG floor: targets never render under 44dp wide. When they don't
          // all fit at that size, the row scrolls at full size rather than
          // shrinking anything.
          if (fit >= 44) {
            // A slot may breathe beyond its 44dp target, but only so far: in a
            // wide side pane an uncapped spread scattered three buttons across
            // 400+dp of bar. Capped, the cluster stays a cluster and the
            // leftover width becomes symmetric margin. The item itself stays
            // 44dp (badge geometry hangs off it); the slack is padding.
            final gap = (math.min(fit, 44 + 2 * AppSpacing.lg) - 44).clamp(
              0.0,
              44.0,
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final action in actions)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: gap / 2),
                    child: _item(tokens, action, 44),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final action in actions) _item(tokens, action, 44),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _item(AppTokens tokens, BarAction action, double extent) => Tooltip(
    message: action.tooltip,
    child: InkWell(
      onTap: action.onTap,
      customBorder: const CircleBorder(),
      child: Container(
        // HIG: a full 44dp target in both axes, in every tier.
        width: extent,
        height: 44,
        decoration: action.active
            ? BoxDecoration(color: tokens.accentSoft, shape: BoxShape.circle)
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              action.icon,
              size: 22,
              color: action.onTap == null
                  ? tokens.textFaint
                  : action.active
                  ? tokens.accent
                  : tokens.textDim,
            ),
            if (action.badge != null)
              PositionedDirectional(
                top: 6,
                end: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    action.badge!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: tokens.onAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
