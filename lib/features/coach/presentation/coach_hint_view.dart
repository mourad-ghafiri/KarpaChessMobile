import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../core/markdown/markdown_view.dart';
import '../../../core/text/html_lite.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../application/coach_hint_controller.dart';
import '../domain/coach_answer_format.dart';
import '../domain/coach_menu.dart';
import '../domain/coach_service.dart';

/// The body of the hint toast in every mode: pick a question, then read the
/// coach's answer. Deliberately text-only — nothing here ever draws on the
/// board (SAN chips stay decorative).
class CoachHintView extends ConsumerWidget {
  const CoachHintView({super.key, required this.scope});

  final HintScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final state = ref.watch(coachHintControllerProvider(scope));
    final controller = ref.read(coachHintControllerProvider(scope).notifier);

    if (state.intent == null) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final intent in coachMenuFor(scope))
            ActionChip(
              label: Text(t(coachIntentLabelKey(intent))),
              onPressed: () => controller.ask(intent),
            ),
        ],
      );
    }

    if (state.loading || state.answer == null) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            t(coachIntentLabelKey(state.intent!)),
            style: context.type.body.copyWith(color: tokens.textDim),
          ),
        ],
      );
    }

    // The pills answer only the questions they belong to. Both used to ride
    // on every answer, so asking for a PLAN printed the engine's best move
    // above it — the answer to a question the reader chose not to ask —
    // and a bare eval the plan never explained.
    final intent = state.intent!;
    final evalCp = intent == CoachIntent.bestMove ||
            intent == CoachIntent.evaluation
        ? state.evalCp
        : null;
    final bestSan = intent == CoachIntent.bestMove ? state.bestSan : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (evalCp != null || bestSan != null) ...[
          Row(
            children: [
              if (evalCp != null)
                _Pill(
                  label: _evalText(evalCp),
                  color: _evalColor(evalCp, tokens),
                  mono: true,
                ),
              if (bestSan != null) ...[
                if (evalCp != null) const SizedBox(width: AppSpacing.sm),
                _Pill(label: bestSan, color: tokens.accent, mono: true),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        MarkdownView(
          enrichCoachMarkdown(htmlLiteToMarkdown(state.answer!)),
          style: _coachStyle(context, tokens),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: controller.back,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(t('coach.askAnother')),
          ),
        ),
      ],
    );
  }

  /// Eval from the side to move: green when they stand better, red when
  /// worse, neutral when it is level.
  static Color _evalColor(int cp, AppTokens tokens) {
    if (cp > 60) return tokens.best;
    if (cp < -60) return tokens.mistake;
    return tokens.textDim;
  }

  static String _evalText(int cp) {
    if (cp.abs() > 90000) return cp > 0 ? '#' : '#-';
    final pawns = cp / 100;
    return '${pawns >= 0 ? '+' : ''}${pawns.toStringAsFixed(1)}';
  }

  /// On-brand markdown: accent headings and SAN chips, dimmed quotes.
  static KarpaMarkdownStyle _coachStyle(
    BuildContext context,
    AppTokens tokens,
  ) {
    // The type roles, not a smaller private scale: the answer is reading
    // text, and at 13 it was the smallest prose in the app.
    final base = KarpaMarkdownStyle.fromTheme(Theme.of(context));
    final type = context.type;
    return KarpaMarkdownStyle(
      body: base.body.merge(type.body).copyWith(color: tokens.text),
      h2: base.h2.merge(type.heading).copyWith(color: tokens.accent),
      h3: base.h3
          .merge(type.body)
          .copyWith(fontWeight: FontWeight.w700, color: tokens.accent),
      h4: base.h4.merge(type.label).copyWith(color: tokens.accent),
      code: base.code.copyWith(color: tokens.textDim),
      quote: base.quote.merge(type.label).copyWith(
            fontWeight: FontWeight.w400,
            color: tokens.textDim,
          ),
      quoteBarColor: tokens.accentSoft,
      sanChip: type.san.copyWith(
        fontWeight: FontWeight.w700,
        color: tokens.accent,
      ),
      sanChipBackground: tokens.accentSoft,
      ruleColor: tokens.edge,
      blockSpacing: 8,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.mono = false});

  final String label;
  final Color color;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // The pill floats on the toast's floating plane.
    final fill = Color.alphaBlend(
      color.withValues(alpha: 0.16),
      tokens.surfaceAt(Elevation.floating).fill,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: (mono ? context.type.san : context.type.label).copyWith(
          fontWeight: FontWeight.w800,
          color: tokens.legible(color, on: fill),
        ),
      ),
    );
  }
}
