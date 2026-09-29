import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../engine/application/engine_providers.dart';
import '../domain/builtin_coach.dart';
import '../domain/coach_service.dart';
import '../domain/insight_builder.dart';

/// Shared engine insight scanner (coach answers + studio node analysis).
final insightBuilderProvider = Provider<InsightBuilder>(
  (ref) => InsightBuilder(ref.watch(engineServiceProvider)),
);

/// The offline coach that answers every hint question.
final coachServiceProvider = Provider<CoachService>((ref) {
  // `requireValue`, not a null-safe fallback: the whole UI is gated on the
  // bundle having loaded (see app.dart), and the identity translator this
  // used to fall back to answered every question in raw dotted keys.
  final i18n = ref.watch(i18nProvider).requireValue;
  return BuiltinCoach(i18n.t, i18n.plural);
});
