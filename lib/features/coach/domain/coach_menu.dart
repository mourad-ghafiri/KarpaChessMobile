import 'coach_service.dart';

/// Which board a hint is being asked about. Each mode keeps its own hint
/// state so the two live screens never share a toast.
enum HintScope { practice, studio }

/// The questions offered for [scope], in menu order.
///
/// The sets are deliberately different: while playing you want help with
/// YOUR next move, while studying a finished game you first want the move
/// that was just played explained.
List<CoachIntent> coachMenuFor(HintScope scope) => switch (scope) {
      HintScope.practice => const [
          CoachIntent.bestMove,
          CoachIntent.tactics,
          CoachIntent.plan,
          CoachIntent.evaluation,
          CoachIntent.kingSafety,
        ],
      HintScope.studio => const [
          CoachIntent.lastMove,
          CoachIntent.bestMove,
          CoachIntent.tactics,
          CoachIntent.plan,
          CoachIntent.evaluation,
        ],
    };

/// i18n key for a question's button label.
String coachIntentLabelKey(CoachIntent intent) => 'coach.ask.${intent.name}';
