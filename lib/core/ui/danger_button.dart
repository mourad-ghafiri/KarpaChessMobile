import 'package:flutter/material.dart';

import '../theme/tokens_context.dart';

/// The confirm of a dialog that throws something away — a live game, a
/// lesson's progress, an imported game, everything (Reset).
///
/// Those confirms were the accent primary, the same green "go on" as Play
/// and Next, so the safest-looking button on the dialog was the one that
/// discarded work. A destructive confirm now wears the danger ink, and the
/// dismiss beside it stays the quiet text button it always was.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: tokens.danger,
        foregroundColor: tokens.legible(tokens.onAccent, on: tokens.danger),
      ),
      child: child,
    );
  }
}
