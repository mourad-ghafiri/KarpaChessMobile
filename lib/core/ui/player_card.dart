import 'dart:io' as io;

import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/tokens_context.dart';

/// THE player-bar surface, identical in Practice and Studio: a soft glass
/// card carrying a [PlayerIdentity], a trailing slot (the clock chip) and,
/// underneath both, what that player has taken. Accent ring + gentle glow
/// while that side is to move.
class PlayerBarCard extends StatelessWidget {
  const PlayerBarCard({
    super.key,
    required this.identity,
    this.trailing,
    this.captured,
    this.toMove = false,
  });

  /// The height a player-bar slot reserves, passed to `ModePanes` by every
  /// screen that shows one — the same shape as `ModeHeaderBar.height`, so the
  /// card and the box cut for it can never drift apart.
  ///
  /// Covers a 44dp avatar (48 with the editable identity's tap padding), the
  /// ~16dp captured line beneath it and the card's own 8dp of vertical
  /// padding, with a few pixels to spare. `slotHeightFor` grows the slot from
  /// here with the text scale.
  static const double height = 76;

  final Widget identity;
  final Widget? trailing;

  /// The pieces this player has captured, on their own line. Given the row
  /// rather than the trailing slot because sharing that slot with the clock is
  /// what squeezed the old version down to an ellipsis.
  final Widget? captured;

  final bool toMove;

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
      decoration: style.decoration(AppRadius.control).copyWith(
            border: Border.all(
              color: toMove ? tokens.accent : style.border,
              width: toMove ? 1.4 : 1,
            ),
            // The side to move keeps its accent halo on top of the plane's
            // own shadow, so "your turn" reads before you find the clock.
            boxShadow: toMove
                ? [
                    ...style.shadows,
                    BoxShadow(color: tokens.accentSoft, blurRadius: 12),
                  ]
                : style.shadows,
          ),
      // A column, so the extra height buys the captured pieces a line of their
      // own. `mainAxisSize.min` and a centred cross axis so the card still
      // sits correctly when the slot is taller than it needs — `_slot` centres
      // whatever it is given rather than stretching it.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(child: identity),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          if (captured != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: captured,
            ),
        ],
      ),
    );
  }
}

/// The shared player identity cluster — a generous avatar (picked picture
/// or glyph fallback) plus name and subtitle — used by the Practice and
/// Studio player bars so both modes present players the same way.
class PlayerIdentity extends StatelessWidget {
  const PlayerIdentity({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarPath,
    this.glyph = '🙂',
    this.active = false,
    this.onEdit,
    this.avatarSize = 44,
  });

  final String name;

  /// Small dim line under the name (engine level, game meta).
  final String? subtitle;

  /// Picture file path; null falls back to [glyph].
  final String? avatarPath;
  final String glyph;

  /// Highlights the avatar ring (side to move).
  final bool active;

  /// Tapping the identity edits it (practice human, studio players).
  final VoidCallback? onEdit;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final path = avatarPath;
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? tokens.accentSoft : tokens.raised,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? tokens.accent : tokens.edge,
              width: active ? 1.6 : 1,
            ),
            image: path != null
                ? DecorationImage(
                    // Decode at display size: a full-resolution gallery
                    // photo would cost tens of MB for a ~40dp circle.
                    image: ResizeImage(
                      FileImage(io.File(path)),
                      width: (avatarSize *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: path == null
              ? Text(
                  glyph,
                  style: TextStyle(fontSize: avatarSize * 0.5),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Through the type roles, not a literal: these cards
                      // used to hardcode their sizes and so were the one
                      // surface that ignored the reader's chosen typeface.
                      style: context.type.label.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onEdit != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: tokens.textFaint,
                    ),
                  ],
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(color: tokens.textDim),
                ),
            ],
          ),
        ),
      ],
    );
    if (onEdit == null) return identity;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: identity,
      ),
    );
  }
}
