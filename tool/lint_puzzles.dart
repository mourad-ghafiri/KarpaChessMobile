import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:karpachess/content/domain/models.dart';
import 'package:karpachess/core/chess/san_moves.dart';
import 'package:karpachess/core/chess/tolerant_position.dart';

import 'src/corpus.dart';
import 'src/findings.dart';
import 'src/lesson_glossary.dart';
import 'src/prose_rules.dart';

/// The puzzle **prose** gate — `docs/LESSON_STYLE.md` §8, rules P01–P08.
///
///   dart run tool/lint_puzzles.dart              # all of them
///   dart run tool/lint_puzzles.dart forks-01 fork-05
///
/// `tool/puzzles.dart check` proves what a line achieves; this reads what the
/// puzzle SAYS about it. One contract for every puzzle, trainer and teaching
/// alike — the pool puzzles Sharpen serves without their text included,
/// because any of them can be promoted to a lesson's proof and then every word
/// is on screen.
///
/// Where each field is shown decides what each rule protects: the setup is
/// read before the move and its chips are tappable on the starting position;
/// the hint is asked for; the title and explanation appear only once the
/// puzzle is over.
void main(List<String> args) {
  final corpus = Corpus();
  final puzzles = corpus.puzzles();
  final lessons = corpus.lessons('en');
  final order = corpus.readingOrder();

  // Which lesson each proof closes. A proof is read as that lesson's last beat,
  // so it is held to that lesson's vocabulary and board orientation.
  final proofOf = <String, String>{
    for (final file in order)
      if (lessons[file]?.proof case final proof?) _id(proof): file,
  };

  final wanted = args.map(_id).toSet();
  for (final missing in wanted.difference(puzzles.keys.toSet())) {
    stderr.writeln('no such puzzle: $missing');
  }

  final findings = <Finding>[];
  final titles = <String, String>{};
  var linted = 0;
  for (final id in puzzles.keys.toList()..sort()) {
    final file = puzzles[id]!;
    // P08 — judged against the whole corpus even on a narrowed run.
    final title = (file.puzzle.title ?? '').trim().toLowerCase();
    final first = title.isEmpty ? id : titles.putIfAbsent(title, () => id);
    if (wanted.isNotEmpty && !wanted.contains(id)) continue;
    linted++;
    if (first != id) {
      findings.add(Finding.error(
          id, 'title "${file.puzzle.title}" is already used by $first'));
    }
    final lessonFile = proofOf[id];
    findings.addAll(_lint(
      file,
      lessonFile,
      lessonFile == null ? null : lessons[lessonFile],
      order,
    ));
  }

  exit(report(findings, 'linted $linted puzzle(s)'));
}

String _id(String name) =>
    name.split(Platform.pathSeparator).last.replaceAll('.json', '');

const _maxExplanation = 90;
const _maxSetup = 30;
const _maxHint = 30;
const _maxTitle = 6;

Iterable<Finding> _lint(
  PuzzleFile file,
  String? lessonFile,
  Lesson? lesson,
  List<String> order,
) sync* {
  final id = file.fileId;
  final puzzle = file.puzzle;
  final Position start;
  try {
    start = positionFromFen(puzzle.fen);
  } on Object {
    return; // content.dart owns FEN validity.
  }
  final line = _replay(start, puzzle.solution);

  final fields = {
    'title': puzzle.title ?? '',
    'setup': puzzle.setup ?? '',
    'hint': puzzle.hint ?? '',
    'explanation': puzzle.explanation ?? '',
  };
  final title = fields['title']!;
  final setup = fields['setup']!;
  final hint = fields['hint']!;
  final explanation = fields['explanation']!;

  // P01 — the shape. Every field is on screen somewhere, and the one the
  // reader meets after a solve is short enough to read on a phone.
  for (final entry in fields.entries) {
    if (entry.value.trim().isEmpty) yield Finding.error(id, '${entry.key} is empty');
  }
  if (explanation.isNotEmpty) {
    if (!explanation.startsWith('## The Idea')) {
      yield Finding.error(id, 'explanation does not open with "## The Idea"');
    }
    final headings =
        RegExp(r'^\s*#', multiLine: true).allMatches(explanation).length;
    if (headings > 1) {
      yield Finding.error(
          id, '$headings headings — "## The Idea" is the only one a puzzle gets');
    }
    final words = wordCount(explanation.replaceFirst('## The Idea', ''));
    if (words > _maxExplanation) {
      yield Finding.error(id, 'explanation is $words words, $_maxExplanation max');
    }
  }
  for (final (field, text, max) in [
    ('setup', setup, _maxSetup),
    ('hint', hint, _maxHint),
  ]) {
    final words = wordCount(text);
    if (words > max) yield Finding.error(id, '$field is $words words, $max max');
  }
  if (title.trim().split(RegExp(r'\s+')).length > _maxTitle) {
    yield Finding.error(id, 'title is longer than $_maxTitle words');
  }
  if (RegExp(r'[*_`#{}]').hasMatch(title)) {
    // Titles render as plain Text, so markup would appear literally.
    yield Finding.error(id, 'title "$title" carries markup; titles are plain text');
  }

  // P02 — the setup and hint point at the goal, never at the move. A proof
  // closing one of the lessons where naming or reading the move IS the
  // exercise (`answerLeakAllowed`) inherits that lesson's exemption.
  final exempt =
      lessonFile != null && answerLeakAllowed.containsKey(lessonFile);
  if (puzzle.solution.isNotEmpty && !exempt) {
    final first = puzzle.solution.first;
    final shown = {'setup': setup, 'hint': hint};
    final leak = answerLeakIn(first, shown);
    if (leak != null) {
      yield Finding.error(id, 'the $leak contains the answer ($first)');
    } else {
      final landing = landingSquareLeakIn(first, shown);
      if (landing != null) {
        yield Finding.error(
            id, 'the $landing picks out the square $first lands on');
      }
    }
  }

  // P03 — a chip is a move. A square is written bare.
  final squareChips = <String>{};
  for (final entry in fields.entries) {
    for (final token in extractSanTokens(entry.value)) {
      if (!RegExp(r'^[a-h][1-8]$').hasMatch(token)) continue;
      if (line.any((p) => legalMoveFromSan(p, token) != null)) continue;
      squareChips.add(token);
      yield Finding.error(
        id,
        '${entry.key}: {{$token}} is a square dressed as a move — write it bare',
      );
    }
  }

  // P04 — setup chips are the tappable ones, previewed on the start position.
  for (final token in extractSanTokens(setup)) {
    if (squareChips.contains(token)) continue;
    if (legalMoveFromSan(start, token) == null) {
      yield Finding.error(
        id,
        'setup chip {{$token}} is not a legal move in the starting position, '
        'where setup chips are tapped',
      );
    }
  }

  // P05 — a sentence about a square is checked against the board. A flag:
  // "has just taken your queen on d1" is true narrative about a piece that is
  // gone, and only a reader can tell that from a stale sentence.
  final learner = start.turn;
  for (final claim in squareClaims('$setup\n$hint')) {
    if (!claimHolds(claim, [start.board], learner: learner)) {
      yield Finding.flag(id, 'setup/hint says "${claim.text}" — not on the board');
    }
  }
  final frames = [for (final p in line) p.board];
  for (final claim in squareClaims(explanation)) {
    if (!claimHolds(claim, frames, learner: learner)) {
      yield Finding.flag(
          id, 'explanation says "${claim.text}" — not on any board of the line');
    }
  }

  // P06 — one register with the lessons.
  final prose = fields.values.join('\n');
  for (final (found, wanted) in offRegister(prose)) {
    yield Finding.error(id, '"$found" — the corpus is American: "$wanted"');
  }
  for (final phrase in bannedIn(prose)) {
    yield Finding.error(id, 'banned phrase "$phrase"');
  }
  final pronoun = firstPronoun(prose);
  if (pronoun != null) {
    yield Finding.error(
      id,
      '"${pronoun[0]}" — name the side (Black, White, your opponent); '
      'pieces are "it" and people are "they"',
    );
  }
  // A proof closing a lesson about the written form of a move (basics-07,
  // culture-03) may print the move as type, exactly as its lesson does.
  if (lessonFile == null || !backtickSanAllowed.contains(lessonFile)) {
    for (final span in backtickSans(prose)) {
      yield Finding.error(id, '`$span` is a move written as inline code — use {{$span}}');
    }
  }

  // P07 — a proof is its lesson's last beat.
  if (lessonFile != null) {
    final index = order.indexOf(lessonFile);
    for (final term in lessonGlossary) {
      final owner = order.indexOf(term.owner);
      if (index < 0 || owner < 0 || index >= owner) continue;
      if (term.okBefore.contains(lessonFile)) continue;
      final match = term.pattern.firstMatch(prose);
      if (match == null) continue;
      yield Finding.error(
        id,
        '"${match[0]}" uses ${term.label}, taught in ${term.owner} (lesson '
        '${owner + 1}) — this proves $lessonFile (lesson ${index + 1})',
      );
    }
    final side = lesson == null ? null : _lessonSide(lesson);
    if (side != null && side != start.turn) {
      yield Finding.flag(
        id,
        'proves $lessonFile, which the learner plays as ${side.name}, but it is '
        '${start.turn.name} to move — the board stays turned the lesson\'s way',
      );
    }
  }
}

/// Every position the line passes through, the start included. Stops at the
/// first illegal move, which `tool/content.dart` reports.
List<Position> _replay(Position start, List<String> line) {
  final out = [start];
  var position = start;
  for (final san in line) {
    final move = legalMoveFromSan(position, san);
    if (move == null) break;
    position = position.playUnchecked(move);
    out.add(position);
  }
  return out;
}

/// The side a lesson's board is turned toward — the first play beat's side
/// to move, as `ConceptPlayerScreen` resolves it.
Side? _lessonSide(Lesson lesson) {
  for (final step in lesson.steps) {
    if (step is! PlayStep) continue;
    try {
      return positionFromFen(step.fen).turn;
    } on Object {
      return null;
    }
  }
  return null;
}
