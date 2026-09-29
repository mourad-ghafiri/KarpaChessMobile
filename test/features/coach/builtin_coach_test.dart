import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/features/coach/domain/builtin_coach.dart';
import 'package:karpachess/features/coach/domain/coach_service.dart';

/// Stub translate: returns the key plus sorted params inline, e.g.
/// 'coach.builtin.bestMove.recommendation{move:Nf3}'. Interpolation is the
/// i18n layer's job — the coach only passes keys and params.
String stubT(String key, [Map<String, Object?>? params]) {
  if (params == null || params.isEmpty) return key;
  final entries = params.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return '$key{${entries.map((e) => '${e.key}:${e.value}').join(',')}}';
}

/// Key-only stub: drops params entirely, so any '{' surviving in an answer
/// must have been written by the coach itself.
String keyOnlyT(String key, [Map<String, Object?>? params]) => key;

/// Stub pluralize: appends the count so a test can see which number the
/// responder handed over, without pinning a real CLDR category (that is
/// `plural_rules_test.dart`'s job).
String stubP(String key, int count, [Map<String, Object?>? params]) =>
    stubT(key, {...?params, 'n': count});

/// Key-only pluralize, for the no-unreplaced-brace sweep.
String keyOnlyP(String key, int count, [Map<String, Object?>? params]) => key;

const startpos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const kpEndgame = '8/8/8/4k3/8/8/4P3/4K3 w - - 0 40';

void main() {
  final coach = BuiltinCoach(stubT, stubP);

  group('bestMove', () {
    test('with bestMoveHint in the opening (exact output)', () async {
      const ctx = CoachContext(fen: startpos, bestMoveHint: 'e4', evalCp: 20);
      final answer = await coach.askIntent(CoachIntent.bestMove, ctx);
      expect(
        answer.markdown,
        'coach.builtin.bestMove.recommendation{move:e4}\n\n'
        'coach.builtin.bestMove.whyHeader\n'
        'coach.builtin.bestMove.castle\n'
        'coach.builtin.bestMove.develop{squares:b1, c1, f1, g1}\n'
        'coach.builtin.bestMove.center\n'
        '\ncoach.builtin.bestMove.evalSuffix'
        '{eval:coach.builtin.eval.balanced{pawns:0.20}}',
      );
    });

    test('without an engine answer it says so, and recommends nothing',
        () async {
      const ctx = CoachContext(fen: startpos);
      final answer = await coach.askIntent(CoachIntent.bestMove, ctx);
      expect(answer.markdown,
          startsWith('coach.builtin.bestMove.noEngine\n\n'));
      // It must not name a move it has not evaluated.
      expect(answer.markdown, isNot(contains('recommendation')));
    });

    test('without hint and without sample goes straight to why', () async {
      const ctx = CoachContext(fen: startpos);
      final answer = await coach.askIntent(CoachIntent.bestMove, ctx);
      expect(answer.markdown, startsWith('coach.builtin.bestMove.whyHeader'));
      expect(answer.markdown,
          contains('coach.builtin.bestMove.evalSuffix'
              '{eval:coach.builtin.eval.unclear}'));
    });

    test('endgame branch pushes passed pawns and king activity', () async {
      const ctx = CoachContext(fen: kpEndgame);
      final answer = await coach.askIntent(CoachIntent.bestMove, ctx);
      expect(
          answer.markdown,
          contains('coach.builtin.bestMove.passedEnd'
              '{n:1,squares:e2}'));
      expect(answer.markdown, contains('coach.builtin.bestMove.activeKing'));
    });
  });

  group('evaluation', () {
    test('positive eval credits the side to move', () async {
      const ctx = CoachContext(fen: startpos, evalCp: 150);
      final answer = await coach.askIntent(CoachIntent.evaluation, ctx);
      expect(
          answer.markdown,
          contains('coach.builtin.evaluation.engine{eval:'
              'coach.builtin.eval.better'
              '{pawns:1.50,side:game.side.white,sign:+}}'));
    });

    test('negative eval credits the opponent', () async {
      const ctx = CoachContext(fen: startpos, evalCp: -150);
      final answer = await coach.askIntent(CoachIntent.evaluation, ctx);
      expect(
          answer.markdown,
          contains('coach.builtin.eval.better'
              '{pawns:-1.50,side:game.side.black,sign:}'));
    });

    test('small eval is balanced, missing eval is unclear', () async {
      const near = CoachContext(fen: startpos, evalCp: -15);
      final a1 = await coach.askIntent(CoachIntent.evaluation, near);
      expect(a1.markdown,
          contains('coach.builtin.eval.balanced{pawns:-0.15}'));

      const none = CoachContext(fen: startpos);
      final a2 = await coach.askIntent(CoachIntent.evaluation, none);
      expect(a2.markdown, contains('coach.builtin.eval.unclear'));
    });

    test('black to move flips the eval perspective', () async {
      const fen =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1';
      const ctx = CoachContext(fen: fen, evalCp: 150);
      final answer = await coach.askIntent(CoachIntent.evaluation, ctx);
      expect(
          answer.markdown,
          contains('coach.builtin.eval.better'
              '{pawns:1.50,side:game.side.black,sign:+}'));
    });
  });

  group('lastMove', () {
    test('no history yields the none message', () async {
      const ctx = CoachContext(fen: startpos);
      final answer = await coach.askIntent(CoachIntent.lastMove, ctx);
      expect(answer.markdown, 'coach.builtin.lastMove.none');
    });

    test('annotated capture-with-check (exact output)', () async {
      const ctx = CoachContext(
        fen: startpos,
        sanHistory: ['e4', 'e5', 'Bc4', 'Nc6', 'Bxf7+'],
        lastMoveSan: 'Bxf7+',
        bestMoveHint: 'Kxf7',
      );
      final answer = await coach.askIntent(CoachIntent.lastMove, ctx);
      expect(
        answer.markdown,
        'coach.builtin.lastMove.line{anns:coach.builtin.lastMove.capture, '
        'coach.builtin.lastMove.check,san:Bxf7+}\n\n'
        'coach.builtin.lastMove.evalLine{eval:coach.builtin.eval.unclear}'
        'coach.builtin.lastMove.topChoice{move:Kxf7}',
      );
    });

    test('quiet move and castling annotations', () async {
      const quiet = CoachContext(fen: startpos, lastMoveSan: 'Nf3');
      final a1 = await coach.askIntent(CoachIntent.lastMove, quiet);
      expect(a1.markdown,
          startsWith('coach.builtin.lastMove.quiet{san:Nf3}'));

      const long = CoachContext(fen: startpos, lastMoveSan: 'O-O-O');
      final a2 = await coach.askIntent(CoachIntent.lastMove, long);
      expect(
          a2.markdown,
          startsWith('coach.builtin.lastMove.line'
              '{anns:coach.builtin.lastMove.castleQueenside,san:O-O-O}'));

      const short = CoachContext(fen: startpos, lastMoveSan: 'O-O');
      final a3 = await coach.askIntent(CoachIntent.lastMove, short);
      expect(
          a3.markdown,
          startsWith('coach.builtin.lastMove.line'
              '{anns:coach.builtin.lastMove.castleKingside,san:O-O}'));

      const promo = CoachContext(fen: startpos, lastMoveSan: 'e8=Q#');
      final a4 = await coach.askIntent(CoachIntent.lastMove, promo);
      expect(
          a4.markdown,
          startsWith('coach.builtin.lastMove.line'
              '{anns:coach.builtin.lastMove.checkmate, '
              'coach.builtin.lastMove.promote,san:e8=Q#}'));
    });
  });

  group('tactics', () {
    test('flags loose pieces and the exposed enemy king', () async {
      // Black to move; white knight on e4 is undefended.
      const ctx = CoachContext(fen: '4k3/8/8/8/4N3/8/8/4K3 b - - 0 1');
      final answer = await coach.askIntent(CoachIntent.tactics, ctx);
      expect(answer.markdown,
          startsWith('coach.builtin.tactics.header{side:game.side.black}'));
      expect(
          answer.markdown,
          contains('coach.builtin.tactics.loose'
              '{list:coach.builtin.pieceOn'
              '{piece:♞ chess.piece.n,square:<b>e4</b>},n:1}'));
      expect(
          answer.markdown,
          contains('coach.builtin.tactics.exposedKing'
              '{notes:coach.builtin.kingNote.startingSquare,'
              'score:coach.builtin.kingScore.waiting}'));
      expect(answer.markdown, contains('coach.builtin.tactics.footer'));
    });

    test('mentions the enemy queen as a tempo target', () async {
      const ctx = CoachContext(fen: '3qk3/8/8/8/8/8/PPP5/1K6 w - - 0 20');
      final answer = await coach.askIntent(CoachIntent.tactics, ctx);
      expect(answer.markdown,
          contains('coach.builtin.tactics.queenTarget{square:d8}'));
    });
  });

  group('chip intents bypass routing', () {
    test('every intent produces a non-empty answer', () async {
      const ctx = CoachContext(
        fen: startpos,
        sanHistory: ['e4', 'e5'],
        lastMoveSan: 'e5',
        bestMoveHint: 'Nf3',
        evalCp: 25,
      );
      for (final intent in CoachIntent.values) {
        final answer = await coach.askIntent(intent, ctx);
        expect(answer.markdown, isNotEmpty, reason: 'intent: $intent');
      }
    });

    test('kingSafety chip answers with the king safety report', () async {
      const ctx = CoachContext(fen: startpos);
      final answer = await coach.askIntent(CoachIntent.kingSafety, ctx);
      expect(answer.markdown,
          startsWith('coach.builtin.kingSafety.header'));
      expect(answer.markdown,
          contains('who:coach.builtin.kingSafety.you'));
      expect(answer.markdown,
          endsWith('coach.builtin.kingSafety.footer'));
    });
  });

  group('robustness', () {
    test('never throws on a malformed FEN', () async {
      const ctx = CoachContext(fen: 'this is not a fen');
      for (final intent in CoachIntent.values) {
        final answer = await coach.askIntent(intent, ctx);
        expect(answer, isA<CoachAnswer>(), reason: 'intent: $intent');
      }
      final routed = await coach.askIntent(CoachIntent.bestMove, ctx);
      expect(routed, isA<CoachAnswer>());
    });

    test('no answer contains an unreplaced { — params stay out of the text',
        () async {
      final keyCoach = BuiltinCoach(keyOnlyT, keyOnlyP);
      const contexts = [
        CoachContext(
          fen: startpos,
          sanHistory: ['e4', 'e5', 'Nf3'],
          lastMoveSan: 'Nf3',
          bestMoveHint: 'Nc6',
          evalCp: 34,
        ),
        CoachContext(fen: kpEndgame),
        CoachContext(fen: 'k7/3p4/8/8/3P4/3P4/8/K7 b - - 0 25', evalCp: -80),
      ];
      for (final ctx in contexts) {
        for (final intent in CoachIntent.values) {
          final answer = await keyCoach.askIntent(intent, ctx);
          expect(answer.markdown, isNot(contains('{')),
              reason: 'intent: $intent');
          expect(answer.markdown, isNot(contains('}')),
              reason: 'intent: $intent');
        }
      }
    });
  });
}
