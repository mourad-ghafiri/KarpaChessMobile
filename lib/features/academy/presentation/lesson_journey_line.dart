import 'package:flutter/material.dart';

import '../../../core/i18n/i18n_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/tokens_context.dart';

/// The SEE → PLAY → OWN tracker as one slim line, floating in the lead gap
/// directly above the lesson card (the `ModePanes.leadContent` slot) — the
/// run's shape decorates slack that was already there, so the board never
/// moves for it.
class LessonJourneyLine extends StatelessWidget {
  const LessonJourneyLine({
    super.key,
    required this.beatPhases,
    required this.current,
    required this.t,
  });

  /// One phase i18n key per beat, in beat order (`academy.seeIt` …).
  final List<String> beatPhases;

  /// Index of the beat the learner is on.
  final int current;

  final Translate t;

  /// The distinct phases in the order the lesson visits them. Usually
  /// SEE·PLAY·OWN, but a lesson with no proof simply has no OWN segment.
  List<String> get _phases {
    final out = <String>[];
    for (final key in beatPhases) {
      if (!out.contains(key)) out.add(key);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentPhase = beatPhases[current.clamp(0, beatPhases.length - 1)];
    final phases = _phases;
    final reached = phases.indexOf(currentPhase);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, phase) in phases.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child:
                  Icon(Icons.chevron_right, size: 17, color: tokens.textFaint),
            ),
          _PhaseStep(
            label: t(phase),
            state: i < reached
                ? _PhaseState.done
                : i == reached
                ? _PhaseState.current
                : _PhaseState.upcoming,
            tokens: tokens,
          ),
        ],
      ],
    );
  }
}

enum _PhaseState { done, current, upcoming }

class _PhaseStep extends StatelessWidget {
  const _PhaseStep({
    required this.label,
    required this.state,
    required this.tokens,
  });

  final String label;
  final _PhaseState state;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _PhaseState.done => tokens.success,
      _PhaseState.current => tokens.accent,
      _PhaseState.upcoming => tokens.textFaint,
    };
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (state) {
              _PhaseState.done => Icons.check_circle_rounded,
              _PhaseState.current => Icons.play_circle_fill_rounded,
              _PhaseState.upcoming => Icons.circle_outlined,
            },
            size: 18,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: context.type.font.display,
                fontSize: 16,
                height: 1.1,
                fontWeight: state == _PhaseState.current
                    ? FontWeight.w800
                    : FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
