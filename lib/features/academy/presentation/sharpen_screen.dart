import 'dart:async';

import 'package:chessground/chessground.dart' show Arrow, PlayerSide, Shape;
import 'package:dartchess/dartchess.dart' show NormalMove, Position, Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sound_providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/chess/san_moves.dart';
import '../../../core/chess/tolerant_position.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/layout/mode_panes.dart';
import '../../../core/markdown/markdown_view.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/board_context_card.dart';
import '../../../core/ui/board_feedback.dart';
import '../../board/presentation/board_stage.dart';
import '../../../core/ui/celebration_overlay.dart';
import '../../../core/ui/hint_toast.dart';
import '../../../core/ui/measure.dart';
import '../../../core/ui/stat_chip.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/progression.dart';
import '../../board/presentation/karpa_board.dart';
import '../application/academy_providers.dart';
import '../../../core/ui/mode_header_bar.dart';
import 'concept_player_screen.dart' show academyRevertDelay;
import 'pattern_thumb.dart';

/// Sharpen session: quick-fire reviews of due patterns. One position per
/// pattern — find the move on the first try to keep it sharp. Also serves
/// single-pattern reviews launched from the Pattern Book.
class SharpenScreen extends ConsumerStatefulWidget {
  const SharpenScreen({super.key, required this.conceptIds});

  /// Review queue (already capped by the caller).
  final List<String> conceptIds;

  @override
  ConsumerState<SharpenScreen> createState() => _SharpenScreenState();
}

class _SharpenScreenState extends ConsumerState<SharpenScreen> {
  int _index = 0;
  int _misses = 0;
  int _combo = 0;
  int _reviewed = 0;
  int _correct = 0;
  int _starUps = 0;
  int _xpEarned = 0;
  bool _leveledUp = false;
  bool _resolved = false;
  bool _done = false;
  bool _showLevelUp = false;
  bool _flash = false;
  int _shakeTick = 0;
  Position? _transient;
  NormalMove? _transientMove;
  NormalMove? _answerArrow;
  bool _showAnswer = false;
  bool _answerDismissed = false;
  Timer? _revertTimer;
  int _skipScheduledFor = -1;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  void _next() {
    _revertTimer?.cancel();
    if (!mounted) return;
    if (_index + 1 >= widget.conceptIds.length) {
      ref.playSound(AppSound.win);
      ref.hapticMedium();
      setState(() => _done = true);
      return;
    }
    setState(() {
      _index++;
      _misses = 0;
      _resolved = false;
      _flash = false;
      _transient = null;
      _transientMove = null;
      _answerArrow = null;
      _showAnswer = false;
      _answerDismissed = false;
    });
  }

  /// Skips an unresolvable queue entry (no PlayStep, no proof, bad FEN).
  void _scheduleSkip() {
    if (_skipScheduledFor == _index) return;
    _skipScheduledFor = _index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_done) _next();
    });
  }

  Future<void> _review(String conceptId, {required bool success}) async {
    final controller = ref.read(progressionControllerProvider.notifier);
    final before =
        ref.read(progressionControllerProvider).patterns[conceptId]?.stars ?? 0;
    final leveled = await controller.reviewPattern(conceptId, success: success);
    if (!mounted) return;
    final after =
        ref.read(progressionControllerProvider).patterns[conceptId]?.stars ?? 0;
    setState(() {
      _reviewed++;
      if (success) _correct++;
      if (after > before) _starUps++;
      if (success) _xpEarned += XpRules.patternSharpened;
      _leveledUp = _leveledUp || leveled;
    });
  }

  void _onMove(NormalMove move, Position base, SharpenChallenge challenge) {
    if (_resolved) return;
    final (next, _) = base.makeSan(move);
    final ok = challenge.answers.any((a) => acceptsAuthored(base, move, a));

    if (ok) {
      final firstTry = _misses == 0;
      ref.playSound(AppSound.good);
      ref.hapticLight();
      setState(() {
        _resolved = true;
        _transient = next;
        _transientMove = move;
        _flash = true;
        _combo = firstTry ? _combo + 1 : 0;
      });
      _review(challenge.conceptId, success: true);
      return;
    }

    ref.playSound(AppSound.bad);
    setState(() {
      _misses++;
      _transient = next;
      _transientMove = move;
      _shakeTick++;
    });
    if (_misses >= 2) {
      // Second miss: reveal the answer, mark the review failed, and wait
      // for the learner to acknowledge it — no auto-advance.
      final answer = legalMoveFromSan(base, challenge.answers.first);
      setState(() {
        _resolved = true;
        _combo = 0;
        _answerArrow = answer;
        _showAnswer = true;
      });
      _revertTimer = Timer(academyRevertDelay, () {
        if (mounted) {
          setState(() {
            _transient = null;
            _transientMove = null;
          });
        }
      });
      _review(challenge.conceptId, success: false);
    } else {
      _revertTimer = Timer(academyRevertDelay, () {
        if (mounted) {
          setState(() {
            _transient = null;
            _transientMove = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;

    if (_done || widget.conceptIds.isEmpty) {
      final subtitle = StringBuffer('$_correct / $_reviewed  ⚔');
      if (_starUps > 0) subtitle.write('   ★ +$_starUps');
      return Scaffold(
        body: ColoredBox(
          color: tokens.bg,
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_showLevelUp)
                  CelebrationOverlay(
                    emoji: '🚀',
                    title: t('gamify.levelUp'),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(t('ui.button.close')),
                      ),
                    ],
                  )
                else
                  CelebrationOverlay(
                    emoji: '⚔',
                    title: t('academy.sharpen'),
                    subtitle: subtitle.toString(),
                    xpEarned: _xpEarned > 0 ? _xpEarned : null,
                    formatXp: (n) => t('gamify.earned', {'n': n}),
                    actions: [
                      FilledButton(
                        onPressed: () {
                          if (_leveledUp) {
                            setState(() => _showLevelUp = true);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(t('ui.button.close')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final conceptId = widget.conceptIds[_index];
    // Names what is being sharpened — until now nothing on this screen did.
    final conceptTitle =
        ref.watch(conceptLessonProvider(conceptId)).valueOrNull?.title ?? '';
    final challengeAsync = ref.watch(sharpenChallengeProvider(conceptId));
    final challenge = challengeAsync.valueOrNull;
    if (challengeAsync.hasError ||
        (challengeAsync.hasValue && challenge == null)) {
      _scheduleSkip();
    }

    Position? base;
    if (challenge != null) {
      try {
        base = positionFromFen(challenge.fen);
      } catch (_) {
        _scheduleSkip();
      }
    }

    // The one header every mode wears. Sharpen's close needs no
    // confirmation: every graded answer has already banked.
    final topBar = ModeHeaderBar(
      label: t('academy.sharpen'),
      progress: widget.conceptIds.isEmpty
          ? 0
          : (_index + 1) / widget.conceptIds.length,
      actionIcon: Icons.close,
      actionTooltip: t('ui.button.close'),
      onAction: () => Navigator.of(context).pop(),
    );

    if (base == null || challenge == null) {
      return Scaffold(
        body: SafeArea(
          // The header where the loaded screen puts it, so it doesn't jump
          // when the challenge resolves.
          child: ModePanes.pending(
            topBar: topBar,
            body: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final position = _transient ?? base;
    final orientation = sideToMoveOf(challenge.fen);
    final playerSide = _resolved || _transient != null
        ? PlayerSide.none
        : base.turn == Side.white
        ? PlayerSide.white
        : PlayerSide.black;

    final shapes = <Shape>{
      if (_answerArrow != null)
        Arrow(
          color: tokens.info.withValues(alpha: 0.8),
          orig: _answerArrow!.from,
          dest: _answerArrow!.to,
        ),
    };

    final glow = (0.10 + 0.05 * _combo).clamp(0.10, 0.30).toDouble();

    return Scaffold(
      body: SafeArea(
        child: ModePanes(
          topBar: topBar,
          topBarHeight: ModeHeaderBar.height,
          aboveBoard: BoardContextCard(
            emoji: '⚡',
            title: conceptTitle,
            trailing: _combo > 1
                // A run of right answers, not the day streak's flame.
                ? StatChip(label: '×$_combo', icon: Icons.done_all)
                : null,
          ),
          aboveHeight: BoardContextCard.height,
          // The answer reveal floats as the unified hint toast; the
          // acknowledge button stays pinned in the panel below it.
          toast: _showAnswer && !_answerDismissed
              ? HintToast(
                  icon: Icons.school_outlined,
                  title: t('academy.showAnswer'),
                  onClose: () => setState(() => _answerDismissed = true),
                  child: Text(
                    challenge.answers.first,
                    style: TextStyle(
                      fontFamily: context.type.font.mono,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: tokens.info,
                    ),
                  ),
                )
              : null,
          boardBuilder: (context, boardSize) => ShakeOnMiss(
            tick: _shakeTick,
            child: AnimatedContainer(
              duration: Motion.slow,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (_combo >= 2)
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: glow),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: BoardStage(
                size: boardSize,
                builder: (board) => [
                  KarpaBoard(
                    size: board,
                    position: position,
                    orientation: orientation,
                    lastMove: _transientMove,
                    playerSide: playerSide,
                    onMove: (move) => _onMove(move, base!, challenge),
                    shapes: shapes,
                  ),
                  SuccessFlash(visible: _flash),
                ],
              ),
            ),
          ),
          panel: SingleChildScrollView(
            padding: AppInsets.panel,
            // The lesson panel's grammar — a start-aligned heading over its
            // prose, both at a reading measure. A centred heading over a
            // start-aligned paragraph left the two on different edges.
            child: ReadingMeasure(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('academy.findTheMove'), style: context.type.title),
                  // The author's setup says what is being asked. Without it a
                  // plan or opening position has several good moves and only
                  // one of them is graded as correct.
                  if (challenge.prompt.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    MarkdownView(challenge.prompt.trim()),
                  ],
                ],
              ),
            ),
          ),
          actionBar: _resolved
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                  child: ButtonMeasure(
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _showAnswer ? t('academy.gotIt') : t('ui.button.next'),
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

}
