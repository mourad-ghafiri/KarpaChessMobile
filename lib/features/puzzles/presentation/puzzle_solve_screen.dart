import 'dart:async';
import 'dart:math' as math;

import 'package:chessground/chessground.dart' show PlayerSide;
import 'package:dartchess/dartchess.dart' show NormalMove, Position, Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/application/content_providers.dart';
import '../../../content/domain/models.dart';
import '../../../core/audio/sound_providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/chess/san_moves.dart';
import '../../../core/chess/tolerant_position.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/mode_panes.dart';
import '../../../core/markdown/markdown_view.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/board_feedback.dart';
import '../../../core/ui/measure.dart';
import '../../../core/ui/board_context_card.dart';
import '../../../core/ui/celebration_overlay.dart';
import '../../../core/ui/hint_toast.dart';
import '../../../core/ui/stat_chip.dart';
import '../../../core/ui/mode_header_bar.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/progression.dart';
import '../../../progression/domain/puzzle_outcome.dart';
import '../../board/presentation/board_stage.dart';
import '../../board/presentation/karpa_board.dart';
import '../../commentator/application/drawing_controller.dart';
import '../../commentator/presentation/drawing_overlay.dart';
import '../../../core/ui/drawing_mode_bar.dart';
import '../application/puzzles_providers.dart';
import '../domain/puzzle_picker.dart';
import '../domain/puzzle_solver.dart';

/// How long a wrong move stays on the board before it snaps back.
const _revertDelay = Duration(milliseconds: 800);

/// The pause before the opponent answers, so the reply reads as a move
/// rather than a jump.
const _replyDelay = Duration(milliseconds: 450);

/// The beat between moves while a shown solution plays out.
const _solutionStepDelay = Duration(milliseconds: 900);

/// Misses before "Show solution" is offered — aligned with the academy's
/// answer-after-misses threshold so giving up costs the same struggle
/// everywhere.
const _solutionAfterMisses = 3;

/// What the trainer is serving.
sealed class PuzzleRun {
  const PuzzleRun();
}

/// Endless, near the reader's rating.
class RatedRun extends PuzzleRun {
  const RatedRun();
}

/// One pack, in its authored order.
class PackRun extends PuzzleRun {
  const PackRun(this.pack);
  final PuzzlePack pack;
}

/// Today's single puzzle.
class DailyRun extends PuzzleRun {
  const DailyRun();
}

/// One specific puzzle, opened from the pack detail list. Tapping an
/// already-solved row IS the replay gesture, so serving ignores outcomes
/// entirely; like the daily, it ends by closing.
class SinglePuzzleRun extends PuzzleRun {
  const SinglePuzzleRun(this.pack, this.puzzleId);
  final PuzzlePack pack;
  final String puzzleId;
}

/// Where the live puzzle stands: being solved, its solution playing out
/// after the reader gave up, or finished either way.
enum _PuzzlePhase { solving, revealing, resolved }

/// The solve surface: one board, one puzzle at a time.
///
/// Wears the same chrome as the lesson player and Sharpen — `ModePanes`,
/// `BoardStage`, the shake, the flash, the one hint toast — because a puzzle
/// solved here should feel like a puzzle solved anywhere else in the app.
class PuzzleSolveScreen extends ConsumerStatefulWidget {
  const PuzzleSolveScreen({super.key, required this.run});

  final PuzzleRun run;

  @override
  ConsumerState<PuzzleSolveScreen> createState() => _PuzzleSolveScreenState();
}

class _PuzzleSolveScreenState extends ConsumerState<PuzzleSolveScreen> {
  final _random = math.Random();

  /// Served this session, so the endless stream never repeats itself even
  /// when a puzzle was failed rather than solved.
  final _seen = <String>{};

  /// Serving policy: ignore lifetime results when picking. Set when a run
  /// is entered with nothing fresh left (a finished pack, an exhausted
  /// rated corpus) and by "play again". It changes only WHAT IS SERVED —
  /// nothing is scored differently here, because the domain's outcome map
  /// decides what an attempt pays: the rating moves only on a puzzle's
  /// first-ever attempt, and a replay mints XP only when it beats the
  /// stored best.
  bool _practice = false;

  Puzzle? _puzzle;
  PuzzleSolver? _solver;

  /// Every puzzle this session served, oldest first — the live puzzle is the
  /// last entry. The back button walks [_cursor] into the past for a
  /// read-only review (solved position + explanation); nothing there can be
  /// re-played or re-rated.
  final List<Puzzle> _history = [];
  int _cursor = 0;

  bool get _reviewing => _cursor < _history.length - 1;

  /// Fixed for the whole puzzle: the side the solver plays. Derived per
  /// frame from the side to move it would turn the board around the moment
  /// the opponent replied.
  Side _orientation = Side.white;

  /// The wrong move, shown briefly before the board snaps back.
  NormalMove? _rejected;
  var _rejectTick = 0;

  bool _hintOpen = false;
  bool _flash = false;
  _PuzzlePhase _phase = _PuzzlePhase.solving;

  /// What the live attempt produced, set at resolution.
  PuzzleOutcome? _outcome;

  /// The stored best when the live puzzle was served — what a replay has to
  /// beat for the upgrade banner.
  PuzzleOutcome? _outcomeBefore;

  int _ratingBefore = 0;
  int _ratingAfter = 0;

  bool get _solved => _outcome?.isSolved ?? false;
  bool get _done => _phase == _PuzzlePhase.resolved;

  int _solvedThisRun = 0;
  bool _leveledUp = false;
  bool _celebrate = false;

  Timer? _revertTimer;
  Timer? _replyTimer;
  Timer? _solutionTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    _replyTimer?.cancel();
    _solutionTimer?.cancel();
    super.dispose();
  }

  // -- serving -------------------------------------------------------

  /// Which puzzle comes next, given what counts as already done.
  ///
  /// `PuzzlePicker` is a pure function over an exclude set, so the POLICY —
  /// whether a lifetime solve disqualifies a puzzle — belongs here, at the
  /// caller, and the picker never learns about practice runs.
  Puzzle? _pick(List<Puzzle> corpus, {required bool practice}) {
    final progression = ref.read(progressionControllerProvider);
    // In practice the lifetime results are not a filter: only what this
    // session has already shown, so a replay still never repeats itself.
    // Failed puzzles are never excluded — retrying them is the point.
    final done = practice
        ? {..._seen}
        : {...progression.solvedPuzzleIds, ..._seen};
    return switch (widget.run) {
      RatedRun() => PuzzlePicker.rated(
        corpus,
        rating: progression.puzzleRating,
        exclude: done,
        random: _random,
      ),
      PackRun(pack: final pack) => PuzzlePicker.inPack(
        [
          for (final file in pack.puzzleFiles)
            ...corpus.where((p) => p.id == puzzleIdOf(file)),
        ],
        exclude: done,
      ),
      DailyRun() => PuzzlePicker.daily(corpus, DateTime.now()),
      // The row was tapped knowing its state; outcomes are no filter here.
      SinglePuzzleRun(puzzleId: final id) => _seen.contains(id)
          ? null
          : corpus.where((p) => p.id == id).firstOrNull,
    };
  }

  void _serve(List<Puzzle> corpus) {
    // A fresh puzzle owes nothing to the last one's pending effects.
    _revertTimer?.cancel();
    _replyTimer?.cancel();
    _solutionTimer?.cancel();
    var practice = _practice;
    var next = _pick(corpus, practice: practice);
    // Nothing fresh AT ENTRY is a finished pack asking to be run again, not
    // an ending: `_seen.isEmpty` is what separates "I already completed this"
    // from "I just played through it". Without this branch a completed pack
    // celebrated before it ever drew a board, which made it unplayable.
    if (next == null && !practice && _seen.isEmpty) {
      practice = true;
      next = _pick(corpus, practice: true);
    }
    if (next == null) {
      // A single-puzzle run that cannot resolve its id (a stale row) has
      // nothing to celebrate and nothing to serve — just leave.
      if (widget.run is SinglePuzzleRun && _seen.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _celebrate = true);
      return;
    }
    // Held as a final: `next` is reassignable above, so it does not promote
    // inside the setState closure below.
    final chosen = next;
    _seen.add(chosen.id);
    final solver =
        PuzzleSolver.of(fen: chosen.fen, solution: chosen.solution);
    // An unusable puzzle is skipped rather than dead-ending the reader —
    // and never enters the history, which must hold only reviewable solves.
    if (solver == null) {
      _serve(corpus);
      return;
    }
    ref
        .read(drawingControllerProvider(DrawingScope.puzzles).notifier)
        .resetLayer();
    setState(() {
      _practice = practice;
      _puzzle = chosen;
      _solver = solver;
      _history.add(chosen);
      _cursor = _history.length - 1;
      _orientation = solver.position.turn;
      _rejected = null;
      _hintOpen = false;
      _flash = false;
      _phase = _PuzzlePhase.solving;
      _outcome = null;
      _outcomeBefore = ref
          .read(progressionControllerProvider)
          .puzzleResults[chosen.id];
    });
  }

  /// Runs the whole thing again from the top, unscored. The history is kept
  /// deliberately: the back button can still review what was just played.
  void _replay(List<Puzzle> corpus) {
    setState(() {
      _celebrate = false;
      _practice = true;
      _seen.clear();
      _solvedThisRun = 0;
    });
    _serve(corpus);
  }

  /// The solved-out position of a reviewed puzzle: its line replayed to the
  /// end, with the final move for the last-move highlight. Falls back to the
  /// start position if the line will not replay (it always should — the
  /// content gate proves it).
  (Position, NormalMove?) _reviewPosition(Puzzle puzzle) {
    try {
      Position position = positionFromFen(puzzle.fen);
      NormalMove? last;
      for (final san in puzzle.solution) {
        final move = legalMoveFromSan(position, san);
        if (move == null) break;
        position = position.play(move);
        last = move;
      }
      return (position, last);
    } catch (_) {
      return (positionFromFen(puzzle.fen), null);
    }
  }

  // -- solving -------------------------------------------------------

  void _onMove(NormalMove move, List<Puzzle> corpus) {
    final solver = _solver;
    final puzzle = _puzzle;
    if (solver == null ||
        puzzle == null ||
        _phase != _PuzzlePhase.solving ||
        _rejected != null) {
      return;
    }
    switch (solver.offer(move)) {
      case SolveOutcome.wrong:
        ref.playSound(AppSound.bad);
        setState(() {
          _rejected = move;
          _rejectTick++;
        });
        _revertTimer?.cancel();
        _revertTimer = Timer(_revertDelay, () {
          if (mounted) setState(() => _rejected = null);
        });
      case SolveOutcome.correct:
        ref.playSound(AppSound.good);
        ref.hapticLight();
        setState(() {});
        _replyTimer?.cancel();
        _replyTimer = Timer(_replyDelay, () {
          if (!mounted) return;
          // A corrupt line is treated as solved: never dead-end the reader
          // over an authoring slip.
          if (!solver.playReply()) {
            _finish(puzzle, solver);
            return;
          }
          setState(() {});
          if (solver.isSolved) _finish(puzzle, solver);
        });
      case SolveOutcome.solved:
        ref.playSound(AppSound.good);
        ref.hapticLight();
        _finish(puzzle, solver);
    }
  }

  Future<void> _finish(Puzzle puzzle, PuzzleSolver solver) async {
    if (_done) return;
    final progression = ref.read(progressionControllerProvider);
    _ratingBefore = progression.puzzleRating;
    setState(() {
      _phase = _PuzzlePhase.resolved;
      _outcome = solver.firstTry ? PuzzleOutcome.flawless : PuzzleOutcome.solved;
      _flash = true;
      _solvedThisRun++;
    });
    final leveled = await ref
        .read(progressionControllerProvider.notifier)
        .solvePuzzle(
          puzzleId: puzzle.id,
          puzzleRating: puzzle.rating ?? _ratingBefore,
          firstTry: solver.firstTry,
        );
    if (!mounted) return;
    setState(() {
      _ratingAfter = ref.read(progressionControllerProvider).puzzleRating;
      _leveledUp = _leveledUp || leveled;
    });
  }

  /// The reader gave up: record the fail (a pure rating event, and only on
  /// the puzzle's first attempt — the domain no-ops on replays), then play
  /// the authored line out move by move. Scripted board playback, not an
  /// auto-advance: nothing moves on to the next puzzle without a tap.
  Future<void> _showSolution(Puzzle puzzle, PuzzleSolver solver) async {
    if (_phase != _PuzzlePhase.solving) return;
    final progression = ref.read(progressionControllerProvider);
    _ratingBefore = progression.puzzleRating;
    // Pieces are about to move: stale arrows pinned to their squares would
    // annotate a position that no longer exists.
    ref
        .read(drawingControllerProvider(DrawingScope.puzzles).notifier)
        .resetLayer();
    setState(() {
      _phase = _PuzzlePhase.revealing;
      _hintOpen = false;
    });
    await ref.read(progressionControllerProvider.notifier).failPuzzle(
          puzzleId: puzzle.id,
          puzzleRating: puzzle.rating ?? _ratingBefore,
        );
    if (!mounted) return;
    setState(() {
      _ratingAfter = ref.read(progressionControllerProvider).puzzleRating;
    });
    _solutionTimer?.cancel();
    _solutionTimer = Timer.periodic(_solutionStepDelay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final move = solver.advanceSolution();
      setState(() {});
      if (move == null || solver.isSolved) {
        timer.cancel();
        setState(() {
          _phase = _PuzzlePhase.resolved;
          _outcome = PuzzleOutcome.failed;
        });
      }
    });
  }

  // -- rendering -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(i18nProvider).requireValue.t;
    final corpus = ref.watch(trainerPuzzlesProvider);

    return corpus.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          Scaffold(body: Center(child: Text(t('puzzles.noneLeft')))),
      data: (puzzles) {
        if (_puzzle == null && !_celebrate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _puzzle == null && !_celebrate) _serve(puzzles);
          });
        }
        return _scaffold(t, puzzles);
      },
    );
  }

  Widget _scaffold(Translate t, List<Puzzle> corpus) {
    final puzzle = _puzzle;
    final solver = _solver;

    // The one header every mode wears: run name on the left, close on the
    // right behind a confirmation — the Studio's exact chrome.
    final topBar = ModeHeaderBar(
      label: switch (widget.run) {
        RatedRun() => t('puzzles.rated'),
        PackRun(pack: final pack) => t(pack.nameKey),
        DailyRun() => t('puzzles.daily'),
        SinglePuzzleRun(pack: final pack) => t(pack.nameKey),
      },
      actionIcon: Icons.close,
      actionTooltip: t('ui.button.close'),
      onAction: () => _confirmClose(context, t),
    );

    if (_celebrate || puzzle == null || solver == null) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // The header where the loaded puzzle puts it, so it doesn't
              // jump when one is served.
              ModePanes.pending(
                topBar: topBar,
                body: const Center(child: CircularProgressIndicator()),
              ),
              if (_celebrate)
                CelebrationOverlay(
                  emoji: '🧩',
                  title: t('puzzles.runComplete'),
                  subtitle: t('puzzles.runSolved', {'n': _solvedThisRun}),
                  actions: [
                    // The daily puzzle is one position a day and a single
                    // puzzle is one tap on its row: neither has an "again"
                    // to offer, only the door.
                    if (widget.run is! DailyRun &&
                        widget.run is! SinglePuzzleRun)
                      FilledButton.tonal(
                        onPressed: () => _replay(corpus),
                        child: Text(t('puzzles.playAgain')),
                      ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t('ui.button.close')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    // A rejected move is shown on the board, then taken back.
    final drawingActive = ref.watch(
      drawingControllerProvider(DrawingScope.puzzles).select((s) => s.active),
    );
    // What the screen shows: the live puzzle, or — while the back button has
    // walked into the history — a past solve, read-only.
    final shown = _reviewing ? _history[_cursor] : puzzle;
    final shownSolved = _reviewing || _done;
    final rejected = _rejected;
    final Position position;
    final NormalMove? lastMove;
    if (_reviewing) {
      (position, lastMove) = _reviewPosition(shown);
    } else {
      position = rejected == null
          ? solver.position
          : solver.position.play(rejected);
      lastMove = rejected ?? solver.lastMove;
    }
    final playerSide =
        _reviewing ||
            _phase != _PuzzlePhase.solving ||
            drawingActive ||
            rejected != null ||
            solver.awaitsReply
        ? PlayerSide.none
        : solver.position.turn == Side.white
        ? PlayerSide.white
        : PlayerSide.black;

    final progression = ref.watch(progressionControllerProvider);
    // The shown puzzle's pack names its category ("Mate in One", "Forks").
    // Every trainer puzzle belongs to exactly one pack, so the lookup is
    // by membership, never by parsing the id.
    final pack = ref
        .watch(puzzlePackManifestProvider)
        .valueOrNull
        ?.packs
        .where((p) => p.puzzleFiles.any((f) => puzzleIdOf(f) == shown.id))
        .firstOrNull;
    // The badge is DERIVED, never stored, from the shown puzzle's stored
    // best: a flawless best has nothing left to score ("Practice"), while a
    // failed or after-miss best can still be upgraded ("Replay"). No badge
    // on a first attempt.
    final priorShown = progression.puzzleResults[shown.id];
    final badge = priorShown == null
        ? null
        : priorShown == PuzzleOutcome.flawless
            ? t('puzzles.practice')
            : t('puzzles.replay');
    final help = puzzle.hint;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ModePanes(
              topBar: topBar,
              topBarHeight: ModeHeaderBar.height,
              // The category floats in the lead gap, right on top of the
              // task card — decoration of slack that was already there, so
              // the board cannot move for it.
              leadContent: pack != null
                  ? _CategoryLine(
                      icon: pack.icon,
                      name: t(pack.nameKey),
                      badge: badge,
                    )
                  : null,
              // Pinned under the header, where a section title belongs —
              // Learn's journey line keeps the default card-hugging spot.
              leadAlignment: Alignment.topCenter,
              // The task above the board, where the other modes put the
              // player — ONE card, so the board keeps the same origin as
              // every other mode. The session numbers ride inside it as the
              // second line; the trailing chip stays the PUZZLE's rating.
              // The puzzle's title is hidden until resolved, because a name
              // like "Royal Fork" is half the answer; once the solution has
              // been seen — solved, failed or reviewed — its name shows.
              aboveBoard: BoardContextCard(
                emoji: '🧩',
                // A reviewed puzzle's word is its REAL stored outcome —
                // a failed one must not read "Solved" beside a "Replay"
                // badge just because the review shows the solved-out board.
                title: shownSolved
                    ? (shown.title ??
                        t((_reviewing
                                ? priorShown?.isSolved != false
                                : _solved)
                            ? 'puzzles.solved'
                            : 'puzzles.failed'))
                    : t('puzzles.findTheMove'),
                secondary: _SessionLine(
                  rating: progression.puzzleRating,
                  streak: progression.streakAt(DateTime.now()),
                  solvedThisRun: _solvedThisRun,
                  t: t,
                ),
                trailing: shown.rating != null
                    ? StatChip(label: '${shown.rating}', emoji: '🧩')
                    : null,
              ),
              aboveHeight: BoardContextCard.height,
              overlayBar: DrawingModeBar(scope: DrawingScope.puzzles, t: t),
              overlayBarHeight: DrawingModeBar.height,
              toast: _hintOpen && help != null && help.trim().isNotEmpty
                  ? HintToast(
                      title: t('ui.button.hint'),
                      onClose: () => setState(() => _hintOpen = false),
                      child: MarkdownView(help),
                    )
                  : null,
              boardBuilder: (context, boardSize) => ShakeOnMiss(
                tick: _rejectTick,
                child: BoardStage(
                  size: boardSize,
                  builder: (board) => [
                    KarpaBoard(
                      size: board,
                      position: position,
                      orientation: _orientation,
                      lastMove: lastMove,
                      playerSide: playerSide,
                      onMove: (move) => _onMove(move, corpus),
                    ),
                    DrawingOverlay(
                      size: board,
                      t: t,
                      scope: DrawingScope.puzzles,
                      orientation: _orientation,
                    ),
                    SuccessFlash(visible: _flash),
                    AwaitingMove(waiting: playerSide != PlayerSide.none),
                  ],
                ),
              ),
              panel: _panel(t, shown, shownSolved),
              // ONE 48dp row — [hint · back · advance] + pencil — the same
              // idiom every mode's action bar leads with, and never empty:
              // an unsolved puzzle still shows hint, back and the pencil.
              // Same footer as Learn's: padded above as well as below, since
              // `ModePanes` gives the bar no margin of its own.
              actionBar: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    ..._actions(t, corpus, help),
                    DrawingModeButton(scope: DrawingScope.puzzles, t: t),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            if (_leveledUp)
              CelebrationOverlay(
                emoji: '🚀',
                title: t('gamify.levelUp'),
                actions: [
                  FilledButton(
                    onPressed: () => setState(() => _leveledUp = false),
                    child: Text(t('ui.button.close')),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// [solved] covers the live puzzle once resolved AND every reviewed one —
  /// a resolved puzzle shows its payoff (explanation), never its setup.
  Widget _panel(Translate t, Puzzle puzzle, bool solved) {
    // A replay that beat the stored best minted the small upgrade award.
    final upgraded = !_reviewing &&
        _done &&
        _outcomeBefore != null &&
        (_outcome?.improvesOn(_outcomeBefore) ?? false);
    return SingleChildScrollView(
      padding: AppInsets.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title and rating live on the card above the board now. The
          // delta shows whenever the rating moved — up on a solve, down on
          // a first-attempt fail; a replay leaves it still and shows the
          // upgrade line instead when a best was beaten.
          if (!_reviewing && _done && _ratingAfter != _ratingBefore) ...[
            const SizedBox(height: AppSpacing.sm),
            _RatingDelta(before: _ratingBefore, after: _ratingAfter),
          ],
          if (upgraded) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              t('puzzles.bestImproved', {
                'xp': XpRules.puzzleUpgraded(
                  puzzle.rating ??
                      ref.read(progressionControllerProvider).puzzleRating,
                ),
              }),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.tokens.accent,
              ),
            ),
          ],
          // The prose keeps a reading measure: under a portrait tablet's
          // board this panel is ~770dp wide.
          if (!solved && (puzzle.setup ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ReadingMeasure(child: MarkdownView(puzzle.setup!)),
          ],
          if (solved && (puzzle.explanation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ReadingMeasure(child: MarkdownView(puzzle.explanation!)),
          ],
        ],
      ),
    );
  }

  /// The action row's mode-owned cells: [hint?] [back] [advance]. Back walks
  /// the session history; advance walks it forward again and, at the newest
  /// point, serves the next puzzle once the live one is solved.
  List<Widget> _actions(Translate t, List<Puzzle> corpus, String? help) {
    final tokens = context.tokens;
    final solving = _phase == _PuzzlePhase.solving;
    final canHint = !_reviewing &&
        solving &&
        help != null &&
        help.trim().isNotEmpty;
    final closesRun = widget.run is DailyRun || widget.run is SinglePuzzleRun;

    final VoidCallback? advance;
    final String advanceLabel;
    var revealing = false;
    if (_reviewing) {
      advance = () => setState(() => _cursor++);
      advanceLabel = t('ui.button.next');
    } else if (_done) {
      advance = closesRun
          ? () => Navigator.of(context).pop()
          : () => _serve(corpus);
      advanceLabel = closesRun ? t('ui.button.close') : t('ui.button.next');
    } else if (solving &&
        (_solver?.misses ?? 0) >= _solutionAfterMisses &&
        _puzzle != null) {
      // Enough misses to have earned the exit: giving up is a fail on the
      // first attempt, and the line plays itself out either way.
      advance = () => _showSolution(_puzzle!, _solver!);
      advanceLabel = t('puzzles.showSolution');
    } else if (_phase == _PuzzlePhase.revealing) {
      // The button the reader just tapped stays put, disabled, while the
      // line plays out — a vanishing button reflows the row and reads as
      // a missing feature.
      revealing = true;
      advance = null;
      advanceLabel = t('puzzles.showSolution');
    } else {
      advance = null;
      advanceLabel = '';
    }

    return [
      // Always present, leading the row — the app-wide action-bar idiom.
      // It disables rather than disappears (a vanishing button reflows the
      // row and reads as a missing feature), and it has nothing to say only
      // once the puzzle is solved or under review.
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
        // Locked while a solution plays out: walking into history would
        // leave the reveal timer stepping a board no longer on screen.
        onPressed: _cursor > 0 && _phase != _PuzzlePhase.revealing
            ? () => setState(() {
                _cursor--;
                _hintOpen = false;
              })
            : null,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: advanceLabel.isEmpty
              ? const SizedBox.shrink()
              : _advanceButton(
                  label: advanceLabel,
                  onPressed: advance,
                  // Giving up is tonal — an exit, never the row's primary
                  // move — and the disabled reveal-in-progress button
                  // keeps that shape.
                  tonal: solving || revealing,
                ),
        ),
      ),
    ];
  }

  /// The advance slot's one button shape: tonal for the give-up exit,
  /// filled for the primary advance. The label scales down rather than
  /// wrapping — "Показать решение" must fit a 260dp landscape pane.
  Widget _advanceButton({
    required String label,
    required VoidCallback? onPressed,
    required bool tonal,
  }) {
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1),
    );
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    return ButtonMeasure(
      child: tonal
          ? FilledButton.tonal(onPressed: onPressed, style: style, child: child)
          : FilledButton(onPressed: onPressed, style: style, child: child),
    );
  }

  /// Mid-run close confirms, matching the Studio's header contract. Nothing
  /// is genuinely lost (solves bank immediately), so the celebration shell
  /// closes without asking.
  Future<void> _confirmClose(BuildContext context, Translate t) async {
    // Nothing served yet (loading shell) and the celebration shell both
    // have nothing in progress to protect.
    if (_celebrate || _puzzle == null) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('ui.button.close')),
        content: Text(t('puzzles.confirmClose')),
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
}

/// The shown puzzle's category as a proper title — pack glyph in accent,
/// name in the display face ("♛ Mate in One") — pinned under the header in
/// the lead gap. Big enough to read as the screen's headline, sized to fit
/// the gap it decorates (which is why it may never grow past one line).
class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.icon,
    required this.name,
    this.badge,
  });

  final String icon;
  final String name;

  /// Badge label when this position has been attempted before — "Replay"
  /// while the stored best can still be upgraded, "Practice" once it is
  /// flawless and nothing is left to score. Null on a first attempt.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: 20, color: tokens.accent)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: context.type.font.display,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: tokens.text,
            ),
          ),
        ),
        if (badge case final label?) ...[
          const SizedBox(width: 8),
          StatChip(label: label),
        ],
      ],
    );
  }
}

/// The session numbers as one slim dim line inside the task card: your
/// rating, the day streak (hidden at zero), and this run's tally. Words for
/// the rating rather than a second puzzle chip, so it can never be misread
/// as the puzzle's difficulty in the trailing slot.
class _SessionLine extends StatelessWidget {
  const _SessionLine({
    required this.rating,
    required this.streak,
    required this.solvedThisRun,
    required this.t,
  });

  final int rating;
  final int streak;
  final int solvedThisRun;
  final Translate t;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final parts = [
      '${t('puzzles.rating')} $rating',
      if (streak > 0) '🔥 $streak',
      t('puzzles.runSolved', {'n': solvedThisRun}),
    ];
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.1,
        fontWeight: FontWeight.w600,
        color: tokens.textDim,
      ),
    );
  }
}

/// The rating moving, which is the whole point of a rated solve.
class _RatingDelta extends StatelessWidget {
  const _RatingDelta({required this.before, required this.after});

  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final up = after >= before;
    final delta = (after - before).abs();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$after',
          style: context.type.display.copyWith(
            color: up ? tokens.success : tokens.danger,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 18,
          color: up ? tokens.success : tokens.danger,
        ),
        Text(
          '$delta',
          style: TextStyle(
            fontFamily: context.type.font.mono,
            fontWeight: FontWeight.w800,
            color: up ? tokens.success : tokens.danger,
          ),
        ),
      ],
    );
  }
}
