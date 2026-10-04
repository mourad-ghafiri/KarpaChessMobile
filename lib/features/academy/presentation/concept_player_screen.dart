import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart'
    show Arrow, Circle, PlayerSide, Shape;
import 'package:dartchess/dartchess.dart' show NormalMove, Position, Side;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/domain/models.dart';
import '../../../core/audio/sound_providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/chess/san_moves.dart';
import '../../../core/chess/tolerant_position.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/mode_panes.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/markdown/markdown_view.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/board_feedback.dart';
import '../../board/presentation/board_stage.dart';
import '../../../core/ui/board_context_card.dart';
import '../../../core/ui/celebration_overlay.dart';
import '../../../core/ui/danger_button.dart';
import '../../../core/ui/drawing_mode_bar.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/hint_toast.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/lesson_progress.dart';
import '../../../progression/domain/progression.dart';
import '../../board/presentation/karpa_board.dart';
import '../../commentator/application/drawing_controller.dart';
import '../../commentator/presentation/drawing_overlay.dart';
import '../../../core/ui/mode_header_bar.dart';
import '../../../core/ui/measure.dart';
import '../application/academy_providers.dart';
import '../domain/board_script.dart';
import '../../../core/ui/stat_chip.dart';
import 'lesson_journey_line.dart';

/// How long each move of a taught sequence is held before the next one plays.
const _frameInterval = Duration(milliseconds: 900);

/// How long a rejected move stays visible before the board snaps back. Shared
/// with Sharpen so the same mistake feels the same wherever it is made.
const academyRevertDelay = Duration(milliseconds: 800);

/// Pause before the scripted opponent reply inside a proof line.
const _replyDelay = Duration(milliseconds: 450);

/// How long a tapped chip's preview arrow lingers.
const _previewLinger = Duration(seconds: 2);

/// Misses before the board offers the piece, and before it offers the move.
const _hintAfterMisses = 2;
const _answerAfterMisses = 3;

/// One unit of a lesson run. Every beat answers the same questions, so the
/// panel can render any of them without knowing which it holds — a beat type
/// cannot invent its own layout.
sealed class _Beat {
  const _Beat(this.position);

  final Position position;

  /// i18n key for the phase chip.
  String get phaseKey;

  /// Optional heading above the prose.
  String? get heading;

  /// Markdown body. Rendered the same way for every beat type.
  String get body;

  /// The authored hint for this position, shown by the hint button.
  String? get help;
}

class _SeeBeat extends _Beat {
  const _SeeBeat(super.position, this.step);

  final TeachStep step;

  @override
  String get phaseKey => 'academy.seeIt';

  @override
  String? get heading => step.title;

  @override
  String get body => step.text;

  @override
  String? get help => null;
}

class _PlayBeat extends _Beat {
  const _PlayBeat(super.position, this.step);

  final PlayStep step;

  @override
  String get phaseKey => 'academy.playIt';

  @override
  String? get heading => null;

  @override
  String get body => step.prompt;

  @override
  String? get help => step.hint;
}

class _ProofBeat extends _Beat {
  const _ProofBeat(super.position, this.puzzle);

  final Puzzle puzzle;

  @override
  String get phaseKey => 'academy.ownIt';

  @override
  String? get heading => puzzle.title;

  @override
  String get body => puzzle.setup ?? '';

  @override
  String? get help => puzzle.hint;
}

/// The concept player: SEE it (the board speaks the step's chips) → PLAY it
/// (guided moves, with help on request) → OWN it (proof puzzles).
/// Completing the run mints the concept as an owned pattern.
class ConceptPlayerScreen extends ConsumerStatefulWidget {
  const ConceptPlayerScreen({super.key, required this.conceptId});

  final String conceptId;

  @override
  ConsumerState<ConceptPlayerScreen> createState() =>
      _ConceptPlayerScreenState();
}

class _ConceptPlayerScreenState extends ConsumerState<ConceptPlayerScreen> {
  List<_Beat>? _beats;
  final Map<int, BoardScript> _scripts = {};
  int _beat = 0;

  /// Beats whose play/proof was completed this run. `_enterBeat` restores
  /// `_beatSolved` from here, so stepping back re-enters a beat in its
  /// solved state instead of demanding a re-solve to move forward again.
  final Set<int> _solvedBeats = {};

  /// Beats that have already paid out. XP is minted once per beat per run —
  /// without this, walking back and forward again would farm the awards.
  /// Seeded from the persisted [LessonProgress] on resume, so abandoning
  /// and reopening a lesson cannot re-mint either.
  final Set<int> _awardedBeats = {};

  /// Furthest beat ever entered this lesson — the persisted resume point.
  /// Monotonic: walking back never regresses it. Any progress past beat 0
  /// is also what offers the header's restart action.
  int _furthestBeat = 0;

  /// Fixed for the whole lesson: the side the learner plays. Deriving it per
  /// beat turned the board around mid-lesson.
  Side _orientation = Side.white;

  // SEE state.
  int _frame = 0;
  NormalMove? _previewArrow;

  // PLAY / OWN state.
  int _misses = 0;
  bool _hintOpen = false;
  Position? _transient;
  NormalMove? _transientMove;
  bool _beatSolved = false;
  Position? _proofPosition;
  NormalMove? _proofLastMove;
  int _proofCursor = 0;

  // Effects.
  bool _flash = false;
  int _shakeTick = 0;
  int _floaterTick = 0;

  // Completion.
  bool _finished = false;

  /// Everything banked during the run — per-beat awards plus the mint — so the
  /// celebration reports what the learner actually earned.
  int _earnedXp = 0;
  bool _leveledUp = false;
  bool _showOwned = false;
  bool _showLevelUp = false;

  Timer? _sequenceTimer;
  Timer? _revertTimer;
  Timer? _replyTimer;
  Timer? _previewTimer;

  /// Drives the panel's prose so a solved proof can bring its explanation into
  /// view. The explanation is the only place the app says *why* a tactic
  /// works, and it is long enough (median ~770 characters) to sit entirely
  /// below the fold on a phone if nothing scrolls to it.
  final ScrollController _panelScroll = ScrollController();

  @override
  void dispose() {
    _cancelTimers();
    _panelScroll.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _sequenceTimer?.cancel();
    _revertTimer?.cancel();
    _replyTimer?.cancel();
    _previewTimer?.cancel();
  }

  // -- beat lifecycle ------------------------------------------------

  static List<_Beat> _buildBeats(Lesson lesson, Puzzle? proof) {
    final beats = <_Beat>[];
    for (final step in lesson.steps) {
      final Position position;
      try {
        position = positionFromFen(step.fen);
      } catch (_) {
        continue;
      }
      switch (step) {
        case TeachStep():
          beats.add(_SeeBeat(position, step));
        case PlayStep():
          if (step.targetSan.isNotEmpty) beats.add(_PlayBeat(position, step));
      }
    }
    if (proof != null && proof.solution.isNotEmpty) {
      try {
        beats.add(_ProofBeat(positionFromFen(proof.fen), proof));
      } catch (_) {
        // A proof with an unparseable FEN drops the OWN beat rather than
        // dead-ending the lesson.
      }
    }
    return beats;
  }

  /// The side the learner plays, fixed for the whole lesson: the first beat
  /// that asks for a move decides, otherwise the opening position does.
  static Side _resolveOrientation(List<_Beat> beats) {
    for (final beat in beats) {
      if (beat is _PlayBeat || beat is _ProofBeat) return beat.position.turn;
    }
    return beats.isEmpty ? Side.white : beats.first.position.turn;
  }

  BoardScript _scriptFor(int index, _SeeBeat beat) =>
      _scripts[index] ??= BoardScript.of(beat.position, beat.step.text);

  void _enterBeat(int index) {
    _cancelTimers();
    final beats = _beats;
    if (beats == null || index >= beats.length) return;
    final beat = beats[index];
    final solved = _solvedBeats.contains(index);
    // A solved beat re-enters in its SOLVED state — flag AND position.
    // Restoring only the flag left a resumed proof beat showing the
    // unsolved board under the answer text, unplayable.
    Position? transient;
    NormalMove? transientMove;
    var proofCursor = 0;
    NormalMove? proofLastMove;
    Position? proofPosition = beat is _ProofBeat ? beat.position : null;
    if (solved) {
      switch (beat) {
        case _PlayBeat():
          final move = beat.step.targetSan
              .map((san) => legalMoveFromSan(beat.position, san))
              .whereType<NormalMove>()
              .firstOrNull;
          if (move != null) {
            transient = beat.position.play(move);
            transientMove = move;
          }
        case _ProofBeat():
          var position = beat.position;
          for (final san in beat.puzzle.solution) {
            final move = legalMoveFromSan(position, san);
            if (move == null) break;
            position = position.play(move);
            proofLastMove = move;
          }
          proofPosition = position;
          proofCursor = beat.puzzle.solution.length;
        case _SeeBeat():
          break;
      }
    }
    setState(() {
      _beat = index;
      _frame = 0;
      _previewArrow = null;
      _misses = 0;
      _hintOpen = false;
      _transient = transient;
      _transientMove = transientMove;
      _beatSolved = solved;
      _flash = false;
      _proofCursor = proofCursor;
      _proofLastMove = proofLastMove;
      _proofPosition = proofPosition;
    });
    ref
        .read(drawingControllerProvider(DrawingScope.journey).notifier)
        .resetLayer();

    _furthestBeat = max(_furthestBeat, index);
    _saveProgress();

    if (beat is! _SeeBeat) return;
    final script = _scriptFor(index, beat);
    // A menu draws every option at once; only a sequence plays through.
    if (script is! MoveSequence || !script.hasMotion) return;
    _sequenceTimer = Timer.periodic(_frameInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_frame >= script.frames.length - 1) {
        timer.cancel();
      } else {
        setState(() => _frame++);
      }
    });
  }

  void _next() {
    final beats = _beats;
    if (beats == null) return;
    if (_beat + 1 < beats.length) {
      _enterBeat(_beat + 1);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_beat > 0) _enterBeat(_beat - 1);
  }

  /// Mints [amount] for the current beat, once per run: revisiting a beat
  /// through the back button never pays twice, and — because the awarded
  /// set is persisted with the lesson's progress — neither does abandoning
  /// the lesson and resuming it later.
  void _award(int amount) {
    if (!_awardedBeats.add(_beat)) return;
    _earnedXp += amount;
    _saveProgress();
    ref.read(progressionControllerProvider.notifier).award(amount).then((
      leveled,
    ) {
      if (leveled && mounted) setState(() => _leveledUp = true);
    });
  }

  /// Persists where this run stands, so the lesson card can show a progress
  /// bar and reopening resumes here. Skipped once the lesson is owned —
  /// ownership supersedes progress, and owned replays stay ephemeral.
  void _saveProgress() {
    final beats = _beats;
    if (beats == null || beats.isEmpty || _finished) return;
    final progression = ref.read(progressionControllerProvider);
    if (progression.completedNodes.contains(widget.conceptId)) return;
    ref.read(progressionControllerProvider.notifier).saveLessonProgress(
          widget.conceptId,
          LessonProgress(
            beat: _furthestBeat,
            beatCount: beats.length,
            solvedBeats: _solvedBeats,
            awardedBeats: _awardedBeats,
          ),
        );
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _cancelTimers();
    ref.playSound(AppSound.win);
    ref.hapticMedium();
    // The mint on top of everything banked beat by beat, so the celebration
    // reports the run rather than just its last award.
    _earnedXp += ref
        .read(progressionControllerProvider)
        .ownPatternXp(widget.conceptId);
    final leveled = await ref
        .read(progressionControllerProvider.notifier)
        .ownPattern(widget.conceptId);
    if (!mounted) return;
    setState(() {
      _leveledUp = _leveledUp || leveled;
      _showOwned = true;
    });
  }

  // -- interactions --------------------------------------------------

  void _completeSee() {
    if (_finished) return;
    _award(XpRules.teachStep);
    _next();
  }

  void _previewSan(String san, Position position) {
    final move = legalMoveFromSan(position, san);
    if (move == null) return;
    _previewTimer?.cancel();
    setState(() => _previewArrow = move);
    _previewTimer = Timer(_previewLinger, () {
      if (mounted) setState(() => _previewArrow = null);
    });
  }

  void _rejectMove(Position shown, NormalMove move) {
    ref.playSound(AppSound.bad);
    setState(() {
      _misses++;
      _transient = shown;
      _transientMove = move;
      _shakeTick++;
    });
    _revertTimer = Timer(academyRevertDelay, () {
      if (mounted) {
        setState(() {
          _transient = null;
          _transientMove = null;
        });
      }
    });
  }

  void _onPlayMove(NormalMove move, _PlayBeat beat) {
    if (_beatSolved) return;
    final (next, _) = beat.position.makeSan(move);
    final ok = beat.step.targetSan
        .any((a) => acceptsAuthored(beat.position, move, a));
    if (!ok) {
      _rejectMove(next, move);
      return;
    }
    ref.playSound(AppSound.good);
    ref.hapticLight();
    setState(() {
      _beatSolved = true;
      _solvedBeats.add(_beat);
      _transient = next;
      _transientMove = move;
      _flash = true;
      _floaterTick++;
    });
    _award(XpRules.playStep);
  }

  void _onProofMove(NormalMove move, _ProofBeat beat) {
    if (_beatSolved) return;
    final position = _proofPosition ?? beat.position;
    final solution = beat.puzzle.solution;
    if (_proofCursor >= solution.length) return;
    final (next, _) = position.makeSan(move);
    if (!acceptsAuthored(position, move, solution[_proofCursor])) {
      _rejectMove(next, move);
      return;
    }

    ref.playSound(AppSound.good);
    ref.hapticLight();
    final cursor = _proofCursor + 1;
    setState(() {
      _proofPosition = next;
      _proofLastMove = move;
      _proofCursor = cursor;
      _transient = null;
      _transientMove = null;
    });
    if (cursor >= solution.length) {
      _solveProof(beat);
      return;
    }
    // Opponent replies from the solution line after a beat.
    _replyTimer = Timer(_replyDelay, () {
      if (!mounted) return;
      final current = _proofPosition;
      if (current == null || _proofCursor >= solution.length) return;
      final reply = legalMoveFromSan(current, solution[_proofCursor]);
      if (reply == null) {
        // Corrupt line — never dead-end the learner.
        _solveProof(beat);
        return;
      }
      final afterReply = _proofCursor + 1;
      setState(() {
        _proofPosition = current.play(reply);
        _proofLastMove = reply;
        _proofCursor = afterReply;
      });
      if (afterReply >= solution.length) _solveProof(beat);
    });
  }

  void _solveProof(_ProofBeat beat) {
    setState(() {
      _beatSolved = true;
      _solvedBeats.add(_beat);
      _flash = true;
      _floaterTick++;
    });
    _award(XpRules.proofStep);
    _revealExplanation(beat.puzzle);
  }

  /// Brings the just-revealed explanation into view. Without this the learner
  /// sees only a green tick and a Next button, with the payoff off-screen.
  void _revealExplanation(Puzzle puzzle) {
    final text = puzzle.explanation;
    if (text == null || text.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_panelScroll.hasClients) return;
      _panelScroll.animateTo(
        _panelScroll.position.maxScrollExtent,
        duration: Motion.slow,
        curve: Motion.enter,
      );
    });
  }

  // -- build ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final tokens = context.tokens;
    final lessonAsync = ref.watch(conceptLessonProvider(widget.conceptId));
    final proofAsync = ref.watch(conceptProofProvider(widget.conceptId));

    Widget shell(Widget child) => Scaffold(body: SafeArea(child: child));

    // Shells have nothing in progress, so their close needs no confirmation.
    // [ModePanes.pending] puts it where the loaded lesson's header will be.
    Widget closeBar() => ModeHeaderBar(
      label: '',
      actionIcon: Icons.close,
      actionTooltip: t('ui.button.close'),
      onAction: () => Navigator.of(context).pop(),
    );

    if (lessonAsync.isLoading || proofAsync.isLoading) {
      return shell(
        ModePanes.pending(
          topBar: closeBar(),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final lesson = lessonAsync.valueOrNull;
    final proof = proofAsync.valueOrNull;
    if (lesson == null) {
      // A lesson that FAILED to load and a concept that simply has none used
      // to render the same mute glyph, which makes a broken bundle or a
      // malformed file indistinguishable from an empty one — and impossible
      // to report. Say which it is.
      final error = lessonAsync.error;
      return shell(
        ModePanes.pending(
          topBar: closeBar(),
          body: EmptyState(
            error: error == null
                ? null
                : t('ui.toast.parseFail', {'error': '$error'}),
          ),
        ),
      );
    }

    if (_beats == null) {
      final beats = _beats = _buildBeats(lesson, proof);
      _orientation = _resolveOrientation(beats);
      if (beats.isNotEmpty) {
        // Pick up where the learner left off. A record whose beat count no
        // longer matches the lesson is content drift: resuming into the
        // wrong beat would be worse than starting over, so it is dropped.
        final progression = ref.read(progressionControllerProvider);
        final saved = progression.lessonProgress[widget.conceptId];
        final owned =
            progression.completedNodes.contains(widget.conceptId);
        var startBeat = 0;
        if (saved != null && !owned && saved.beatCount == beats.length) {
          _solvedBeats.addAll(saved.solvedBeats);
          _awardedBeats.addAll(saved.awardedBeats);
          _furthestBeat = saved.beat.clamp(0, beats.length - 1);
          startBeat = _furthestBeat;
        } else if (saved != null) {
          ref
              .read(progressionControllerProvider.notifier)
              .clearLessonProgress(widget.conceptId);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _enterBeat(startBeat);
        });
      }
    }
    final beats = _beats!;
    if (beats.isEmpty) {
      return shell(
        ModePanes.pending(
          topBar: closeBar(),
          body: const EmptyState(),
        ),
      );
    }

    final beat = beats[_beat.clamp(0, beats.length - 1)];
    final drawingActive = ref.watch(
      drawingControllerProvider(DrawingScope.journey).select((s) => s.active),
    );

    // -- board configuration for the current beat --
    //
    // Two arrow roles, and only two. Accent teaches; info assists. An arrow
    // that appears because the learner is stuck must never look like an arrow
    // that is teaching them something.
    final teaching = tokens.accent.withValues(alpha: 0.8);
    final assisting = tokens.info.withValues(alpha: 0.8);
    final shapes = <Shape>{};
    Position position;
    NormalMove? lastMove;
    PlayerSide playerSide = PlayerSide.none;
    void Function(NormalMove)? onMove;

    /// Escalating help, identical on PLAY and OWN: the piece first, the move
    /// only once the learner is properly stuck.
    void addStuckHelp(Iterable<NormalMove> answers) {
      if (_beatSolved || _misses < _hintAfterMisses || answers.isEmpty) return;
      final origins = answers.map((m) => m.from).toSet();
      if (_misses >= _answerAfterMisses && answers.length == 1) {
        final only = answers.first;
        shapes.add(Arrow(color: assisting, orig: only.from, dest: only.to));
      } else if (origins.length == 1) {
        // Several accepted answers sharing one piece: point at the piece, never
        // at one arbitrary destination.
        shapes.add(Circle(color: assisting, orig: origins.first));
      } else {
        shapes.add(Circle(color: assisting, orig: answers.first.from));
      }
    }

    switch (beat) {
      case _SeeBeat():
        final script = _scriptFor(_beat, beat);
        switch (script) {
          case MoveSequence():
            final frames = script.frames;
            final frame = frames[_frame.clamp(0, frames.length - 1)];
            position = frame.position;
            lastMove = frame.move;
            final move = frame.move;
            if (move != null) {
              shapes.add(
                Arrow(color: teaching, orig: move.from, dest: move.to),
              );
            }
          case MoveMenu():
            // Every option, on the one position the prose describes.
            position = script.start;
            for (final move in script.moves) {
              shapes.add(
                Arrow(color: teaching, orig: move.from, dest: move.to),
              );
            }
        }
      case _PlayBeat():
        position = _transient ?? beat.position;
        lastMove = _transientMove;
        if (!_beatSolved && _transient == null && !drawingActive) {
          // Which way the board faces is a lesson-level choice; who may move
          // is whatever the position says.
          playerSide = beat.position.turn == Side.white
              ? PlayerSide.white
              : PlayerSide.black;
        }
        onMove = (move) => _onPlayMove(move, beat);
        addStuckHelp([
          for (final san in beat.step.targetSan)
            if (legalMoveFromSan(beat.position, san) case final NormalMove m) m,
        ]);
      case _ProofBeat():
        position = _transient ?? _proofPosition ?? beat.position;
        lastMove = _transientMove ?? _proofLastMove;
        final onLearnersTurn = position.turn == beat.position.turn;
        if (!_beatSolved &&
            _transient == null &&
            !drawingActive &&
            onLearnersTurn) {
          // Which way the board faces is a lesson-level choice; who may move
          // is whatever the position says.
          playerSide = beat.position.turn == Side.white
              ? PlayerSide.white
              : PlayerSide.black;
        }
        onMove = (move) => _onProofMove(move, beat);
        // Proof beats used to offer no help at any miss count, which is where
        // learners got permanently stuck.
        if (onLearnersTurn && _proofCursor < beat.puzzle.solution.length) {
          final next = legalMoveFromSan(
            position,
            beat.puzzle.solution[_proofCursor],
          );
          addStuckHelp([?next]);
        }
    }
    final preview = _previewArrow;
    if (preview != null) {
      shapes.add(Arrow(color: assisting, orig: preview.from, dest: preview.to));
    }
    final orientation = _orientation;

    // The one header every mode wears: art name on the left, run progress in
    // the middle, close on the right behind a confirmation — the Studio's
    // exact chrome, so the academy stops reading as a different product.
    final artId = ref
        .watch(skillMapProvider)
        .valueOrNull
        ?.conceptById(widget.conceptId)
        ?.artId;
    final topBar = ModeHeaderBar(
      label: artId == null ? '' : t('academy.art.$artId'),
      progress: (_beat + 1) / beats.length,
      actionIcon: Icons.close,
      actionTooltip: t('ui.button.close'),
      onAction: () => _confirmClose(context, t),
      // Any run with progress can be started over — a session action, so
      // it lives in the header behind a confirmation like every other one.
      secondaryActionIcon:
          _furthestBeat > 0 && !_finished ? Icons.replay : null,
      secondaryActionTooltip:
          _furthestBeat > 0 && !_finished ? t('academy.restartLesson') : null,
      onSecondaryAction: _furthestBeat > 0 && !_finished
          ? () => _confirmRestart(context, t)
          : null,
    );

    // The hint is the sentence the lesson author wrote for this position,
    // shown when the learner asks for it — the same affordance every other
    // mode uses, through the same toast.
    final help = beat.help;
    final body = ModePanes(
      topBar: topBar,
      topBarHeight: ModeHeaderBar.height,
      // The SEE→PLAY→OWN journey floats in the lead gap, right on top of
      // the lesson card — decoration of slack that was already there, so
      // the board cannot move for it (ModePanes reserves nothing for
      // leadContent, and drops it when the gap is tight).
      leadContent: LessonJourneyLine(
        beatPhases: [for (final b in beats) b.phaseKey],
        current: _beat,
        t: t,
      ),
      // Centered in the gap, reading as the screen's headline — the same
      // billing the trainer gives its category title.
      leadAlignment: Alignment.center,
      // What you are learning, where Play shows who you are playing — the
      // slot is what makes this board sit and size like the other modes'.
      aboveBoard: BoardContextCard(
        emoji: '📖',
        title: lesson.title,
        subtitle: lesson.summary.isEmpty ? null : lesson.summary,
        trailing: StatChip(label: '${_beat + 1} / ${beats.length}'),
      ),
      aboveHeight: BoardContextCard.height,
      overlayBar: DrawingModeBar(scope: DrawingScope.journey, t: t),
      overlayBarHeight: DrawingModeBar.height,
      toast: _hintOpen && help != null && help.isNotEmpty
          ? HintToast(
              icon: Icons.school_outlined,
              title: t('ui.button.hint'),
              onClose: () => setState(() => _hintOpen = false),
              child: MarkdownView(help),
            )
          : null,
      boardBuilder: (context, boardSize) => ShakeOnMiss(
        tick: _shakeTick,
        child: BoardStage(
          size: boardSize,
          builder: (board) => [
            KarpaBoard(
              size: board,
              position: position,
              orientation: orientation,
              lastMove: lastMove,
              playerSide: playerSide,
              onMove: onMove,
              shapes: shapes,
            ),
            DrawingOverlay(
              size: board,
              t: t,
              scope: DrawingScope.journey,
              orientation: orientation,
            ),
            SuccessFlash(visible: _flash),
            // The board says "your turn" too, where the learner is looking.
            AwaitingMove(waiting: playerSide != PlayerSide.none),
            if (_floaterTick > 0)
              _XpFloater(
                tick: _floaterTick,
                tokens: tokens,
                label: t('gamify.earned', {'n': XpRules.playStep}),
              ),
            // No tap-to-advance layer over the board. Two full-board tap
            // targets used to move on — on a teach beat, and on any beat once
            // solved — so a stray tap (studying the arrows, re-tapping the
            // piece just played) skipped a beat. The advance button below is
            // the one way forward; the board is inert at both moments anyway.
          ],
        ),
      ),
      panel: _panel(beat, lesson, t),
      // ONE 48dp row — [hint · back · advance] + pencil — matching the
      // leading-icons idiom of every other mode's action bar. The old
      // stacked column (hint over Next over a caption) cost ~122dp; this
      // returns the difference to the prose viewport. Padded on BOTH sides:
      // `ModePanes` docks the bar flush under the panel with no margin of its
      // own, so bottom-only padding left the 48dp Next button touching the
      // footer's top edge. 8 + 48 + 8 is the 64dp `ModePanes` already books.
      actionBar: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            const SizedBox(width: 8),
            ..._actions(beat, t),
            DrawingModeButton(scope: DrawingScope.journey, t: t),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );

    // A hardware keyboard — a desktop window, an iPad with its keyboard —
    // walks the lesson as the action bar does, on the two keys Review and
    // the Studio step with. Each key fires only where its button would: the
    // advance on a teaching beat or a solved one, never mid-celebration or
    // while the drawing tools hold the board.
    final canAdvance = beat is _SeeBeat || _beatSolved;
    final keyed = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!canAdvance || drawingActive || _showOwned) return;
          beat is _SeeBeat && !_beatSolved ? _completeSee() : _next();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (drawingActive || _showOwned) return;
          _back();
        },
      },
      child: Focus(autofocus: true, child: body),
    );

    return shell(
      Stack(
        fit: StackFit.expand,
        children: [
          keyed,
          if (_showOwned && !_showLevelUp)
            CelebrationOverlay(
              emoji: '✨',
              title: t('academy.patternOwned'),
              subtitle: t('academy.addedToBook'),
              xpEarned: _earnedXp,
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
            ),
        ],
      ),
    );
  }

  // -- panel ---------------------------------------------------------

  /// Scrolling prose above a pinned action zone: primary actions never
  /// sink below the fold when the prose grows.
  ///
  /// Every beat renders through this one path — phase chip, optional heading,
  /// markdown body, then actions. Previously each beat type built its own
  /// layout, which is why reading a lesson, doing it and proving it felt like
  /// three different products.
  Widget _panel(_Beat beat, Lesson lesson, Translate t) {
    final tokens = context.tokens;
    // A proof's title names the pattern it tests — "The Royal Fork" is half
    // the answer — so, exactly as in the trainer, it waits for the solve.
    final heading = beat is _ProofBeat && !_beatSolved ? null : beat.heading;
    final body = beat.body.trim();

    return SingleChildScrollView(
      controller: _panelScroll,
      padding: AppInsets.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A beat that wants a move says so as a call to action, not
          // as the same soft pill the reading beats use.
          // The lesson title and phase chip live on the card above the
          // board now; the panel opens straight on the call to action or
          // the prose.
          if (beat is! _SeeBeat && !_beatSolved)
            _TurnBanner(
              label: t('academy.yourMove'),
              side: t('academy.youPlay', {
                'side': t(
                  beat.position.turn == Side.white
                      ? 'game.side.white'
                      : 'game.side.black',
                ),
              }),
              tokens: tokens,
            ),
          // The prose keeps a reading measure: under a portrait tablet's
          // board this panel is ~770dp wide. The banner and the proof dots
          // still span it.
          if (heading != null && heading.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ReadingMeasure(child: Text(heading, style: context.type.title)),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (body.isNotEmpty)
            ReadingMeasure(
              child: MarkdownView(
                body,
                onSanTap: (san) => _previewSan(san, beat.position),
              ),
            )
          else
            Text(
              t('academy.findTheMove'),
              style: context.type.body.copyWith(color: tokens.text),
            ),
          if (beat is _ProofBeat) ...[
            const SizedBox(height: AppSpacing.sm),
            _proofDots(tokens),
          ],
          if (beat is _ProofBeat && _beatSolved) _explanation(beat.puzzle),
        ],
      ),
    );
  }

  /// The puzzle's own words on why the line worked — authored, and previously
  /// dropped on the floor.
  Widget _explanation(Puzzle puzzle) {
    final text = puzzle.explanation;
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ReadingMeasure(child: MarkdownView(text)),
    );
  }

  bool get _isLastBeat => _beat + 1 >= (_beats?.length ?? 0);

  /// The advance button announces where it is going: "Play it" or "Own it"
  /// when the next beat crosses into a new phase, plain "Next" inside one,
  /// "Finish lesson" at the end. This is what makes the run's shape legible
  /// from the button alone.
  String _advanceLabel(Translate t) {
    if (_isLastBeat) return t('academy.finishLesson');
    final beats = _beats!;
    final next = beats[_beat + 1];
    return next.phaseKey == beats[_beat].phaseKey
        ? t('ui.button.next')
        : t(next.phaseKey);
  }

  /// The action row's mode-owned cells: [hint?] [back] [advance]. A play or
  /// proof beat that is not yet solved earns no advance — the row then holds
  /// hint and back beside the pencil, never empty chrome.
  List<Widget> _actions(_Beat beat, Translate t) {
    final tokens = context.tokens;
    final help = beat.help;
    final canHint = help != null && help.trim().isNotEmpty && !_beatSolved;
    final canAdvance = beat is _SeeBeat || _beatSolved;

    return [
      // Always present, leading the row — the app-wide action-bar idiom.
      // It disables rather than disappears (a vanishing button reflows the
      // row and reads as a missing feature); reading beats simply have no
      // authored hint, and a solved beat has nothing left to hint.
      IconButton(
        tooltip: t('ui.button.hint'),
        icon: Icon(
          Icons.lightbulb_outline,
          color: !canHint
              ? tokens.textFaint
              : _hintOpen
              ? tokens.accent
              : tokens.textDim,
        ),
        style: IconButton.styleFrom(
          backgroundColor: _hintOpen ? tokens.accentSoft : null,
        ),
        onPressed:
            canHint ? () => setState(() => _hintOpen = !_hintOpen) : null,
      ),
      IconButton(
        tooltip: t('ui.button.back'),
        icon: const Icon(Icons.chevron_left),
        onPressed: _beat > 0 ? _back : null,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: canAdvance
              ? ButtonMeasure(
                  child: FilledButton(
                    onPressed:
                        beat is _SeeBeat && !_beatSolved ? _completeSee : _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(_advanceLabel(t)),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ];
  }

  /// Mid-lesson close confirms — the same header contract the Studio
  /// follows. Nothing is lost anymore (banked XP stays and the run resumes
  /// where it left off), but leaving is still ending a session.
  Future<void> _confirmClose(BuildContext context, Translate t) async {
    if (_finished) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('ui.button.close')),
        content: Text(t('academy.confirmClose')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('ui.button.dismiss')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('ui.button.close')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Starting a resumed lesson over drops the saved position, so it
  /// confirms. Banked XP stays banked, and beats that already paid this
  /// lesson keep refusing to pay again — restarting is never a mint.
  Future<void> _confirmRestart(BuildContext context, Translate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('academy.restartLesson')),
        content: Text(t('academy.confirmRestart')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('ui.button.dismiss')),
          ),
          DangerButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('academy.restartLesson')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(progressionControllerProvider.notifier)
        .clearLessonProgress(widget.conceptId);
    if (!mounted) return;
    // The celebration reports the post-restart run; banked XP stays
    // banked, and `_awardedBeats` survives so restarting never re-mints.
    setState(() {
      _solvedBeats.clear();
      _furthestBeat = 0;
      _earnedXp = 0;
    });
    _enterBeat(0);
  }

  Widget _proofDots(AppTokens tokens) {
    final beats = _beats!;
    final proofBeats = [
      for (final (i, b) in beats.indexed)
        if (b is _ProofBeat) i,
    ];
    final current = proofBeats.indexOf(_beat);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < proofBeats.length; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < current
                  ? tokens.accent
                  : i == current
                  ? tokens.accentSoft
                  : tokens.raised,
              border: Border.all(
                color: i == current ? tokens.accent : tokens.edge,
              ),
            ),
          ),
      ],
    );
  }
}

/// "Your move" — the beat is waiting for the learner to play something.
///
/// The reading beats read as prose; a beat that wants a move needs
/// to read as an instruction, so this is filled, carries a touch icon, and
/// names the side the learner is playing. Without it the only difference
/// between "watch this" and "your turn" was one word in a pale pill.
class _TurnBanner extends StatelessWidget {
  const _TurnBanner({
    required this.label,
    required this.side,
    required this.tokens,
  });

  final String label;
  final String side;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base,
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
        decoration: BoxDecoration(
          color: tokens.accent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 18, color: tokens.onAccent),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tokens.onAccent,
                    ),
                  ),
                  Text(
                    side,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.onAccent.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The localized "+10 XP" rising over the board after a correct play beat.
class _XpFloater extends StatelessWidget {
  const _XpFloater({
    required this.tick,
    required this.tokens,
    required this.label,
  });

  final int tick;
  final AppTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(tick),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Motion.enter,
          builder: (context, v, child) => Opacity(
            opacity: v < 0.7 ? 1.0 : ((1 - v) / 0.3).clamp(0.0, 1.0),
            child: Transform.translate(
              // Clamped so the floater never escapes above the board.
              offset: Offset(0, max(0.0, 40 - 70 * v)),
              child: child,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: context.type.font.mono,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: tokens.accent,
            ),
          ),
        ),
      ),
    );
  }
}
