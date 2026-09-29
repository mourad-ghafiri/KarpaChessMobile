import 'package:flutter/material.dart';

import '../theme/tokens_context.dart';
import '../theme/app_spacing.dart';
import 'progress_bar.dart';

/// THE game-chrome header, one widget for every board mode (the
/// `ModePanes.topBar` slot, 40dp): leading context label, optional run
/// [progress] filling the middle, trailing destructive/primary action.
/// Practice puts "new game" here, the Studio and the academy screens their
/// close — destructive actions live in the header with confirmation
/// dialogs, never inside the action bars.
///
/// The academy used to carry its own header (close on the LEFT, progress in
/// the middle), which made its two board screens read as a different product
/// from the four that used this bar. Progress moved in here instead and the
/// second widget was deleted: one header, one close position, app-wide.
class ModeHeaderBar extends StatelessWidget {
  const ModeHeaderBar({
    super.key,
    required this.label,
    this.progress,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.secondaryActionIcon,
    this.secondaryActionTooltip,
    this.onSecondaryAction,
  });

  /// Standard slot height to pass as `topBarHeight`.
  static const double height = 40;

  final String label;

  /// 0..1 through the run (lesson beats, sharpen queue). Null when the mode
  /// has no linear progress to report; the label then takes the full width.
  final double? progress;

  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  /// Optional second header action, rendered before the primary one — the
  /// lesson player's restart lives here. Session-level actions only, same
  /// confirmation contract as the primary.
  final IconData? secondaryActionIcon;
  final String? secondaryActionTooltip;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: tokens.textDim,
      ),
    );
    return Row(
      children: [
        const SizedBox(width: AppSpacing.lg),
        if (progress case final value?) ...[
          // A tight 3:2 split: the label gets the larger share (a loose
          // flex starved it to a few glyphs beside two header actions,
          // and left its unused allocation as dead air), and the bar is
          // always visible at the smaller one.
          Expanded(flex: 3, child: title),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AnimatedProgressBar(value: value, height: 4),
          ),
        ] else
          Expanded(child: title),
        if (secondaryActionIcon != null)
          _HeaderActionButton(
            icon: secondaryActionIcon!,
            tooltip: secondaryActionTooltip,
            onPressed: onSecondaryAction,
          ),
        if (actionIcon != null)
          _HeaderActionButton(
            icon: actionIcon!,
            tooltip: actionTooltip,
            onPressed: onAction,
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// A header action drawn as a small raised circle rather than a bare glyph.
/// The dim naked icon disappeared against the board chrome — the close
/// button is the one way out of an immersive game, so it wears the same
/// surface ladder every card does: a `raised` fill, the theme's hairline
/// edge, and full-strength ink. The visual circle is 32dp inside the
/// standard 44dp tap target.
class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.raised,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.edge),
              ),
              child: Icon(icon, size: 18, color: tokens.text),
            ),
          ),
        ),
      ),
    );
  }
}
