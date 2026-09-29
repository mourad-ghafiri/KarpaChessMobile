import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';
import 'package:karpachess/features/academy/domain/board_script.dart';

import 'src/corpus.dart';
import 'src/findings.dart';
import 'src/lesson_glossary.dart';
import 'src/prose_rules.dart';

/// The lesson **style** gate: everything `tool/content.dart` does not look at.
///
///   dart run tool/lint_lessons.dart              # all 100
///   dart run tool/lint_lessons.dart tactics-01-the-fork.json
///
/// `content.dart` proves a lesson *loads*: the FENs parse and the answers are
/// legal. It never reads a word of prose, which is how a corpus of a hundred
/// lessons came to share one shape, hand out its own answers in 81 of 214 play
/// prompts, and use "tempo" thirty lessons before the lesson that teaches it.
///
/// The rules are written down in `docs/LESSON_STYLE.md`; the ids below are the
/// ones that document refers to. An **error** is a fact — the answer is in the
/// prompt, the chip is dropped, the piece is not on that square. A **flag** is
/// a screen: something that is usually wrong and occasionally deliberate.
///
/// The rules it shares with `tool/lint_puzzles.dart` live in
/// `tool/src/prose_rules.dart`. English only — which is all the content there is.
void main(List<String> args) {
  final corpus = Corpus();
  final lessons = corpus.lessons('en');
  final order = corpus.readingOrder();
  final proofs = _proofFiles(corpus);
  final proofFens = _proofFens(corpus);

  final wanted = args.map(_basename).toSet();
  final targets = wanted.isEmpty
      ? order
      : [
          for (final file in order)
            if (wanted.contains(file)) file,
        ];
  for (final missing in wanted.difference(order.toSet())) {
    stderr.writeln('no such lesson: $missing');
  }

  final findings = <Finding>[];
  for (final file in targets) {
    final lesson = lessons[file];
    if (lesson == null) {
      findings.add(Finding.error('lessons/en/$file', 'named by the manifest, not on disk'));
      continue;
    }
    findings.addAll(_lint(file, lesson, order, proofs, proofFens));
  }
  // Corpus-wide rules can only be judged against the whole corpus.
  if (wanted.isEmpty) {
    findings.addAll(_sameness(order, lessons));
    findings.addAll(_sharedPlayPositions(order, lessons));
  }

  exit(report(findings, 'linted ${targets.length} lesson(s)'));
}

/// Every proof puzzle's starting position, keyed by file name.
Map<String, String> _proofFens(Corpus corpus) {
  final out = <String, String>{};
  for (final entry in corpus.puzzles().entries) {
    out['${entry.key}.json'] = entry.value.puzzle.fen;
  }
  return out;
}

Set<String> _proofFiles(Corpus corpus) {
  final dir = Directory('${corpus.root}/puzzles/en');
  if (!dir.existsSync()) return const {};
  // By path, not by type: dartchess exports its own `File` (the a-h kind).
  return dir
      .listSync()
      .map((e) => e.path.split(Platform.pathSeparator).last)
      .where((name) => name.endsWith('.json'))
      .toSet();
}

String _basename(String path) => path.split(Platform.pathSeparator).last;

// ---------------------------------------------------------------------------

Iterable<Finding> _lint(
  String file,
  Lesson lesson,
  List<String> order,
  Set<String> proofs,
  Map<String, String> proofFens,
) sync* {
  final where = 'lessons/en/$file';
  final index = order.indexOf(file);
  final learner = _learnerSide(lesson);

  yield* _lessonShape(where, lesson, proofs);
  yield* _proofIsNew(where, lesson, proofFens);
  yield* _rehearsedAnswer(where, file, lesson);
  yield* _glossary(where, file, lesson, order, index);
  yield* _register(where, lesson);
  yield* _banned(where, lesson);
  yield* _blockquoteBudget(where, lesson);

  for (final (i, step) in lesson.steps.indexed) {
    final at = '$where step ${i + 1}';
    final position = _parse(step.fen);
    if (position == null) continue; // content.dart owns FEN validity.

    switch (step) {
      case TeachStep():
        yield* _chips(at, position, step);
        yield* _claims(at, position, step, learner);
        yield* _teachBudget(at, step);
      case PlayStep():
        yield* _answerLeak(at, file, step);
        yield* _promptBudget(at, step);
        yield* _playClaims(at, position, step);
    }
    yield* _reachable(at, position);
    yield* _backtickSan(at, file, _prose(step));
  }
}

/// The side the learner plays, which is what "your" means in a teach beat.
///
/// It is the lesson's orientation, and `ConceptPlayerScreen` takes that from
/// the first play beat — so this does too.
Side _learnerSide(Lesson lesson) {
  for (final step in lesson.steps) {
    if (step is! PlayStep) continue;
    final position = _parse(step.fen);
    if (position != null) return position.turn;
  }
  return Side.white;
}

/// L10 — the lesson as a whole.
Iterable<Finding> _lessonShape(
  String where,
  Lesson lesson,
  Set<String> proofs,
) sync* {
  if (lesson.title.trim().isEmpty) yield Finding.error(where, 'no title');
  if (lesson.summary.trim().isEmpty) {
    // Rendered under the title on the art card, so an empty one is a hole in
    // the UI rather than an unused field.
    yield Finding.error(where, 'no summary');
  }
  final proof = lesson.proof;
  if (proof == null || proof.trim().isEmpty) {
    yield Finding.error(where, 'no proof puzzle — the lesson has no OWN beat');
  } else if (!proofs.contains(proof)) {
    yield Finding.error(where, 'proof $proof is not in puzzles/en');
  }
  if (lesson.steps.isEmpty) {
    yield Finding.error(where, 'no steps');
    return;
  }
  if (lesson.steps.first is! TeachStep) {
    yield Finding.error(where, 'opens on a play step — tell before you ask');
  }
  if (lesson.steps.last is! PlayStep) {
    yield Finding.error(where, 'ends on a teach step — the proof follows a play beat');
  }
}

/// L13 — the OWN beat must ask something the lesson has not already asked.
///
/// A proof standing on a position the lesson already played is not a proof, it
/// is the same question twice — and Sharpen then reviews that position forever,
/// so the pattern is only ever tested where it was taught.
Iterable<Finding> _proofIsNew(
  String where,
  Lesson lesson,
  Map<String, String> proofFens,
) sync* {
  final fen = proofFens[lesson.proof];
  if (fen == null) return;
  for (final (i, step) in lesson.steps.indexed) {
    if (step is PlayStep && boardKey(step.fen) == boardKey(fen)) {
      yield Finding.error(
        where,
        'the proof ${lesson.proof} stands on the same position as play step '
        '${i + 1} — the OWN beat asks what the PLAY beat just asked',
      );
      return;
    }
  }
}

/// L14 — the side NOT to move must not be in check.
///
/// Such a position cannot arise in a game: the player who left their king
/// attacked would already have lost it. The tolerant reader accepts it on
/// purpose (CLAUDE.md: lesson FENs may be pedagogical), and for a one-king
/// teaching board that is right — which is why this is a flag, not an error.
/// But the draws lesson shipped a board where a white knight was attacking the
/// black king on White's turn, and narrated "White is dead lost" over it.
Iterable<Finding> _reachable(String at, Position position) sync* {
  final board = position.board;
  // A single-king teaching board is the documented shape; it cannot trip this.
  if (board.kingOf(Side.white) == null || board.kingOf(Side.black) == null) {
    return;
  }
  if (position.copyWith(turn: position.turn.opposite).isCheck) {
    yield Finding.flag(
      at,
      'the side not to move is in check — this position cannot arise in a game',
    );
  }
}

/// L12 — a teach beat may not play the next play beat's answer on the board.
///
/// The subtler half of L04. A prompt can be scrupulous about not naming the move
/// and the beat still be worthless, because the teach step immediately before it
/// stands on the same position and *animates the answer*. The reader is asked to
/// repeat something they have just watched.
///
/// Three conditions, and all three are needed. **Same FEN**: a chip shown against
/// a different position is teaching, not rehearsing. **One accepted answer**: the
/// piece lessons open on "jump the knight anywhere an L will carry it" and accept
/// every legal move, so showing all eight first is the drill, not a leak — there
/// is no answer to give away. And **not an allowlisted lesson**, for the same
/// reason those are exempt from L04.
Iterable<Finding> _rehearsedAnswer(
  String where,
  String file,
  Lesson lesson,
) sync* {
  if (answerLeakAllowed.containsKey(file)) return;
  for (var i = 1; i < lesson.steps.length; i++) {
    final play = lesson.steps[i];
    final teach = lesson.steps[i - 1];
    if (play is! PlayStep || teach is! TeachStep) continue;
    if (play.targetSan.length != 1) continue;
    if (play.fen != teach.fen) continue;
    final shown = extractSanTokens(teach.text).map(cleanSan).toSet();
    for (final san in play.targetSan) {
      if (shown.contains(cleanSan(san))) {
        yield Finding.error(
          '$where step ${i + 1}',
          'the beat before it plays $san on this same position — the answer is '
          'animated before it is asked for',
        );
      }
    }
  }
}

/// L01/L02 — the chips a teach body hands to the board.
///
/// `BoardScript.of` drops a chip that neither chains nor fits a menu, and it
/// does it silently: the reader sees an animation that stops early and nothing
/// anywhere says why. This is the one mechanical way a prose rewrite breaks the
/// board, so it is the first rule.
Iterable<Finding> _chips(String at, Position position, TeachStep step) sync* {
  final tokens = extractSanTokens(step.text);
  if (tokens.isEmpty) return;
  final script = BoardScript.of(position, step.text);

  switch (script) {
    case MoveSequence(:final frames):
      final played = frames.length - 1;
      if (played < tokens.length) {
        yield Finding.error(
          at,
          'chip {{${tokens[played]}}} is illegal here and is silently dropped, '
          'along with ${tokens.length - played - 1} after it',
        );
      }
    case MoveMenu(:final moves):
      // A menu means "the squares this piece reaches". Arrows leaving several
      // different squares are almost always a line the classifier could not
      // tell apart, because every move happened to be legal for one side.
      final origins = {for (final m in moves) m.from};
      if (origins.length > 1) {
        yield Finding.flag(
          at,
          '${tokens.length} chips all legal here, so the board draws them as '
          'alternatives from ${origins.length} different squares at once — '
          'if these are a line, they are not being animated',
        );
      }
  }
}

/// L03 — "the knight on f6", "Black's rook on a8", "your queen on d1" are
/// checked against the board.
///
/// The claim may be true of any position the step actually shows: prose that
/// walks through its own chips ("after {{e4}}, the pawn on e4…") describes a
/// later frame, and that is fine. "Your" is the side the lesson has the
/// learner play.
Iterable<Finding> _claims(
  String at,
  Position start,
  TeachStep step,
  Side learner,
) sync* {
  final boards = <Board>[start.board];
  final script = BoardScript.of(start, step.text);
  if (script is MoveSequence) {
    boards.addAll(script.frames.map((f) => f.position.board));
  }

  for (final claim in squareClaims(step.text)) {
    if (!claimHolds(claim, boards, learner: learner)) {
      yield Finding.error(
        at,
        'prose says "${claim.text}" but the position does not have one there',
      );
    }
  }
}

/// L03 for a play beat: its prompt and hint describe exactly one position,
/// the one the learner is looking at, and "your" is the side to move.
Iterable<Finding> _playClaims(String at, Position position, PlayStep step) sync* {
  final text = '${step.prompt}\n${step.hint ?? ''}';
  for (final claim in squareClaims(text)) {
    if (!claimHolds(claim, [position.board], learner: position.turn)) {
      yield Finding.error(
        at,
        'the prompt or hint says "${claim.text}" but the position does not '
        'have one there',
      );
    }
  }
}

/// L04 — a play beat may not answer itself.
Iterable<Finding> _answerLeak(String at, String file, PlayStep step) sync* {
  if (answerLeakAllowed.containsKey(file)) return;
  final haystacks = {'prompt': step.prompt, 'hint': step.hint ?? ''};
  for (final san in step.targetSan) {
    final field = answerLeakIn(san, haystacks);
    if (field != null) {
      yield Finding.error(
        at,
        'the $field contains its own answer ($san) — say the goal, not the move',
      );
    }
  }
}

/// L05 — a move in prose is a chip, never inline code.
Iterable<Finding> _backtickSan(String at, String file, String prose) sync* {
  if (backtickSanAllowed.contains(file)) return;
  for (final span in backtickSans(prose)) {
    yield Finding.error(
      at,
      '`$span` is a move written as inline code — use {{$span}} so it is '
      'tappable and previews on the board',
    );
  }
}

/// L06 — no word the reader has not been given.
Iterable<Finding> _glossary(
  String where,
  String file,
  Lesson lesson,
  List<String> order,
  int index,
) sync* {
  if (index < 0) return;
  final prose = lesson.steps.map(_prose).join('\n');
  for (final term in lessonGlossary) {
    final owner = order.indexOf(term.owner);
    if (owner < 0 || index >= owner) continue;
    if (term.okBefore.contains(file)) continue;
    final match = term.pattern.firstMatch(prose);
    if (match == null) continue;
    yield Finding.error(
      where,
      '"${match[0]}" uses ${term.label}, taught in ${term.owner} '
      '(lesson ${owner + 1}; this is lesson ${index + 1})',
    );
  }
}

/// L07 — one spelling register, and it is the app's.
Iterable<Finding> _register(String where, Lesson lesson) sync* {
  final prose = lesson.steps.map(_prose).join('\n');
  final titles = [lesson.title, lesson.summary].join('\n');
  for (final (found, wanted) in offRegister('$prose\n$titles')) {
    yield Finding.error(where, '"$found" — the corpus is American: "$wanted"');
  }
}

/// L09 — the register the corpus is leaving behind.
Iterable<Finding> _banned(String where, Lesson lesson) sync* {
  final prose = lesson.steps.map(_prose).join('\n');
  for (final phrase in bannedIn(prose)) {
    yield Finding.error(where, 'banned phrase "$phrase"');
  }
  final pronoun = firstPronoun(prose);
  if (pronoun != null) {
    yield Finding.error(
      where,
      '"${pronoun[0]}" — name the side (Black, White, your opponent); '
      'pieces are "it" and people are "they"',
    );
  }
}

/// L08 — one blockquote per lesson, not one per step.
Iterable<Finding> _blockquoteBudget(String where, Lesson lesson) sync* {
  var quotes = 0;
  for (final step in lesson.steps) {
    var inQuote = false;
    for (final line in _prose(step).split('\n')) {
      final isQuote = line.trimLeft().startsWith('>');
      if (isQuote && !inQuote) quotes++;
      inQuote = isQuote;
    }
  }
  if (quotes > 1) {
    yield Finding.error(where, '$quotes blockquotes — a lesson may land on one');
  }
}

/// L08 — the teach beat's budget.
Iterable<Finding> _teachBudget(String at, TeachStep step) sync* {
  const maxWords = 110;
  const maxBullets = 4;

  final words = wordCount(step.text);
  if (words > maxWords) {
    yield Finding.error(at, '$words words — a teach beat is one idea, $maxWords max');
  }

  final headings =
      RegExp(r'^\s*#{2,4}\s', multiLine: true).allMatches(step.text).length;
  final titled = (step.title ?? '').trim().isNotEmpty;
  if (titled && headings > 0) {
    yield Finding.error(
      at,
      'has a title AND $headings heading(s) — the panel renders both, so the '
      'heading is the same signal twice',
    );
  } else if (headings > 1) {
    yield Finding.error(at, '$headings headings in one beat — split the beat');
  }

  var run = 0;
  for (final line in step.text.split('\n')) {
    final isItem = RegExp(r'^\s*([-*]\s|\d+\.\s)').hasMatch(line);
    run = isItem ? run + 1 : 0;
    if (run > maxBullets) {
      yield Finding.error(at, 'a list of more than $maxBullets items — prose it');
      break;
    }
  }
}

/// L08 — the play beat's prompt is one sentence that states the goal.
Iterable<Finding> _promptBudget(String at, PlayStep step) sync* {
  const maxWords = 24;
  final words = wordCount(step.prompt);
  if (words > maxWords) {
    yield Finding.error(at, 'prompt is $words words — one sentence, $maxWords max');
  }
  final sentences = sentenceCount(step.prompt);
  if (sentences > 1) {
    yield Finding.error(at, 'prompt is $sentences sentences — ask one thing');
  }
  if ((step.hint ?? '').trim().isEmpty) {
    yield Finding.flag(at, 'no hint — the hint button will not appear');
  }
}

/// L11 — the corpus-wide sameness rules, which no single lesson can see.
Iterable<Finding> _sameness(
  List<String> order,
  Map<String, Lesson> lessons,
) sync* {
  final headings = <String, List<String>>{};
  final openings = <String, List<String>>{};

  for (final file in order) {
    final lesson = lessons[file];
    if (lesson == null) continue;
    for (final step in lesson.steps) {
      for (final m
          in RegExp(r'^\s*#{2,4}\s+(.+?)\s*$', multiLine: true).allMatches(_prose(step))) {
        headings.putIfAbsent(m[1]!.toLowerCase(), () => []).add(file);
      }
    }
    final first = lesson.steps.firstOrNull;
    if (first is TeachStep) {
      final words = plain(first.text).split(RegExp(r'\s+')).take(5).join(' ');
      if (words.isNotEmpty) {
        openings.putIfAbsent(words.toLowerCase(), () => []).add(file);
      }
    }
  }

  for (final entry in headings.entries) {
    if (entry.value.length > 2) {
      yield Finding.flag(
        'lessons/en',
        'the heading "${entry.key}" appears in ${entry.value.length} lessons',
      );
    }
  }
  for (final entry in openings.entries) {
    if (entry.value.length > 1) {
      yield Finding.flag(
        'lessons/en',
        '${entry.value.length} lessons open "${entry.key}…": ${entry.value.join(', ')}',
      );
    }
  }
}

/// L15 — one board, one place: a play position is asked about by one lesson.
///
/// A reader who meets the same question in two lessons is being tested on
/// memory, not on the pattern. The first lesson in reading order keeps it.
/// (Puzzles repeating a lesson's play position are `tool/puzzles.dart
/// check`'s to catch.)
Iterable<Finding> _sharedPlayPositions(
  List<String> order,
  Map<String, Lesson> lessons,
) sync* {
  final owner = <String, String>{};
  for (final file in order) {
    final lesson = lessons[file];
    if (lesson == null) continue;
    for (final (i, step) in lesson.steps.indexed) {
      if (step is! PlayStep) continue;
      final first = owner.putIfAbsent(boardKey(step.fen), () => file);
      if (first != file) {
        yield Finding.error(
          'lessons/en/$file step ${i + 1}',
          'plays the same position as $first — a board is asked about in one '
          'place',
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------

String _prose(LessonStep step) => switch (step) {
      TeachStep(:final title, :final text) => '${title ?? ''}\n$text',
      PlayStep(:final prompt, :final hint) => '$prompt\n${hint ?? ''}',
    };

Position? _parse(String fen) {
  try {
    return positionFromFen(fen);
  } on Object {
    return null;
  }
}
