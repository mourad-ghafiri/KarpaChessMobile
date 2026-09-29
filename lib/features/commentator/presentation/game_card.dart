import 'package:flutter/material.dart';

import '../../../content/domain/models.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/stat_chip.dart';
import '../../../core/ui/surface.dart';

/// One game as a row: who played whom, where and when, how long.
///
/// Shared by the library list and the import sheet's preview on purpose — the
/// preview has to be the row it is about to become, or it is not a preview.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.t,
    required this.p,
    this.onTap,
    this.onRemove,
  });

  final StudyGame game;
  final Translate t;
  final Pluralize p;

  /// Null in the import preview, where the card is showing rather than offering.
  final VoidCallback? onTap;

  /// Non-null only for the reader's own games.
  final VoidCallback? onRemove;

  /// Event, year and length, skipping whatever the source did not say. A
  /// pasted move list has none of the three but its move count.
  String get _byline => [
        if (game.event.isNotEmpty) game.event,
        if (game.year != null) '${game.year}',
        p('commentator.moveCount', game.moveCount),
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = game.title.isEmpty ? t('commentator.untitled') : game.title;
    // Self-sizing row card: monogram · pairing + byline · result. No fixed
    // box required from the caller.
    return Surface(
      onTap: onTap,
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
            child: Text(
              game.monogram.isEmpty ? '♞' : game.monogram,
              style: TextStyle(
                fontFamily: context.type.font.display,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: context.type.font.display,
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: tokens.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _byline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: tokens.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatChip(label: game.result, color: tokens.accent, filled: true),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: t('commentator.remove'),
              icon: Icon(Icons.delete_outline, size: 20, color: tokens.textDim),
            ),
        ],
      ),
    );
  }
}
