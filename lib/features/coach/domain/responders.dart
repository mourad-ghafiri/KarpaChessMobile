/// One responder per coach intent. Every user-facing string is produced
/// through the injected [Translate] with `coach.builtin.*` keys and params —
/// interpolation itself is the i18n layer's job.
library;

import 'coach_service.dart';
import 'position_features.dart';

const Map<String, String> _pieceGlyph = {
  'p': '♟',
  'n': '♞',
  'b': '♝',
  'r': '♜',
  'q': '♛',
  'k': '♚',
};

bool _hasText(String? s) => s != null && s.isNotEmpty;

class CoachResponders {
  const CoachResponders(this.t, this.p);

  final Translate t;

  /// Count-bearing messages. The responders never choose a singular or plural
  /// word themselves — they hand the number over and let the language decide.
  final Pluralize p;

  // ---------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------

  String sideName(String color) =>
      t(color == 'w' ? 'game.side.white' : 'game.side.black');

  String pieceLower(String letter) => t('chess.piece.${letter.toLowerCase()}');

  String pieceCap(String letter) {
    final n = pieceLower(letter);
    if (n.isEmpty) return n;
    return n[0].toUpperCase() + n.substring(1);
  }

  /// Renders an eval line from a centipawn score given from the
  /// side-to-move's perspective.
  String formatEval(int? cp, String turn) {
    if (cp == null) return t('coach.builtin.eval.unclear');
    final pawns = (cp / 100).toStringAsFixed(2);
    if (cp.abs() < 30) return t('coach.builtin.eval.balanced', {'pawns': pawns});
    final sideColor = cp > 0 ? turn : (turn == 'w' ? 'b' : 'w');
    final side = sideName(sideColor);
    final sign = cp > 0 ? '+' : '';
    return t('coach.builtin.eval.better',
        {'sign': sign, 'pawns': pawns, 'side': side});
  }

  /// Markdown block listing Stockfish's MultiPV candidates, or '' if absent.
  String topLinesBlock(CoachContext ctx, String turn) {
    if (ctx.topLines.isEmpty) return '';
    final items = <String>[];
    for (var i = 0; i < ctx.topLines.length; i++) {
      final line = ctx.topLines[i];
      items.add(t('coach.builtin.topLines.item', {
        'rank': i + 1,
        'san': '{{${line.san}}}',
        'eval': formatEval(line.evalCp, turn),
      }));
    }
    return '\n\n${t('coach.builtin.topLines.header')}\n${items.join('\n')}';
  }

  /// One-line opponent-threat warning, or '' when no scan is available.
  ///
  /// [moverColor] is a colour code ('w'/'b'), never a display name — the
  /// caller that passed `sideName(pos.turn)` here made every threat read as
  /// White's, because `'White' == 'w'` is false.
  String threatBlock(CoachContext ctx, String moverColor) {
    final threat = ctx.threat;
    if (threat == null) return '';
    final opponent = moverColor == 'w' ? 'b' : 'w';
    return '\n\n${t('coach.builtin.threatLine', {
          'side': sideName(opponent),
          'san': '{{${threat.san}}}',
          'eval': formatEval(threat.evalCp, opponent),
        })}';
  }

  String scoreLabel(String key) => t('coach.builtin.kingScore.$key');

  /// "Rook on e4" as ONE template: the preposition and the word order
  /// belong to the language, not to Dart. Japanese puts the square first,
  /// and two translators gave up and wrote an em dash when this was glued
  /// together here.
  String pieceOn(String piece, String square) =>
      t('coach.builtin.pieceOn', {'piece': piece, 'square': square});

  String looseList(List<LoosePiece> loose) =>
      loose.map((l) => pieceOn(pieceCap(l.piece), l.square)).join(', ');

  // ---------------------------------------------------------------
  // Responders
  // ---------------------------------------------------------------

  String respondBestMove(
    CoachContext ctx,
    ParsedPosition pos,
    MaterialReport mr,
    String ph,
    KingSafetyReport ksW,
    KingSafetyReport ksB,
    PawnStructureReport psW,
    PawnStructureReport psB,
    List<LoosePiece> loose,
  ) {
    final turn = pos.turn;
    var out = '';
    if (_hasText(ctx.bestMoveHint)) {
      out +=
          '${t('coach.builtin.bestMove.recommendation', {'move': ctx.bestMoveHint})}\n\n';
    } else {
      // No engine answer means no recommendation. This used to fall back to
      // `ctx.legalSample[0]` — the first legal move in board order — and
      // present it as "Without deeper search, consider: Na3." The position
      // notes below are observations and stand on their own.
      out += '${t('coach.builtin.bestMove.noEngine')}\n\n';
    }
    out += '${t('coach.builtin.bestMove.whyHeader')}\n';

    if (ph == 'opening') {
      final dev = developmentReport(pos, turn);
      if (!dev.castled) out += '${t('coach.builtin.bestMove.castle')}\n';
      if (dev.minorHome.isNotEmpty) {
        out +=
            '${p('coach.builtin.bestMove.develop', dev.minorHome.length, {'squares': dev.minorHome.join(', ')})}\n';
      }
      final cc = centerControl(pos, turn);
      if (cc.pawnsOnCenter == 0) {
        out += '${t('coach.builtin.bestMove.center')}\n';
      }
    } else if (ph == 'middlegame') {
      if (loose.isNotEmpty) {
        out +=
            '${p('coach.builtin.bestMove.loose', loose.length, {'list': looseList(loose)})}\n';
      }
      final opp = turn == 'w' ? ksB : ksW;
      if (opp.score != 'safe') {
        out +=
            '${t('coach.builtin.bestMove.oppKing', {'score': scoreLabel(opp.score)})}\n';
      }
      final own = turn == 'w' ? ksW : ksB;
      if (own.score == 'danger') {
        out += '${t('coach.builtin.bestMove.ownKing')}\n';
      }
    } else {
      final ps = turn == 'w' ? psW : psB;
      if (ps.passed.isNotEmpty) {
        out +=
            '${p('coach.builtin.bestMove.passedEnd', ps.passed.length, {'squares': ps.passed.join(', ')})}\n';
      }
      out += '${t('coach.builtin.bestMove.activeKing')}\n';
      if (mr.diff != 0) {
        // One whole sentence per case. This used to be three translated
        // fragments glued in English word order ("You're {state} {n} points
        // — {advice}"), which also read "1 points".
        out += '${p(mr.diff > 0 ? 'coach.builtin.bestMove.ahead' : 'coach.builtin.bestMove.behind', mr.diff.abs())}\n';
      }
    }
    out +=
        '\n${t('coach.builtin.bestMove.evalSuffix', {'eval': formatEval(ctx.evalCp, turn)})}';
    out += topLinesBlock(ctx, turn);
    return out;
  }

  String respondTactics(
    CoachContext ctx,
    ParsedPosition pos,
    List<LoosePiece> loose,
  ) {
    // Two different things, deliberately named apart: the colour code drives
    // logic, the display name only ever reaches a template.
    final turnName = sideName(pos.turn);
    final ph = phaseKey(pos, ctx.sanHistory.length);
    final ksW = kingSafety(pos, 'w', ph, t);
    final ksB = kingSafety(pos, 'b', ph, t);
    final targetSide = pos.turn == 'w' ? 'b' : 'w';
    final theirKing = targetSide == 'w' ? ksW : ksB;

    final lines = <String>[];
    if (loose.isNotEmpty) {
      final list = loose
          .map((l) => pieceOn('${_pieceGlyph[l.piece]} ${pieceLower(l.piece)}',
              '<b>${l.square}</b>'))
          .join(', ');
      lines.add(p('coach.builtin.tactics.loose', loose.length, {'list': list}));
    } else {
      lines.add(t('coach.builtin.tactics.defended'));
    }
    if (theirKing.score != 'safe') {
      final joined = theirKing.notes.join(', ');
      final notes = joined.isEmpty ? t('coach.builtin.tactics.openLines') : joined;
      lines.add(t('coach.builtin.tactics.exposedKing',
          {'score': scoreLabel(theirKing.score), 'notes': notes}));
    }
    if (pos.material[targetSide]!['q']! > 0) {
      PlacedPiece? q;
      for (final piece in pos.pieces[targetSide]!) {
        if (piece.piece == 'q') {
          q = piece;
          break;
        }
      }
      // Only once the queen has committed. This used to fire whenever the
      // opponent simply HAD a queen, so the tactics scan asked whether you
      // could chase her off d8 on move one — noise that made the rest of the
      // scan look equally unconsidered.
      final home = targetSide == 'w' ? 'd1' : 'd8';
      if (q != null && q.square != home) {
        lines.add(t('coach.builtin.tactics.queenTarget', {'square': q.square}));
      }
    }
    if (_hasText(ctx.bestMoveHint)) {
      lines.add(t('coach.builtin.tactics.engineSuggests',
          {'move': ctx.bestMoveHint}));
    }

    return '${t('coach.builtin.tactics.header', {'side': turnName})}\n\n'
        '${lines.map((l) => '• $l').join('\n')}'
        '${threatBlock(ctx, pos.turn)}\n\n'
        '${t('coach.builtin.tactics.footer')}';
  }

  String respondPlan(
    CoachContext ctx,
    ParsedPosition pos,
    MaterialReport mr,
    String ph,
    KingSafetyReport ksW,
    KingSafetyReport ksB,
    PawnStructureReport psW,
    PawnStructureReport psB,
  ) {
    final turn = sideName(pos.turn);
    final myKS = pos.turn == 'w' ? ksW : ksB;
    final oppKS = pos.turn == 'w' ? ksB : ksW;
    final myPawns = pos.turn == 'w' ? psW : psB;
    final plans = <String>[];

    if (ph == 'opening') {
      final dev = developmentReport(pos, pos.turn);
      if (dev.minorHome.isNotEmpty) {
        plans.add(p('coach.builtin.plan.developMinors', dev.minorHome.length,
            {'squares': dev.minorHome.join(', ')}));
      }
      if (!dev.castled) plans.add(t('coach.builtin.plan.castle'));
      if (dev.queenMoved && dev.minorHome.isNotEmpty) {
        plans.add(t('coach.builtin.plan.queenEarly'));
      }
      final cc = centerControl(pos, pos.turn);
      if (cc.pawnsOnCenter == 0) plans.add(t('coach.builtin.plan.centerPawn'));
    } else if (ph == 'middlegame') {
      if (myKS.score == 'danger') plans.add(t('coach.builtin.plan.kingDanger'));
      if (myKS.castled && oppKS.castled && myKS.notes.isNotEmpty) {
        plans.add(t('coach.builtin.plan.oppositeWings'));
      }
      if (myPawns.passed.isNotEmpty) {
        plans.add(p('coach.builtin.plan.pushPassed', myPawns.passed.length,
            {'squares': myPawns.passed.join(', ')}));
      }
      if (myPawns.isolated.isNotEmpty) {
        plans.add(p('coach.builtin.plan.isolated', myPawns.isolated.length,
            {'squares': myPawns.isolated.join(', ')}));
      }
      plans.add(t('coach.builtin.plan.improveWorst'));
    } else {
      if (myPawns.passed.isNotEmpty) {
        plans.add(p('coach.builtin.plan.racePassed', myPawns.passed.length,
            {'squares': myPawns.passed.join(', ')}));
      }
      plans.add(t('coach.builtin.plan.activateKing'));
      if (mr.diff > 0) {
        plans.add(p('coach.builtin.plan.aheadTrade', mr.diff));
      } else if (mr.diff < 0) {
        plans.add(p('coach.builtin.plan.behindKeep', mr.diff.abs()));
      }
      if (myPawns.count <= 2) plans.add(t('coach.builtin.plan.fewPawns'));
    }
    final phase = t('coach.builtin.phase.$ph');
    return '${t('coach.builtin.plan.header', {'side': turn, 'phase': phase})}\n\n'
        '${plans.map((p) => '• $p').join('\n')}';
  }

  String respondLastMove(CoachContext ctx, ParsedPosition pos) {
    final san = ctx.lastMoveSan;
    if (!_hasText(san)) return t('coach.builtin.lastMove.none');
    san!;
    final anns = <String>[];
    if (san.contains('x')) anns.add(t('coach.builtin.lastMove.capture'));
    if (san.endsWith('+')) anns.add(t('coach.builtin.lastMove.check'));
    if (san.endsWith('#')) anns.add(t('coach.builtin.lastMove.checkmate'));
    if (san.startsWith('O-O-O')) {
      anns.add(t('coach.builtin.lastMove.castleQueenside'));
    } else if (san.startsWith('O-O')) {
      anns.add(t('coach.builtin.lastMove.castleKingside'));
    }
    if (san.contains('=')) anns.add(t('coach.builtin.lastMove.promote'));
    var out = anns.isNotEmpty
        ? t('coach.builtin.lastMove.line',
            {'san': san, 'anns': anns.join(', ')})
        : t('coach.builtin.lastMove.quiet', {'san': san});
    out +=
        '\n\n${t('coach.builtin.lastMove.evalLine', {'eval': formatEval(ctx.evalCp, pos.turn)})}';
    if (_hasText(ctx.bestMoveHint)) {
      out += t('coach.builtin.lastMove.topChoice', {'move': ctx.bestMoveHint});
    }
    return out;
  }

  String respondEvaluation(
    CoachContext ctx,
    ParsedPosition pos,
    MaterialReport mr,
    String ph,
    KingSafetyReport ksW,
    KingSafetyReport ksB,
    PawnStructureReport psW,
    PawnStructureReport psB,
  ) {
    final phase = t('coach.builtin.phase.$ph');
    final turn = sideName(pos.turn);
    final out = <String>[
      t('coach.builtin.evaluation.header', {'phase': phase, 'side': turn}),
      '',
    ];

    var diffSuffix = t('coach.builtin.evaluation.equalSuffix');
    if (mr.diff != 0) {
      diffSuffix = t('coach.builtin.evaluation.diffSuffix', {
        'side': mr.diff > 0 ? sideName('w') : sideName('b'),
        'n': mr.diff.abs(),
      });
    }
    out.add(t('coach.builtin.evaluation.material', {
      'w': mr.whitePoints,
      'b': mr.blackPoints,
      'diff': diffSuffix,
    }));
    out.add(t('coach.builtin.evaluation.engine',
        {'eval': formatEval(ctx.evalCp, pos.turn)}));

    String notesFmt(List<String> arr) => arr.isNotEmpty
        ? t('coach.builtin.evaluation.notesFmt', {'notes': arr.join(', ')})
        : '';
    out.add(t('coach.builtin.evaluation.whiteKing',
        {'score': scoreLabel(ksW.score), 'notes': notesFmt(ksW.notes)}));
    out.add(t('coach.builtin.evaluation.blackKing',
        {'score': scoreLabel(ksB.score), 'notes': notesFmt(ksB.notes)}));

    List<String> weakList(PawnStructureReport ps) {
      final bits = <String>[];
      for (final s in ps.isolated) {
        bits.add(t('coach.builtin.evaluation.isolatedPrefix', {'sq': s}));
      }
      for (final f in ps.doubled) {
        bits.add(t('coach.builtin.evaluation.doubledPrefix', {'file': f}));
      }
      return bits;
    }

    final wWeak = weakList(psW);
    final bWeak = weakList(psB);
    if (wWeak.isNotEmpty) {
      out.add(t('coach.builtin.evaluation.pawnWeaknessesWhite',
          {'list': wWeak.join(', ')}));
    }
    if (bWeak.isNotEmpty) {
      out.add(t('coach.builtin.evaluation.pawnWeaknessesBlack',
          {'list': bWeak.join(', ')}));
    }

    if (psW.passed.isNotEmpty) {
      out.add(p('coach.builtin.evaluation.passedWhite', psW.passed.length,
          {'squares': psW.passed.join(', ')}));
    }
    if (psB.passed.isNotEmpty) {
      out.add(p('coach.builtin.evaluation.passedBlack', psB.passed.length,
          {'squares': psB.passed.join(', ')}));
    }
    if (_hasText(ctx.bestMoveHint)) {
      out.add(
          t('coach.builtin.evaluation.topMove', {'move': ctx.bestMoveHint}));
    }
    return out.join('\n') + topLinesBlock(ctx, pos.turn);
  }

  String respondKingSafety(
    KingSafetyReport ksW,
    KingSafetyReport ksB,
    String turnColor,
  ) {
    final head = t('coach.builtin.kingSafety.header');
    final youStr = t('coach.builtin.kingSafety.you');
    final oppStr = t('coach.builtin.kingSafety.opponent');
    final castledW =
        ksW.castled ? t('coach.builtin.kingSafety.castledSuffix') : '';
    final castledB =
        ksB.castled ? t('coach.builtin.kingSafety.castledSuffix') : '';
    final joinedW = ksW.notes.join(', ');
    final joinedB = ksB.notes.join(', ');
    final notesW =
        joinedW.isEmpty ? t('coach.builtin.kingSafety.noConcerns') : joinedW;
    final notesB =
        joinedB.isEmpty ? t('coach.builtin.kingSafety.noConcerns') : joinedB;
    return '$head\n\n'
        '${t('coach.builtin.kingSafety.line', {
          'side': sideName('w'),
          'who': turnColor == 'w' ? youStr : oppStr,
          'score': scoreLabel(ksW.score),
          'castled': castledW,
          'notes': notesW,
        })}\n'
        '${t('coach.builtin.kingSafety.line', {
          'side': sideName('b'),
          'who': turnColor == 'b' ? youStr : oppStr,
          'score': scoreLabel(ksB.score),
          'castled': castledB,
          'notes': notesB,
        })}\n\n'
        '${t('coach.builtin.kingSafety.footer')}';
  }
}
