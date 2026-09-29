# KarpaChess Mobile

KarpaChess for iOS and Android (phone + tablet). **This repo owns its content
and its tooling.** There is no upstream to sync from and nothing outside it to
consult.

## Commands

- `flutter test` — full suite (unit + widget; fast, no engine).
- `flutter drive --driver=test/device/driver.dart --target=test/device/engine_smoke.dart -d <device>`
  — real Stockfish smoke test on a device/simulator. Every test file lives
  under `test/`; the ones that need a device are in `test/device/`, run
  through `flutter drive`, and deliberately carry no `_test.dart` suffix, so
  a plain `flutter test` (which runs every `*_test.dart` on the host, with no
  device and no Stockfish) never picks them up: `engine_smoke.dart`,
  `app_flow.dart`, `store_screenshots.dart` and `layout_audit.dart` (every
  screen on one device, into `build/screenshots/audit/`, for judging layouts
  by eye).
- `sh tool/store_screenshots.sh [ios|android|all]` — the store screenshots.
  `screenshots/` holds the publishing sets and nothing else; raw captures
  stay in `build/screenshots/raw/`. See docs/RELEASE.md, "Store screenshots".
- `python3 tool/website.py [--check]` — the generated parts of `website/`
  (karpachess.com): the privacy page from `docs/PRIVACY.md`, and the
  screenshots, icons, piece previews and fonts from the repo. Run it after
  touching any of those; `--check` fails when the site is stale.
- `flutter analyze` — must stay at zero issues.
- `flutter run -d <device>` — run the app.

## Architecture (feature-first, clean layers)

- `lib/core/` — i18n (dot-path JSON bundles, 12 langs, `ar` RTL), markdown
  dialect parser (`{{san}}` chips), audio (3 modal-synthesis sound packs),
  haptics (pref-gated), theme (10 palettes + 5 board colorways + a
  switchable typeface),
  Motion tokens, adaptive layout helpers, tolerant FEN parsing, avatar
  store (`core/media/`), shared `PlayerIdentity` card (`core/ui/`).
- `lib/engine/` — Stockfish NNUE behind `EngineService`;
  `UciEngineService` serializes searches (interactive preempts batch, one
  `go` at a time, scores normalized to White-perspective at the parse
  boundary, every position through `EnginePosition` before it queues,
  `suspend`/`resume` for the lifecycle). `MoveClassifier` = the single source of cp-loss thresholds
  (<20 best, <60 good, <150 inaccuracy, <300 mistake, else blunder;
  brilliant = engine-best + ≥150cp sacrifice).
- **Engine module**: `packages/karpa_engine` — first-party, no third-party
  plugin. Official Stockfish 19 sources + our own bridge
  (`native/karpa_bridge.cpp`: in-memory streambufs, engine on a dedicated
  thread, lines pushed to Dart via NativeCallable.listener; restartable).
  iOS/macOS pods use synced copies of `stockfish/`+`native/` (CocoaPods
  can't reference outside a local pod root) — after touching those dirs run
  `packages/karpa_engine/tool/sync_sources.sh`. Android CMake references
  the canonical dirs directly. NNUE nets download at build time and are
  verified against their names' SHA-256 prefix. GPL-3.0 notes in the
  package README.
- `lib/content/` — lesson/puzzle models + `AssetContentRepository`
  (per-file English fallback).
- `lib/prefs/` — one JSON blob in shared_preferences (`karpachess.v2`).
- `lib/features/<x>/{domain,application,presentation}` — academy (learn),
  puzzles (the rated trainer), practice (incl. rewritten ChessClock with
  working increment/timeout), review, coach (offline heuristics + the shared
  hint flow, no tab of its own), commentator, settings, board (shared
  chessground wrapper `KarpaBoard`, and `PieceSetId`, the ten piece sets).
- `lib/progression/` — the ONE score. `xp` feeds level, level feeds rank,
  and every surface awards into it, so level/rank/streak/daily-goal are
  global by construction. `ScoreCard` renders it; there is exactly one such
  widget (it used to be hand-copied into the academy home and settings).

Seams are abstract interfaces bound via Riverpod providers: `EngineService`,
`CoachService`, `SoundService`, `ContentRepository`, `PrefsRepository`.
Domain layers are pure Dart — no Flutter imports.

## Key invariants

- Engine scores: always White-perspective cp at the `EngineLine` boundary;
  convert with `EvalScore.cpFor(color)` at use sites.
- After `stop`, the pending `bestmove` must be consumed before the next `go`
  (owned by `UciEngineService` — don't bypass the queue).
- Lesson/puzzle FENs may be pedagogical (single king, opposite check):
  always construct positions with `positionFromFen` from
  `core/chess/tolerant_position.dart`, never bare `Chess.fromSetup`.
- **The engine is the one exception: nothing reaches Stockfish except
  through `EnginePosition`** (`engine/domain/engine_position.dart`).
  - **Why.** Stockfish 19 validates every `position` command and, on anything
    it refuses, prints `CRITICAL ERROR` and calls `std::exit(1)`. The engine
    runs in the app's process, so that exit closes the app.
    - Refused: a missing or extra king, a pawn on a back rank, the side not
      to move in check, 9+ pawns, more promoted pieces than missing pawns, an
      illegal token in `moves`.
    - A Studio import with a one-king `[FEN]` once crash-looped the Studio,
      and a hint asked for while in check closed the app.
  - **How.** `UciEngineService.analyse`/`bestMove` check the position before
    it queues and fail with `EngineRejectedPosition`. They send dartchess's
    re-serialized FEN, never the caller's string, and a history
    re-canonicalized through `kingCastlingForm`.
  - **The import.** `MoveTree.fromPgn` reads a `[FEN]` tag through
    `engineAcceptedPosition` and throws `FormatException`, so the import sheet
    refuses such a game.
  - Never send the engine a `positionFromFen` board, and never bypass the
    service.
- A `NormalMove` always says where the piece **landed**: castling is the
  king's own move (`e1→g1`), never dartchess's king-takes-rook normalization
  (`e1→h1`), which only Chess960 needs. Everything drawn *about* a move — the
  quality badge, the last-move highlight, a teaching arrow — anchors on
  `move.to`, and the rook's origin is the one square castling empties, so the
  badge landed on bare wood. Enforced by `kingCastlingForm`
  (`core/chess/castling_moves.dart`) at the three seams a move enters from:
  `KarpaBoard.onMove` (the user), `legalMoveFromSan` (authored SAN),
  `MoveTree.fromPgn` / `CommentatorController.playMove` (PGN and the studio).
  Engine replies need nothing — `e1g1` is what standard UCI means. Never call
  `Position.normalizeMove`; it converts the wrong way.
- The board widget forces LTR internally; app chrome follows the i18n
  direction. Use `EdgeInsetsDirectional` in feature UI.
- Layout: `ModePanes` is the single board-screen layout authority
  (four compositions — the phone's `compact` and `landscapeCompact`, the
  tablet's `stacked` and `twoPane` — chosen by `ModePanes.layoutFor`, never
  a raw pixel check). The board rect derives only from window
  constraints. `ModePanes` owns the whole panel pane and builds it once for
  every branch as a `CustomMultiChildLayout` over three slots: `panel` is
  scrolling content ONLY, the pinned controls go in `actionBar`, the drawing
  tools in `overlayBar` and transient hints in `toast` (a `HintToast` — the ONE
  hint surface app-wide, always closable). The float stack is the LAST child, so
  it paints over everything beneath it, and it is docked against the action
  bar's **measured** top edge. That measurement runs under UNBOUNDED height,
  never the pane's: bounding it handed the whole pane to any height-greedy
  bar child (a default-`max` Column in the lesson actions was enough), which
  laid the entire mode out at zero height — buttons visible, board and prose
  gone. So every `actionBar` must shrink-wrap vertically, and the guard is
  the unbounded constraint itself, not `IntrinsicHeight` — Play's `ActionBar`
  holds a `LayoutBuilder`, which intrinsics reject at runtime. Four shapes were tried: a `Positioned` at a
  constant `bottom: 72` covered the very button that dismissed it; a Column row
  consumed the panel's height, so a hint reflowed the panel and pushed the
  controls off a short phone; docked inside the panel's box it moved nothing but
  was painted before the action bar, whose floating shadow bled across it; and
  measuring the bar fixed the paint order but left the float boxed inside the
  *panel*, which in the Studio is `SizedBox.shrink()` — so its entire world was
  the ~90dp a two-row pinned zone left over, and it could not rise over the
  board however it was painted. **What the layout spans is what the float can
  cover**, because a child laid outside its parent's box paints but is never
  hit-tested — overflowing upward would have made the toast's own close button
  visible and dead. So on a phone (both orientations) and in the stacked tablet
  column `_paneStack` is handed the WHOLE column, board and player bars
  included; two-pane hands in just the side panel, which is already full
  height. Never reintroduce a constant for where
  the float sits, and never shrink what the layout spans back to the panel.
  Fixed slot
  heights go through `slotHeightFor`
  (text scale + the 48dp tap target); content widths through `ContentWidth`;
  modal sheets through `showAppSheet`. Never hand-roll landscape branches on
  board screens.
- Tablets: a tablet window (`LayoutSpec.tablet` — neither phone class) is
  composed by its SHAPE, because its width class is the same in both
  orientations; splitting a portrait iPad by width left the board floating
  between empty bands and half of every home screen blank. Phones keep every
  layout they had — `_compact`, `_landscapeCompact`, `_paneStack` and
  `_PaneLayout` are untouched by the tablet branches.
  - **Board screens.** `ModePanes.layoutFor` picks whichever of `stacked`
    and `twoPane` gives the larger board, judged at nominal type size (in
    practice portrait stacks and landscape splits). `ModeLayout` is the ONE
    decision for layout-gated content — screens switch on it
    (`listsMoves`: every composition but the phone column) and never
    re-derive "am I wide" from thresholds.
  - **`stacked`** is the phone column centred at the board plus 8dp a side,
    with ONE canonical reservation for every mode: header
    (`ModeHeaderBar.height`), a lead row exactly the lead-content gate
    (48dp), both card rows (`PlayerBarCard.height`, booked even when a mode
    has no card) and a panel floor of `max(132, 22% of the height)`. All six
    boards share one rect in a given window — Review opens where Play's
    board was — and a mode without a below card gives that row to its panel.
  - **`twoPane`** lets the board fill the height (`boardMaxSize` 1000):
    board = min(H − 16, W − 28 − 320), the side pane takes what is left
    (320–460dp), and the group is centred at its computed width.
  - `MoveListCard` (`core/ui/`) is the ONE move-list surface. It flows pairs
    row-major into as many 220dp columns as its own width holds (always one
    in a side pane) and opens on the move on the board. Play mounts it
    read-only (live, not a scrubber); Review scrubs with it, and in
    `stacked` puts its tallies in the above-board row and the list beside
    the explanation. SAN is LTR: the card forces `Directionality.ltr` on its
    list body.
  - **The STUDIO never lists a move past the board.** On phones its panel
    stays empty; on tablets it holds the moves SO FAR —
    `MoveTree.lineTo(currentNode)`, the path to the position shown, which
    cannot give anything away — read-only while drawing. A pane that listed
    the line ahead would reveal the match and kill the study; the whole tree
    stays in the opt-in moves toast. Play and Review are spoiler-free by
    construction (only moves already played / the reader's own finished
    game).
  - **Browse screens** split only when the window is landscape-shaped
    (`LayoutSpec.split` — a phone on its side, or an expanded tablet in
    landscape; the ONE gate). Learn and Puzzles compose a `TabletHero`
    (the profile beside the big actions on a wide page, over them on a
    narrower one) and grids whose column counts divide their fixed item
    counts — arts 4 or 2, packs 5 or 4, personas 2 — so no row is left
    short. The art view, pack detail and Pattern Book take the grid cap in
    portrait and the wide cap in landscape.
  - **Nothing stretches into a slab.** Prose keeps a reading measure
    (`ReadingMeasure`); a lone button is `ContentWidth.button`
    (`ButtonMeasure`, which still fills any phone-sized slot); the
    `ActionBar` pill stops at 440dp; dialogs cap at `ContentWidth.dialog`
    (a `MaterialApp.builder` theme override, tablets only — Settings passes
    its own 720); Settings opens as a dialog on every tablet, its pickers as
    5-column grids (`PickerStrip.columns`).
- Performance contracts: engine work is visibility-gated (studio analyzes
  only while its tab is active; nothing analyzes at restore) and lifecycle-
  gated.
  - **The lifecycle hold.** On background, `AppLifecycleGuard` calls
    `EngineService.suspend()` and pauses the clock; on return it calls
    `resume()`.
  - Suspend HOLDS work, it never drops it. The running search is stopped,
    its truncated result discarded, and the job is re-queued once its
    bestmove is consumed.
  - Nothing boots or searches while held. On resume the stopped search runs
    again, so a reply, review or analysis that was under way still arrives.
  - It replaced `cancelAll()`, which left Practice stuck on Stockfish's turn
    with its clock running, and Review half-done.
  - **Threads.** Batch searches and handicapped replies run on 1 thread;
    interactive full-strength work on 2. It is set per job, but only sent
    when the count changes, because each change rebuilds Stockfish's thread
    pool and clears its hash.
  Every state class implements field-identity `==` and its Notifier
  overrides `updateShouldNotify` — keep that for new state. The practice
  clock ticks 1s (200ms under 10s), emitting only on displayed-second
  change. Long analysis loops must be cancellable and `autoDispose`-scoped.
- Puzzles are two different things and must not be confused. The academy's
  are teaching artifacts: 100 named 1:1 by `Lesson.proof` as OWN beats, plus
  a 101-puzzle surplus that Sharpen rotates through via `puzzles/index.json`
  and `puzzleThemeArt`. The 25 `*-proof` files (`deflection-proof`,
  `greek-gift-proof`, …) are deliberately in NO index
  theme: proofs resolve by filename (`conceptProofProvider`), and indexing
  them would let Sharpen's rotation re-serve a pattern on the very position
  it was proved on. The trainer's
  are a rated ladder in `puzzles/packs.json`, generated by
  `dart run tool/puzzles.dart packs` (never hand-edited) and carrying a
  `rating`. Twenty packs, twelve puzzles each, 600–2000.
  **A trainer pack must never appear in `index.json`**, or it leaks into
  Sharpen's review pools. Trainer puzzles ship in English, Arabic, Indonesian, French, Spanish, Chinese, Russian, Japanese, Hindi, Turkish, Italian and Portuguese like
  every other puzzle; other locales read the English files.
- The trainer rating (`ProgressionState.puzzleRating`, Elo via
  `PuzzleRating`) measures how hard what you can do is; `xp` measures how
  much you have done. The XP goes into the same pool the lessons feed.
  `PuzzleSolver` is the one multi-move solve loop — Sharpen still grades
  only ply 0 of its challenge, which is why a mate-in-2 there is scored on
  its first move. Every solve loop (trainer, academy play and proof beats,
  Sharpen) judges a move through ONE predicate, `acceptsAuthored`
  (`core/chess/san_moves.dart`): the authored move, or — when the authored
  move checkmates — any checkmate. Rejecting a mate because the author wrote
  down a different one taught readers that mating was the mistake.
- **Nothing in the trainer is ever finished-and-gone.** Every pack opens a
  `PackDetailScreen` (blurb, rating range, one row per puzzle with its
  stored best); any row replays as a `SinglePuzzleRun`, and a run that
  finds nothing fresh AT ENTRY (`_seen.isEmpty` — a completed pack, an
  exhausted rated corpus) re-serves in PRACTICE: `_pick(practice: true)`
  drops lifetime results from the exclude set and keeps only this
  session's. What an attempt pays is the domain's job and lives in ONE
  place — `ProgressionState.puzzleResults`, a `Map<String, PuzzleOutcome>`
  (failed < solved < flawless): the rating moves only on a puzzle's
  first-ever attempt (`solvePuzzle` up, `failPuzzle` down — taking "Show
  solution" after 3 misses is the fail), full XP mints with that first
  solve, and a replay pays `XpRules.puzzleUpgraded` only when it beats the
  stored best, which never downgrades. No screen may re-implement any of
  that. Failed puzzles are deliberately NOT excluded from serving — retry
  is the point — and do not count toward pack progress. The badge is
  likewise DERIVED per position ("Practice" when the best is flawless,
  "Replay" when it can still improve), never a stored flag.
- Hints: ONE affordance app-wide — a hint button, answered in the shared
  `HintToast`. Outside the academy the pick runs `coachMenuFor(HintScope)`,
  one Stockfish scan, and the offline `BuiltinCoach` answers. **Inside the
  academy the hint is the sentence the lesson author wrote** — `PlayStep.hint`
  on a play beat, `Puzzle.hint` on a proof beat — because a lesson knows its
  own position better than a scan does. There is no Coach tab and no
  free-text chat.
- Engine arrows are forbidden outside Learn: Practice/Studio/Review draw no
  move arrows (badges only), and chessground's native draw is off. Lesson
  and Sharpen teaching arrows are the sole exception.
- A Studio side line is said in COLOUR, never in words: `BoardStage.sideline`
  takes the bezel off the wood toward `tokens.info`, rings it and haloes it,
  and the SQUARES take the same hue as a wash UNDER the pieces
  (`KarpaBoard.wash`, `tokens.info` at `BoardStage.sidelineWash` = 0.2 —
  blended into the colorway in `boardColorScheme`, so the pieces stay at
  full strength). This is NOT the rejected uniform alpha fade, which dimmed
  pieces too and read as "this screen is disabled"; the wash tints only the
  wood. Bezel and wash fade on the same `Motion.base` curve.
  The frame's *thickness* never changes — it is subtracted from the stage
  footprint, so growing it would resize the squares under a live annotation.
- Academy arrows carry exactly TWO meanings, and never swap: `tokens.accent`
  **teaches** (sequence frames, menu options) and `tokens.info` **assists**
  (tapped-chip preview, stuck-help). An arrow shown because the learner
  failed must never look like an arrow that is teaching.
- The board's orientation is a property of the LESSON, not of a step
  (`_resolveOrientation`): the side the learner plays, held for every beat.
  Deriving it per beat turned the board around mid-lesson. `playerSide` is a
  separate concern and still follows the position's side to move.
- Every lesson beat renders through one panel: phase chip → optional heading
  (`TeachStep.title` / `Puzzle.title`) → markdown body → actions. Teach text,
  play prompts and puzzle setups are all markdown; none is flattened.
- **Practice strength is ONE scale.** `EngineStrength` beginner, casual and
  club are Stockfish `Skill Level` 0, 2 and 4 (≈1350, 1570 and 1950 on
  Stockfish's own Elo scale); master is full strength.
  - `UCI_LimitStrength`/`UCI_Elo` are never sent. Club used to be Elo 1700,
    which Stockfish maps to skill ≈2.8 — weaker than Casual.
  - A handicapped Stockfish picks its move at depth `1 + level` and discards
    every deeper iteration. So a handicapped reply searches
    `go depth 1+skill movetime 1000`: the same pick at a fraction of the CPU.
  - `replyPace` (practice domain) keeps each level's old 80/150/400 ms rhythm
    as a timer.
- **Practice hands Stockfish the whole game** (`bestMove(startFen, moves, …)`
  → `position fen … moves …`) so it sees repetitions. A third repetition ends
  the game drawn: `isThreefold` compares the first four FEN fields, back
  `halfmoves` plies. That is FIDE 9.2.2, because dartchess writes en passant
  only when legal.
- Session state belongs to a controller, never to a screen. Whether a
  practice game is running is `PracticeState.status`, and the game itself —
  line, side, orientation and clock — is persisted through `PracticeStore`
  (`features/practice/data/`), the same seam shape as `CommentatorStore`. A
  screen holding "am I in a game?" in widget state loses it every time the
  shell swaps between the bottom bar and the rail, which is why the tab
  stack in `mode_shell.dart` carries a `GlobalKey`: the two layout branches
  are different trees and Flutter must reparent that subtree, not rebuild
  it. Saved games are the ones still in progress; a finished game is cleared
  when it ends. A restored clock comes back paused and starts on the first
  move — the elapsed gap while the app was closed is never charged. The
  clock runs in EVERY game: down toward a flag when timed, UP as accumulated
  thinking time when unlimited (`ChessClock` counts into the same two
  fields, so snapshots and the no-wall-anchor contract carry over) — the
  card shows a timer icon for a countdown, an hourglass for elapsed, and
  `PracticeState.timedGame` says which way to read the number.
- The shell goes immersive in-game: while the active tab shows a live
  board (Play `PracticeStatus.active`, Studio `hasGame`) `mode_shell` drops
  the AppBar and, in portrait, the bottom `NavigationBar` — the two bars
  cost ~136dp, which height-clamped Play/Studio boards visibly narrower
  than the fullscreen-routed Learn/Puzzles. In-game the `ModeHeaderBar`
  close/new-game action is the way back out, and ending the game brings
  the bars home; the wide branches keep the rail (it costs width, not
  board height). The rail extends into labelled rows only at
  `WindowClass.extendedRailAt` (1600dp): a 13" iPad in landscape keeps the
  72dp rail, whose 168dp extended form came out of the in-game board.
- Game chrome: `ModeHeaderBar` is THE header, on all six board modes —
  label left, optional run `progress` filling the middle, action right.
  (`AcademyHeaderBar` was deleted: its left-side close made the academy read
  as a different product.) Destructive/session actions (studio close,
  practice new game, mid-lesson and mid-run close) live in that header
  behind confirmation dialogs — never inside an `ActionBar`; Sharpen closes
  without asking because every graded answer has already banked. Action
  bars lead with [hint, flip, …] in every mode; on Learn and Puzzles the
  bar is ONE row — [hint · back · advance] + pencil — where the advance
  button announces the coming phase ("Play it", "Own it", "Finish lesson")
  and back walks the run: lesson beats re-enter in their solved state
  (`_solvedBeats`) and XP mints once per beat (`_awardedBeats`); the
  trainer keeps a read-only session history — reviewed puzzles show the
  solved-out position and explanation and can never re-rate. Player bars use the shared
  `PlayerBarCard`, whose slot height is `PlayerBarCard.height` (never a bare
  number at a call site) and which carries a `CapturedPieces` line: what that
  player has TAKEN — the opponent's losses — plus the material lead, derived
  from the board by `CapturedMaterial.of` (`core/chess/`), never from a move
  list. The board because the Studio's node FEN is the only truth inside a
  side line, and because a Practice version derived from `state.moves` once
  shipped showing each player the pieces they had *lost*. The captured row is
  ONE clipped line — a row that wrapped would resize the board mid-game. The
  drawing bar and hint toast are one float stack
  layered over the panel and docked to its bottom edge — never over the
  board, and never over the action bar. In the compact branch `ModePanes`
  lifts the board group off the top bar with a COMPUTED gap
  (`_compactLeadShare`, a fifth of the genuine leftover) that is the first
  thing to collapse when space is tight — never a flex pair, whose split
  forced the board reservation to be inflated by the inverse fraction. In
  portrait the board and the player cards share one width: screen minus 8dp
  a side. The board's rect is still a pure function of the window
  constraints. Two reservation rules paid
  for in board pixels: the panel minimum and the drawing-bar clearance are
  `max()`ed, never summed — the bar floats OVER the panel, so the claims
  share pixels (summing them once shrank every drawing screen's board by the
  bar's height), and a below-board card's slot is DISCOUNTED from the
  drawing-bar clearance: drawing is modal, so the open tools may ride over
  that card (paused clock, captures — nothing actionable) but never the
  board; and in the side-pane branches the player/context cards live in
  the SIDE pane, never in the board's column, where each dp of card height
  would come straight out of a height-bound board. (The stacked tablet
  column keeps them: `layoutFor` only picks it when, cards paid for, it
  still gives the larger board.) Cards span their pane's
  width, 8dp off the screen edge in every branch. Learn, Sharpen and
  Puzzles fill the above-board slot with a `BoardContextCard` (what you are
  working on, where the other modes show who is playing); its `height` IS
  `PlayerBarCard.height` by reference, which is what keeps the board's
  origin and size aligned across all five modes — never let those two
  constants diverge. Session state costs the board NOTHING,
  two placements: the trainer's `_SessionLine` (rating in words, streak,
  run tally — words so it cannot be misread as the puzzle-difficulty chip
  in trailing) rides INSIDE the card via `BoardContextCard.secondary`;
  Learn's `LessonJourneyLine` (SEE→PLAY→OWN tracker) floats ABOVE the card
  in `ModePanes.leadContent` — a decoration of the compact branch's
  computed lead gap that reserves nothing and renders only when the gap has
  room (`_leadContentMin`, an effective 48dp through `slotHeightFor`'s
  floor); the stacked tablet column books a lead row of exactly that height
  for every mode, and the side-pane branches stack it in the side pane
  where height costs the panel. A second stacked card was tried and
  pushed the board ~82dp down; a line inside the lesson card was tried and
  rejected — the journey belongs on top of the card, never in it. A puzzle's title stays off the card until solved: a
  name like "Royal Fork" is half the answer — in the trainer, and in the
  academy's OWN beat, whose heading stays empty until the proof is solved.
- Theming: colors come from `context.tokens`, type from `context.type` —
  never hardcode a `fontFamily` or a hex. A theme is 11 colors through
  `_dark`/`_light`; everything else (hairlines, shadows, sheen, quality
  ladder, board washes) is derived so it can't drift between themes. Four
  of the eleven are the surface ladder — `bg`/`panel`/`raised`/`float`,
  ~7 L\* apart in the darks — and `tint` is the theme's hue, which every
  edge and shadow carries so no two dark themes share a surface. The
  launcher icon is generated from the default palette by `tool/gen_icon.py`
  (the single icon mechanism — there is no icon plugin); re-run it if the
  default palette moves. Its knight is the Classic set's, rendered by
  `tool/gen_pieces.py` (never a pasted image), so the icon and the board are
  one character. Its mortarboard is DRAWN in gen_icon, in that knight's own
  language (its outline and stroke hierarchy, flat fill + one shade, a gold
  tassel), never pasted as an icon glyph. It is fitted to the knight's
  measured anatomy: the skullcap's seat IS the crown contour, and it sits on
  the poll just behind the ear, which stays in front. Redraw the knight and you
  re-tune `ANCHOR_U`/`TILT`/`LIFT` by eye. The whole mark is placed by one
  balance rule (`MARK_H`, box centre averaged with the visual centroid).
- Depth: `Surface(elevation: …)` is the ONE card widget — never hand-roll a
  fill + hairline + shadow. `AppTokens.surfaceAt` decides how a plane is
  drawn, and it branches on brightness: dark themes step the tone, light
  themes barely move the fill and let the shadow lift it. `raised` is above
  `panel` in both modes. `BoardStage` (features/board) frames the board in
  a bezel cut from the colorway and hands its `builder` the inner edge
  length — every layer must be sized from that, not from the footprint.
  Each `AppThemeId` names the colorway it was designed around
  (`id.board`), which choosing a theme adopts.
- HIG: 44dp touch targets; panel primary actions are pinned by passing them
  to `ModePanes.actionBar` — never inside the panel's scroll;
  dialogs have titles, `ui.button.dismiss` cancels, labeled confirms;
  radii via `AppRadius`, spacing via `AppSpacing`, type via the roles on
  `context.type` (`display`/`title`/`heading`/`body`/`label`/`caption`)
  rather than a fresh `fontSize`; text scale clamped ≤1.3.
- Settings' language switcher is `LanguagePicker`: a grid of
  `LanguageChoiceCard`s, each showing a flag beside the language's own name
  (its bundle's `language.name`). The flag is the system emoji spelled from
  `I18nService.flagRegions`. A language is not a country, so each region is
  a decision recorded once in that table: 🇺🇸 for the American-spelled
  English, 🇸🇦 for Modern Standard Arabic, 🇵🇹 for European Portuguese. A new
  language needs its region there, and `i18n_service_test` fails without
  one. The language cards, the sound packs and the typefaces all share one
  `SettingsChoiceFrame`, so the sheet's pickers cannot drift apart. The two
  board pickers in Appearance share `_BoardPreviewFrame` for the same
  reason. The piece strip (`PieceSetPreviewCard`) shows each set on the
  reader's OWN colorway, and the colorway strip draws its boards with the
  reader's own pieces: each choice is previewed against the other.
- Drawing mode: `DrawTool.arrow` is armed on entry — an arrow is what people
  open the tools to draw, so the first drag produces one. The ROW leads with
  select, then undo · redo · clear right beside it ([select, undo, redo,
  clear | square, arrow, …]) — order is visual only, the armed default stays
  arrow. `select` is the
  re-tap fallback (re-tapping the armed tool falls back to the pointer) and
  the hand-off after creating a text label; tools never disarm while active.
  `setColor`/`setStrokeWidth` restyle the selected shape; drags apply
  `movedBy` to the drag-start snapshot. While a selection drag is in flight
  a trash target shows at the board's BOTTOM CENTER (overlay-local geometry,
  never hit-tested — the pan owns the pointer); dropping there deletes the
  shape as ONE undo frame (undo restores it where it stood), and a gesture
  cancel snaps back with no frame. `draggingSelection`/`overTrash` are
  transient `DrawingState` fields, never persisted. The toolbar is ONE 44dp row —
  select · history · tools · colors · strokes · selection — scrolling sideways so it
  costs the screen as little height as possible while open;
  its vertical budget is `DrawingModeBar.height`, which the floating screens
  (play, lesson, puzzles) pass as `overlayBarHeight` — the pair were once
  unlinked `56`/`60` literals in different files. The STUDIO is the one
  exception: it passes no `overlayBar` and instead swaps the toolbar into
  its pinned zone, in place of the ReplayBar row, while drawing is active —
  drawing is modal there, so the navigation row it replaces is exactly the
  control set that cannot be used anyway, and the pencil row below survives
  so exiting stays one tap. An embedding host owns the bar's 12dp horizontal
  inset (the float slot used to provide it). The pencil lives bottom-right on
  every drawing screen, as `Row[Expanded(actions), DrawingModeButton,
  SizedBox(12)]` in the `actionBar` slot — never in a header.
- Academy pacing: the learner advances, never a timer — auto-advance
  Timers to `_next` are forbidden (opponent auto-replies are fine).
- Engine insight: `InsightBuilder` (coach domain) is the one MultiPV-3 +
  threat scanner, shared by the hint flow and the studio's node analysis.
- The Studio's study library is `assets/data/games/games.json`: 240 short
  decisive master games in 24 player collections — short, decisive, both
  players named, every move replayed before it was kept, and kept that way
  by `tool/content.dart`, which loads each one through `MoveTree.fromPgn`. One file, not the
  index-plus-files shape lessons and puzzles use, because games are
  language-neutral and tiny: no per-language directory, nothing to translate.
- The Studio lands on that library, not on a paste form: importing is a button
  that opens `showStudioImportSheet`. Bundled games and the reader's imports are
  one list behind one interface — `StudyGame` (`content/domain/models.dart`) —
  so the cards, the search and the filter strip cannot tell them apart. An
  `ImportedGame` keeps its **original PGN text**, never a re-serialization: an
  import may carry comments, variations and NAGs, and a library that quietly
  dropped them would be editing someone's study. It is persisted through
  `ImportedGamesStore` (`studio_library.json`), and the controller's `build()`
  drops anything that no longer parses — which is what lets `loadPgn` throw
  rather than carry a parse-error field nobody reads. The import sheet is the
  one caller that can be handed bad input, and the one place a person can be
  told — including a `[FEN]` tag Stockfish would refuse (see `EnginePosition`).
  Read a tag pair with `MoveTree.header`, never `headers[...]` directly:
  dartchess fills Event/Site/Round/White/Black with `?` for a bare move list,
  and `header` is the single place that reads `?` as "not stated".
- `assets/data/` is the CANONICAL corpus — authored here, gated here. Run
  `dart run tool/content.dart` after touching it: every lesson FEN parses,
  every `targetSan` is legal, every puzzle solution replays, and the manifests
  agree with disk. It runs against the app's own
  models and its own tolerant FEN reader, so passing it means the app can load
  what passed. `lessons/index.json` is the single source of lesson
  existence (the app takes its *order* from `artOrder`); puzzle pools are
  dealt to concepts positionally in `puzzles/index.json` theme order, so
  beginner themes (`first-steps`) must stay first. Foundations teaches
  gradually: board → notation → one lesson per piece → captures → values →
  check → mate → special moves.
- iOS minimum platform is 15.0: App Store Connect's validation warns that
  from April 2027 uploads must target iOS 15.0 or later (file_picker alone
  needs 14.0). CocoaPods via
  `ios/Podfile` and `macos/Podfile` (karpa_engine is CocoaPods-based).

## Production invariants

The release audit (`docs/RELEASE.md` is the runbook) left these contracts.
Keep them when touching the code they govern.

- **The engine build is portable.** Android arm64 and iOS arm64 compile
  Stockfish with NEON and **without dot-product** (`USE_NEON=8`, no
  `-march=armv8.2-a+dotprod`, no `USE_NEON_DOTPROD`). The phones the app
  installs on include ARMv8.0 cores (Cortex-A53/A73; iPhone 6s–XS/XR under
  the iOS 15 target), where dot-product instructions and the LSE atomics
  that `armv8.2-a` licenses raise SIGILL the moment the engine searches.
  Only macOS arm64 keeps dot-product, because every Apple Silicon Mac has it.
  Stockfish 19's `arm64-universal` (runtime dispatch: dot-product where the
  CPU has it, plain NEON where it does not) would retire this compromise, and
  it was tried. It does **not** work here: on Darwin the build fails outright
  (`clang++: error: invalid arch name '-arch armv8'` — the universal path
  emits GNU-style flags), its CPU probe is `getauxval`/`<sys/auxv.h>` which
  Apple does not have, its per-variant static-init trick is ELF-only, and the
  dispatcher selects a `main()` while our bridge calls `UCIEngine` directly —
  so the bridge would need dispatching too. Revisit only with an ARMv8.0
  device to test on.
- **NNUE nets are verified, never trusted.** A net's name carries its SHA-256
  prefix, and `android/CMakeLists.txt` and `tool/fetch_nnue.sh` (iOS/macOS
  script phases) reject a file that does not match. An HTTP error page saved
  under a net's name would be embedded, and Stockfish `exit()`s the whole
  app when its embedded net fails to load. Android caches verified nets once
  in `packages/karpa_engine/.nnue/`. `tool/sync_sources.sh` copies the
  fetcher into the pod roots.
- The `karpa_engine` pod ships `Resources/PrivacyInfo.xcprivacy` (iOS and
  macOS). Stockfish's Syzygy loader references `fstat`, and without the
  declaration App Store Connect rejects the upload (ITMS-91053).
- **One error sink.** `AppErrors.install()` runs first in `main`:
  `PlatformDispatcher.onError` routes uncaught async errors into
  `FlutterError.reportError`, and a release build draws a quiet mark instead
  of the grey `ErrorWidget`. `bootstrap()` guards every pre-frame step, so a
  device whose stored data cannot be read opens on defaults, not a blank
  screen.
- **Stored JSON is decoded tolerantly.** `Prefs`, `ProgressionState`,
  `LessonProgress` and `PatternMastery` read fields through
  `core/json/json_read.dart`, never `as` casts: a wrong-typed field costs that
  field, never the blob or the launch. The SharedPreferences repositories
  never throw and set an unreadable blob aside under `<key>.unreadable`
  before starting over, so the next save cannot destroy the learner's only
  copy. `clear()` (Reset progress) removes both.
- **File stores write atomically** (`core/io/atomic_write.dart`: temp file,
  flush, rename). A kill mid-write can no longer truncate the practice game,
  the Studio session or the reader's imported library.
- **Stored photo paths are re-found, not trusted.** iOS moves the app
  container on update, so absolute paths go stale. `relocateStoredFile`
  (`core/io/stored_files.dart`) re-finds a photo by name in the current
  directory, or drops it so the placeholder shows. `bootstrap()` does this for
  the avatar, and `FileCommentatorStore.load()` for the Studio photos.
- A failed engine boot fails every queued request and is forgotten, so the
  next request boots again (`UciEngineService._ensureReady`/`_pump`).
  Nothing may wait forever on an engine that never came up.
- **Move sounds mix with other audio.** The sound pools play under one
  `AudioContext`: Android game sonification with no audio focus, and iOS
  `playback` with `mixWithOthers`. The plugin's default took exclusive focus
  and paused the reader's music on every move. The iOS silent-switch
  behavior is deliberately unchanged.
- **Framework strings are localized**: `MaterialApp` carries
  `GlobalMaterialLocalizations.delegates` and `locale` from `prefs.lang`
  (`pt` → `pt_PT`, as the app's Portuguese is European). The app's own copy
  still lives only in the i18n bundles. The iOS `Info.plist` declares the 12
  languages (`CFBundleLocalizations`) so the App Store lists them. The
  in-app choice stays the source of truth.
- **The app is GPL-3.0-or-later**: it embeds Stockfish, chessground and
  dartchess. `AppInfo` (`core/app_info.dart`) holds the name, version (kept
  equal to pubspec by `app_info_test`), `sourceUrl` and `privacyUrl`. Settings › About
  shows the version, the source notice, the privacy notice and Flutter's licenses page, which
  `registerAppLicenses()` completes with Stockfish, the three OFL fonts
  (`assets/licenses/OFL-1.1.txt`) and the app's own artwork (CC0). Selling it
  is allowed; the conditions are in `docs/RELEASE.md` ("Selling under the
  GPL"), and the App Store needs the custom agreement in `docs/EULA.md`.
- **Everything bundled is cleared for sale.** The pieces are the app's own:
  ten sets drawn by `tool/gen_pieces.py` into `assets/pieces/<set>/`
  (128 px plus 2.0x/3.0x/4.0x, lossless WebP), read ONLY through `PieceSetId`
  (`features/board/presentation/piece_sets.dart`). Never use chessground's
  `PieceSet`, its `ChessboardColorScheme` presets or any
  `package: 'chessground'` asset. chessground is VENDORED in
  `packages/chessground/` with its `lib/` untouched and its asset block
  removed (`NOTICE.md`). The hosted package bundles 40 piece sets, several
  licensed for non-commercial use only, so never switch back to it.
  `test/core/commercial_assets_test.dart` guards all three rules. The artwork
  (pieces and launcher icon) is original and dedicated CC0 1.0
  (`assets/pieces/LICENSE`); the code is GPL-3.0-or-later. Never trace or fit
  shapes to another set: inspiration only. A set is added in gen_pieces'
  `SETS`, `PieceSetId`, the pubspec asset list and the
  `nbSettings.pieceSetName.*` keys; `piece_sets_test` pins all four.
- **The pieces answer to a gate, not to taste.** `gen_pieces.py` writes
  nothing unless every piece of every set passes `audit`:
  - one baseline (0.900);
  - the height ladder (K > Q > B ≥ N > R > P);
  - optical centring;
  - one connected silhouette;
  - no unintended kink (`Path.corner()` declares the deliberate ones).
  Two bars carry most of the polish:
  - **Legibility.** At 24 px no two pieces may share 0.84 of their silhouette,
    nor the king and queen 0.82. Silhouette, whose whole point is its
    outlines, answers to 0.76 and 0.74. For scale, cburnett and merida sit
    near 0.70; our first cut shared bodies and ran 0.87–0.92, and giving each
    piece its own body and pedestal width is what fixed it.
  - **Comfort.** Pieces are looked at for hours. No piece may exceed 12:1
    between its darkest line and its lightest light (the old Diagram was
    19:1), yet each piece's edge or body must reach 2.5:1 against every one
    of the ten square colours. Shade and highlight bands scale with the part,
    so a pearl is not all shadow. Every size is area-averaged from one
    3072 px canvas: never a LANCZOS resample, whose halos shimmer along every
    edge.
  - **Mass: the knight sets it** (`MASS`, `CROWN_W`). Each piece's ink, as
    a share of its own set's knight, must sit between the 10th and 90th
    percentile of 25 classic sets: K 0.91–1.25, Q 0.84–1.14, R 0.83–1.01,
    B 0.66–0.93, P 0.48–0.72. The king's crown must span at least 0.60 of
    the square and the queen's 0.70, measured as the widest run in the top
    60% of the piece. The first cut drew narrow crowns on trumpet stems (a
    king at 0.80 of the knight, its crown 0.43 wide), and the new knight
    looked as if it came from a bolder set. So the queen is a CUP flaring
    from a collar low on the body to her pearled points.
  - **The king wears the arched crown** (`king_form`), the king players
    know from cburnett, merida and the Staunton icons: two round arches
    over a banded brim, parted in the middle by a bulb that carries the
    cross or, in the neutral sets, by the cut gem (`arched_crown`,
    `gem_crown`, `crown_bulb`). The gate wants some row across the top 45%
    of the king to cross three runs (arch, bulb or gem, arch) parted by
    gaps of at least 0.015. A domed "closed crown" was tried to part the
    king from the queen. It read as a lidded pot in the cross sets and as
    an onion in the gem sets, and crossed as a single run. Where a king and
    queen still come too close at 24 px, the king's body moves, never the
    queen: a slimmer neck, or the crown carried low on a short stem
    (Silhouette, Facet).
  - **The bishop wears the Staunton mitre** (`bishop_form`): taller than
    wide, rising to a point under a small ball, cut by a THIN slit from its
    upper right toward its middle, as on physical Staunton sets and
    chess.com. The gate reads the mitre off the shape itself (the part the
    slit cuts): height ≥ 1.15 of its width, and 10% below its tip no wider
    than 0.32 of its widest. The mass pass had rounded it into an egg (0.88)
    with a wide wedge, which read as a Pac-Man. Soft's and Bold's ovals were
    tall enough but round-topped (0.58). Each set draws the mitre in its own
    language: `mitre_outline` smooth, `lancet_outline` for Modern and Deco,
    planes for Facet, a softened point for Soft and Bold.
  - **The knight is THE chess knight** (`knight_form`), because a knight
    that is merely a horse reads as wrong. One ear; a straight face into a
    crisp muzzle; a chin; and the jowl, where the jaw rises steeply from the
    chin, then rounds off to reach the throat almost level. From the throat
    the neck front falls at about 50° and swings forward into the chest. The
    gate wants an open V under the jaw (≥ 0.07 tall), its apex ≥ 0.30 behind
    the muzzle, the chest ≥ 0.18 in front of it, and ≥ 0.65 of width. These
    sit at the low edge of what the canonical knights measure, and every one
    of our ten clears them. Two failures taught this. A neck rising straight
    up read as a horse bust on a column. A jaw climbing steeply INTO the
    throat pinched the V into a slit once the 2.6% outline was drawn: it
    looked open on paper and measured 0.02. All ten sets draw one skeleton
    (`KNIGHT`, Hobby splines through its landmarks; `KNIGHT_MARKS` for the
    straight-edged sets), so they cannot drift apart. Inside the head go
    only an eye, a nostril and, on styles that model light, the jowl's
    shadow along the jaw (`Style.shadow`). Its proportions come from an
    average of many sets, never from tracing one. It shares about 0.84 of
    its 64 px silhouette with Staunty and with Monarchy alike, so it
    matches the archetype and copies neither.
  Nothing tunes a threshold to let a piece through: move the geometry.
- **Kings and religious symbols.** The five sets added after the original
  five (Marble, Deco, Facet, Silhouette, Soft) crown the king with a cut gem
  (`jewel`, `set_gem`), never a cross. The original five keep the
  Staunton cross by the owner's decision. The gem stands where the cross
  set's bulb does, between the crown's two arches: broad (0.24 of the
  square), wider than tall, and set into the crown, whose arches meet in a
  cusp inside the gem's lower tip (`gem_crown`). On a neck, a gem's post and
  girdle resolve to a small cross at thumbnail size, which is exactly what
  it replaces. Every new set follows the neutral rule.
- **One privacy statement, said three times, never different.** The three
  places:
  - `docs/PRIVACY.md`, rendered by `tool/website.py` into
    `website/privacy.html` and published at `AppInfo.privacyUrl`
    (`https://karpachess.com/privacy.html`) — both stores link to it. Never
    edit the rendered block; edit the Markdown and re-run the tool;
  - the in-app notice (`settings.privacyBody`, Settings › About › Privacy
    policy), which Apple requires inside the app (Guideline 5.1.1(i));
  - the App Privacy / Data safety answers in the store consoles.

  All three say the app collects nothing and never connects to the
  internet. A feature that changes either fact changes all three first.
  Reset also deletes the stored player photo (`AvatarStore.remove`), which is
  what the notice promises. The policy's "This website" section also promises
  that karpachess.com sets no cookies and loads nothing from another site, so
  the site self-hosts its fonts and carries no analytics or embeds.
- **The website says only what the app does.** `website/index.html` states
  counts (100 lessons, 441 puzzles, 240 master games, twelve languages, ten
  piece sets) and features; change it when they change. Its store boxes say
  "Coming soon" until a listing is live, and then take that store's official
  badge, never a home-made one.
- **Nothing personal or machine-specific is published.**
  - **The gate.** `dart run tool/shareable.dart` scans exactly what git would
    publish (tracked files plus unignored ones). It errors on:
    - this machine's home path or account name, read from the environment and
      never written down. The app's own bundle and application IDs are read
      past, because the stores publish them: the Apple bundle ID is
      `com.mouradghafiri.karpachess`;
    - any `/Users/<name>/` or `/home/<name>/` path;
    - a `DEVELOPMENT_TEAM` in an Xcode project;
    - generated output;
    - credential files, judged by name and never opened.
  - **The iOS signing team** lives only in the git-ignored
    `ios/Flutter/Signing.xcconfig`, which `Flutter/Debug.xcconfig` and
    `Release.xcconfig` pull in with `#include?`. Xcode's Signing tab writes it
    back into `project.pbxproj`; move it out again.
  - **Build output** carries absolute paths and stays ignored at any depth:
    `android/build/`, `**/stockfish/src/*.o` and the host binary.
  - A new repository is made from `git ls-files --cached --others
    --exclude-standard`, never from a zip of the working folder.
- Android release signing reads `android/key.properties`, a git-ignored
  secret that is never created or read by tooling. Without it, a release
  build falls back to the debug key and Gradle warns that it cannot be
  uploaded.

## Content

`assets/data/`: 100 lessons, 201 teaching + 240 trainer puzzles,
240 study games,
i18n bundles in 12 languages
(451 leaf keys in English, COMPLETE — every key translated in every bundle.
A bundle's leaf count is not the same number in every language and must not
be "fixed" to match: a count-bearing message is a map of CLDR plural
categories, so `id`/`ja`/`zh` carry 435 leaves (one category), `ru` 467
(three) and `ar` 515 (all six). `PluralRules.requiredCategories` is what
decides, and `i18n_integrity_test` compares category sets, never totals.
The app chrome is fully localized; lesson/puzzle CONTENT ships in English, Arabic, Indonesian, French, Spanish, Chinese, Russian, Japanese, Hindi, Turkish, Italian and Portuguese). `test/content/content_integrity_test.dart` replays every
FEN/SAN with dartchess; `test/core/i18n_integrity_test.dart` checks key and
`{param}` parity across languages. Keep both green when touching content.

**How a lesson is written is a contract, not a taste**: `docs/LESSON_STYLE.md`,
gated by `dart run tool/lint_lessons.dart`. The short version — vivid-coach
voice, second person, American spelling; the opponent is *Black*/*White* or
*your opponent*, never *he* (pieces are *it*, people are *they*); a teach beat
is ≤110 words and one idea, and carries a `title` **or** a `##` heading, never
both, because the panel renders both; a play prompt is one sentence that states
the **goal** and never contains its own answer; every move in prose is a
`{{chip}}`, never `` `code` ``; and no term may be used before the lesson that
owns it (`tool/src/lesson_glossary.dart`). There is no fixed beat skeleton —
the corpus used to be 74 lessons of identical `teach·play·teach·play` at ~380
words each, which is what "boring" turned out to mean.

**Every lesson is SEE → PLAY → OWN.** A lesson names its own proof puzzle
(`Lesson.proof`, one per lesson, unique corpus-wide) rather than having one
dealt from a themed pool by position — the old dealer gave the five endgame
puzzles to the five *easiest* endgames and left Philidor and Lucena with none.
`puzzleThemeArt` now only builds each art's **review pool**: the surplus
puzzles Sharpen rotates through so a pattern is not reviewed on one position
forever. Sharpen deliberately reviews the *proof*, never the lesson's first
play step — that step is the Pattern Book thumbnail, so reviewing it showed
the answer before asking the question. It shows the puzzle's `setup` under
"Find the move" (`SharpenChallenge.prompt`) and grades only the first move, so
a setup must name the goal whenever the position has more than one good move —
openings, plans, notation and castling drills all do.

Eight arts, in `artOrder` (`features/academy/domain/skill_map.dart`) which is
what the grid and the Continue button follow — **not** the manifest order:
Foundations 18 · The Story of Chess 8 · The Blade 17 · The First Moves 18 ·
The Finish 12 · The Plan 11 · The Hunt 8 · The Chess World 8. Tactics
deliberately precedes openings. Every art has a review pool:
`puzzleThemeArt` maps all fourteen themes in `puzzles/index.json`, including
`history`, `culture`, `openings` and `strategy`.

**Content is English, Arabic, Indonesian, French, Spanish, Chinese, Russian, Japanese, Hindi, Turkish, Italian and Portuguese; the UI is twelve languages.** `lessons/en/`
and `puzzles/en/` are the canonical corpus — authored, gated and fixed there
first. `lessons/ar|id|fr|es|zh|ru|ja|hi|tr|it|pt/` and `puzzles/ar|id|fr|es|zh|ru|ja|hi|tr|it|pt/` mirror them file for file (100 lessons,
441 puzzles), translated by hand, with only the prose changed: ids, FENs,
solutions, `targetSan` and ratings are identical. `ContentRepository` callers
never pass a language — `AssetContentRepository` resolves the reader's UI
language file by file and falls back to English, so every other locale reads
English content. `docs/TRANSLATION_AR.md` is the Arabic contract (pieces
الملك/الوزير/الرخ/الفيل/الحصان/البيدق, Latin squares and SAN, Western digits,
faithful to facts and adapted in tone) and its glossary; `docs/TRANSLATION_ID.md`
is the Indonesian one (raja/menteri/benteng/gajah/kuda/pion, «Anda», `## Ide`,
the vocabulary of the `id` UI bundle); `docs/TRANSLATION_FR.md` is the French
one (roi/dame/tour/fou/cavalier/pion, «vous», `## L'idée`, cases blanches/noires,
non-breaking spaces before `: ; ! ?`); `docs/TRANSLATION_ES.md` is the Spanish
one (rey/dama/torre/alfil/caballo/peón, «tú», `## La idea`, opening ¿ ¡,
casillas blancas/negras); `docs/TRANSLATION_ZH.md` is the Chinese one
(Simplified; 王/后/车/象/马/兵, «你», `## 思路`, full-width punctuation, one space
between Chinese and Latin text or digits); `docs/TRANSLATION_RU.md` is the
Russian one (король/ферзь/ладья/слон/конь/пешка, «вы», `## Идея`, ё always,
«ёлочки», белые/чёрные lowercase); `docs/TRANSLATION_JA.md` is the Japanese one
(キング/クイーン/ルーク/ビショップ/ナイト/ポーン, ですます調, `## 狙い`, full-width
punctuation and NO space between Japanese and Latin text, digits or chips — the
opposite of the Chinese rule — and no shogi vocabulary); `docs/TRANSLATION_HI.md`
is the Hindi one (मानक हिन्दी, राजा/वज़ीर/हाथी/ऊँट/घोड़ा/प्यादा, «आप», `## विचार`,
danda «।» as the full stop, the nukta always written — वज़ीर, सफ़ेद, ख़ाना —
Western digits, and the note that the piece Hindi calls हाथी took its move from
the chariot); `docs/TRANSLATION_TR.md` is the Turkish one (ölçünlü Türkçe,
şah/vezir/kale/fil/at/piyon — the piece is **şah**, never *kral* — «siz»,
`## Fikir`, dikey/yatay/çapraz, and the apostrophe Turkish puts between
notation and a suffix: e4'te, g8'e, {{Nf3}}'ten); `docs/TRANSLATION_IT.md` is
the Italian one (re/donna/alfiere/cavallo/torre/pedone — never *regina*,
*vescovo* or *cavaliere* — «voi», il Bianco/il Nero, `## L'idea`, casa/colonna/
traversa, « » caporali, the straight `'`, and accents that are never optional:
perché, più, può, così); `docs/TRANSLATION_PT.md` is the European Portuguese
one (rei/dama/torre/bispo/cavalo/peão — never *rainha*, *cavaleiro*, *castelo*
or *soldado* — «tu» with its own verb forms, «estar a» + infinitive and never
the gerund, enclisis (dá-lhe), as brancas/as pretas, `## A Ideia`,
casa/coluna/linha, « » aspas angulares, the straight `'`, AO90 spelling but
keeping facto/contacto and the ó/é family: económico, fenómeno, género).
**Any change to an
English lesson or puzzle's prose must be carried into its Arabic, Indonesian,
French, Spanish, Chinese, Russian, Japanese, Hindi, Turkish, Italian and
Portuguese twins**, and
a change to its chess (FEN, line, chips) must be mirrored there too, or
`dart run tool/translations.dart` goes red. The 12-language i18n UI bundles
(`assets/data/i18n/`) are a separate tree and stay complete.

### The content tooling

All of it is Dart, in `tool/`, run with `dart run`. Pure dartchess over the
app's own models — the whole corpus in about a second. That covers legality,
replay and **proofs** (a forced mate enumerated exhaustively is stronger than
any engine opinion).

Judgements about move QUALITY are not proofs and are not made in Dart. They
belong to `puzzles.dart check --engine`, which drives **one** Stockfish
process — the same engine the app ships, through the app's own
`UciEngineService` — via `tool/src/process_uci_transport.dart`. It never
falls back to a search of its own: a `rivals()` that scored positions with a
depth-4 material negamax used to live in `chess_proofs.dart`, and a gate that
guesses is worse than no gate.

- `dart run tool/content.dart` — integrity of everything bundled: lessons,
  puzzles, manifests, for `en/`, and the 240 Studio games, each loaded
  through the Studio's own `MoveTree.fromPgn`:
  - the game replays and its SAN is canonical;
  - both players are named and the result is decisive;
  - a final mate agrees with the result;
  - the ply and collection counts are right, with no duplicates.

  A directory under `lessons/` or `puzzles/` that is neither `en/` nor a
  translated language is flagged as a leftover (an empty stray `fr/` once
  turned this gate red with a hundred errors).
- `dart run tool/app_check.dart` — the same corpus through the APP's own
  runtime pipeline (`positionFromFen`, `BoardScript.of`, `legalMoveFromSan`):
  proves every lesson beat builds, every play beat is winnable and every
  solution replays with the code the screens actually run — the style
  linter only *mirrors* `BoardScript`, this executes it.
- **A content fix is not delivered until the app re-bundles it.** Flutter's
  incremental build can serve a stale `flutter_assets` snapshot across
  `flutter run`s (it once pinned a 71-lesson corpus for days while the disk
  held 100). When content changes don't show up in the app: delete
  `.dart_tool/flutter_build`, run `flutter build bundle`, and cold-start the
  app — hot reload/restart never re-bundles assets.
- `dart run tool/puzzles.dart check [pack…]` — the puzzle chess gate, for
  trainer AND teaching puzzles (teaching ones were once skipped, and a lesson's
  OWN beat shipped a final move that hung its rook). Structure (ratings for the
  trainer only), lines that end on the learner's move, one board one place (no
  puzzle repeats another puzzle or ANY lesson play position), legality, forced
  replies, and a **proof** of what each line achieves: a mating line within
  five plies is verified shortest, its first move unique, and every later
  learner move but the last the only one that still forces mate in time — the
  last may have twins, because any mate is accepted (`acceptsAuthored`). A
  narrowed run (`check fork pin`) skips teaching puzzles. `--engine` adds the
  evaluative screen: one Stockfish 19 process, depth 20, MultiPV 5, asking
  whether each first move is really the only good one (no rival within 50cp;
  a mating rival must mate at least as fast). Proven mates are skipped —
  the prover already settles them — and so are the themes whose prompts name
  the goal (`openings`, `strategy`, `history`, `culture`, `endgames`, plus
  the notation and board drills), which deliberately have several good moves.
  Build the engine first: `sh packages/karpa_engine/tool/build_host.sh`.
- `dart run tool/puzzles.dart packs [--check]` — regenerates
  `assets/data/puzzles/packs.json` from the files on disk. Never hand-edit it.
- `dart run tool/puzzles.dart fen [--from "<fen>"] "<sans>"` — **never type a
  FEN**; derive it by replaying moves and read the printed board back.
- `dart run tool/puzzles.dart prove "<fen>"` — is there a forced mate, how
  long, and is the key move unique? The authoring loop.
- `dart run tool/compose.dart --theme … --plies … --shelter` — searches for
  positions whose tactic is *provable*, filtered by a theme predicate
  (`king-hunt`, `sacrifice`, `quiet`, `zwischenzug`, `defence`). Composing by
  taste produces puzzles with two solutions; this produces none.

**Flags are not errors.** "Ends level without mate" is expected of a trapped
piece, an endgame or a first-steps capture, and "the opponent had N legal
replies" is expected of a promotion race — every flag `check` prints is
triaged in `docs/content-audit.md`. A repeated position is never a flag: it is
an error, for teaching puzzles too. Errors must be zero.

- `dart run tool/lint_lessons.dart [file…]` — the lesson **style** gate.
  `content.dart` proves a lesson *loads*; this one reads the prose.
  `docs/LESSON_STYLE.md` is the contract it enforces and the document a lesson
  is written to. Errors: a `{{chip}}` silently dropped by `BoardScript`, a
  claim about a square the FEN does not support, a play prompt or hint holding
  its own answer, a teach beat that **animates** the next play beat's single
  answer on the same position (the subtler half — the prompt can be clean and
  the beat still be a replay), a proof puzzle standing on a position the lesson
  already played (the OWN beat then asks what the PLAY beat asked, and Sharpen
  reviews the pattern forever on the board where it was taught), a move written
  as `` `code` `` instead of a chip, a glossary term used before the lesson that
  teaches it, British spelling, a teach beat over 110 words, a `##` heading under
  a step that already has a `title`, more
  than one blockquote in a lesson. Flags: menu-vs-sequence ambiguity, a heading
  reused across the corpus, two lessons opening the same way.
  `tool/src/lesson_glossary.dart` holds the vocabulary ledger and the three
  allowlists; the reading order is computed from `artOrder` and the manifest,
  never typed. Claims are checked with their color ("Black's rook on a8",
  "your queen on d1" — "your" is the lesson's side) in teach bodies, play
  prompts and hints; and a play position belongs to one lesson (L15).
- `dart run tool/lint_puzzles.dart [id…]` — the puzzle **prose** gate, one
  contract for all 441 puzzles (`docs/LESSON_STYLE.md` §8, P01–P08):
  `## The Idea` explanations of ≤ 90 words, setup/hint that never give or
  point at the first move, squares written bare (never `{{g7}}`), setup chips
  legal where they are tapped, the lessons' register, glossary order and
  orientation for proofs, unique titles. The rules it shares with
  `lint_lessons` live once, in `tool/src/prose_rules.dart`.

- `dart run tool/translations.dart [ar|id|fr|es|zh|ru|ja|hi|tr|it|pt]` — the translation gate for
  `ar/`, `id/`, `fr/`, `es/`, `zh/`, `ru/`, `ja/`, `hi/`, `tr/`, `it/` and `pt/`: the
  same ids, FENs, solutions and answers as English, the same `{{chips}}` per
  field, heading/blockquote/backtick parity, Western digits only, no
  forbidden piece names (الملكة، القلعة، الجندي), and Latin text only where
  notation needs it (squares, SAN, file letters). Write square ranges as
  «من a2 إلى g8», never `a2-g8`. For `id/`: explanations open `## Ide`, the
  agreed piece words (never ratu/bidak/petak/skak), and no English words left
  in prose outside chips and *italic* loan terms. For `fr/`: explanations open
  `## L'idée`, French typography (U+00A0 before `: ; ! ?` and inside « »), the
  agreed piece and tactic names (never reine/évêque/fourche/épingle), and no
  English words left in prose. For `es/`: explanations open `## La idea`,
  every ? and ! paired with its ¿ and ¡, no space before `: ; ? !`, « » never
  straight quotes, the agreed names (never reina/caballero/obispo/tenedor), and
  no English words left in prose. For `zh/`: explanations open `## 思路`,
  Simplified characters only, full-width ，。：；？！「」（） with no space beside
  them, one space between Chinese and Latin text, digits or chips, the agreed
  names (never 皇后/王后/城堡/主教/骑士/卒/将死), and no Latin words outside
  chips, squares, SAN and a short allowlist. For `ru/`: explanations open
  `## Идея`, ё where standard spelling has it (чёрные, ещё), no straight quotes
  and no space before `, : ; ? !`, the agreed names (never королева/офицер/
  лошадь/«шах и мат»/«законный ход» — the FIDE word is «невозможный ход»), no
  word mixing Cyrillic and Latin letters, and no Latin outside chips, squares,
  SAN, Roman numerals and the shared allowlist. For `ja/`: explanations open
  `## 狙い`, ですます調 throughout (常体 is rejected), full-width 、。：；？！「」（）
  with no space beside them, **no** space between Japanese and Latin text,
  digits or chips, 「…d5」 rather than ASCII dots after Japanese, the agreed
  katakana names (never 女王/司教/騎士/塔/歩兵 or a shogi word), and no Latin
  outside chips, squares, SAN and the shared allowlist. For `hi/`: explanations
  open `## विचार`, every sentence ends on a danda «।» (the ASCII period is left
  to notation and numbers), «आप» throughout (तू/तुम are rejected), Western
  digits, no straight quotes and no space before `, : ; ? ! ।`, the agreed names
  word-initially (never रानी/मंत्री/किश्ती/सिपाही/बिशप/नाइट, and never the
  nukta-less वजीर/सफेद/फाइल/खाना), and no Latin outside chips, squares, SAN and
  the shared allowlist. For `tr/`: explanations open `## Fikir`, a suffix on
  notation takes an apostrophe (e4'te, {{Nf3}}'ten — a square glued to a letter
  is an error), the straight `'` and “ ” never `"` or `’`, no space before
  `, . : ; ? !` (the «...d5» ellipsis excepted), the agreed stems (never
  kral/kraliçe/kule/piskopos/şövalye/piyade — *piyade* in italics is
  chaturanga's infantry, and a capitalized bare «Kral» is a real monarch),
  Turkish written with its diacritics (never sah/tas/acik/dort), «siz» as the
  reader (sen/senin/sana are rejected) and no English words left in the prose.
  For `it/`: explanations open `## L'idea`, « » never straight `"`, the straight
  `'` never `’`, no space before `, . : ; ? !` (the «...d5» ellipsis excepted),
  the mandatory accents (perché/più/può/così/già/cioè, and `e'` is an error),
  the agreed words (never regina/vescovo/cavaliere/castello/soldato/pedina) and
  no English words left in prose outside chips and *italic* loan terms.
  For `pt/` (European Portuguese, not Brazilian): explanations open
  `## A Ideia`, « » never straight `"`, the straight `'` never `’`, no space
  before `, . : ; ? !` (the «...d5» ellipsis excepted), the accents that
  Portuguese does not make optional (não/são/já/só/três/peão/tática), the
  agreed stems (never rainha/cavaleiro/castelo/soldado/enroque — *alfil* in
  italics is the historical piece), the Brazilian markers rejected outright
  (você/vocês, pra, fato/contato, registro, and the ô/ê family: econômico,
  fenômeno, gênero), «estar a» + infinitive and never «estar» + gerund —
  `ir` + gerund («vai tirando») is idiomatic in Portugal and deliberately
  allowed, as is «a regra do quadrado» — and no English words left in prose.
  `I18nService.t` still
  falls back per key for UI strings.

The chip rules the style linter enforces mirror `BoardScript.of`
(`lib/features/academy/domain/board_script.dart`). A teach step's chips are
ordered, de-duplicated, then classified into **one** of two modes, never a mix:

- **menu** — 2+ chips, all legal from the step's own position: alternatives,
  drawn as arrows at once on that position ("the squares this piece reaches").
- **sequence** — anything else: chained move by move and animated.

The classifier is total because a real line alternates sides — after White's
`e4`, Black's `d5` is illegal from that same position, so a line can never be
read as a menu. Any chip that is neither is the defect that used to draw a
knight's seven options fanning out of a square the knight had already left.
