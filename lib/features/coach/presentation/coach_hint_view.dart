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
            style: TextStyle(fontSize: 13, color: tokens.textDim),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.evalCp != null || state.bestSan != null) ...[
          Row(
            children: [
              if (state.evalCp != null)
                _Pill(
                  label: _evalText(state.evalCp!),
                  color: _evalColor(state.evalCp!, tokens),
                  mono: true,
                ),
              if (state.bestSan != null) ...[
                const SizedBox(width: 8),
                _Pill(label: state.bestSan!, color: tokens.accent, mono: true),
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
    final base = KarpaMarkdownStyle.fromTheme(Theme.of(context));
    return KarpaMarkdownStyle(
      body: base.body.copyWith(fontSize: 13, color: tokens.text),
      h2: base.h2.copyWith(fontSize: 16, color: tokens.accent),
      h3: base.h3.copyWith(fontSize: 14, color: tokens.accent),
      h4: base.h4.copyWith(fontSize: 13, color: tokens.accent),
      code: base.code.copyWith(color: tokens.textDim),
      quote: base.quote.copyWith(fontSize: 12.5, color: tokens.textDim),
      quoteBarColor: tokens.accentSoft,
      sanChip: context.type.san.copyWith(
        fontSize: 12.5,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: (mono ? context.type.san : const TextStyle()).copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
