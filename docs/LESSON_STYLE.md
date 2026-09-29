# The lesson style guide

Every lesson in `assets/data/lessons/en/` is written to this document, and
`dart run tool/lint_lessons.dart` enforces the half of it that can be checked
by a machine. Rule ids below (`L01`…) are the linter's.

Lessons and puzzles ship in **English** only; the eight-language i18n bundles
are UI strings and are not covered here. Puzzles have their own contract in §8.

---

## 1. What a lesson is

**SEE → PLAY → OWN.** Teach beats show, play beats ask, and the proof puzzle
named by `Lesson.proof` is the OWN beat the app appends at the end.

The learner is reading a phone, one beat at a time, with a chessboard above the
text. They came to play chess, not to read about it. Every word is rent.

### The three faults this guide exists to prevent

1. **The template.** The corpus this guide replaced was 74 lessons of exactly
   `teach · play · teach · play`, each teach beat ~190 words with two `##`
   headings, a bullet list and a closing blockquote maxim. Every lesson was the
   same lesson. Sameness is what "boring" means here — the sentences were often
   fine.
2. **The leak.** 81 of 214 play prompts contained their own answer
   (*"Make the defining trade with **{{cxd4}}**"*). Being asked and having to
   produce is the whole value of a play beat. A prompt that answers itself is
   dead weight the reader taps through.
3. **The forward reference.** The 4th lesson said "developed", the 13th said
   "tempo"; both words belong to the 44th. A reader who meets a word they were
   never given concludes the fault is theirs.

---

## 2. Voice

**Second person, present tense, active.** *You* are playing. The board in front
of you is *this* board.

**Short sentences carry weight.** Vary the length. A four-word sentence after a
twenty-word one lands. Twenty in a row is a wall.

**Concrete before abstract.** Name the square, the piece, the cost. "Black's
knight has nowhere to go" beats "the knight lacks mobility".

**Dry wit is welcome. Goofiness is not.** The good line already in this corpus
— *"that knight has gone d1, c3, b1, d2, b3, which looks like a man who has
lost his keys until you see where it is going"* — is the target. No jokes at
the reader's expense, no exclamation marks, no emoji in prose.

**Never flatter and never console.** Do not write "great job", "don't worry" or
"this is tricky!". The learner finds out how they did by playing the move.

### Openings (L09, L11)

Open with a claim, a tension or a number. Never with a definition, and never
with any of these:

> In this lesson · Let's learn · Today we · As we saw · As you know ·
> It is important to · Remember that · Now that you know · First of all

Two lessons must not open the same way. If three lessons in an art all start
"White has just…", two of them are wrong.

### People (L09)

The opponent is **Black**, **White**, or *your opponent*. Never *he*, *him*,
*his*. This is not decoration: chess prose is clearer when it names the side,
and the corpus previously called the opponent "he" while giving pieces genders
at random — the bishop was "her" in one lesson and the knight "him" in another.

Pieces are **it**. A piece is a piece.

Real, named people (Morphy, Steinitz, Polgár) take *they/them* unless the
lesson has a documented reason to do otherwise.

### Register (L07)

**American spelling**, matching the app's own UI strings: *center*, *color*,
*defense*, *favor*, *analyze*, *maneuver*, *practice* (noun and verb).

Standard chess names keep their own spelling — *the French Defense*,
*the Sicilian Defense* — but consistently.

---

## 3. Shape

There is **no fixed skeleton**. A lesson may be four beats or nine. What is
fixed is the budget, so no lesson can become a wall again.

### The teach beat (L08)

| | |
|---|---|
| body | **≤ 110 words** |
| `##` headings | **at most one**, and **none at all when the step has a `title`** |
| blockquotes | **at most one per lesson**, not per step |
| bullet run | **≤ 4 items** |

The panel already renders `title` in the display face. A `##` under it is the
same signal twice, so it is banned outright when a title is present — the
redundancy is the reason the old lessons felt like documentation.

A teach beat carries **one idea**. If it carries two, it is two beats. Splitting
a 190-word wall into two 70-word beats is the single most useful structural
move available, and it costs nothing: two teach steps may share the same FEN.

There is no mandatory closing maxim. A lesson may end on one — once.

### The play beat (L04, L08)

The prompt is **one sentence, ≤ 24 words**, and it states the **goal**, never
the move:

```
bad   Make the defining trade with **{{cxd4}}**, swapping a flank pawn
      for a central one and opening a file for good.
good  Trade your wing pawn for White's center pawn and open the file
      your rook wants.
```

The prompt says what you are trying to achieve; the position says which move
achieves it. The hint is the second nudge and it does not contain the answer
either — it points at the thing that makes the answer findable ("count the
defenders of f7").

**The answer never appears in its own `prompt` or `hint`.** The linter checks
every `targetSan` against both. Five lessons are exempt — `basics-00-board-and-setup`,
`basics-07-notation` and `culture-03-recording-games` because *naming or
reading the move is the exercise*, and the mechanics beats of
`basics-03-castling` and `basics-02b-promotion` because the written form of
the mechanic is what is being demonstrated. That list lives in
`tool/src/lesson_glossary.dart` and does not grow without a reason written
next to it.

**And the beat before it must not have played the answer either.** A prompt can
be scrupulous about not naming the move while the teach step in front of it
stands on the *same position* and animates that exact move as a chip. The reader
is then being asked to repeat something they just watched. This is L12, and it
only fires where it means something: same FEN, exactly one accepted answer, and
not one of the allowlisted lessons. The piece lessons that open on "jump the
knight anywhere an L will carry it" accept every legal move, so showing all
eight first is the drill, not a leak.

Where a play beat accepts several moves, prefer **one** — the escalating stuck
help only draws the full arrow when there is exactly one accepted answer.

### The lesson (L10)

- First step is a `teach`. The reader has to be told something before being
  asked anything.
- Last authored step is a `play`. The OWN beat follows it.
- The proof puzzle stands on a position **the lesson has not already played**
  (L13). A proof that repeats a play step is the same question twice, and
  Sharpen then reviews the pattern forever on the one board where it was taught.
- A play position belongs to **one lesson** (L15). Two lessons asking the same
  question on the same board test memory, not the pattern; the later lesson
  picks another moment. No puzzle may repeat a lesson's play position either
  (§8).
- `title`, `summary` and `proof` are all set. `summary` is rendered under the
  title on the art card, so it is a promise, not a label: *"Two kings, one
  tempo, and who has to blink"*, not *"Learn about the opposition"*.

---

## 4. The board

### Chips (L01, L02, L05)

**Every move in prose is a `{{chip}}`.** Chips are tappable — a tap previews the
move on the board as an arrow — and in a teach body they drive what the board
does. `` `backticks` `` render as inert code: reserve them for text that must
*not* become a move (a file name, a symbol like `=` being explained).

A teach body's chips are read by `BoardScript.of`
(`lib/features/academy/domain/board_script.dart`) and become exactly one of
two things:

- **menu** — 2+ chips, **all legal from that step's own FEN**. Drawn as arrows
  all at once: "here are the squares this piece reaches."
- **sequence** — anything else. Chained move by move and animated: "watch this
  line."

The classification is total because a real line alternates sides — after
White's `e4`, Black's `d5` is illegal from that same position, so a line can
never be misread as a menu. But it fails **silently** in one direction: a chip
that neither chains nor fits the menu is *dropped*, and the reader sees an
animation that stops early with no error anywhere. `L01` exists solely for
that, and it is the one mechanical risk in rewriting prose.

Practical consequences when you write:

- Chips are de-duplicated in order. Repeating a move later in the body is a
  no-op; **reordering changes the animation.**
- Adding a second chip to a body that had one can flip the whole step from
  animation to menu. Check the step's FEN, not your intent.
- Chips in a `prompt` are fine and do not pre-draw the answer, but they must
  not *be* the answer (L04). Chips in a `hint` are rendered but not tappable.

### Claims about the position (L03)

Anything the prose asserts about a square is checked against the FEN. Write
*"the knight on f6"* only when there is a knight on f6. This catches the most
common decay in a corpus like this: the prose is edited, the position is not.

Squares are bare and lowercase: **f7**, **the e-file**, **the sixth rank**.
Not `f7`, not "F7".

### Positions that could not happen (L14)

A teaching FEN may be pedagogical — a lone king, a board with three pieces on it.
What it may not quietly be is **impossible**: a position where the side *not* to
move is in check could never arise in a game, because the player who left their
king attacked would already have lost it. The draws lesson shipped exactly that
— a white knight attacking the black king on White's turn — and narrated "White
is dead lost" over a board where White was one move from taking a king.

It is a flag rather than an error, because a one-king teaching board is a
supported shape and cannot trip it. Treat the flag as a defect anywhere the
lesson is about the rules.

---

## 5. Order: you may only use what has been taught

The lessons are met in one order: `artOrder`
(`lib/features/academy/domain/skill_map.dart`) zipped with each art's list in
`assets/data/lessons/index.json`. Foundations · The Story of Chess · The Blade ·
The First Moves · The Finish · The Plan · The Hunt · The Chess World.

`tool/src/lesson_glossary.dart` records, for each load-bearing term, the lesson
that **owns** it. Using the term before that lesson is an error (L06).

Three ways to comply, in order of preference:

1. **Say the thing instead of naming it.** "Knights are often the first pieces
   to come out" needs no word for *development*.
2. **Move the idea to where it belongs.** If a Foundations lesson genuinely
   needs the concept, the concept is misplaced, not the lesson.
3. **Earn the exception.** A lesson may be added to a term's `okBefore` list
   when it *defines the term in place* — bolded, in one clause, at first use.
   The list is short and every entry is deliberate.

Terms already introduced earlier are free to reuse, and reuse is good: it is
what makes the corpus feel like one course rather than a hundred articles.

---

## 6. Worked example

The old first beat of `tactics-01-the-fork` — 210 words, two `##` headings, a
bullet list, a numbered procedure and a maxim:

> A **fork** is a single move that attacks two enemy pieces at the same time.
> Your opponent can only save one — you keep the other.
>
> ## Why the knight is the king of forks
> The knight jumps over pieces, attacks eight squares from a strong central
> post, and **no piece can block its check**. …
>
> ## The geometry
> A knight on a square *X* hits eight squares arranged like the corners of two
> interlocking rectangles. …
>
> ## How to spot it
> 1. Find every undefended enemy piece. …
>
> > If you remember nothing else about tactics, remember this: …

Two beats, 63 and 58 words, one idea each:

> **Two Pieces, One Move**
>
> Black's king sits on c6 and the queen on d5. Your knight on c2 is one hop
> from b4 — and from b4 it touches both.
>
> {{Nb4+}}. The check has to be answered, and answering it does nothing at all
> for the queen.

> **Why the Knight**
>
> Every other piece attacks along a line, and a line can be blocked. A knight
> jumps, so a knight's check has exactly two answers: move the king, or take
> the knight.
>
> That is why the knight is the forker. It attacks two squares that have
> nothing to do with each other.

Then the play beat asks, without telling:

> Find the square that attacks Black's king and queen at the same time.

---

## 7. Checklist before a lesson is done

- [ ] `dart run tool/lint_lessons.dart <file>` — 0 errors
- [ ] `dart run tool/content.dart` — 0 errors
- [ ] No play prompt or hint contains its own answer
- [ ] Every move in prose is a chip; no backticked SAN
- [ ] Every claim about a square matches the FEN
- [ ] No term used that the reader has not been given
- [ ] It opens differently from the lesson before it
- [ ] Read it aloud. If you get bored, so will they.

---

## 8. Puzzles

Every puzzle file is held to one contract — the 240 rated trainer puzzles, the
lesson proofs and the Sharpen review pools alike — and
`dart run tool/lint_puzzles.dart` enforces it (rule ids `P01`…). Whether the
chess is right is `dart run tool/puzzles.dart check`'s job.

### Where each field is read

| field | shown | so it says |
|---|---|---|
| `setup` | before the move; in a lesson's OWN beat its chips are tappable on the starting position | the goal and the tension, never the move |
| `hint` | on request | the second nudge, never the move |
| `title` | once the puzzle is over — in the trainer and the academy alike | a name, which may name the pattern |
| `explanation` | once the puzzle is over | why the line works, briefly |

Sharpen serves proofs and pool puzzles under "Find the move" with the
puzzle's `setup` beneath it, and grades only the first move. The setup is
therefore the whole brief: when a position has several good moves (an opening
plan, a notation drill, castling), the setup must name the goal that singles
out the authored one. Where no sentence can do that, the position is a bad
review puzzle, however well it is written.

### The contract

- **P01 shape.** `explanation` opens `## The Idea` and has no other heading, and
  runs **≤ 90 words** after it. `setup` and `hint` are **≤ 30 words**. `title` is
  **≤ 6 words** of plain text: titles render as plain type, so markup would show
  literally.
- **P02 no answer.** `setup` and `hint` never contain the first move, and never
  pick out its landing square as a chip, in bold or as code. The proof of a
  lesson exempt from L04 (naming or reading the move is its exercise) inherits
  the exemption.
- **P03 squares are bare.** `{{g7}}` renders as a move chip. Write g7. A chip
  that is a legal pawn move somewhere on the line is a move, and fine.
- **P04 setup chips are legal** in the starting position, where they are tapped.
- **P05 claims.** A piece the setup or hint puts on a square is on it; one the
  explanation puts on a square is on it somewhere along the line. A flag rather
  than an error, because "has just taken your queen on d1" is true of a piece
  that is gone — read each one.
- **P06 register.** §2 applies unchanged: no *he* or *she*, American spelling,
  none of the banned phrases (*Takeaway:*, *luft*…), no backticked moves — except
  in the proof of a lesson allowed them (basics-07, culture-03), which inherits
  that allowance the way it inherits P02's.
- **P07 a proof is its lesson's last beat.** No term before the lesson that owns
  it (§5). The side to move should be the side the lesson plays — a flag,
  because a trap shown from the other side can be the point.
- **P08 titles are unique** across the corpus.
- **P09 the line ends on the learner's move** (`puzzles.dart check`).

### What the solve loops accept

Exactly the authored line, with one exception: when the authored move
checkmates, **any** checkmating move is accepted (`acceptsAuthored` in
`lib/core/chess/san_moves.dart`, asked by the trainer, the academy's play and
proof beats, and Sharpen). A twin mate on the final move is therefore fine. A
twin anywhere earlier is an error: for mates of up to five plies,
`puzzles.dart check` proves that every learner move before the last is the only
one that still forces the mate in time.

### One board, one place

A position is asked about once. A puzzle never repeats another puzzle or any
lesson's play position (`puzzles.dart check`), and a play position belongs to
one lesson (L15). The reader who meets a board twice is answering from memory.

An explanation is written like a teach beat: concrete, second person, one idea.
"The bishop on d3 is aimed at h7" beats "the bishop has a strong diagonal".
