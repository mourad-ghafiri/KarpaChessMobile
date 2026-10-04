import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/ui/progress_bar.dart';
import '../../core/ui/progress_ring.dart';
import '../../core/ui/stat_chip.dart';
import '../../core/ui/surface.dart';
import '../../core/ui/symbol_glyph.dart';
import '../../features/academy/domain/academy_rank.dart';
import '../application/progression_controller.dart';
import '../domain/progression.dart';

/// THE score, rendered once.
///
/// Rank crest, level bar, streak and the daily-goal ring — the same numbers
/// wherever they appear, because there is only one of everything behind
/// them: `xp` feeds level, level feeds rank, and every surface in the app
/// awards into that one counter. Lessons, practice wins and puzzles all move
/// this card.
///
/// It used to exist twice, hand-copied into the academy home and the
/// settings sheet; a third surface was the moment to stop.
class ScoreCard extends ConsumerWidget {
  const ScoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(progressionControllerProvider);
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final now = DateTime.now();
    final rank = AcademyRank.fromLevel(progression.level);
    final streak = progression.streakAt(now);
    final xpToday = progression.xpTodayAt(now);

    return Surface(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.accent),
            ),
            child: SymbolGlyph(rank.glyph, size: 22, color: tokens.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              // Shrink-wrapped, so the row centres it: on a tablet the card
              // is stretched to the height of the actions beside it
              // (`TabletHero`), and a full-height column left the rank and
              // bar pinned to the top while the crest and ring sat centred.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(rank.labelKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.title,
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedProgressBar(value: progression.levelProgress),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatChip(label: t('gamify.level', {'n': progression.level})),
                    // Only once there is one: a first launch greeted the
                    // reader with "0-day streak", a score of having done
                    // nothing yet.
                    if (streak > 0)
                      StatChip(
                        emoji: '🔥',
                        label: t('gamify.dayStreak', {'n': streak}),
                        color: tokens.accent,
                        filled: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Tooltip(
            message: t('gamify.dailyGoal'),
            child: ProgressRing(
              // Clamped: a big day used to push the ring past full on the
              // academy home while settings clamped it, so the same number
              // drew two different rings.
              progress: (xpToday / XpRules.dailyGoalXp).clamp(0.0, 1.0),
              size: 52,
              strokeWidth: 5,
              child: Text(
                '$xpToday',
                style: context.type.monoAt(12, weight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
