import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../theme/tokens_context.dart';

/// The pieces one player has taken, and how far ahead that leaves them.
///
/// Renders as a single clipped line — `♛ ♜×2 ♟×3   +7` — grouped by piece and
/// most valuable first, with a count only where there is more than one. The
/// alternative, one glyph per capture in the order they happened, turns a
/// normal game into `♟♟♟♟♟♟♟♟` and stops being readable at a glance.
///
/// **It must never grow.** Player bars live in the fixed-height slots
/// `ModePanes` reserves, and the board's size is computed from what those slots
/// reserve — so a captured row that wrapped onto a second line would resize the
/// board as pieces came off it. One line, [maxLines] of 1, clipped at the end.
class CapturedPieces extends StatelessWidget {
  const CapturedPieces({
    super.key,
    required this.roles,
    required this.semanticsLabel,
    this.lead = 0,
  });

  /// What a screen reader announces instead of the glyph row.
  ///
  /// The row is built from decorative characters (♟♞♝) that VoiceOver and
  /// TalkBack cannot name, so the whole strip is replaced by this sentence.
  /// The caller resolves it — the widget stays free of i18n.
  final String semanticsLabel;

  /// Most valuable first; see `CapturedMaterial.capturedBy`.
  final List<Role> roles;

  /// Pawns this player is ahead by. Zero renders nothing, so only the side
  /// actually winning material carries a number.
  final int lead;

  /// The one place a piece becomes a character. The filled set for both
  /// colours: the outline glyphs (♙♘♗) vanish against the app's light
  /// surfaces, and these are what the board's own player bars already used.
  ///
  /// The pawn is the exception, drawn as its outline ♙: ♟ is the one chess
  /// glyph that is also an emoji, and the system drew it as a glossy black
  /// emoji pawn — darker than every piece beside it, and nearly invisible on
  /// a dark card. Flutter does not honour the text-presentation selector.
  static const glyphs = {
    Role.pawn: '♙',
    Role.knight: '♞',
    Role.bishop: '♝',
    Role.rook: '♜',
    Role.queen: '♛',
    Role.king: '♚',
  };

  /// `[queen, rook, rook, pawn]` → `♛ ♜×2 ♟`. Relies on [roles] arriving
  /// grouped, which `CapturedMaterial` guarantees by construction.
  String get _text {
    final parts = <String>[];
    for (var i = 0; i < roles.length;) {
      final role = roles[i];
      var run = 1;
      while (i + run < roles.length && roles[i + run] == role) {
        run++;
      }
      parts.add(run == 1 ? glyphs[role]! : '${glyphs[role]!}×$run');
      i += run;
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty && lead <= 0) return const SizedBox.shrink();
    return Semantics(
      label: lead > 0 ? '$semanticsLabel, +$lead' : semanticsLabel,
      excludeSemantics: true,
      child: _row(context),
    );
  }

  Widget _row(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Flexible(
          child: Text(
            _text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: TextStyle(fontSize: 14, height: 1.1, color: tokens.textDim),
          ),
        ),
        if (lead > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$lead',
            maxLines: 1,
            // The glyphs' tight line height, not the mono font's own: left
            // to its natural metrics this made the row 18dp, and the side to
            // move — whose accent border is 0.4dp thicker a side — overflowed
            // its PlayerBarCard slot whenever it also led on material.
            style: TextStyle(
              fontFamily: context.type.font.mono,
              fontSize: 12.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: tokens.accent,
            ),
          ),
        ],
      ],
    );
  }
}
