import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../layout/content_width.dart';
import '../layout/window_class.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/app_spacing.dart';
import '../theme/tokens_context.dart';

/// Full-screen celebration: confetti burst + big emoji + title + an XP
/// count-up. Used for lesson/checkpoint completion and game wins.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.xpEarned,
    this.formatXp,
    this.actions = const [],
  }) : assert(xpEarned == null || formatXp != null,
            'xpEarned needs formatXp — the XP chip text is localized');

  final String emoji;
  final String title;
  final String? subtitle;
  final int? xpEarned;

  /// Localizes the counting XP chip (the caller owns i18n, this overlay
  /// does not): typically `(n) => t('gamify.earned', {'n': n})`.
  final String Function(int value)? formatXp;

  final List<Widget> actions;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Short (landscape-phone) windows get tighter chrome, and the card
        // scrolls instead of overflowing when the content doesn't fit.
        final tight = constraints.maxHeight < LayoutSpec.shortAt;
        final margin = tight ? AppSpacing.lg : AppSpacing.xxl;
        final padding = tight ? AppSpacing.lg : AppSpacing.xl;
        // A DEFINITE width, not a cap. As a non-positioned child of a Stack
        // the card is laid out loosely, so a bare maxWidth left it hugging its
        // own Column — "Level up!" and one button rendered as a sliver down
        // the middle of the screen.
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth - margin * 2
            : ContentWidth.dialog;
        final width = available.clamp(0.0, ContentWidth.dialog);
        return Stack(
          alignment: Alignment.center,
          children: [
            ModalBarrier(color: tokens.scrim, dismissible: false),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 50,
                gravity: 0.25,
                colors: [
                  tokens.accent,
                  tokens.best,
                  tokens.info,
                  tokens.brilliant,
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.all(margin),
              padding: EdgeInsets.all(padding),
              width: width,
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight - margin * 2).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              decoration:
                  tokens.surfaceAt(Elevation.floating).decoration(24).copyWith(
                        // The one card that floats over a full-screen
                        // scrim: it carries the floating plane's shadow
                        // twice over, so it lifts clear of the confetti.
                        boxShadow: [
                          BoxShadow(
                            color: tokens.shadow.withValues(alpha: 0.50),
                            blurRadius: 44,
                            offset: const Offset(0, 18),
                          ),
                          ...tokens.surfaceAt(Elevation.floating).shadows,
                        ],
                      ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1),
                      duration: Motion.slow,
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style:
                          context.type.display.copyWith(color: tokens.text),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.textDim),
                      ),
                    ],
                    if (widget.xpEarned != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: widget.xpEarned!),
                        duration: const Duration(milliseconds: 900),
                        curve: Motion.enter,
                        builder: (context, value, _) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.formatXp!(value),
                            style: TextStyle(
                              fontFamily: context.type.font.mono,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (widget.actions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        // The card no longer hugs its content, so the buttons
                        // have to be centred deliberately.
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: widget.actions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
