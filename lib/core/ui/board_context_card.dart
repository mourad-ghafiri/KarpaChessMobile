import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/tokens_context.dart';
import 'player_card.dart';

/// The lesson/puzzle counterpart of [PlayerBarCard]: what you are working on,
/// above the board, where the other modes show who is playing.
///
/// Its whole reason to exist is the slot it fills. Learn and Puzzles used to
/// pass no `aboveBoard` to `ModePanes`, so their boards sat 74dp higher (and
/// larger) than Play's and the Studio's — the same app, four different board
/// origins. This card reserves [height], which deliberately *is*
/// [PlayerBarCard.height], so the boards align by construction rather than by
/// two constants that happen to agree today.
///
/// On a phone the below-board side still differs legitimately (a prose panel
/// here, a second player card there), so the compact branch's lead split
/// gives these screens a slightly deeper top gap — alignment of the chrome,
/// not pixel identity of the board origin. The stacked tablet column books
/// both card rows for every mode, so there the boards ARE pixel-identical.
class BoardContextCard extends StatelessWidget {
  const BoardContextCard({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.secondary,
    this.trailing,
  });

  /// The slot height screens pass as `aboveHeight` — never a bare number.
  static const double height = PlayerBarCard.height;

  /// Leading identity mark, mirroring the player card's avatar circle.
  final String emoji;
  final String title;
  final String? subtitle;

  /// Rich second line under the title — a phase tracker, session numbers —
  /// shown INSTEAD of [subtitle]. It rides inside the card's fixed height,
  /// so a mode can carry live state up top without adding a second card
  /// that would push the board down.
  final Widget? secondary;

  /// Phase chip, rating chip, streak — whatever names the current state.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.surfaceAt(Elevation.floating);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: style.decoration(AppRadius.control),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.raised,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.edge),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.label.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (secondary case final widget?)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: widget,
                  )
                else if (subtitle case final line?)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        context.type.caption.copyWith(color: tokens.textDim),
                  ),
              ],
            ),
          ),
          if (trailing case final chip?) ...[
            const SizedBox(width: AppSpacing.sm),
            chip,
          ],
        ],
      ),
    );
  }
}
