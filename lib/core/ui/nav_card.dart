import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/tokens_context.dart';
import 'surface.dart';
import 'symbol_glyph.dart';

/// THE row card that takes you somewhere: a mark in its well, a title over a
/// line of explanation, and the way in.
///
/// Sharpen and the Pattern Book on Learn, Keep going and the daily puzzle on
/// Puzzles, and the Studio's import invitation were four hand-copies of this
/// row. Their marks were set at 22, 24 and 26 with nothing to hold them, so
/// the titles beside them started on different columns, and their blurbs ran
/// at 11.5, 12 and 12.5. The mark now sits in the same 40dp well a Studio
/// game card's monogram does, so every row of this kind — and the game list
/// under the import invitation — shares one leading column.
class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.title,
    this.subtitle,
    this.glyph,
    this.icon,
    this.markColor,
    this.trailing,
    this.onTap,
    this.emphasized = false,
  }) : assert(glyph != null || icon != null, 'a NavCard needs a mark');

  final String title;
  final String? subtitle;

  /// A symbol or emoji for the mark (drawn through [SymbolGlyph]).
  final String? glyph;

  /// A Material icon for the mark, when the row has no symbol of its own.
  final IconData? icon;

  /// Ink for an [icon] or a type [glyph]; the accent by default.
  final Color? markColor;

  /// Shown before the chevron — a rating chip, say.
  final Widget? trailing;

  /// Null makes the card a status row: no ink, no chevron.
  final VoidCallback? onTap;

  /// The card that is the screen's next step: an accent wash, and a forward
  /// arrow in place of the chevron.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ink = markColor ?? tokens.accent;
    return Surface(
      onTap: onTap,
      wash: emphasized ? tokens.accent : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: icon != null
                ? Icon(icon, size: 22, color: ink)
                : SymbolGlyph(glyph!, size: 20, color: ink),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.heading.copyWith(color: tokens.text),
                ),
                if (subtitle case final line?) ...[
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      height: 1.3,
                      color: tokens.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing case final widget?) ...[
            const SizedBox(width: AppSpacing.sm),
            widget,
          ],
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              emphasized ? Icons.arrow_forward : Icons.chevron_right,
              color: emphasized ? tokens.accent : tokens.textDim,
            ),
          ],
        ],
      ),
    );
  }
}
