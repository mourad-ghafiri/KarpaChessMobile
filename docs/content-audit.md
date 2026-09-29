# Content audit — September 2026

The working ledger of the correctness and consistency pass over the English
lessons and puzzles. Each finding names a file, where in it, what is wrong and
the evidence (an engine evaluation, a gate rule, or a board fact). It is a
working document: keep it or drop it when the pass is committed.

## The protocol every fix follows

1. **Ownership.** A fixer edits only the files assigned to it. Nobody but the
   main session touches `tool/src/lesson_glossary.dart`, `puzzles/index.json`,
   `puzzles/packs.json` (generated — `dart run tool/puzzles.dart packs`),
   `docs/` or `CLAUDE.md`; a fixer reports what those need.
2. **Truth.** Every sentence that asserts something about a board is checked:
   squares, counts, "only move", "forced", "wins", "draws", mate lengths.
   Board facts with dartchess through the repo's own tooling; evaluative
   claims with the Stockfish **19** this repo vendors and the app ships —
   `dart run tool/puzzles.dart check --engine`, one process, depth 20,
   MultiPV 5. Never a separately installed engine and never a search of our
   own: a Homebrew Stockfish 18 read through python-chess used to do this
   job, which meant the gate judged the corpus with a different engine from
   the one the reader plays.
3. **Play beats.** The accepted answers must be sound (within 30 cp of the best
   move, and doing what the prose says the move does) and complete: any move
   within 30 cp that a strong reader following the prompt would play is either
   added to `targetSan` or ruled out by a sharper prompt. When the target mates,
   every mate is accepted automatically (`acceptsAuthored`).
4. **Puzzles.** The first move is the only good one (no rival within 50 cp, or
   the only mate). Every learner move is sound; every scripted defence is the
   best one or the prose never calls it forced; the line ends on the learner's
   move. A proof tests its lesson's idea, is played from the lesson's side, and
   stands on a board used nowhere else in the corpus.
5. **Positions are derived, never typed**: replay moves
   (`dart run tool/puzzles.dart fen …` or python-chess) and read the board back;
   prove mates with `dart run tool/puzzles.dart prove`.
6. **Style.** `docs/LESSON_STYLE.md` — lessons §1–7, puzzles §8.
7. **Gates.** Zero errors for the files touched, run before a fix is called done:
   `dart run tool/lint_lessons.dart <lesson.json…>`,
   `dart run tool/lint_puzzles.dart <id…>`, `dart run tool/content.dart`,
   `dart run tool/puzzles.dart check` (unnarrowed: duplicates are corpus-wide),
   `dart run tool/app_check.dart`.

## Phase 0 — guardrails (done)

- Any checkmate now answers an authored checkmate everywhere
  (`acceptsAuthored`): 13 trainer lines whose final move had a mating twin
  stop rejecting mates.
- A proof's title stays hidden in the academy until the proof is solved.
- `content.dart` checks `en/` only; the stray untracked `lessons/fr`,
  `puzzles/fr` and `puzzles/.dart_tool` directories are flags, not 100 errors.
- New `tool/lint_puzzles.dart` (P01–P08); `puzzles.dart check` now proves
  teaching puzzles too, rejects twins at intermediate plies, and treats a
  puzzle repeating any puzzle or lesson play position as an error;
  `lint_lessons` checks colored claims and play prompts, plus L15.

Baseline after Phase 0: `lint_lessons` 5 errors · `lint_puzzles` 697 errors,
38 flags · `puzzles.dart check` 24 errors · `content.dart` 0 errors.

Tests: the new pure-Dart tests pass (`test/core/chess/san_moves_test.dart`,
the any-mate cases in `puzzle_solver_test.dart`). The academy widget suites
(`concept_player_screen_test.dart`, `sharpen_screen_test.dart`) were already
stale before this pass — they look for `academy.newPattern` and
`academy.ownItProve`, keys that no longer exist in `lib/` or the bundles (the
screens were reworked on Aug 24; the tests were last touched Aug 19), and their
other cases time out. The new proof-title and Sharpen any-mate widget tests live
in those suites and cannot be validated until the suites are repaired.

## Findings

Known before the fix waves, from the read-only audit (python-chess, a Stockfish
screen of every play beat and learner ply, a depth-26 re-check of every hit,
and reading with boards). "L15"/"dup" = a board repeated across surfaces; the
lesson keeps its board unless noted.

### Foundations A — basics-00, 07, 01a–01f
- basics-00 proof first-steps-13: escaping a knight check, before any piece has
  been taught → new coordinate-drill proof (inherits the L04/P02 exemption).
- basics-07 proof first-steps-18: a promotion before the promotion lesson
  (forward refs: promotion, interference, passed pawn) → new notation proof.
- basics-07 step 2 plays basics-00's board (L15) → basics-07 picks another board.
- first-steps-01..06: "Takeaway:" furniture, square chips; first-steps-01 setup
  picks out the capture square.

### Foundations B — basics-05, 02x, 02, 02a, 03, 02b, 04
- basics-02b step 7 claims promoting to a knight beats a queen here — false:
  e8=Q is +2.1, e8=N+ only draws (depth 26). Rebuild steps 6–7 on a position
  where the underpromotion is the only win.
- basics-04 step 6: exf6 is −0.2 while c3 is +1.1 — acceptable only because the
  prompt asks for the en passant capture; the prose must not call it best.
- Proofs first-steps-08/07/11/16/19, mate-in-1-04, tactics-mix-13 (no black
  king): prose to §8; first-steps-19 uses "passed pawn" before its lesson.

### The Story of Chess — history-01..08
- Facts sampled and correct: Opera Game (Paris 1858, 17 moves), Steinitz–
  Zukertort 1886 (+10 −5 =5), Fischer–Spassky game 6 (1972, 41.Qf4), Deep Blue
  1997 (3½–2½, game 6 in 19), Turochamp (1948, hand-played 1952).
- history-08 step 5 narrates the pawn taking at once; step 6 says Kasparov did
  not take at once. Reconcile.
- Proof prose forward refs: history-03 (pin, skewer), history-05 (tempo),
  history-06 (outpost), history-07 (battery).
- history-03 proof: scripted …Kc5 walks into the loss (…Ke4 holds longer);
  history-07 proof: scripted …gxf6 is not forced. Prose must not say "forced".
- history-05's proof board is also culture-08's play step 6 — culture-08 moves.
  (Resolved the other way, per "lessons keep their boards, puzzles move": the
  proof now starts one move earlier; see the history-05 fix entry.)

### The Blade A — tactics-01..06
- tactics-05 step 4: "the same knight move wins that queen — but Black then
  has choices" contradicts itself (it attacks the queen; it does not win it).
- tactics-06's proof forks-06: Qa1+ is stronger than the fork Qd5+ → make the
  first move unique.
- forks-03 (tactics-01 proof) wins the queen into K+N v K, a dead draw — say
  what the fork achieves honestly or add material so it converts.

### The Blade C — tactics-13..17
- tactics-16 step 7: f6 is −3.4 and every move loses (depth 26) — rebuild.
- tactics-15 step 3: Kg6 and Kf7 both mate in 2 — accept both or sharpen.
- Proofs off-concept → new: tactics-13 → tactics-mix-02 (g3 is the only legal
  move; the queen is not trapped; lesson played as Black); tactics-14 →
  tactics-mix-01 (Bxf7+ gives back a piece, cites a knight on g8 that is not
  there, ends on the opponent's move); tactics-16 → tactics-mix-08 (a drawn
  K+P race; the king on e8 is inside the square); tactics-17 → discovered-02
  (one double check in K+R+N v K, many equal wins; "forced to d7 or f7" is
  false). tactics-15's proof tactics-mix-14 uses opposition/passed pawn early.

### The First Moves A — openings-01..09
- openings-01 proof: hint says king and queen are "already one knight-leap
  apart" (e8/e4 — false); scripted …Kxf7 is not forced (…Kd8).
- openings-02 step 3 plays basics-09's board; openings-09 step 7 plays
  history-03's board (L15) → both openings lessons pick other boards.
- openings-04 proof (Elephant Trap) stands on tactics-10's play step 3 → move
  the puzzle to another moment of the trap.
- Proof side flags (P07): openings-05, openings-07, openings-08 — trap lessons
  may show the other side deliberately; decide per case (mirroring is an option).
- openings-03/09 proofs: scripted defences are the trap's blunders by design —
  the prose must present them as the trap, not as forced.

### The First Moves B — openings-10..18
- openings-14 proof: ply 3 …Nc5 hangs a8 (−3.8; Bb7 +1.0) → fix the line.
- openings-12 proof: Nxb4 wins nothing (−1.2, all near-equal) → check claims.
- openings-11 proof ("The Greek Gift") ends only +0.9 → check claims.
- openings-10/13 proofs: scripted defences are poor (traps) → prose honesty.
- openings-18 proof: a4 and Ne5 near-equal → first move unique.

### The Finish A — endgames-01..06
- endgames-02 proof endgames-01: Kc3 and Kc2 both mate in 3 (gate error).
- endgames-01 proof endgame-04: Kd5, Kd4, Kf4 all equal → unique.
- endgames-06 (KPK) proof endgame-01 is endgames-03's play step 6 board and is
  played from the other side → new KPK proof; endgame-01 must leave that board.

### The Plan A — strategy-01..06
- strategy-01 proof setup: "your last undeveloped piece" — the b8 knight is
  undeveloped too.
- strategy-03 step 10: Nc4 drops e4 (−1.8; f3 +0.7). Proof side flag.
- strategy-04 steps 6–7: h4 is −1.9, and Nxh4 −1.7 where Bxh4 is +1.1; its
  proof strategy-04 (h4, −1.6) ignores Nxe5 (+1.6) → rebuild lesson + proof.
- strategy-06 step 3 and proof: Ba3 drops a piece (−4.1 / −3.4) → rebuild.
- strategy-05 proof side flag.

### The Plan B — strategy-07..11
- strategy-10 steps 3/5/7: d5 is up to 0.7 better than each target — the
  prompts must make the maneuver the only move that fits, or accept d5.
- strategy-08 step 3, strategy-11 step 8: near-equal rivals — prompts.

### The Hunt B — attack-05..08
- Proofs off-concept → new: attack-05 → back-rank-10 (back-rank mate, other
  side), attack-06 → back-rank-12 ("Rxd8 must take" — false, …g6),
  attack-07 → back-rank-02 (no f7 in it).
- attack-07 step 7: Bxf7+ and Nxf7 are equal (+1.2); the teach beat says Nxf7
  runs into …Bxf2+ — verify, then accept both or fix the prose.

### The Chess World A — culture-01..04
- culture-01 step 6, culture-02 step 8, culture-04 step 7 are rated trainer
  puzzles (mate-in-one-08/05/06) → each lesson moves to another moment of the
  same game; trainer ids stay.
- culture-02 and culture-03 proofs: a twin forcing the same mate at ply 3
  (Bxg3+/Qxg3+; h4+/f4+) → fix the lines. culture-03 proof side flag.
- culture-04 facts checked: Elo tables (200 → 76%, 400 → 91%), USCF 1960,
  FIDE 1970/July 1971, titles 2300/2400/2500.

### The Chess World B — culture-05..08
- culture-06 step 9 is mate-in-one-10; culture-08 steps 6 and 9 are history-05's
  proof and mate-in-one-12 → culture-06 and culture-08 move to other moments.
  (culture-08 step 6 resolved by moving history-05's proof instead; step 9
  still shares mate-in-one-12's board.)
- culture-07 proof side flag. culture-05 facts checked (27 GMs 1950, WGM ladder,
  Polgár 1991).

### Pools — 79 non-proof teaching puzzles (Sharpen shows no text)
- Broken: first-steps-21 (answer allows Ra1#), discovered-05 (…Re7 holds).
- Boards repeated from lesson play steps: first-steps-09, forks-01, forks-02,
  pins-skewers-01, mate-in-1-02, back-rank-01, tactics-mix-17 → recompose.
- tactics-mix-06 ends on the opponent's move.
- Not unique (Sharpen rejects the equal move): first-steps-09, tactics-mix-04,
  05, 16, pins-skewers-07.
- Prose: "Takeaway:" in nearly every mate-in-1, ~180 square chips, a "her".

### Trainer — 240 rated puzzles
- king-hunt-01/02/03/08: two moves force the same mate at ply 3 (gate error) →
  recompose, keeping ids and the ascending ratings.
- skewer-04/08: a near-equal rival on the collecting move.
- back-rank-09 hint contains Re8#; a "she" in mate-in-one-05; 33 backticked
  moves in rook/pawn-ending explanations; duplicate titles (fork-09 with
  forks-01/07, back-rank-mate-04/decoy-07, discovery-02/smothered-10,
  mate-in-one-06/pin-06, pawn-ending-09/promotion-06,
  remove-guard-05/remove-defender-proof).
- Lines ending at 0.00 (pawn-ending-01..05/12, rook-ending-04/05/09..12,
  deflection-04…): a drawing puzzle may end level; a winning one may not —
  triage each with the engine.

### Engine screen additions (depth 20, every beat and learner ply)
- tactics-06 step 3: Qd4 (+6.5) is ~1.9 worse than Qd8+ (+8.3) — the double
  attack must be the best move, or the prompt must exclude the check.
- tactics-16 step 3: b6 +8.1, Kf2 +9.5 — both win outright; the prose must not
  call b6 the only way.
- pins-skewers-10: the answer Rxd7+ leaves 0.00 while Rd6 keeps +0.8.
- pins-skewers-07: Bxe7 wins, Rxe7+ mates — Sharpen would reject the mate.
- back-rank-02 / back-rank-12: the "sacrifice" is not needed (quiet moves mate
  or win faster) and the scripted recapture is a blunder (…g6/…h6 survive
  longer) — the prose must not call the recapture forced.
- forks-10 (skewer proof): scripted …Kd6 is not the best defence.
- Trainer, lines ending level or worse for the solver — triage each:
  remove-guard-02..07 (remove-guard-06 ends −2.8), trapped-03 (−2.5),
  trapped-04 (−1.1), trapped-05/07/12, decoy-09, deflection-02/04, fork-03.
  A rated tactic that ends lost is broken; one that wins material next move is
  fine but its line should end once the gain is on the board.
- Trainer: pawn-ending-01..05/12, rook-ending-04/05/09..12 end at 0.00 — draw
  puzzles are fine; a puzzle sold as a win is not.
- Trainer: promotion-06 (…axb6) and promotion-11 (…Kh8) scripted defences are
  poor — prose must not call them forced.

## Fix log

### Foundations C — basics-06, 08, 09 (done)
- basics-06: proof → new `draws-proof` (Qa7+ is the only non-losing move; …Kxa7
  stalemates); prose fixes in steps 3, 6, 7 (overstated "finish White off";
  the 75-move/fivefold automatic draws).
- basics-08: the lesson called Nxe5 "the right move" — false (Nxe5 Qg5 leaves
  White worse, −0.6; Nxd4 +1.2). Steps 2–5 rewritten so the story matches the
  engine; proof → new `thinking-process-proof`.
- basics-09: steps 6–7 rebuilt on the Two Knights (4.Ng5 — the threat is real,
  …d5 best by ~1.0); step 2's "g6 is forced" corrected; opening line no longer
  duplicates basics-08's; proof → new `common-mistakes-proof`.
- Pool: first-steps-22 and first-steps-24 rebuilt in place (unique winning
  first moves); mate-in-1-06 prose to §8.

### Audit corrections
- tactics-mix-07: the audit called "the queen must trade" false. It is true —
  every queen retreat lands on a square White attacks, and nothing defends the
  queen. The real defects were the two-ply line (ending on the opponent) and
  the prose; both fixed by the Blade 07–12 fixer.

### The Blade B — tactics-07..12 (done)
- tactics-07: the opening board was broken (the c6 knight was already pinned, so
  Qxd4 won at once and Bxc6+ lost). Rebuilt on a bishop guarded only by the c6
  knight: Bxc6+ +4.7 (next c3 +1.9), then Qxd4 +4.8.
- tactics-08 step 5: "Qxd8 is a queen for a rook" was false (it just wins the
  rook). Rewritten as Qe8+ Rxe8 Rxe8+ Kh7, where the king escapes.
- tactics-09 step 7 accepts a8=R+ too (both mate in 2).
- tactics-12: step 3 prompt asks for the cheapest wall (rules out Re8); step 7
  rebuilt (d6 +6.7, next a4 +5.3; …Nf3 no longer check).
- New proofs: `zwischenzug-proof` (…Nxe2+ Kh1 axb6), `xray-proof`
  (Nxe5 Rxe5 Rxe5), `interference-proof` (Bc6, +6.6 vs +1.8).
- overload-proof moved to a board with a unique first move (Bxa5 Rxa5 Re8#);
  deflection-proof ends Rxc8#; remove-defender-proof prose names the
  …Nxf6 Rd8+ mate; tactics-mix-07, pins-skewers-05, discovered-04 fixed as pool
  puzzles.

### The Plan A — strategy-01..06 (done)
- strategy-01: rebuilt on the Winawer (…b6 and …Ba6 are now the engine's best).
- strategy-03 step 10: Nc4 no longer drops e4 (+0.60 vs best +0.78).
- strategy-04: the unsound h4 plan replaced by Nxg5 / Bxg5 on an Italian
  (+2.3); proof rebuilt (Nxg5 +0.9 vs −0.2).
- strategy-06 step 3: Bf4 (engine best) replaces the piece-dropping Ba3; step 6
  prompt no longer calls g4 a dark square; proof on Reca–Réti 1924 (Bh6).
- Proofs strategy-01..06 rebuilt in place with unique answers and from the
  lesson's side. Tightest: strategy-01 (Ba6 by 51 cp at depth 26). New finding
  fixed on the way: strategy-02's old proof had a rival (Nab1) within 30 cp.

### The Finish B — endgames-07..12 (done)
- endgames-07 Philidor: rebuilt on a c-pawn board where the fence (…Ra6) is the
  only hold (0.00 vs +4.4) — on the old board e6 simply dropped the pawn and
  step 7's "king walks d4, c3, b2" was false. New proof `philidor-proof`;
  endgames-03 recomposed as a pool puzzle (…Re6 the only hold).
- endgames-08 Lucena: "cannot step out / forever" claims were false (Ke7 mates
  in 14 on the old board) — reworded; step 6's animation fixed (…Rxd7 after Ke5).
- endgames-09: knight hop counts corrected; steps 5–7 rebuilt (Nc6 +3.5 vs
  +0.6; the old board was −9 whatever White played); proof endgames-05
  recomposed (Bc6 the only hold).
- endgames-10: "entirely light squares" corrected; prompts no longer claim the
  draw depends on the move; Kg7 accepted; proof endgames-06 recomposed.
- endgames-11: the old cut-off Rd1 was a dead draw — first half rebuilt where Rd1
  is the only win (+4.1 vs +0.05); side named in step 6; proof endgame-05 now Rd1.
- endgames-12: step 3 hint picks Qe4+ (the check covering the e-file); proof
  endgames-07 recomposed (Qf7+ the only win).

### Accepted exceptions
- endgames-04 (Lucena proof): a won Lucena has several winning methods — a
  search of 11,720 c/d/e-pawn boards found none where building the bridge is the
  only win. The proof keeps Rc4, and its setup names the method the lesson
  teaches (not the move), the same "sharper prompt" rule play beats use.
  Limitation: Sharpen shows no text, so there a learner who wins another way is
  marked wrong.

### basics-02b-promotion (done, main session)
- Steps 6–7 (rebuilt by the stopped Foundations B fixer) verified: e8=N+ +8.9,
  next best −7.9; e8=Q loses to …Qc1+ Qe1 Qxe1#. Step 6's hypothetical "a
  knight on e8" reworded (L03).
- Proof first-steps-19 moved to 8/7P/6k1/8/8/8/8/4K3 w: the black king on g6
  takes h7 if White waits, so promotion is the only win (h8=Q mate in 12; h8=R
  wins slowly; the rest draw). Prose rewritten to §8 (no "Takeaway:", no
  "passed pawn" before its lesson).
- Still open from that fixer: `en-passant-proof.json` was created but
  basics-04 still points at first-steps-16 — decide when basics-04 is done.

### attack-03-greek-gift (done, main session)
- Rebuilt on the French Classical (1.e4 e6 2.d4 d5 3.Nc3 Nf6 4.Bg5 Be7 5.e5
  Nfd7 6.Bxe7 Qxe7 7.f4 O-O 8.Nf3 c5 9.Bd3 Nc6): Bxh7+ +2.1 vs +0.8; after
  …Kxh7 (…Kh8 is equal — not called forced) Ng5+ is unique (+2.1 vs −1.0).
  King retreats: …Kg8 Qh5 (+3.7, unique), …Kh8 Qh5+ mate in 2, …Kg6 Qg4 (+2.3;
  the old h4 is −1.1 here), …Kh6 Qd3 (+8.0, threatening Qh7#); …Qxg5 fxg5.
  Step 2's "nothing can take on g5" now "whatever takes on g5 is taken back".
- New proof `greek-gift-proof` (Rubinstein, 1903): Bxh7+ +3.5 vs +1.4; …Kxh7
  is illegal (the queen on c2 sees h7). mate-in-2-02 stays in its pool.
- Engine budget: ~30 s at Threads 2.

### attack-04-rook-lift (done, main session)
- Lesson already clean (fixed by the stopped Hunt fixer). Proof re-pointed from
  back-rank-05 (a back-rank mate in 1, no lift) to new `rook-lift-proof`:
  Chigorin–Lebedev 1901 after 19.Rf3 Be6 — 20.Rg3+ +6.0 vs Be7 +3.3; Black's
  only replies …Kh8 / …Bg4. Its "ends level without mate" flag is expected
  (a positional one-ply win). back-rank-05 stays in its pool.

### attack-05-pawn-storm (done, main session)
- Step 3 fine: only …f5 attacks e4, so the equal rivals (…a5, …b6) do not fit
  the prompt. Step 4's chip line alternates correctly.
- Proof re-pointed from back-rank-10 (a back-rank mate, White to move in a
  Black lesson) to new `pawn-storm-proof`: Bogoljubow–Botvinnik, Nottingham
  1936, 15…g4 (+2.1 vs +1.3); the prose follows the game (16.Ne1 Nxe5 …, 0-1).
  back-rank-10 stays in its pool, prose rewritten to §8 (no "luft"/"Takeaway").
- Accepted exception (positional): step 7 keeps …d5 (+0.63) although …Ne7 /
  …Ba7 score +1.03 at 3 s — …d5 is the only move that opens the center as the
  prompt asks, and it is objectively good. Beyond the 30 cp rule by ~10 cp.

### Protocol note — plan-naming play beats (rule 3, clarified)
A play beat whose prompt names a plan (a pawn storm, a central break) accepts
the best move that carries out that plan, provided it is objectively sound for
the mover. A stronger move outside the plan — usually prophylaxis the prompt
rules out — is recorded here instead of accepted. This replaces the attack-05
"exception" above with a rule. Cases:
- attack-05 step 7: …d5 +0.63 (the only move that opens the center) vs …Ne7 /
  …Ba7 +1.03.
- attack-06 step 3: h4 +0.45 (g4 −0.82, so h4 is the only sound storm move) vs
  Kb1 +1.07.

### attack-06-attacking-the-fianchetto (done, main session)
- Lesson clean; step 3 falls under the plan-naming rule above.
- Proof re-pointed from back-rank-12 (a back-rank deflection) to new
  `fianchetto-proof`: Karpov–Korchnoi, Moscow 1974, 17.Bh6 (+1.06 vs Kb1 +0.16);
  prose follows the game (…Bxh6 Qxh6 … 27.Qh8+ 1-0).
- back-rank-12 stays in its pool; prose fixed ("Rxd8 must take" was false —
  declining with a luft move is better, after which Qxf8+ wins a rook).
  STILL OPEN for the back-rank pool pass: its first move is not unique (quiet
  moves also mate), so Sharpen could reject an equally winning move — recompose.

### attack-07-sacrifice-on-f7 (done, main session)
- Step 1: "the bishop on f8 is boxed in behind its own pawn" was false (it has
  five moves) → "neither has the bishop on f8" (never moved).
- Step 6: called Nxf7 "the wrong one" / "the bait" — false: Nxf7 (+1.16) and
  Bxf7+ (+1.15) are equal. Rewritten: Nxf7 is playable, just the fight Black
  chose; title "Two Ways In". Step 7's prompt ("end Black's castling for good")
  already singles out Bxf7+. Checked: after Qf3+ (step 4) the king has exactly
  five squares; after Bxf7+ (step 5) only …Kf8/…Ke7; after …Bxf2+ (step 6)
  three king moves.
- Proof re-pointed from back-rank-02 (no f7 in it) to new `f7-sacrifice-proof`:
  Tal–Tringov, Amsterdam 1964, 15.Bxf7+ (mate in 7 vs Rxb7 +0.60); prose follows
  the game (…Kxf7 Ng5+ Ke8 Qe6+ 1-0).
- back-rank-02 stays in its pool, prose fixed (no "Takeaway", ≤90 words).
  STILL OPEN for the back-rank pool pass: not unique (h3 etc. also win) and the
  scripted …Rxe8 is not Black's best — recompose.

### attack-08-mating-nets (done, main session, no engine)
- Lesson verified claim by claim against its boards (king squares, the
  unblockable knight check on d6, the e7 pin after Qe2, the pinned e2 bishop
  that cannot take on f3); both engine screens had no hits. No changes.
- Proof mate-in-2-03 is on-concept (a quiet king move takes the last squares,
  then mate) and proven unique by `puzzles.dart check`; prose rewritten to §8
  (≤90 words, no "Takeaway").

### attack-01/02 proofs (verified, main session)
- uncastled-king-proof (Bb5+ Qxb5 Qd8#): forced mate in 3 proven by
  `puzzles.dart check`; prose claims checked on the board (Bg5 covers e7/d8;
  …Bd7 Bxd7# because the d1 queen guards d7 once d3 is vacated).
- opposite-castles-proof (e5 Bxd5 exf6): e5 +4.11 vs +0.25; …Bxd5 is Black's
  best (−4.59); exf6 +4.73 vs −3.14. Prose claims match the board.
- Not yet re-screened: the attack-01/02 LESSON play beats, which the stopped
  fixer edited after the engine screen ran (both lint clean).

### attack-01 / attack-02 lessons (re-screened, main session)
- Engine (1.5 s, Threads 2): attack-01 step 3 Nxe5 +1.9 (best), step 8 Nc6+
  +5.0 (best); attack-02 step 3 g4 +0.38 (h4 +0.34 cannot chase the f6 knight,
  so the prompt excludes it), step 7 …b3 −0.39 best (…exd4 is not the a-file
  sacrifice the prompt asks for). All board claims read against the boards.
- attack-01 step 8 prompt sharpened: "attacks Black's queen" also fit Nxf7+,
  which loses the knight to …Kxf7; now "land where it wins Black's queen" —
  after Nc6+ every legal reply (…Be7, …Qe7, …Ne4) drops the queen.

### basics-04-en-passant (done, main session, no engine)
- Lesson verified against its boards (e5 covers d6; only the f-pawn's double
  step is capturable; …gxf6 an ordinary recapture; step 8 …cxd3 legal e.p.).
  Step 6 (exf6, −0.2 vs +1.1) is a rules drill and the prose never calls it
  best — fine.
- Proof re-pointed from first-steps-16 (a plain capture of a checking knight,
  not en passant) to `en-passant-proof` (written by the stopped Foundations B
  fixer): exd6 e.p. opens the c3–h8 diagonal for mate. Setup corrected — the
  rook guards the g-file beside the king, it does not aim at h8.
- first-steps-16 stays in the first-steps pool; prose rewritten to §8 (no
  highlighted landing square, no "Takeaway", ≤90 words).

### basics-05-piece-values (done, main session, no engine)
- Lesson verified against its boards: the even pawn trade (step 2), the count
  in step 4 (queen, rook, three pawns each plus White's knight), the queens
  facing on the d-file with the d8 rook watching d5, and step 8's counting
  (…Nxd7 free +1; Nxc6 costs the knight to …dxc6 but nets +2). Neither engine
  screen flagged a beat. No changes.
- Proof first-steps-08: chess sound (Qxa7? Rxa7; Qxg7 free — b7 blocks the
  a7 rook, nothing else covers g7; no rival within 30 cp in the deep screen).
  Prose: added "## The Idea", squares written bare.

### basics-02x-captures (done, main session, no engine)
- Lesson verified against its boards (rook on d6 hanging, bishop on f6 guarded
  by g7; the f6 bishop does not see d6; the queen's two clear diagonals with
  Qxa7? Rxa7 and g7 unguarded; b6 guards c5 so Nxc5 nets six). No changes.
- Proof first-steps-07: sound (c7 defends d6, nothing defends f6); the same
  question with the roles reversed, on a different board. Prose: "Takeaway:"
  removed, square written bare in the setup.

### basics-02-check-and-mate (done, main session, no engine)
- Lesson verified earlier against its boards (all check and mate claims hold);
  lint clean. No changes.
- Proof mate-in-1-04 (Rd8#): on-concept back-rank mate; prose rewritten to §8
  (no square chips, no "Takeaway", ≤90 words).
- Pool mate-in-1-02 stood on the lesson's step-8 board → moved to
  7k/6pp/8/8/8/8/5PPP/1R4K1 w (Rb8#; `puzzles.dart prove`: forced mate in 1,
  one first move; board used nowhere else). Prose rewritten to §8.

### basics-02a-escaping-check (done, main session, no engine)
- Lesson verified beat by beat against python-chess legal-move lists (four
  king moves off the e-file; the knight's two blocking squares; only e3 among
  the six squares between e8 and e1 for the d2 bishop; the knight check leaving
  walk-or-take; gxf3 illegal because the g8 rook pins the pawn). No changes.
- Proof first-steps-11: Kf1 is the only legal move and every excluded square is
  covered as stated. Prose rewritten to §8 (≤90 words, no "Takeaway", squares
  written bare).

### basics-03-castling (done, main session, no engine)
- Lesson verified against its boards and python-chess legal moves (king/rook
  squares for both castles; two vs three squares to clear; the six conditions;
  the rook may cross an attacked b8 while c8/d8 must be safe; four and three
  empty squares between the rooks after castling). No changes.
- Proof tactics-mix-13 (O-O-O, no black king — a supported drill shape): the
  setup now asks for the castle outright (the lesson is L04/P02-exempt, so its
  proof is too); hint no longer uses "develops" (taught in lesson 44);
  explanation cut from 194 words / four headings to §8.

### basics-00-board-and-setup (done, main session, no engine)
- Lesson verified against its boards (a2 reaches a3/a4; h1 and a8 light; d1
  light, d8 dark, d2–d4 alternating; the back-rank setup; step 6's "pawn in
  front of the queen, two squares" is d4 only). No changes.
- Proof re-pointed from first-steps-13 (escaping a knight check — before any
  piece has been taught) to new `board-proof`: a coordinate drill using only
  what this lesson teaches ("move a pawn to the square named c4"; only the c2
  pawn reaches it). The lesson is L04-exempt, so its proof names the square.
- Known limitation of drill proofs (board-proof, tactics-mix-13): Sharpen shows
  no text, so there the drill cannot say what it asks.
- first-steps-13 stays in the first-steps pool (Kd2 is its only legal move);
  prose rewritten to §8.

### basics-07-notation (done, main session)
- Lesson verified against its boards (e2 reaches e3/e4; the f1 bishop's example
  squares; "twenty-three characters" counts correctly with spaces). Step 2
  played the starting position, already basics-00's play board (L15) → moved to
  the position after 1.e4 g6 with the entry `2.d4`.
- Proof re-pointed from first-steps-18 (a promotion, twelve lessons early) to
  new `notation-proof`: a printed entry to play (`3.Bc4` after 1.e4 e5 2.Nf3 d6;
  only the f1 bishop reaches c4). Tool: `lint_puzzles` now lets the proof of a
  backtick-allowed lesson (basics-07, culture-03) print moves as type, as its
  P02 exemption already did; LESSON_STYLE §8 P06 says so.
- Pool tactics-mix-17 stood on step 7's board (and its "mirror" move was not
  unique) → rebuilt as a knight fork: 4r1k1/5p1p/8/3N4/8/8/5PPP/6K1 w, Nf6+
  (+5.4 vs +0.0).
- first-steps-18 stays in the first-steps pool (prose fix pending in the pool
  pass).

### basics-01a-pawn (done, main session, no engine)
- Lesson verified against python-chess legal moves (e2→e3/e4; the e4 pawn
  attacks d5 and f5; step 7's exf5 is the pawn's only legal move). No changes.
- Proof first-steps-01 (exd5, the only capture, wins an unguarded knight):
  prose rewritten to §8 — the setup states the goal instead of bolding the
  capture square (P02), no "material" (taught in lesson 9) or point values
  before the piece-values lesson, no "Takeaway".

### basics-01b-knight (done, main session, no engine)
- Lesson verified against python-chess (Nf6 from e4 is two up, one right; all
  eight e4 jumps legal, two from a1; e4 light and all eight targets dark; in
  step 6 the d5 pawn attacks c4, d6 is unguarded, e5 is guarded by d6). No
  changes.
- Proof first-steps-02 (Nxe5, the only capture, an unguarded bishop): prose to
  §8 — no "Takeaway", square written bare, and no "a beginner's eye" (the
  style guide rules out talking down to the reader).

### basics-01c-bishop (done, main session, no engine)
- Lesson verified against python-chess (13 legal bishop moves from d4, the four
  corner/edge chips, the b2 pawn stopping the bishop at c3, d2 and g5 both
  dark). Step 3 said "every other move available here" lands on a dark square —
  false for the king moves on that board → "every other bishop move".
- Proof first-steps-03 (Bxf7, an unguarded rook): prose to §8 — no "the
  exchange" (taught in lesson 9) or point values before the piece-values
  lesson, no "Takeaway"; the setup no longer says the rook is "at the end of"
  the diagonal (g8 lies beyond it).

### basics-01d-rook (done, main session, no engine)
- Lesson verified against python-chess (14 rook moves from d4 — 7 on the file,
  7 on the rank — and 14 from a corner; six on the a1 board, stopped at a3 by
  the a4 pawn and at d1 by the own king; the d-file the only pawnless file in
  step 7). No changes.
- Proof first-steps-04 (Rxd7, nothing recaptures): prose to §8 — no
  "Takeaway", square written bare, and no "nine-point" / "most valuable" value
  claims before the queen (lesson 7) and piece-values (lesson 9) lessons.

### basics-01e-queen (done, main session, no engine)
- Lesson verified against python-chess (27 queen moves from d4 = 14 as a rook
  + 13 as a bishop; step 3's accepted answers are exactly those 27; step 6's
  d-file clear to an unguarded d5). No changes.
- Proof first-steps-05 (Qxh5 along d1–h5, the rook unguarded): prose to §8 —
  the setup no longer bolds the landing square h5 (P02), no "Takeaway", no
  point values before the piece-values lesson.

### basics-01f-king (done, main session, no engine)
- Lesson verified against python-chess (eight king moves from e4; the h5 rook
  removes exactly d5/e5/f5, leaving the five named; with kings on d4 and d6 the
  white king has five moves and none forward; the e3 pawn covers d2/f2 and
  Kxe3 is legal and unguarded). No changes.
- Proof first-steps-06 (Kxd4, the pawn unguarded; it attacks only c3/e3):
  prose to §8 — the setup no longer bolds the landing square (P02), no
  "Takeaway", ≤90 words.
- Foundations A piece lessons (01a–01f) complete.

### history-01-born-in-india (done, main session, no engine)
- Facts checked: chaturanga, northern India around the 6th century, "four-
  limbed" after the army's four arms; the counselor became the queen; the
  alfil's two-square diagonal jump reaching only eight squares.
- Board claims checked with python-chess (the e-file bare but for Black's
  knight and king; Re1 pins it and only the f1 rook reaches e1; …Ne7 blocks
  and Rxe4 still wins the unguarded knight; Ne7+ is the only check that also
  hits c8). No changes.
- Proof history-01: sound (…Kg8 the only reply to Nf7+). Prose to §8 ("## The
  Idea", ≤90 words); the hint's "the rook cannot reach it" was misleading (the
  d8 rook can reach g8) — reworded without naming the landing square.

### history-02-shatranj (done, main session, no engine)
- Facts checked: chaturanga → chatrang → shatranj (no ch in Arabic); ferz and
  alfil moves; bare king and stalemate both wins in shatranj; the rook the
  strongest piece for centuries; al-Adli around 840, as-Suli a century later;
  mansubat; the Arabian mate.
- Board claims checked (Nf6 the only knight square covering h7 and g8; after it
  only pawn moves; Rd8+ lets the king out to g7; Rh7# with the knight guarding
  h7). No changes.
- Proof history-02: mate proven by `puzzles.dart check` (Rc7 unique). The prose
  said the king "already has no legal square" thanks to the knight — it is the
  rook on c7 that takes g7 away. Rewritten to §8 (one heading, ≤90 words, no
  "Takeaway").

### history-03-chess-reaches-europe (done, main session, no engine)
- Facts checked: the al-Andalus, Sicily and Byzantium (*zatrikion*) roads; the
  Catalan will of around 1008 leaving chessmen to a monastery; ferz → queen;
  alfiere / fou / runner; the English *aufin* (alfin, alphyn) still in 1474;
  "bishop" winning in the 1500s; the Lewis chessmen's mitres (c. 1150–1200);
  queen and bishop rebuilt in Iberia in the 1470s (history-04, the next lesson).
- Board claims checked with python-chess (…Bc8 has only b7 and a6; an alfil
  from c8 reaches none of a8–h1; Bc1 sees d2–h6 and an alfil only e3 and g5;
  knight f6, e7 empty, queen d8; the f1 bishop blocked by e2). No changes.
- Proof history-03: mirrored to Black to move (the lesson is played as Black;
  P07 flag cleared). New board `6k1/5ppp/b7/3K4/8/8/P7/7R b`, line …Bb7+ Kc4
  …Bxh1: the bishop lands on b7, the square the lesson's play beat teaches, and
  runs the long light diagonal. Board unused anywhere else. Prose to §8: no
  pin/skewer (forward refs), no "Takeaway", no "forced" (5 legal replies, an
  expected flag); "Europe inherited" dropped, since the lesson says the long
  move only came in the 1470s.

### history-04-the-mad-queen (done, main session, no engine)
- Facts checked: *Scachs d'amor* (Valencian, undated, around 1475, earliest
  surviving game under the new rules); *axedrez de la dama*, *alla rabiosa*,
  *la dame enragée*; the bishop's slide in the same reform; Isabella of Castile
  given as a suggestion, not a record; the rook's nine centuries on top.
- Board claims checked with python-chess (d1, c2, e2 all light; d1→h5 in four
  ferz steps, one queen move; Qd5+ hits g8 and a8 on two diagonals; from d5 the
  d-file and fifth rank are bare; after h3 …Rc8 is legal; Qxa8+ checks down the
  eighth rank). Qd8+ also hits king and rook, but on the rank, from the edge,
  and …Rxd8 takes it, so the prompt's "into the middle… one diagonal… another"
  keeps Qd5+ the only answer. No changes.
- Proof history-04: sound (Qd4+ the only first move that wins the rook against
  every reply; 5 legal replies incl. …f6, all lose it — expected flag). Prose
  to §8: "## The Idea", 143 → ~80 words; "forced" never claimed.

### history-05-the-romantics (done, main session, no engine)
- Facts checked: the Opera Game (Paris 1858, Morphy 21, the Duke of Brunswick
  and Count Isouard consulting, 17 moves, the opera disputed); the score
  replayed to every lesson FEN.
- Board claims checked with python-chess (one white rook to two, White three
  points down; Bf8 has no move; d7 attacked by Bb5, defended by K, Q, N; the
  d-file the only clear file from the first rank; Qe6 guards d7 and faces b3;
  after Qb8+ …Nxb8 is Black's only legal move; the d-file bare after it; Bg5
  covers e7 and d8). No changes.
- Proof history-05: its board was culture-08's play step 6. The puzzle moved
  (lessons keep their boards): it now starts at move 21 of the same game,
  Nxg7+ Kd8 Qf6+ Nxf6 Be7#. Prover: forced mate in 3, Nxg7+ the only first
  move, …Kd8 the only reply, Qf6+ the only mate in 2 after it. The old prose
  claimed "c8 and e8 are covered by the pieces standing there" (c8 is Black's
  own bishop), and used "tempo" (openings-01) and "Takeaway". Rewritten to §8.

### history-06-steinitz (done, main session, one 2 s Stockfish burst)
- Facts: Steinitz–Zukertort 1886 (+10 −5 =5, sampled correct in Phase 1);
  Steinitz–Sellman, Baltimore 1885 as the setting. The game score itself was
  not re-sourced; the knight's walk d1–c3–b1–d2–b3 is consistent between beats.
- Board claims checked with python-chess (…Bc5's diagonal to f2 clear; b4
  guarded by Bd2 and only …Bxb4 hits it; b4 Be7 a3 legal; every black pawn past
  the seventh rank; c6 guarded by Bb7 and Rc8 only; Nc5 and Na5 the only knight
  moves hitting b7, c5 taken by Nd7/Be7/Rc8, a5 only by the queen and guarded by
  b4). One false line fixed: step 4 said "no piece was threatened", but b4
  threatens the c5 bishop — now "Nothing changed hands".
- Proof history-06 (engine, 2 s MultiPV): Qc8 +4.5, Nac6 +4.3, Bf2 +3.1,
  Ndc6 +2.9. Nac6 is the plan move and beats the other knight by ~140 cp, as the
  prose says; Qc8 is an off-plan equal, so the setup now names the plan ("cash in
  the hole"). Scripted …Qb7 is Black's best reply. Prose to §8: 175 → ~75
  words, "outpost" (strategy-02) removed, and the vague "every trade lands on
  White's terms" replaced with the checkable "Black's only dark-squared bishop
  is gone".

### history-07-the-champions (done, main session, no engine)
- Facts checked: Reykjavík 1972 (late arrival, the cameras, game 1 lost, game 2
  forfeited); the title Soviet since 1948; game 6 with White, ending 41.Qf4;
  Fischer the eleventh champion; Lasker's 27 years; the hypermoderns; 24
  Soviet years; the four breaks (1946–48, 1975, 1993–2006, 2023) and Gukesh
  in December 2024 at eighteen.
- Board claims checked with python-chess (the score replays exactly to steps
  6 and 7; only …gxf6 recaptures; nothing black reaches f6 after the second
  Rxf6; Bc4 guards e6; h6 undefended; Qf4 the only queen move that adds to the
  attack on h6 — …Qxg6 takes Qg6). Two fixes: the step 4 hint gave the king
  "two pawns beside it" (only g7 touches h8); step 6 called the second Rxf6
  "the same price" (it takes a pawn for free).
- Proof history-07: mate verified (the queen covers g7 and h8, f7 and f8 are
  Black's own, Bb1 guards h7). The old prose said "g8 and g7 are covered by the
  queen" (g8 is where the king stands; the squares are g7 and h8), and used
  "battery" (openings-03) and "Takeaway". Rewritten to §8; …gxf6 is not called
  forced (18 legal replies — expected flag).

### history-08-machines (done, main session, no engine)
- Facts checked: Turochamp (Turing and Champernowne around 1948; hand-played
  against Glennie in 1952, lost; first run on a computer long after); Deep Blue
  1996 (Kasparov 4–2) and New York, May 1997 (3½–2½); game 6 replayed in full
  with python-chess from 1.e4 c6 to 19.c4 (8.Nxe6 Qe7 9.O-O fxe6 10.Bg6+ Kd8,
  resigned on move 19); 200 million positions a second; AlphaZero 2017;
  Stockfish NNUE from shogi since 2020; seven-piece tables.
- Board claims checked (the step 1 board is the game after 7…h6; f7 the only
  defender of e6; after …fxe6 Bg6+ only …Ke7; O-O the only move of two pieces).
  Fixes: step 5 narrated the immediate capture as history while step 6 said
  Kasparov did not take at once — step 5 now opens "Take the knight at once and
  this is where it ends". The step 4 prompt ("offer the pawn a capture that
  pulls it off the square") was also met by Bg6, which the step before calls a
  lost bishop; now "…and keep the bishop that will check behind it".
- Proof history-08: the old prose said the h2 bishop "has two squares in the
  whole world: g1 and g3" — it has seven (b8–g3 and g1); g3 is what cuts it to
  …Bxg3 and …Bg1. After …Bxg3 fxg3 White is a knight up for a pawn (17 v 15).
  Hint reworded to match; prose to §8 (183 → ~80 words, no "Takeaway").
- **The Story of Chess (history-01..08) is complete.**

### tactics-13-trapping (verified, main session, no engine)
- Board claims checked with python-chess (Bb3 has only Ba4 and Bc4, both
  covered by b5; c4 the only pawn move onto either; after Bb1 the rook's only
  moves are Ra1, Rxa3, Rxb2, all covered). Three fixes: step 1 called b3's
  a2–g8 line "the long diagonal"; step 3 said Bxc4 bxc4 hands over "a bishop
  for a pawn" — Qxc4 then takes a second (now "for two pawns at best"); step 4
  said every exit "costs a rook for a pawn", but …Ra1+ Nxa1 gets nothing.
- Proof trapping-proof (agent-made): sound. After …b6 the a7 bishop has only
  Bb8 (the king on c8 covers it) and Bxb6 (c7 covers it); …Kb8 is illegal and
  …Kb7 lets it out via b6–e3. Lesson and proof both Black. "Ends level (0p)" is
  the expected flag for a trapped piece that falls next move.

### tactics-14-demolition (verified, main session, no engine — no changes)
- Lasker–Bauer, Amsterdam 1889 replayed with python-chess from 1.f4 to 16…Kg8
  (step 1's board) and 17.Bxg7 Kxg7 (step 4's). Claims checked: g7 the only
  piece between Be5 and h8; Bxg7 the only capture of g7; Rf3 legal; "two
  bishops for two pawns". Of the eight checks on move 18, only Qg4+ and Qe5+
  cannot be taken, and Qe5+ is blocked for free by …f6 or …Bf6, so "force the
  king to move" singles out Qg4+ (its one block, …Bg5, drops the bishop to fxg5).
- Proof demolition-proof (agent-made): Rxh7+ leaves …Kxh7 the only legal
  reply; Qh5# with g8, g6, g7 Black's own and h6 covered by Be3 and the queen.

### tactics-15-quiet-move (verified, main session, one 2 s Stockfish burst)
- Board claims checked with python-chess (Ra8+ leaves only …Kh7; Kg6 leaves
  only …Kg8, then Ra8#; the g-file bare but for g7; Bxg7 is not check and Rg1
  guards g7; Qh6 the only queen move onto f6 or h6; after Qh6 all 31 black
  replies allow mate in one). Engine: Qh6 #2, Qg5 #3, Rxg7+ #3 — "both win"
  and "Black is already lost" hold.
- One false line fixed: step 5 said moving the pinned g7 pawn is illegal, but
  …g6 stays on the pin line and is legal (the engine's own mate line is Qh6 g6
  Qg7#). It now says the pawn cannot *capture*, which is what matters for f6/h6.
- Step 3: Kf7 also mates in two (…Kh7 Rh1#) but does not take h7 away, so the
  prompt ("take h7 away") already excludes it — no change.
- Flag triaged, intended: step 6's Rxg7+ and Bxg7 are drawn as a menu from g1
  and b2 — the text offers them as the two loud alternatives, not a line.
- Proof quiet-move-proof (agent-made): all 21 replies to Qf5 are mated next move
  on the h-file; Qd3 fails to …Rxd3/…f5 and Qh3 to …Rxh3/…Rf8, so Qf5 is the
  one quiet move (the prover agrees). The only checks at the start, Rxh7+ and
  Bxg7+, are answered by captures, as the setup says.

### tactics-16-pawn-breakthrough (verified, main session, one Stockfish burst)
- Board claims checked with python-chess (every pawn push on either side is
  capturable; only b6 has two captures; after c6 Black's pawn replies bxc6,
  bxa5, b5 all lose; a6 c5 a7 c4 a8=Q leaves Black's c-pawn on the fourth rank;
  g7 the first piece on the b2 diagonal; gxf6 the only capture of f6; Qg5# the
  only mate at step 9). Engine, 2 s each: the rebuilt step 7 f6 is +4.0 (next
  best +2.2); after Bxf6 White mates in 5, so "Black is already lost" holds.
  Steps 1–2 already say the king walk also wins, as the Phase 1 note required.
- One fix: step 8 put the f6 bishop "one step from the black king" — f6 is two
  squares from g8; now "from f6 the bishop covers both empty squares beside the
  black king, g7 and h8".
- Proof pawn-breakthrough-proof (agent-made): g6 +4.7 is the only winning move
  (f6, Ka2, Kb1 are about −10), so the setup's "exactly one move that wins"
  holds. The prose called …fxg6 "the toughest answer", but …hxg6 is equal
  (+5.4 v +5.5); now "Say Black takes with …fxg6". Flags triaged, expected: 12
  legal replies (a breakthrough, not a forced line) and "−1p without mate" (the
  line stops on the second offer; a pawn queens two moves later).

### tactics-17-windmill (verified, main session, one Stockfish burst)
- Torre–Lasker, Moscow 1925 replayed with python-chess from 1.d4 to 24…Qb5
  (step 1) and on through 32.Rxh5; steps 3, 4 and 6 match the game. Claims
  checked: g7 guarded by the king alone; Bf6 opens b5–h5 for …Qxh5; …Kh8 the
  only reply to Rxg7+, …Kg8 to Rxf7+, …Kh8 to Rg7+; Rxb7+ the only rook capture
  on the seventh rank (engine: Rf7+ +4.5 and Rxb7+ +4.4, the prompt names the
  capture). Fix: step 3 had the f6 bishop "beside the black king" (two squares
  from g8), now "on f6, right against the king's shelter".
- Proof windmill-proof (agent-made; its check was pending when the agent was
  stopped): Rxd7+ +4.8 is the only winning move (Re7+/Rf7+ −4.9 to …Nxf6). The
  setup's test ("cannot answer by taking your bishop") also admitted the double
  checks Rg8+ and Rxh7+, which lose the rook to the king; now "cannot answer
  with a capture", and the prose says why the double checks fail. After …Kg8,
  Rg7+ would allow …Qxg7; Rxb7 is safe.
- **The Blade C (tactics-13..17) is verified.**

### culture-01-etiquette (done, main session, no engine)
- Board move (one board, one place): step 6 played Nd5# on the board of rated
  trainer puzzle mate-in-one-08. Steps 4–6 now stand one move earlier in the
  same Légal line (replayed from 1.e4: after 5…Bxd1), and the learner plays
  Bxf7+. Prover: forced mate in 2, Bxf7+ the only first move; …Ke7 the only
  reply; the board is used nowhere else. This also fixed a false line: step 4
  said Black's bishop took the queen "last move", but on the old board Black's
  last move was …Ke7. Step 5 now says the pieces are "pointed at f7", and the
  prompt asks for "the check that forces mate next move". (A closing teach beat
  showing Nd5# was tried and removed: a lesson must end on a play beat.)
- Claims checked: in step 1 White is in check from Bb4 with exactly Kf1 and
  Ke2 as king moves; c3 and d2 the only blocks, Nc3 the only knight block
  covering d5 and b5; FIDE touch-move, *j'adoube* only on your own turn, the
  draw-offer order and its "cannot be withdrawn" wording, resignation by
  declaration.
- Proof culture-01: mate verified (after Qxh5+ both …Rg6 and …Rxh5 allow
  mate at once; Bg6+ first meets …Rxg6). The prose said Bg6 "lands on the
  square the rook has just left" (the rook left h6, not g6) and gave the g5 pawn
  a role it does not have; the hint's "light squares beside the black king" was
  loose. Rewritten to §8 (131 → ~75 words, no second heading, no backticks).
- puzzles check: 18 → 17 errors.

### culture-02-the-clock (done, main session, one Stockfish burst)
- The board is the Englund Gambit trap, replayed from 1.d4 e5 2.dxe5 Nc6 3.Nf3
  Qe7 4.Bf4 Qb4+ 5.Bd2 Qxb2 6.Bc3 (step 1 matches). Castling fields corrected
  from `KQk` to `KQkq` on every board: nothing in the line moves Black's king or
  a8 rook.
- Board move (one board, one place): step 8 played …Qc1# on trainer puzzle
  mate-in-one-05's board (after 8.Qxc3). Steps 5–8 now stand one move earlier,
  after 7.Qd2 (unused anywhere), and the learner plays …Bxc3. Engine (2 s):
  …Bxc3 −5.0, …Qxa1 −2.0, the rest lose; after …Bxc3, 8.Nxc3 Qxa1+ is White's
  best and 8.Qxc3?? runs into …Qc1#, which the hint now points at. Step 4 stops
  at Qd2 (it used to animate …Bxc3 Qxc3, the new answer). In step 7, "Qxc3+"
  became "Qxc3", since it is not check on this board. The prompt excludes the
  rook grab and the queen trade that step 7 names.
- Facts checked: one-hand rule, move complete on release, increment vs delay,
  FIDE's base + 60 × increment classes (blitz ≤ 10, rapid < 60, standard ≥ 60),
  "bullet" absent from the Laws, flag-fall draw when the opponent cannot mate.
- Proof culture-02 (From's Gambit, replayed: 1.f4 e5 2.fxe5 d6 3.exd6 Bxd6
  4.Nc3): the ledger's twin is real — after …Qh4+ g3 both …Bxg3+ and …Qxg3+
  mate in two, so a 3-ply line rejected the famous …Qxg3+. Now a single move,
  …Qh4+ (the prover says it is the only first move, forced mate in 3), and the
  explanation gives both finishes. Its "the rook on h1 is boxed in" was false
  (hxg3 opens the h-file onto the queen) and is gone. Flag "0p without mate" is
  expected: the mate lands two moves after the line stops.
- puzzles check: 17 → 16 errors.

### culture-03-recording-games (done, main session, one Stockfish burst)
- Lesson verified, no changes. The Lasker Trap in the Albin Countergambit
  replayed from 1.d4 d5 2.c4 e5 3.dxe5 d4 4.e3 Bb4+ 5.Bd2 dxe3 6.Bxb4 (step 1
  matches); …exf2+ is the only capture from e3; the replies are Kxf2 and Ke2
  (Kxf2 loses the queen); four promotions on g1, and only …fxg1=N+ checks;
  after …fxg1=Q Qxd8+ the only reply is …Kxd8. FIDE 8.1 (both sides' moves, in
  algebraic; reply before recording, but record before the next move; never in
  advance except a draw claim) and 8.4 (under five minutes with no increment
  of 30 s or more) checked.
- Proof culture-03 (Edward Lasker–Thomas, London 1912, after 12…Kh6): engine
  Neg4+ #6, Nfg4+ +2.3; after Neg4+ …Kg5 is the only reply, after Nfg4+ the
  king also has …Kh5. The ledger's twin at ply 3 (h4+/f4+) came from the 3-ply
  line ending on a non-mating check; the question is "which knight", so the
  proof is now that one move. The board was mirrored to Black to move (the
  lesson is played as Black; P07 flag cleared): `…/1P2Pn1K/…`, key …Neg5+,
  unused anywhere else, every mirrored claim rechecked. Prose to §8 (119 → ~80
  words; the backticked alternative became a chip). Flag "0p without mate" is
  expected for a single-move proof.

### culture-04-ratings (done, main session, one Stockfish burst)
- The board is the Budapest Gambit trap, replayed from 1.d4 Nf6 2.c4 e5 3.dxe5
  Ng4 4.Bf4 Nc6 5.Nf3 Bb4+ 6.Nbd2 Qe7 7.a3 (step 1 matches). Castling fields
  corrected from `KQk` to `KQkq`.
- Board move (one board, one place): steps 4–7 stood on trainer puzzle
  mate-in-one-06's board (after 8.axb4). They now stand in the trap's other
  known branch, 7…Ngxe5 8.Nxe5 Nxe5 9.axb4 (the engine's own main line; unused
  anywhere), where …Nd3# is still the only mate (e2 pinned by the queen, the
  only white piece touching d3). Step 4 now says "Knights came off on e5, and
  then White took the bishop", and its grab-back chip became …Qxb4 (…Nxb4 does
  not exist on the new board).
- Step 3: …Ncxe5 is a genuine equal of …Ngxe5 (engine +0.60 v +0.45), sets the
  same trap (8.axb4?? Nd3#) and after 8.Nxe5 Nxe5 reaches the same board, so it
  is now accepted too; the hint no longer steers to one knight.
- Facts checked: Elo percentages (Phase 1), USCF 1960, FIDE 1970 and the first
  list on 1 July 1971, K factor, title floors 2300/2400/2500.
- Proof culture-04: engine …Nd4 −2.6 (next best +0.4); after it hxg4 is
  White's best (−2.7), and Nxd4 allows …Qh2#. The prose said "the queen for a
  knight" (it is the queen for two knights, a piece up) and that the g4 knight
  "covers the escape" (it guards the queen on h2); rewritten to §8 with chips
  for the backticked moves. Flag "43 legal replies" is expected — "best", not
  "forced".
- puzzles check: 16 → 15 errors.

### culture-05-titles (done, main session, no engine)
- Lesson verified, no changes. The Ruy Lopez Closed replayed to step 1
  (1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.O-O Be7 6.Re1 b5 7.Bb3 d6 8.c3 O-O)
  and on through 9.h3 Na5 10.Bc2 c5 (step 5, en passant c6); h3 takes g4 from
  …Bg4; d2 is the only unmoved center pawn, and "open the position" excludes d3.
  Facts: 27 GMs in 1950, CM/FM/IM/GM at 2200–2500, the women's titles 200
  lower, norm conditions (9+ rounds, federations, titled opponents, 27 games),
  Polgár's GM title in December 1991 at fifteen.
- Proof culture-05: mate verified (Bf4 covers b8 and c7, only b7 guards a6,
  …bxc6 the only reply). The setup said "a rook down"; the count is 25 v 32,
  so now "far behind on material". Prose to §8 (108 → ~75 words).

### culture-06-tournaments (done, main session, one Stockfish burst)
- Replayed: the Caro-Kann Classical to step 1 (1.e4 c6 2.d4 d5 3.Nc3 dxe4
  4.Nxe4 Bf5 5.Ng3 Bg6 6.h4), and Réti–Tartakower, Vienna 1910, to step 7
  (…8.O-O-O Nxe4). Claims checked: without …h6, h5 leaves the bishop only
  losing squares; after …h6 h5, Bh7 is there; after 9.Qd8+ Kxd8 10.Bg5+ (double
  check) the king has only c7 and e8. Facts: pairing-allocated bye scored as a
  win, round robin 10 players/9 rounds, World Cup two-game matches, Buchholz and
  Sonneborn-Berger, illegal move +2 min then loss (standard play).
- Board move (one board, one place): step 9 played Bd8# on trainer puzzle
  mate-in-one-10's board (after 10…Kc7). It now takes the game's other branch,
  10…Ke8 11.Rd8# (unused anywhere; Rd8# the only mate, Bg5 guarding d8 and e7).
  Step 8 animates Qd8+ Kxd8 Bg5+ Ke8 and states the Kc7 mate in words; trimmed to
  fit 110 words.
- Proof culture-06 (Ruy Lopez trap replayed: 1.e4 e5 2.Nf3 Nc6 3.Bb5 Nf6 4.O-O
  Ng4 5.h3 h5 6.hxg4 hxg4 7.Ne1): engine …Qh4 #4 and the only good move; f4 the
  longest defence (#3); after …g3 only delays. The prose's "Qh5 Rxh5 Bxc6 only
  buys a move" was not the engine's line (9.Qh5 Qxh5 10.fxe5 Qh1#) — replaced
  by the checkable "even Qh5 only delays Qh1# by a move". Setup reworded to
  clear the P05 "knight on g4" flag. Prose to §8.
- puzzles check: 15 → 14 errors.

### culture-07-online-chess (done, main session, no engine)
- Lesson verified, no changes. Damiano's attack replayed from 1.e4 e5 2.Nf3 f6
  3.Nxe5 fxe5 (step 3) through 4.Qh5+ Ke7 5.Qxe5+ Kf7 6.Bc4+ Kg6 7.Qf5+ Kh6
  (step 4, four checks, move 8) and 8.d4+ g5 9.h4 Kg7 10.Qf7+ Kh6 (step 8);
  Qh5+ the only check at step 3, hitting e8 and e5; on g5 both Bxg5+ and hxg5+
  check and only hxg5# mates.
- Proof culture-07 (Petrov trap replayed: 1.e4 e5 2.Nf3 Nf6 3.Nxe5 Nc6
  4.Nxc6 dxc6 5.d3 Bc5 6.Bg5 Nxe4 7.Bxd8): mirrored to White to move (the
  lesson is played as White; P07 flag cleared), castling taken from the replay
  (`KQkq`, not the file's `KQk`). Prover: forced mate in 2, Bxf7+ the only
  first move, …Ke7 the only reply, Bg5#; the board is unused anywhere. The old
  prose wrote the illegal `Kxf2` as code (now in words), the hint said a piece
  was "already watching" the king's one free square (none is until the bishop
  reaches g5), and the setup's "queen on d8" P05 flag is gone. Prose to §8.
- puzzles check: 14 errors (unchanged; culture-07 had none).

### culture-08-why-chess-endures (done, main session, one Stockfish burst)
- Board move (one board, one place): step 9 played Be7# on trainer puzzle
  mate-in-one-12's board (after 22…Nxf6), and no other board ends the Immortal
  Game with that mate. The lesson now ends one beat earlier on Anderssen's
  22.Qf6+ (the move-22 board, which history-05's proof vacated). The two
  history beats moved in front of it; their opening line ("White has two knights
  and a bishop") was only true after the queen sacrifice and now reads "White
  has given up both rooks and a bishop and is about to win anyway". Facts
  checked: 21 June 1851, Falkbeer's "immortal" (1855), checkers solved 2007,
  seven-piece tables 2012, ~4.8 × 10⁴⁴ legal positions (2021).
- Proof culture-08 (the Evergreen, Anderssen–Dufresne, Berlin 1852, replayed
  to 20…Nxe7): engine Qxd7+ #4, every other move is mated; the prover gives
  Bf5+ as the only mate in 3 after …Kxd7, so the 3-ply line has no twin. Two
  false claims fixed: "…Ke8 is forced" (…Kc6 is legal and meets Bd7#), and "Kf8
  runs into fxe7" (it is mate at once, Qxe7# or Bxe7#). Prose to §8.
- puzzles check: 14 → 13 errors. **The Chess World (culture-01..08) is done;
  every culture-vs-trainer board collision is resolved.**

### tactics-01-the-fork (done, main session, no engine)
- Board claims checked with python-chess (Nb4+ the only knight fork of c6 and
  d5; the king's seven squares, of which d6 and c5 still guard the queen; from
  a8 the queen no longer sees e5; after Qxe5+ only king moves). One fix: step 2
  said "a piece a knight is attacking can never take that knight", which its own
  next sentence contradicts — a knight can. Now "can almost never take it back".
- forks-01 and forks-02 stood on the lesson's play steps 3 and 7. Per the rule
  the pool puzzles moved: each keeps its teaching shape, slid to a fresh board
  (`8/8/1k6/2q5/8/8/1N1K4/8`, Na4+ Kb7 Nxc5+; `6k1/8/8/6n1/8/8/8/2Q3K1`,
  Qxg5+), both verified unique and sound and unused anywhere. forks-01's title
  also duplicated fork-09's "The Royal Fork" and its explanation claimed king
  and queen were "two squares apart on a diagonal" (they are adjacent); both
  gone with the rewrite. All three fork puzzles, including the proof forks-03,
  are now §8.
- puzzles check: 13 → 11 errors.

### tactics-02-the-pin (done, main session, no engine)
- Lesson verified, no changes. Checked with python-chess: Rxd6+ is check and
  d6 is undefended (the king on d8 cannot reach it); on the second board the
  f6 knight is in a relative pin, as the text says (python's is_pinned is
  false, which is right — the piece behind is the queen, not the king); Qd6 is
  legal and e7 is the only blocking square. Noted: three moves block on e7
  (Be7, Ke7, Qe7); only Be7 survives the hint's "without hanging", so the
  prompt and hint together single it out — left as is.
- pins-skewers-01 stood on the lesson's play step 4 and repeated the proof's
  idea (rook takes a pinned queen down the d-file). It moved to a different pin
  instead: `7k/7p/5qp1/8/8/8/5PPP/B5K1`, where the queen is nailed to the long
  diagonal and falls to Bxf6+ (the only capture, undefended, …Kg8 forced; on
  Black's move …Qxa1 would be mate). Board unused anywhere.
- Proof pins-skewers-06: prose to §8, and the setup no longer names d2, the
  square the answer lands on (P02).
- puzzles check: 11 → 10 errors.

### tactics-03-back-rank-mate (done, main session, no engine)
- Lesson verified, no changes (king's five squares, the clear c-file, Rc8# the
  only mate, nothing guarding d8, Rxd8# the only mate).
- back-rank-01 stood on the lesson's play step 8; moved to the b-file with an
  a-pawn each side (`1r4k1/p4ppp/8/8/8/8/P4PPP/1R4K1`, Rxb8# the only mate,
  Black left with zero legal moves, board unused). Prose to §8: dropped the
  banned "luft", the square-chips {{h6}}/{{g6}} and the backticked `Rxd8#`.
- Proof tactics-mix-12: prose to §8 (170 → ~85 words). Its "why it's mate" list
  chipped moves that cannot be played — {{Kg8}} (where the king already stands)
  and {{Kxd8}} (illegal) — and used "luft"; all gone.
- puzzles check: 10 → 9 errors.

### tactics-04-the-skewer (done, main session, no engine)
- Lesson verified, no changes. Checked: Ra3+ is a real check and …Qxa3 takes
  the rook; after Rd1+ Black has exactly six moves, all king moves, and every
  one allows Rxd6; d6 is undefended; on the third board the bishop has seven
  squares and two checks (Be3+ and Bb2+), but only Bb2+ lands on the long
  diagonal the king and rook share, which is what the prompt asks for.
- Proof forks-10: prose to §8 (144 → ~85 words); its six-replies claim is
  confirmed. Flag "6 legal replies" is expected — the prose does not call them
  forced.

### tactics-05-discovered-attack (done, main session, no engine)
- Lesson verified, no changes. Checked: the knight has eight moves and every
  one is a discovered check; …Qxc3 really is illegal; on the second board
  exactly two knight moves give double check (Nf6+ and Nd6+) and only Nd6 also
  hits b7, which is what the hint claims.
- Proof discovered-01: one false claim fixed. It said "whichever it picks,
  Nxc8 collects the rook", but after …Kd8 or …Kd7 the king recaptures on c8 —
  it is the exchange, not a free rook (only …Kf8 loses it outright). Prose to
  §8 (138 → ~88 words). Flag "3 legal replies" expected; the scripted …Kd8 is
  Black's best, since …Kf8 drops the whole rook.

### tactics-06-double-attack (done, main session, one Stockfish burst)
- Lesson verified, no changes. Checked: the only loose black pieces are the
  knights on b4 and h4, the fourth rank between them is empty, Qd4 is the only
  queen move hitting both, d4 is not attacked, …Nf3+ is a real check and f3 is
  covered twice; on the second board g7 and a5 are both undefended, Nc6 and Nc4
  are the two knight squares hitting a5 (b5 covers c4), and c3 is undefended.
- Step 3 triage (plan-naming rule): the engine prefers Qd8+ (+7.6) to Qd4
  (+6.5), but the prompt asks for the square that "attacks both knights", which
  only Qd4 does. Stronger off-plan check recorded here, prompt unchanged.
- Proof forks-06 recomposed. The old board (`8/8/8/k6n/8/8/8/3QK3`) was broken
  in a way the Phase 1 note understated: Qxh5+ simply took the knight with
  check, so the fork was never needed. Any board where the queen can reach the
  knight's square has that hole, since landing there is itself the check. New
  board `8/8/8/k6n/8/8/8/5QK1`: the queen cannot reach h5 in one move, Qf5+ is
  the engine's best and the only sound fork (Qb5+ hangs to …Kxb5), and every
  reply loses the knight. Prose to §8, "Takeaway" removed.
- **The Blade (tactics-01..17) is done.**

### endgames-01-king-activity (done, main session, one Stockfish burst)
- Board claims checked (after e6 …Ke7 and nothing defends e6; the walk Kf2,
  …Ke7, Ke3, …Ke8, Kd4 replays; on the last board d7 is undefended and Kxd7 is
  legal). One fix: step 5 called f6 "the square in front of your pawn" — the
  square in front of an e5 pawn is e6; f6 is the one the pawn guards. Now "the
  square it would want beside your pawn".
- Proof endgame-04 (the audit's open uniqueness item): the engine confirms
  three winning first moves — Kd5 #18, Kd4 #20, Kf4 #20 — while Kf3 and Kd3
  draw. Kd5 is the only one that gains a rank, which is what the hint asks for,
  so it stands under the plan-naming rule; the hint now also rules out stepping
  back, and the explanation says outright that Kd4 and Kf4 win more slowly.
  Prose to §8 (194 → ~80 words, one heading).

### endgames-02-queen-mate (done, main session, no engine)
- Lesson verified, no changes: Qh8# is the only mate at step 3, Qd5 really is
  stalemate, and step 6 has exactly the two mates it accepts (Qa8#, Qd8#).
- Proof endgames-01 recomposed. The gate's "2 first moves force mate in 3" was
  right and the prose was wrong: it called Kc2 a stalemate trap, but with the
  white king on c2 the queen's second rank is blocked, so …Ka2 is legal and Kc2
  mates as well. New board `8/8/8/8/3K4/8/4Q3/k7` (queen e2, king d4, bare king
  a1, unused elsewhere): Kc3 is the only move forcing mate, …Kb1 is forced,
  Qb2# ends it, and the tempting Qc2 is a real stalemate — which is the point
  the puzzle wanted to make. Prose to §8, backticked `Kc2` gone.
- puzzles check: 9 → 8 errors.

### endgames-03-opposition (done, main session, engine sweeps)
- Lesson verified, no changes (Ke5 closes the gap; Black's five replies are all
  sideways or backwards; on the pawn board White has exactly four king moves
  with the pawn blocked by its own king; e6 is legal with e6–e8 clear).
- Proof endgame-02 recomposed. Its old board (`8/8/3k4/3P4/3K4/8/8/8`) is a dead
  draw where the engine scores *every* move 0.00, so the authored Kc4 and the
  mirror-image Ke4 were equal and the beat would have rejected a correct move.
  New board `8/8/8/3p4/3k4/8/8/4K3` (White to move, the lesson's side): Kd2 is
  the **only** move that draws — every other move loses — and it draws by taking
  the opposition, which is the lesson's own idea. Prose to §8.
- endgame-01 (endgames-06's proof) stood on this lesson's play step 6 and also
  carried a side flag. Both are fixed at once: K+P wins are symmetric, so its
  old board had two winning moves (Kd6/Kf6). Its new board is the mirror of an
  engine-swept unique-win position — `8/8/3k4/8/4p3/1K6/8/8`, Black to move
  (endgames-06's side), where …Ke5 is the only move that keeps the win. Prose to
  §8. (Superseded in the endgames-06 pass: that board made Black the attacker,
  which does not test a defending lesson; see below.)
- puzzles check: 8 → 7 errors.

### endgames-04-rook-mate (done, main session, no engine)
- Board claims checked: the only checks are Rg8+ and Rh1+ (after Rh1+ the king
  has only …Kg8); Rg7 is stalemate; Kf7 is the only move forcing mate in two
  and …Kh7 the only reply; the king's last squares are h8 and h6, and Rh1# the
  only mate. One wording fix: step 1 said both checks "run through g8" — Rh1+
  does not; now "hand over g8".
- Proof endgames-02: mate verified (…Ka7 the only square, Kc7 the only mate in
  two). Its setup rightly says two moves throw the win away, but the prose named
  the wrong second one: Kb6 only loosens the cut (…Kb8, still a won ending); the
  two losing moves are Rb7 (stalemate) and Rb8+ (hangs the rook). Prose to §8,
  backticked moves now chips.

### endgames-05-passed-pawns (done, main session, engine sweeps)
- Lesson verified, no changes. The square-rule race (e6 Kg5 e7 Kf6 e8=Q)
  replays; after e5 Ke7 e6 the pawn is attacked and undefended; the engine
  scores every move on the step 5/7 board as a draw, exactly as step 6 says
  ("against perfect defense the race is now a draw"), and step 7's prompt names
  the plan (up the pawn's own file), so Ke2 stands.
- Proof endgame-03 recomposed. The old board (`4k3/8/8/8/4P3/4K3/8/8`) is a dead
  draw for every move, including the "winning" Kd4, so its prose taught a win
  that does not exist (and even admitted Kf4 was "also fine"). New board
  `8/8/7k/4P3/8/5K2/8/8` from the engine sweep: the black king on h6 is inside
  the pawn's square, Ke4 is the only winning move (+7.9), and e6 and every other
  king move draw. Prose to §8.

### endgames-06-kpk (done, main session, engine checks)
- Lesson verified with the engine, move by move. From c8 only …Kb8 draws (…Kd8
  and …Kd7 lose, as step 1 says); after a7+ the replies are …Kc8 and …Ka8, and
  after …Ka8 only Ka6 is stalemate while every other white move lets the king
  take a7; on the last board …Kc7 is the only drawing move. One wording fix: step
  5 put the d7 king "directly in front of" the d5 pawn (d6 is between); now
  "ahead of it".
- Proof endgame-01, second recomposition. The board set during endgames-03 made
  Black the side *with* the pawn, but this lesson teaches Black to defend. New
  board `8/8/8/4k3/2P5/2K5/8/8`, Black to move (swept, then confirmed at depth
  24): …Kd6 is the only move that draws and every other move loses; the
  engine's line after it (…Kc6, …Kc7, …Kd7, …Kc8) is the king getting in front of
  the pawn and keeping the opposition. Geometry deliberately not a mirror of
  endgames-03's proof. Prose to §8.
- **The Finish (endgames-01..12) is done.**

### strategy-07-open-files (done, main session, one Stockfish burst)
- Petrov replayed to step 1 (1.e4 e5 2.Nf3 Nf6 3.Nxe5 d6 4.Nf3 Nxe4 5.d4 d5
  6.Bd3 Be7 7.O-O Nc6) and on through 8.Re1 Bg4 9.c4. Three false lines fixed:
  step 1 said both e-pawns "came off on move four" (moves three and four);
  step 2 said a rook on an open file "is worth more than a bishop and a knight
  together" (five points against six); step 6 said a passive reply to b5 would
  "lose the pawn", but b5 …h6 bxc6 bxc6 leaves material level — now "White
  exchanges on c6, leaving a weak pawn behind". Also checked: every file on the
  second board carries a pawn, and b4 is White's only pawn that can reach c6.
- Proof strategy-07: a quiet, level position (engine h3 +0.30, Qe2, Re1, a3 all
  within 0.1). Rc1 is not the engine's first pick but is the only rook move onto
  the named file (the other rook is blocked by the queen), so it stands under the
  plan-naming rule. The prose said the rook "stares at c6 and c7" from c1, but its
  own knight on c3 blocks the file; it now says the rook waits behind the knight.
  The setup's unverifiable "came off on move three" is gone. Prose to §8.

### strategy-08-bishop-pair (done, main session, one Stockfish burst)
- Checked: step 1's Bxf3 Qxf3 Nf6 c3 Be7 replays exactly to step 2's board;
  material level (36 v 36); the c1 bishop has no move on step 2 and exactly one
  (Bd2) on step 4, with White holding both bishops and Black one. One wording
  fix: step 6's hint called c1–h6 "the long diagonal"; now "the diagonal".
- Plan-naming triage (engine, 2 s): step 3's d4 +0.61 against d3 +0.80, and step
  6's e4 −0.06 against Rd1 +0.42. Both are the only moves carrying out their
  prompts, both inside the one-pawn tolerance, so both stand.
- Proof strategy-08: Bc2 +0.57 against d4 +0.08, and the only retreat that keeps
  the pair safely (Bc4 stays in the knight's reach, Ba4 hangs to …bxa4). Prose to
  §8; the second heading and the backticked …Nxb3 are gone, and the claim that
  standing still gives Black the pair, doubled b-pawns and the a-file checks out.

### strategy-09-prophylaxis (done, main session, one Stockfish burst)
- Checked: the a7–g1 diagonal holds only Nd4 and the king; after Bf3 Qb6 the
  knight has no legal move, and after Be3 b2 is attacked and undefended; a4 is
  the only pawn move that hits b5. One fix: step 4 said …b5–b4 would open "the
  b-file onto b2" (Black's own pawn stays on that file) — the real point is
  kicking the knight off c3, which defends e4, and it now says so.
- Engine, 2 s: Kh1 +0.24 (a4 +0.30), a4 +0.20 (Bf3 +0.24), Nb3 +0.16 (Be3 +0.21)
  — all three plan moves within 0.06 of best.
- Proof strategy-09: c4 is the engine's top move (+0.69); f4 is equal (+0.68)
  but does nothing about …b5, which the hint asks for, so c4 stands under the
  plan-naming rule. The prose said c4 "hands Black the b4 square for good", but
  a3 can still cover b4; the price it now names is the one that is real (the d4
  knight loses its pawn support). Prose to §8.

### strategy-10-maneuvering (done, main session, one Stockfish burst)
- Lesson verified, no text changes. Every square count checked with
  python-chess: no checks or loose white pieces on the first board; g3 covers f5
  and h5 and no black pawn watches either; the b1 knight has exactly Na3 and
  Nbd2; Nbd2 Nc6 and Nf1 Bd7 replay to the step 4 and step 6 boards; the d2
  knight has four moves (three queenside, only Nf1 not); the f5 square hits e7
  and d6; the f1 knight has four moves, e3 and g3 look at f5, and only g3 at h5.
- Plan-naming triage (engine, 2 s): Nbd2 +0.53 against d5 +0.59; Ng3 +0.46
  against d5 +0.93; and Nf1 +0.15 against d5 +1.07 — after …Nc6, d5 gains a
  tempo on the returned knight and is about 0.9 better. That is inside the
  one-pawn tolerance and the prompt asks for the next step of the maneuver, so
  Nf1 stands; recorded here as the strongest off-plan rival in the group.
- Proof strategy-10 (Sveshnikov, the knight on a3): Nc2 is the engine's best
  (+0.43, next h4 +0.31). Its pawn claims check out (b5 held by the a-pawn, c4
  covered by the b-pawn). The setup's "chased to a3 five moves ago" does not fit
  the main line it comes from (Na3 on move 8, now move 12) and is gone. Prose to
  §8.

### strategy-11-exchange-sac (done, main session, one Stockfish burst)
- Checked: material level (35 v 35); only the c8 rook reaches c3 and only bxc3
  takes back; the c3 knight covers e4, b5 and d5; Qa5 is the only queen square
  hitting a2 and c3; nothing defends c3 at the end. Engine: Rxc3 is Black's best
  (+0.62 against a5 +0.83), Qa5 within 0.07 of Qc7, Rc8 the best move.
- Two fixes. Step 2 said a3 and b2 "have only the king left to watch them" —
  after bxc3 nothing watches a3; now "b2 has only the king left to watch it, and
  a3 has nothing at all". Step 8's hint reasoned that an undefended pawn needs
  "one more attacker", which would mean the queen should just take it; the engine
  shows …Qxc3 at once is about 0.76 worse, so the hint now says grabbing it
  immediately is premature and the rook comes first.
- Proof strategy-11: Rxc3 is clearly best (−0.87 against Rc5 +1.27). Prose to
  §8; the backticked …Qa1+ became the checkable "one move from checking on a1".
- **The Plan (strategy-01..11) is done.**

### openings-01-opening-principles (done, main session, one Stockfish burst)
- Checked: f7 defended by the king alone and Bc4 the only bishop square aiming
  at it; five knight moves on the Scandinavian board, only Nc3 hitting d5;
  3.Nc3 Qa5 4.d4 Nf6 puts the knight out on move four; the castling board's
  claims (king still on e1, the h1 rook with no square) hold. One fix: step 3's
  hint gave the bishop "two roads out" — it has one open road with five squares.
- Proof openings-01. Engine (2 s): Nxe5 +3.89, d4 +3.58, Bxf7+ +3.46; the hint
  names the fork plan (the king on f7), so Bxf7+ stands under the plan-naming
  rule, with Nxe5 recorded as the stronger off-plan rival. Black's best reply is
  …Kd8, not the scripted …Kxf7; the prose calls neither forced. Two false claims
  fixed: the hint said king and queen were "already one knight-leap apart" (e8
  and e4 — the Phase 1 note), and the prose said declining leaves White "a clean
  piece ahead", but …Kd8 Bxg8 Rxg8 nets only a pawn; White wins on the stranded
  king. Setup's unverifiable queen tour and P05 flag gone; prose to §8.

### openings-02-italian-game (done, main session, one Stockfish burst)
- L15 collision resolved the other way from the earlier note: openings-02 step 3
  and basics-09 step 9 were both play steps on the Giuoco Piano board after
  3…Bc5. That board is the Italian lesson's own (4.c3 is its point), and
  basics-09 only needs *a* position where castling is the safe move, so
  basics-09's steps 8–9 moved to the Four Knights Italian after 4.Nc3 Nf6
  (`r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R`, unused;
  engine: O-O +0.19 against d3 +0.20, and after it f2 has two guards as the text
  says). Its "same moment" became "a similar moment". lint_lessons: 2 → 1 error.
- Lesson claims checked: f7 and f2 each guarded by the king alone; after d4
  exd4 Nxd4 the c6 knight hits d4; c3 the only pawn move guarding d4; 4.c3 Nf6
  5.d3 d6 6.O-O O-O replays to step 4 ("three moves later"); the b1 knight has
  only Na3 and Nbd2. One fix: step 5 said the rebuilt d4 pawn has "no white piece
  behind it", but the queen on d1 and knight on f3 both defend it; now "yours are
  tied down holding it".
- Proof openings-02: Qd5 is clearly best (+3.49 against Bxf7+ +1.75); Qxf7#
  is a real threat; the knight's tries …Nd6 and …Ng5 fall to exd6 and Nxg5.
  Prose to §8 (backticked Qxf7 now a chip; curly apostrophe normalized).

### openings-03-sicilian (done, main session, one Stockfish burst)
- Checked: queenside pawns 3 v 2 after the trade; no white pawn can ever
  defend c2; Rc8 +0.26 against Nxd4 +0.21. Three fixes: step 6 said the c-file
  held "nothing of yours at all" and step 7's hint "nothing of yours stands on
  that file" — Black's own knight sits on c6; both now say "no pawn of yours".
  Step 5 called the d6/e6 pair "a center two squares deep"; they stand side by
  side.
- Proof openings-03 (Siberian Trap): Nd4 −2.76, clearly best (…Nge5 −0.16);
  Qh2# is mate (f1, f2, g2 White's own, h1 covered by the queen, the queen
  guarded by Ng4). The prose said "the knight cannot be ignored, so Nxd4 takes
  it", but White's best is hxg4, giving up the queen (−2.85); Nxd4 is only the
  natural reply that walks into mate, and the prose now says so. Also removed:
  "gambit" (taught in openings-04, the next lesson) and an unsupported c-file
  aside. Prose to §8.

### openings-04-queens-gambit (done, main session, engine searches)
- Lesson verified, no changes: both backing pawns (…e6, …c6) are accepted;
  queenside pawns in the Carlsbad are 2 v 3; b4 is the engine's best (+0.28).
- Proof openings-04 replaced. Its Elephant Trap board was tactics-10's play
  step 3, and tactics-10 also plays the trap's next board (…Bb4+) at step 6, so
  that trap belongs to the zwischenzug lesson. New proof from an engine search
  of the Cambridge Springs Defense (the lesson's own …c6/…e6 setup, played as
  Black): after 1.d4 d5 2.c4 e6 3.Nc3 Nf6 4.Bg5 Nbd7 5.e3 c6 6.Nf3 Qa5 7.Bd3 Ne4
  8.Qc2, the only winning move is …Nxg5 (−3.17; next best −0.21). The queen pins
  c3 to the king, so g5's only guard is f3; after 9.Nxg5 dxc4 the fifth rank
  opens and the queen wins the knight back, and White's other ninth moves leave
  Black a piece up too (−3.4 to −4.1). Board unused elsewhere; 8.Qb3 was rejected
  (two winning replies). Prose to §8.
- puzzles check: 7 → 6 errors.

### openings-05-caro-kann (done, main session, no engine)
- Checked with python-chess: both move orders replay exactly to the lesson's
  boards (…Bf5 Ng3 Bg6 h4 h6, and 3.e5 Bf5 4.Nf3 e6 5.Be2); the e4 knight is
  undefended and Bf5 the only bishop square hitting it; three of Black's first
  four moves were pawn moves; nothing but pieces holds d4; c5 the only pawn move
  hitting it. Three loose lines fixed: …d5 came "two moves later" (it was the
  next move); White had "a knight on e4 and a piece out" (that knight is its only
  piece out); White "moved one knight twice" (it moved a third time).
- Proof openings-05 (the Caro-Kann smothered mate): Nd6# is the only mate; e7
  is pinned, d7 blocks the queen, e7 blocks the bishop, and every square around
  the king holds a black piece. Prose to §8. Side flag triaged, intended: the
  lesson is played as Black and the proof is White's move, but it is the classic
  warning against walling the Caro-Kann king in, and a mirrored version would be
  an opening nobody plays.

### openings-06-english (done, main session, one Stockfish burst)
- Lesson verified, no changes: both move sequences replay exactly to the
  lesson's boards, no white pawn attacks the d5 knight, and the two play answers
  are the engine's first choices (Bg2 +0.29, d4 +0.29).
- Proof openings-06 (the fork trick): Nxe5 is best (+0.42, next Be2 −0.03) and
  …Nxe5 is Black's best reply. The prose said White "comes out a pawn ahead",
  but after d4 Black's best, …Bb4, leaves only +0.43 — White wins the piece back
  and keeps the center, not a pawn. The title "A Tempo Is Worth a Pawn" promised
  the same pawn and is now "Clear the Road to d4" ("The Fork Trick" was taken by
  fork-03). The setup put c5 "next to" e5 (two files apart). Prose to §8.

### openings-07-traps (done, main session, one Stockfish burst)
- Checked: f7 attacked by c4 and h5 and defended by the king alone; the h5
  bishop's pin line to d1 is clear; after 6.Nxe5 Nxe5 the queen can take on h5.
  Engine: Nxe5 is the best move (+1.86), and the careful line (…Nxe5 Qxh5 Nxc4
  Qb5+ c6 Qxc4) leaves White about a pawn up (+1.77), as step 6 says.
- Step 3 accepted answers widened. Of the moves that stop Qxf7#, …g6 (−0.43)
  and …Qe7 (−0.16) are best, but …Qf6 (+0.25) and …Nh6 (+0.33) are sound and do
  exactly what the prompt asks ("fix the count" by adding a defender), so they
  are accepted too rather than rejected; …Ke7, …d5, …Qg5 and …Qh4 stay wrong.
- Proof openings-07 (Légal's mate): …Ke7 is forced after Bxf7+ and Nd5# is mate.
  Prose to §8; setup reworded to clear the P05 "queen on d1" flag; the mating
  net now names f6 too. Side flag triaged, intended: the lesson's second half
  plays White's side of this same trap, and the proof is its finish.

### openings-08-kings-pawn-family (done, main session, one Stockfish burst)
- Lesson verified, no changes: e5 has no defender after 2.Nf3; seven moves
  guard it, and the hint's two descriptions pick out exactly the accepted …Nc6
  and …d6 (…Bd6, the queen moves and …f6 each fail one of them); the Ruy Lopez,
  French, Caro-Kann, Sicilian and Alekhine descriptions and the d5 answer hold.
- Proof openings-08 (punishing …f6): Nxe5 +1.50, with Bc4 +1.54 an equal
  off-plan rival (the hint names the knight sacrifice, so Nxe5 stands). Two
  claims fixed: "…fxe5 is nearly forced" — Black's best is …Qe7 (+1.71, still a
  pawn down), and the prose now says so; and "the h8 rook falls next" belonged
  to the …g6 block (Qxe5+ and Qxh8), not to …Ke7, which the prose had run
  together. Prose to §8. Side flag triaged as for openings-05: it shows the
  punishment of Black's wrong defender from the side that delivers it.

### openings-09-queens-pawn-family (done, main session, one Stockfish burst)
- L15 resolved the other way from the earlier note: openings-09's step 7 and
  history-03's step 4 were both play steps on the Queen's Indian board after
  4.g3. openings-09's steps 5–7 tell a story about that exact position (g3, the
  undefended c4 pawn, …Ba6), while history-03 only needs a board where the c8
  bishop has exactly two squares with one on the long diagonal. history-03's
  steps 1–4 moved to the same opening after 4.Nc3 (`…/2PP4/2N2N2/PP2PPPP/…`,
  unused; the bishop still has exactly Bb7 and Ba6; the text is board-agnostic).
  **lint_lessons is now 0 errors across all 100 lessons.**
- Lesson checked: the move orders replay; c4 is undefended; Ba6 is the engine's
  best (+0.51). One wording fix: step 5 had the bishops "nose to nose with the
  square between them" (four squares lie between); now "facing each other down
  the diagonal, with e4 in the middle".
- Proof openings-09: …Ne3 clearly best (−5.49, next …Nxe5 −1.30); after Qh4+
  g3 is the only reply and Qxg3# is mate. Fixed: "taking is almost forced" —
  White's best is Ngf3, giving up the queen (−5.43), and fxe3 is the blunder; "the
  pawn on e3 has taken f2 away" — it is the queen on g3 that covers f2; the title
  was 7 words ("The Knight You Must Not Take"). Prose to §8.

### openings-10-ruy-lopez (done, main session, one Stockfish burst)
- Checked: e5's only guard after 3.Bb5 is the c6 knight; a6 the only pawn
  move hitting b5; after Bxc6 dxc6 Nxe5 the queen on d4 hits e5 and e4; López de
  Segura 1561. One fix: step 6 said the bishop on c2 "swaps f7 for h7", but from
  c2 its diagonal toward h7 runs into White's own e4 pawn; now "aims toward h7,
  behind its own e-pawn" (trimmed to stay within 110 words).
- Proof openings-10 (Bird's Defense trap). Engine: …Nxb5 −2.68 is stronger than
  …Qg5 −2.28; the hint names the queen's double attack, so …Qg5 stands under the
  plan-naming rule and the prose now says taking the bishop wins more cleanly.
  After …Qg5 White's best is to cut losses (Bd3 −2.43); the mating line needs
  White to keep grabbing with Nxf7, and at the end Qe2 avoids the mate that Be2
  walks into. The prose no longer implies any of it is forced; the setup's P05
  "pawn on e5" flag is gone. Prose to §8.

### openings-11-london-system (done, main session, engine at depth 20–22)
- Step 3 rebuilt. On its old board (after 1.d4 d5 2.Bf4 c5 3.e3 Qb6) the only
  move covering b2 was Qc1, but at depth 22 it is −0.30 against Nc3 +0.82 — more
  than a pawn below best. The step now stands in the usual London move order with
  c3 already played (…Nc6 4.c3 Qb6; unused), where Nc3 does not exist: Qc2
  +0.02, Qb3 −0.09, Qc1 −0.20, and all three are accepted. Qd2 (−0.40) and Qe2
  (−0.26) also guard b2 but block the knight or bishop, which the new hint rules
  out. Step 2's chips now replay to that board (c5 e3 Nc6 c3 Qb6), and step 4's
  "seven quiet moves later" became "six".
- Three false lines fixed: step 2 said …Qb6 "stares at b2 and at d4" — Black's own
  c5 pawn blocks d4, which is attacked by c5 and c6 instead; step 5 called e5 a
  hole "no black pawn will ever cover" while its next paragraph says …f6 could;
  step 6's prompt and hint repeated "no pawn can ever" challenge it (both now name
  the f-pawn). Checked: the d3 bishop's clear road to h7, h7 guarded by the king
  and Nf6, e5 touched only by the c6 knight; Ne5 −0.22 against a4 +0.10.
- Proof openings-11 (a French Greek gift): Bxh7+ is clearly best (+1.21, next
  Nb5 +0.44). Black's toughest defense is …Qxg5 at once rather than the scripted
  …Kg8, after which only …Qxg5 still avoids mate; the prose now says so. Prose to
  §8.

### openings-12-french-defense (done, main session, engine searches)
- Lesson verified, no changes: d4 attacked by c5 and c6 and defended by c3,
  f3 and d1; the Winawer line replays to step 5, where c3 is undefended; the g8
  knight's three squares are e7, f6 (covered by e5) and h6 (covered by the c1
  bishop); Qb6 +0.43 against Bd7 +0.31, and Ne7 the engine's best.
- Proof openings-12 replaced. The old knight sacrifice …Nxb4 was no better than
  quiet queen moves, White is better after its best defense (+1.1), and its
  prose line ended in …Qxa4, which drops the queen to the d1 queen — no "raging
  attack" existed. New proof from an engine search of Advance French lines,
  teaching the lesson's own idea (attack the base of the chain): after 1.e4 e6
  2.d4 d5 3.e5 c5 4.c3 Nc6 5.Nf3 Qb6 6.Bd3 cxd4 7.cxd4 Bd7 8.Nc3, d4 is attacked
  twice and defended once (the d3 bishop blocks the queen), and …Nxd4 is clearly
  best (−0.83; next +0.94). White's best reply is Nxd4, and …Qxd4 leaves Black a
  pawn up; the usual Bb5+ trick fails because the d7 bishop covers b5 once c6 is
  vacated. Board unused. Prose to §8.

### openings-13-kia (done, main session, one Stockfish burst)
- Checked: the eight setup moves match the board; h4 b4 h5 replays; engine e5
  +0.03 (exd5 +0.01) and Nf1 the best move. One fix: step 5 said "its own pawn on
  g3 rules out the short road" for the d2 knight — its short road is e4, and that
  square is covered by Black's pawn on d5; the text now says so.
- Proof openings-13: e5 is 0.00 against c3 +0.21, the move the hint names. The
  count holds (e5 attacked by d6 and c6, defended by f3 and e1), and after …Bxe5
  Nxe5 Nxe5 Rxe5 White is a bishop for a pawn up — but Black's best is simply
  …Bc7 (0.00), and the prose now says so. Two false claims removed: e5 "takes f6
  from Black's knight" (Black's knights are on c6 and e7) and the setup's bishop
  "aiming at h2" (White's g3 pawn blocks that diagonal). Prose to §8.

### openings-14-najdorf (done, main session, one Stockfish burst)
- Checked: after …e5 Bb5+ Black has exactly six replies; b5 is reached by the
  d4 and c3 knights and the f1 bishop; a6 the only pawn move covering it; no
  black pawn can guard d5 after …e5; b5 +0.66 against Nbd7 +0.44. Two fixes:
  step 2's list of the six replies omitted the queen block and …Nc6; step 5 said
  d5 was a hole "Black can never fill again", but the d6 pawn can still advance
  there — now "no black pawn can ever guard again".
- Proof openings-14 (the Phase 1 item): the scripted …Nc5 after …Nxe4 Qf3 hung
  the a8 rook to Qxa8. After Qf3 Black's good answers are …Bb7 (−1.02) and …d5
  (−0.96), a twin, so a three-ply line would reject one of them. The proof is now
  the single move …Nxe4, and the prose names both defenses and the …Nc5 blunder.
  Engine: …Nxe4 +0.87 (after O-O) is sound but not best (…Qc7 +0.50, …Bb7 +0.53);
  the hint names the plan of taking the pawn the knight abandoned, so it stands
  under the plan-naming rule, and the prose no longer says the pawn is won "for
  nothing" — White gets some play. Prose to §8.

### openings-15-kings-indian-defense (done, main session, one Stockfish burst)
- Lesson verified, no changes: five black setup moves; the g7 bishop's road to
  d4 blocked by the f6 knight; c5 and e5 the two pawn pushes hitting d4; e5 the
  engine's best (+0.59), and f5 within 0.08 of best (b6 +0.76, f5 +0.68).
- Proof openings-15 (Four Pawns Attack). …Qa5 pins c3 and hits c5, and after
  White's best, Bd3 (+0.54), …Qxc5 regains the pawn. The engine prefers …Nbd7
  (−0.09), so …Qa5 is about 0.6 below best — inside tolerance, and the hint names
  the queen's two jobs, so it stands under the plan-naming rule. Three false lines
  fixed: the prose called Bd2 "the honest answer" while the line plays Bd3 (the
  engine's choice); the g7 bishop was said to be "raking d4" (the f6 knight blocks
  it); White was said to have "four pawns in the middle" (c4, e4 and f4 remain).
  Prose to §8.

### openings-16-nimzo-indian (done, main session, one Stockfish burst)
- Lesson verified, no changes: the c3 knight is pinned and is e4's only guard;
  bxc3 is the only recapture; no white pawn can guard c3 or c4 afterward (nor c4
  on the later board); Na5 +0.08 against Ba6 +0.02.
- Proof openings-16: …Qa5 is the engine's best (+0.29) and hits c3 and c5; after
  the scripted Bd2, …Qxc5 is Black's best (−0.47). Three fixes: "Bd2 has to come
  out" — White's best is 9.e4, driving the knight off d5 first, and the prose now
  says so; "the free pawn on the other wing" — c3 and c5 are on one file; the hint
  said a c-pawn "has just advanced", but c5 was reached by a capture. Setup
  reworded to clear the P05 "knight on c3" flag. Prose to §8.

### openings-17-gruenfeld (done, main session, one Stockfish burst)
- Lesson verified: Nxc3 is best (+0.37; Nb6 +1.12); after bxc3 the g7 bishop's
  road through f6 and e5 is clear and d4 is guarded by c3, Nf3 and Qd1; c5 is
  best (+0.33). One fix: step 5 named the open b-file twice.
- Proof openings-17 (history 4.Bf4 Bg7 5.e3 c5 6.dxc5 Qa5 7.Rc1 Ne4 8.cxd5 Nxc3
  9.bxc3 replayed; FEN matches): …Bxc3+ is the engine's best (−0.62; …Nd7 +0.09).
  The prose said "Rxc3 is forced" — Ke2, Qd2 and Rxc3 are legal, and Ke2 is best
  (−0.50; Rxc3 −1.85, Qd2 −7.9). It also said "a rook for a bishop ahead" while
  Black starts two pawns down. The line now ends on …Bxc3+ (scripting Rxc3 would
  teach White's mistake as the defense); the explanation names all three replies.
  Prose to §8 (two headings and 123 words before).

### openings-18-catalan (done, main session, one Stockfish burst)
- Lesson verified, no changes: Tartakower, Barcelona 1929; Nf3 +0.31 (Qa4+ equal,
  but the prompt names the knight's development); the c8 bishop has no legal
  move; b6 +0.57 against c5 +0.45 and b5 +1.04, and b6 is the only move that
  prepares the fianchetto the prompt names.
- Proof openings-18: history 4…dxc4 5.Nf3 b5 replays (python-chess drops the
  unusable b6 en-passant field; harmless). 6.a4 +0.68 and 6.Ne5 +0.65 are equal, so
  the setup now names the plan ("Hit that pawn chain") that only a4 carries out.
  After a4, …c6 +0.73 is as good as …Bb7 +0.71, so the prose says "if Black props
  it up with c6"; Ne5 is clearly best after cxb5 (+0.84); …Nd5 is Black's best
  reply (+0.57) and b5 is then undefended. Removed the unsupported claims that
  axb5/cxb5 are forced, that c4 "cannot be held", and "three tempi and a wrecked
  wing". Prose to §8 (two headings and 118 words before). The line stays level on
  material by design (triaged flag).

### first-steps-09 (done, main session, one Stockfish burst)
- Its board duplicated endgames-09's play step 3, and its old answer only led to a
  bishop against a pawn, a draw. New board `5k2/6pp/p7/1p3p2/8/3B4/6PP/6K1 w`, built
  with python-chess: Bxf5 +1.40 is best (Kf2 −0.17, Bc2 −0.24; Bxb5 axb5 −5.91);
  a6 guards b5, nothing guards f5, and …g6 guards it if White waits. No duplicate
  anywhere in assets/data. Prose to §8 (the "Takeaway" line is gone).

### king-hunt-01 (done, main session, no engine — exhaustive mate search)
- After Qd7+ Ka6 both Qc6+ (…Ka7/…Bb6 Ra8#) and Ra8+ (…Kb6 Rb5#) forced mate. A
  black knight on c3 now guards b5, so only Qc6+ works. The bishop on h3 did
  nothing (its only diagonal toward the king ran into its own king on g4), so it
  was removed. New FEN `2Rb4/k7/6p1/5QR1/6K1/2n5/8/r7 w`, same line, id and rating;
  `puzzles prove` gives a unique Qd7+ (mate in 3); no duplicate; packs.json is up
  to date. The hint said the king "has exactly two squares" (it had three:
  b7, b6, a6) and the setup said the bishop bore on the corner; both rewritten.

### king-hunt-02 (done, main session, no engine — exhaustive mate search)
- After Bd5+ Ka7 both Rb7+ (…Ka8 Qa6#) and Ra4+ (…Ba5 Qb6#/Rxa5#) forced mate. A
  black pawn on a5 now blocks the a-file check, so only Rb7+ works. New FEN
  `k7/2b2r2/5Q2/p7/3R4/1B6/KRp5/8 w`, same line, id and rating; `puzzles prove`
  gives a unique Bd5+; Ka7 and Ka8 are the only replies; no duplicate; packs.json
  up to date. The setup called the king "wedged behind" the c7 bishop and White's
  pieces "lined up on the queenside" (the queen is on f6, the rook on d4);
  rewritten.

### king-hunt-03 (done, main session, no engine — exhaustive mate search)
- After Rxb8+ Kc5 both Qd6+ (…Kc4 Qd4#/Rb4#/Rf4#) and Rc7+ (…Bc6 Rxc6#/Qxc6#)
  forced mate. A black pawn on d7 now blocks the f7 rook's road to c7, so only
  Qd6+ works. New FEN `1r3R2/3p1R2/4Q3/1k2B3/b7/8/3p4/5K2 w`, same line, id and
  rating; `puzzles prove` gives a unique Rxb8+; …Ka5 allows mate in one, so …Kc5
  is the only real defense; no duplicate; packs.json up to date. Prose verified,
  no changes.

### king-hunt-08 (done, main session, no engine — exhaustive mate search)
- After Rxf5+ Kg4 both Qf3+ (…Kh4 Rh5#/Rh7#) and Qg6+ (…Kh4/…Kh3 Rh5#/Rh7#)
  forced mate. A black pawn on h7 now guards g6, so only Qf3+ works. New FEN
  `1b1K1R2/2R4p/2Q5/1B3r1k/1p6/8/8/8 w`, same line, id and rating; `puzzles prove`
  gives a unique Rxf5+; no duplicate; packs.json up to date. The setup called the
  f5 rook Black's "last active piece" (the b8 bishop and b4 pawn remain) and spoke
  of a "battery aimed at the kingside" that is not on the board; rewritten.

### tactics-mix-06 (done, main session, no engine)
- The line ended on Black's reply (Nxe5+ Kd8); it is now the single move Nxe5+,
  the only capture and the only answer to the queen's check. Unmentioned before:
  White starts in check from the e5 queen; the setup now says so. False claims
  removed: "no minor pieces left" as the reason Black cannot block (Black has only
  king and queen), and Kd8 as the forced reply (Kf8 and Ke7 are also legal). Prose
  to §8 (three headings, 201 words, and a 31-word setup before).

### Puzzle prose pass (§8), one puzzle at a time
- decoy-07: its title "Two Rooks, One File" was already used by back-rank-mate-04,
  so it is now "The Rook That Pays First". Line replayed (Kxh7 is the only reply,
  Rh1# mates); the claims about the king having no square, f5 covering g6 and the
  rook swinging along an empty first rank all hold.
- mate-in-one-05: "the queen as she lands" became "as it lands". The title "Into
  the Corner" did not fit (the queen mates from c1, not a corner), so it is now "A
  Rank With No Room". Qc1# is the only mate; d1 and d2 are the king's two holes and
  c1 covers both; the b1 knight blocks the a1 rook and c2 blocks the c3 queen.
- pin-06: its title "The Pawn Cannot Take" was also mate-in-one-06's, so it is now
  "A Defender in Name Only". Claims verified: d6 and e6 are empty, so the b6 rook
  pins c6 to the f6 king; c6 is d5's only defender; Rxd5 wins the rook cleanly.
- promotion-06 (one Stockfish burst): its title "Three Against Three" was also
  pawn-ending-09's, so it is now "Break the Pawn Wall". b6 is best (+6.9; Kg2
  +5.5), and after axb6, c6 wins (+8.7) while cxb6 only draws. The prose said
  "whichever way Black recaptures, the a-pawn runs", but if Black does not take
  on c6, cxb7 queens instead. It also skipped …cxb6 (the engine's own choice,
  met by a6). Both are covered now, and moves are chips instead of bold.
- remove-guard-05 (one Stockfish burst): its title "Take the Guard First" was
  also remove-defender-proof's, so it is now "Win the Piece Back". The prose said
  Rxa5 "wins a full piece", but Black starts a piece up, so Nxc6 bxc6 Rxa5 only
  levels the material (+0.06). Every other move loses (h4 −4.71: …Bxb4 cxb4). The
  setup now says White is a piece down, the explanation says the material ends
  level and names the …Bxb4 threat, and Rxa5 is a chip instead of bold.
- back-rank-03: prose to §8 (it had three headings, 146 words, "luft" and square
  chips). It called Rxa8# a "trade", but it is a capture with mate. Title "Rooks
  Off, Mate On" became "First to the Back Rank".
- back-rank-04: its premise was false. With the king on g1, Black to move also had
  Rxd1# (the setup said "only one back rank is defended", the hint said White's
  king guards its entry). The king moved to f1, so Black's Rxd1+ now meets Ke2.
  Rxd8# is still the only mate; no duplicate. Takeaway removed.
- back-rank-06: Takeaway removed; claims hold (Rxe8 is the only reply).
- back-rank-08: the board had no white king, and the prose argued that Black's
  "extra material" could not save it, but White is a rook and pawn up. A king was
  added on g1 (Rb8# is still the only mate; no duplicate), and the prose was
  rewritten to §8.
- back-rank-09: the hint contained the answer (Re8); the setup said "just two kings
  and one rook" (Black has three pawns); the prose spoke of a "rank-7 invasion".
  Rewritten to §8.
- back-rank-11: Rd8 is not check, but the line scripted …Rxd8 as forced (Black
  had 10 replies, and Rd4 +8.2 wins about as well, which is bad for a Sharpen
  puzzle). New board `3r2k1/2q2ppp/8/8/8/8/3R1PPP/3Q2K1 w`: two attackers against
  two defenders on d8, Rxd8+ Qxd8 (the only reply) Qxd8#. The only mate in 2 by
  exhaustive search (engine #2; next best Qe1 +0.05); no duplicate. Prose
  rewritten; Takeaway removed.
- defence-01 (trainer): title over six words, now "No Move to Spare". The prose
  scripted only …Be7; …Qxb7 also answers Rb7+ and is met by Qg6#, so the
  explanation now covers both. It also names the threat: Black mates with …Qh6.
- defence-11 (trainer): the hint repeated a sentence and ran to 34 words. The setup
  never said the c1 rook is giving check; now it does. The explanation says why
  Rg2# works (the a8 bishop guards g2). Both replies, Ke2 and Kf2, lose to Rg2#.
- discovered-03: Takeaway removed. "strolls home a whole rook up" became what is
  actually left: bishop and knight against a bare king (+1.96).
- discovered-05: after Bc8+, Black had …Re7 (four replies), and the "win" was a
  drawn K+R+B v K+R. New board `r3k3/8/4B3/8/4R3/8/8/4K3 w`: Bd5+ (+4.62; Bg4+
  +0.08) uncovers the e4 rook's check and hits the rook on a8, with no black block
  on e5–e7. No duplicate.
- first-steps-10/12/15/23: Takeaways removed and prose to §8. Claims verified:
  the e8 king guards e7; the pawns cover g3 and g4 but not g5; g1 and h2 are
  covered, and Rg2 is the only block; the a2 bishop reaches both knights from d5.
- first-steps-14: Be3 was not the best block (Kd2/Kf1 were equal; the "guarded
  block" point failed). New board `4r2k/1q4pp/8/6B1/8/8/3P1PPP/3RKR2 w`: the king
  has no square, so it is Be3 (−0.80, guarded by d2/f2) or Be7 (Rxe7#).
- first-steps-17: the setup chipped the landing square. It now says what a king
  move costs: Kd2 Qxh1.
- first-steps-18: the old board was mate in 8 whatever White played (Kd2 and Ke2
  were equal), so it was no promotion test. New board `8/4P3/5k2/8/8/8/8/4K3 w`:
  e8=Q wins, anything else lets …Kxe7.
- first-steps-20: the setup chipped the landing square; the prose now names the
  straight push's refutation (…Rxd8).
- first-steps-21: the knight fork "won" nothing: every first move lost (Nd2 −7.2,
  and Ra1# was threatened). New board `8/5ppp/2k1b3/8/8/1N5P/4rPP1/3R2K1 w`: the
  e6 bishop attacks the knight, and Nd4+ forks king and rook (+5.94; next +0.10).
- forks-04/05/09/13/15 were loose-piece grabs with no fork, ending in drawn K+N v K.
  They now have fork boards: forks-04 Nd5+ (K e7 + R b6, +4.06); forks-05 Ne7+ (K g8 +
  Q c6, +4.69); forks-09 the pawn fork d4 on c5/e5 (+4.18); forks-13 Nd6+ (K e8 +
  Q f5, +8.95); forks-15 the queen fork Qa4+ (K e8 + N h4, +0.56 against −2.54).
  Each was checked for duplicates and titled uniquely.
- forks-07/08/12/14: the fork boards drew (K+N v K). forks-07 is now Nf7+ against a
  cornered king (+5.19); forks-08 has a pawn on a5 that rescues the a8 knight
  (+5.10); forks-12 moved to a queen fork, Qd5+ (+8.70, next +0.22), because it
  was a third copy of the c7 fork; forks-14 has pawns (+3.79, next −4.78). Its
  prose now says the fork trades into a won pawn ending.
- forks-11: sound; the prose now says Black goes from a queen down to level.
- mate-in-1-01..31 (28 puzzles), prose to §8. False claims fixed: -01 "e8 covered"
  (the king stands there); -03 the second rook "backs up" the mate (it plays no
  part; hint, title and prose changed); -12 and -24 start with White in check from
  the h7 pawn, which the setups never said; -15 the bishop covered f8 before the
  rook moved (e7 blocks it); -17 credited the c8 bishop with the king's job; -19
  "Kxf7 illegal because of the check" (f7 is not next to the king); -20 "her".
  -07's knight did nothing (Kf6 already covered e7); new board
  `5k2/5p1K/3p4/5N2/8/8/Q7/8 w`, where Qa8# is the only mate and without the knight
  there is none.
- pawn-ending-02/07/11/12 (trainer): one square chip each, `Kd4`/`Ke4` backticks,
  and -07's garbled last line. Engine-checked: -07's c6 race wins (mate in 7–8
  after c8=Q); -11's Ke4 draws and the Kh6 walk wins; both -12 branches (h4 / Kb6)
  draw, and the prose now tells both.
- pins-skewers-02: not a skewer (the h1 rook was on the far side of the bishop) and
  a drawn K+B v K. New board `r7/6pp/8/3k4/8/8/1K2B1PP/8 w`: Bf3+ skewers the king
  to the a8 rook (+4.66; next −3.87).
- pins-skewers-03: "the pinned queen cannot move" (it can, and takes the rook).
  New board `4k3/pp2qppp/8/8/8/8/PPB2KPP/3R4 w`: Re1 pins the queen, with the king
  guarding e1 (+4.63; next −4.08).
- pins-skewers-04: the queen was called "paralyzed", but Qxd2+ is Black's threat,
  which is why Rxd5+ must come now. The setup bolded the landing square.
- pins-skewers-07: both Rxe7+ and Bxe7 won the rook outright, since each capture
  was covered by the other piece, so "take with the cheaper piece" was false. New
  board `2n1k3/pp2rppp/8/2B5/8/8/PP3PPP/4R1K1 w`: a c8 knight guards e7, so Bxe7
  (+4.62) beats Rxe7+ (+2.15).
- pins-skewers-08: the setup and hint said the queen could not leave the file, but
  it is not pinned until Rxd6 removes the d6 pawn. The setup bolded the landing
  square.
- promotion-06, pin-06, decoy-07, mate-in-one-05, remove-guard-05: see above.
- pins-skewers-09: "the rook alone is a bad trade" was false: the d6 pawn guarded
  e7, so Rxe7+ won the knight as well as dxe7, and every waiting move won too (the
  pinned knight could not escape). New board `r3k3/pp2nppp/8/3P4/8/7B/PP2RPPP/6K1
  w`: d6 must come now (+5.76; next +2.51). After …Rd8, Rxe7+ wins the knight
  because the pawn now guards e7.
- pins-skewers-10: Rxd7+ Kxd7 was a drawn rook-for-bishop trade, and Rd6 was
  equal. New board `3k4/p2b1ppp/6n1/1pP5/8/8/PP1R1PPP/6K1 w`: c6 attacks the
  pinned bishop, which cannot take it (+5.16; next −0.54).
- pins-skewers-11: the "pinned" queen could play Qxa2+, and every move drew. New
  board `q7/5ppp/8/k7/8/7P/5PPK/6R1 w`: a true skewer, Ra1+ Kb6 Rxa8 (+6.45; next
  −3.04).
- promotion-09: moves were bold instead of chips.
- rook-ending-03/04/05/06/08/10/11/12 (trainer): backticked moves chipped. Every
  sideline the prose claims was engine-checked: -03 …Rc2+ Kb3 trades into a draw;
  -04 …Rf6 Rb1 wins for White (+56); -10 "check from close range, …Rf1" (it is not
  a check; now "go behind the pawn"); -12 after …Kd3 or …Kf3, Rb7 wins (+4.4).
- smothered-04/06: backticks chipped. smothered-10: its title was a duplicate, now
  "The Knight Picks h6".
- tactics-mix-03/05/09/10/11/18: prose to §8. False claims removed: -05 "d5
  defended by nothing" (the d8 queen guards it; the setup also gave the move away
  with "White accepts"); -09 called the capture of a loose rook "a trade"; -11
  called e5 "less central" than d4; -18 called the line after …dxe4 "roughly
  equal" (Qxd8+ leaves White +1.5).
- tactics-mix-04: a8=Q+, Kd2 and Ke2 all mated in 9, so the check was not the
  point. New board `4k3/P7/8/8/8/1K6/7p/8 w`: the check buys the tempo for Qh1
  against the h-pawn (mate in 12; a quiet king move lets …h1=Q). Single-move line,
  because Qh1 and Qh8 both stop the pawn afterwards.
- tactics-mix-15: K+P v K with a rook pawn drew after every move, yet the prose
  called it a win. A square-rule board was tried and dropped: it was a near-copy of
  tactics-mix-08. New board `8/4k3/8/3K4/8/4P3/8/8 w`, found by an engine search
  of king and pawn boards with a single winning move: Ke5 takes the opposition in
  front of the pawn (mate in 17; e4, Ke4 and Kc5 all 0.00).
- tactics-mix-16: Bxc6+ was not best (Nf3 +1.61), and the prose listed "bxc6"
  twice and said …Bd7 and …Qd7 could not block. New board
  `r1b1k2r/ppp2ppp/2n5/3Bq3/8/2N1P2P/PP3PPQ/R4RK1 w`: Bxc6+ removes the queen's
  only guard with check (+8.86; next +2.91). The e3 pawn stops Rae1 from pinning
  the queen instead, and the knight is not pinned beforehand, so e5 really is
  guarded.
- P05 flags triaged (lint_puzzles, 17): every one is a true narrative or
  hypothetical ("has just taken your queen on d1", "a queen on c8 would not
  check"). openings-05/07/08 side flags were triaged earlier.
- New puzzles-check flags triaged: "ends level" on forks-04/05/09/13/15 and
  pins-skewers-03/09/10 (one-move lines whose material comes a move later), and
  "N legal replies" on discovered-05, forks-12 and pins-skewers-11 (every reply
  loses the same material).

### Second pass (2026-09-17): whole-corpus engine screen and a full claims read

Method: (1) every learner move in all 441 puzzles screened with Stockfish (0.3 s,
MultiPV 3), flagging moves worse than best by more than 100 cp and first-move
rivals within 50 cp (proven ≤5-ply mates excluded, since the prover covers them);
(2) every scripted defender reply screened against the defender's best; (3) every
lesson play step screened the same way; (4) a sentence-by-sentence claims read of
the 21 agent-written lessons with their proofs, and of the 213 trainer puzzles
untouched since the audit began. Each claim was checked with python-chess, and
the engine was used for evaluative claims only.

- Boards without both kings (engine-invalid): back-rank-05 (White king added on
  h1); mate-in-2-02 (h1); tactics-mix-13 (a black king on g6; on g8 it allowed
  Ra8#).
- Drawn captures that tested nothing: every move scored 0.00. first-steps-01/02/03/06
  got pawns on both sides, so the capture is now the only winning move (gaps of
  +2.1 to +6.6). first-steps-08: Qe4+ and Qe5+ also forked, so pawns on d6 and f5
  now cover e5 and e4 (Qxg7 +3.3; next −0.9). forks-06: K+Q against K+N won
  after any move. New board `6k1/pp2rpp1/7p/n7/3Q4/8/PP3PPP/6K1 w`: Qd8+ forks
  the g8 king and the a5 knight (+7.9; next +2.4). Found by exhaustive search.
- Decline lines that were misdescribed: back-rank-02 (declining costs Black only
  a rook trade, not a rook); back-rank-12 (Qxf8+ is recaptured). promotion-11
  moves were bold instead of chips, and it named only one reply.
- Lesson fixes: tactics-12 s1 "six squares of empty rank" → five; endgames-08 s4
  "rook on d1 guards the queening square" (it is behind the pawn); endgames-11 s5
  "rook on the third rank" → sixth (the corpus counts ranks from White's side);
  basics-09 s3 move count listed three of four moves per side; strategy-02 blockquote
  "their pawns cannot reach it" (the f-pawn can, at a cost); endgame-04 "stepping
  back with Kd4/Kf4" → sideways.
- Proof fixes: philidor-proof "pinning" → keeping on the back rank;
  remove-defender-proof and thinking-process-proof understated material;
  strategy-06 "no piece left that moves on the dark squares" → no bishop.
- Trainer claim fixes (each verified): back-rank-mate-01 absolute "always";
  back-rank-mate-08 "long diagonal"; defence-03 omitted Ka5; discovery-02/04/07/09/12
  (a "queen up" that was level, "busy stepping out of check" with three blocks
  available, "rook" for "bishop", "a queen down" for level material); fork-03
  "side by side"; fork-11 "fork square"; king-hunt-06 (the setup called a
  developed rook undeveloped, and the hint was garbled); king-hunt-09 "force";
  king-hunt-10 "between your queen and your rook" (not a line); mate-in-one-11
  missing e8 coverage; mate-in-one-12 material; mate-in-two-05 "rakes the dark
  squares" (g6 is light); overload-06/08/11 (the bishop was "dragged off d8" from
  d7, and a queen "took the square it vacated"); pawn-ending-03 (Kd5 by a king
  already on d5); pawn-ending-04 backtick and "Black's" for "White's";
  pawn-ending-05 "beside" → behind; pawn-ending-06; pin-01 "long"; pin-10 typo;
  promotion-01 (Rd8 also blocks); promotion-03 (Ka7/Kb7 keep the rook guarded, so
  there is no skewer win; rewritten); promotion-04; remove-guard-06/07/09/10
  ("pawn count", and the king also guards g7/h7); rook-ending-02 (f8=B also hits
  g7, but only draws; backticks); skewer-06 (b6 is guarded by the f2 bishop, not
  the rook that moved); smothered-01 "any check at all is mate"; smothered-12 title
  duplicated decoy-12's apart from the apostrophe; trapped-01/04 (the escape-square
  count); zugzwang-01/03/04/05 (b3+ runs into Qxb3#); zwischenzug-04/05/08/09
  ("hangs the rook, and it does"; "rook covers g7" where Black's own pawn stands).
- 40 explanation fields had moves in bold; they are chips now. Every remaining
  bold span is a square or a term.
- Screen hits judged sound and left: opening and strategy proofs, and lesson
  plans whose near-equal rivals the prompt or setup rules out (plan-naming, as
  in the first pass); culture-08 s3 Bd6, the historical Immortal Game move;
  basics-04 s6 exf6 (−0.15 against +1.15), since the beat teaches en passant
  itself and makes no claim that it is best; mates of different lengths where
  the authored mate is the shortest.
- New flags triaged: forks-06 (2 replies, both lose the knight); tactics-mix-13
  (a castling puzzle ends level by design).

### Third pass (2026-09-17): cross-checks, a full read of the teaching puzzles, and history sources

- Mechanical cross-checks over all 441 puzzles: "forced/only" claims against the
  real reply counts; square-color claims; "White/Black to move" against the FEN;
  titles unique after stripping punctuation, case and curly apostrophes. All five
  hits were correct in context.
- Defense-substitution screen: for every non-mate line, can another defender reply
  keep the material the scripted reply loses? Hits: forks-01 (…Kb5 guards the queen
  and Nxc5 Kxc5 is a dead draw, so the fork won nothing). New board
  `8/5ppp/3k4/q7/8/8/1N3PPP/6K1 w`, found by search: Nc4+ forks d6 and a5, and
  no king move reaches a5 (+4.5; next −7.6). discovered-04 now says a king
  recapture on b8 still leaves rook against bare king. The other hits were
  already covered in their prose (promotion-07, remove-defender-proof,
  xray-proof, opening lines).
- Full claims read of all 201 teaching puzzles. Fixes: culture-03 ("mated on the
  sixth move"; the engine mates faster); f7-sacrifice-proof ("Qe6+ leaves it
  nowhere": Kf8/Kd8/Ne7 are legal, and all are mated within two); windmill-proof
  (dropped the false "back to g7 lets the queen take it", since Rg7+ Qxg7 Bxg7 wins
  the queen too); openings-08 ("…Qe7 still leaves White a pawn up" is false:
  Nf3 d5 d3 dxe4 dxe4 Qxe4+ regains it); openings-10 ("Nxb5 wins even more
  cleanly" → just as strong); strategy-09 (the d4 knight "loses its pawn support",
  which it never had); endgame-04 (Kd4/Kf4 also won, so it made a poor review
  puzzle; the White king moved to d4, and now Kd5 +3.4 is the only win, every
  other move 0.00).
- History sources (web and replay): Tal–Tringov 1964, Karpov–Korchnoi 1974,
  Steinitz–Sellman 1885 and Bogoljubow–Botvinnik 1936 were each replayed from
  their published scores to the exact proof FEN. Chigorin–Lebedev matches
  wtharvey's Moscow 1900 position a few moves later, dated "Moscow 1900/01" now
  because databases split the date. The "Rubinstein game of 1903" in
  greek-gift-proof could not be sourced, so the attribution was removed and the
  board kept. Lesson dates were checked against known history; endgames-08 now
  calls Lucena's book the oldest surviving book on the modern game (Caxton's 1474
  book is older, but it is an allegory).
- Code comment in academy_providers.dart updated to 201 teaching / 101 surplus.
- Open design issue (not content): Sharpen reviews a proof or pool puzzle with no
  text and accepts only solution[0]. 23 teaching puzzles have an engine-equal
  alternative that Sharpen would mark wrong. Their setups name the goal, but
  Sharpen does not show setups: openings-01/06/08/10/11/13/14/15/16/18,
  strategy-01/07/08/09/10, notation-proof, board-proof, tactics-mix-05/13,
  history-06, endgames-04, back-rank-12. Searches for unique boards failed for
  the Lucena and back-rank-12 shapes.
- Sharpen design issue resolved (user chose to show the setup): `SharpenChallenge`
  now carries `prompt` (the puzzle's `setup`, or the play step's `prompt` in the
  fallback), and `SharpenScreen` renders it under "Find the move". New widget
  test in `sharpen_screen_test.dart` (not run here). LESSON_STYLE §8 and CLAUDE.md
  updated. Setups that described the position without naming a goal gained one
  (openings-01/06/08/10/11/13/14/15/16, strategy-01/08/09/10, tactics-mix-05,
  back-rank-12). Each goal rules out the engine-equal rival without naming the
  move (P02 clean).

### Progress snapshot (2026-09-14, end of the pass)
- Lessons with their proofs: 100 of 100 done. The 21 agent-written lessons
  were re-read claim by claim in the second pass (2026-09-17).
- Puzzles: all 441 (240 trainer + 201 teaching: 100 proofs + 101 surplus) pass
  the §8 prose gate.
- Gates: lint_lessons 0 errors (1 triaged flag, tactics-15 step 6);
  lint_puzzles 0 errors (17 triaged flags); puzzles check 0 errors (173
  triaged flags — the 167 of this pass plus the six triaged under "New gate
  check: a claimed mate must be forced" below); packs --check,
  content.dart and app_check are clean.
- Not run here: `flutter test` and `flutter analyze` (the user runs these).

---

## Engine screen, made repeatable (September 2026)

The evaluative half of this audit used to be a person driving inline `python3`
heredocs against Homebrew Stockfish — this file's own protocol note says *"no
scripts are written to disk"*, so the guarantee could not be re-run and an
edited puzzle could gain a second solution with nothing to catch it.

It is now a gate:

```sh
sh packages/karpa_engine/tool/build_host.sh     # Stockfish 19, the app's own sources
dart run tool/puzzles.dart check --engine       # one process, depth 20, MultiPV 5
```

It drives **one** Stockfish process through the app's own `UciEngineService`,
and it replaced `rivals()` — a depth-4 negamax on material alone that used to
answer "is this move unique?" and could not.

**Thresholds.** No rival within 50cp of the authored first move. A *mating*
rival must mate at least as fast: in a winning position almost any sane move
mates eventually, and a mate in 9 is not a second solution to a mate in 4.
Proven ≤5-ply mates are skipped — `chess_proofs.dart` settles those by
exhaustion, which is stronger than an engine opinion.

**Skipped: 54 goal-named drills.** `openings`, `strategy`, `history`,
`culture` and `endgames`, plus `board-proof`, `notation-proof`,
`tactics-mix-05` and `tactics-mix-13`. CLAUDE.md is explicit that these state
the goal in the prompt *because* they have several good moves; holding them to
"one good move" measures them against a rule they were never written to.

### Result: 387 screened, 4 findings, 0 content changes needed

| id | finding | verdict |
|---|---|---|
| `back-rank-02` | authored `Re8` not in the engine's top 5 | **prose already correct** — see below |
| `back-rank-12` | authored `Qd8` not in the engine's top 5 | **prose already correct** — see below |
| `tactics-mix-05` | `exd5 (+1.13)` ties `Nxe5 (+1.13)` | prompt names the pawn *and* the capturer; now skipped |
| `tactics-mix-13` | `O-O-O` not in top 5 | castling drill, prompt names the move; now skipped |

### New gate check: a claimed mate must be forced

`_outcome` asked whether the mating key move was *unique* but never whether it
was a mating move **at all** — so a line ending in `#` passed even when
nothing forced it. Six puzzles claim a mate that the first move does not
force: `back-rank-02`, `back-rank-12`, `history-07`, `openings-03`,
`openings-09`, `overload-proof`.

All six were read, and all six are **legitimate**, so this is a flag rather
than an error: an opening trap shows what happens *if* the opponent blunders,
and that blunder is the lesson. What such a puzzle must never do is call the
reply forced — the concern recorded against `back-rank-02`/`back-rank-12`
earlier in this file. Their prose already handles it (*"Black does better to
decline with a pawn move that gives the king air…"*), and `overload-proof`
says it outright: *"Nothing was offered and nothing was forced."*

### Prover soundness

`movesForcingMateIn` returned a **partial** list when its node budget ran out,
with no way for the caller to tell, so a search that gave up read as "the key
move is unique". Both prover entry points now report exhaustion and the gate
treats it as an error. Re-running found **zero** affected puzzles: the hole
was latent, not active.

---

## Release-readiness pass (2026-09-23)

A read-only re-check before the first store release, then two changes.

- **The engine is the one the content was judged by.** All 85 vendored files
  under `packages/karpa_engine/stockfish/` are byte-identical to the official
  `sf_19` tag (commit `edb0d9db`), with nothing from upstream `src/` or
  `scripts/` missing.
- **No chess changed since the engine screen.** Every English edit after
  `3b62591` is prose only — apostrophes and a few wordings, no FEN, line or
  answer — so the Stockfish 19 screen recorded above still covers every
  position. It was not re-run.
- **Gates:**

  | Gate | Result |
  |---|---|
  | `content.dart` | 0 errors, 0 flags |
  | `app_check` | clean |
  | `lint_lessons` | 0 errors, 1 flag |
  | `lint_puzzles` | 0 errors, 17 flags |
  | `puzzles.dart check` | 0 errors, 173 flags |
  | `packs --check` | up to date |
  | `translations.dart` | 0 errors, 0 flags |

  All flags are the triaged ones.
- **New: the Studio library is gated.** `content.dart` now loads all 240 games
  of `games/games.json` through the Studio's own `MoveTree.fromPgn`. It checks:
  - every game loads, and its stored SAN is what the Studio writes;
  - both players are named and the result is decisive;
  - a final mate agrees with the result;
  - `plies` and the collection counts are right;
  - no id or move list repeats.

  It passed first time: 240 games, 0 errors. "Every move replayed before it
  was kept" was a promise about how the library was built, and nothing kept
  it true afterwards.
- **New: an imported game must start on a position Stockfish accepts.**
  `MoveTree.fromPgn` now reads a `[FEN]` tag through `engineAcceptedPosition`,
  not the tolerant reader. Stockfish 19 exits its process — the app's — on a
  position it refuses, and the Studio analyses what it loads. The bundled
  corpus is unaffected: lessons and puzzles never reach the engine, and no
  bundled game has a `[FEN]` tag.
