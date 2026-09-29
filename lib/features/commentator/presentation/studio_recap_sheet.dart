import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/progress_ring.dart';
import '../application/commentator_controller.dart';

/// Recap modal styled as a shareable summary card: result headline plus both
/// players with their accuracy rings. Returns when the sheet is dismissed.
Future<void> showStudioRecapSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (context) => const _RecapSheet(),
  );
}

class _RecapSheet extends ConsumerWidget {
  const _RecapSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final state = ref.watch(commentatorControllerProvider);
    final recap = state.recap;
    if (recap == null) return const SizedBox(height: 120);

    return Padding(
      padding: AppInsets.sheet.resolve(Directionality.of(context)).copyWith(top: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tokens.raised, tokens.panel],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.accentSoft),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('commentator.result.title'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: tokens.textDim,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _headline(t, recap.result),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: context.type.font.display,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _RecapSide(
                        t: t,
                        info: state.white,
                        fallbackKey: 'commentator.result.white',
                        accuracy: recap.whiteAccuracy,
                        computing: recap.computing,
                      ),
                    ),
                    Expanded(
                      child: _RecapSide(
                        t: t,
                        info: state.black,
                        fallbackKey: 'commentator.result.black',
                        accuracy: recap.blackAccuracy,
                        computing: recap.computing,
                      ),
                    ),
                  ],
                ),
                if (recap.computing) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: recap.totalCount == 0
                          ? null
                          : recap.analyzedCount / recap.totalCount,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${t('commentator.result.analyzing')} '
                    '${recap.analyzedCount}/${recap.totalCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _headline(Translate t, GameResult? result) {
    if (result == null) return t('commentator.untitled');
    return switch (result.kind) {
      GameResultKind.checkmate => t('commentator.result.checkmate', {
          'winner': t(result.winner == 'w'
              ? 'commentator.result.white'
              : 'commentator.result.black'),
        }),
      GameResultKind.stalemate => t('commentator.result.stalemate'),
      GameResultKind.draw => t('commentator.result.drawnGame'),
      GameResultKind.whiteWins => t('commentator.result.whiteWins'),
      GameResultKind.blackWins => t('commentator.result.blackWins'),
    };
  }
}

class _RecapSide extends StatelessWidget {
  const _RecapSide({
    required this.t,
    required this.info,
    required this.fallbackKey,
    required this.accuracy,
    required this.computing,
  });

  final Translate t;
  final PlayerInfo info;
  final String fallbackKey;
  final double? accuracy;
  final bool computing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final name = info.name.isNotEmpty ? info.name : t(fallbackKey);
    final photo = info.photoPath;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: tokens.raised,
          // Decode at display size (44dp circle), not full photo resolution.
          backgroundImage: photo != null
              ? ResizeImage(
                  FileImage(File(photo)),
                  width:
                      (44 * MediaQuery.devicePixelRatioOf(context)).round(),
                )
              : null,
          child: photo == null
              ? Text(
                  _monogram(name),
                  style: TextStyle(
                    fontFamily: context.type.font.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.accent,
                  ),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.text,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ProgressRing(
          progress: (accuracy ?? 0) / 100,
          size: 92,
          strokeWidth: 6,
          child: Text(
            accuracy != null ? '${accuracy!.round()}%' : (computing ? '…' : '—'),
            style: TextStyle(
              fontFamily: context.type.font.display,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: tokens.text,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          t('commentator.result.accuracy'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: tokens.textDim,
          ),
        ),
      ],
    );
  }

  static String _monogram(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '♞';
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    final word = parts.first;
    return word.length >= 2 ? word.substring(0, 2) : word;
  }
}
