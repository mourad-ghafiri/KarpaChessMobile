import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/core/ui/move_list_card.dart';
import 'package:karpachess/engine/domain/move_classifier.dart';

// The shared move-list surface: paired rows, current-ply highlight, jump
// taps, and the LTR guarantee that keeps "1. e4" from bidi-reordering
// under an RTL app locale.

String _t(String key, [Map<String, Object?>? params]) => key;

List<MoveListEntry> _line(List<String> sans) => [
  for (var i = 0; i < sans.length; i++)
    MoveListEntry(san: sans[i], moveNumber: i ~/ 2 + 1, isWhite: i.isEven),
];

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  TextDirection direction = TextDirection.ltr,
  double width = 400,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: SizedBox(width: width, child: card)),
      ),
    ),
  );
}

void main() {
  testWidgets('flows pairs into columns, row-major, when wide', (
    tester,
  ) async {
    // The panel under a portrait tablet's board: 792dp inside the card holds
    // three 220dp pairs, so 1-3 share a line and 4 wraps to the next.
    await _pump(
      tester,
      MoveListCard(
        t: _t,
        entries: _line(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4']),
        currentIndex: 6,
      ),
      width: 800,
    );
    final one = tester.getTopLeft(find.text('1.'));
    expect(tester.getTopLeft(find.text('2.')).dy, one.dy);
    expect(tester.getTopLeft(find.text('3.')).dy, one.dy);
    expect(tester.getTopLeft(find.text('2.')).dx, greaterThan(one.dx));
    expect(tester.getTopLeft(find.text('3.')).dx, greaterThan(one.dx));
    expect(tester.getTopLeft(find.text('4.')).dy, greaterThan(one.dy));
    expect(tester.getTopLeft(find.text('4.')).dx, one.dx);
  });

  testWidgets("keeps one column at a side pane's width", (tester) async {
    // The widest side pane hands its list 428dp — narrower than two pairs.
    await _pump(
      tester,
      MoveListCard(
        t: _t,
        entries: _line(['e4', 'e5', 'Nf3', 'Nc6']),
        currentIndex: 3,
      ),
      width: 428,
    );
    final one = tester.getTopLeft(find.text('1.'));
    expect(tester.getTopLeft(find.text('2.')).dy, greaterThan(one.dy));
    expect(tester.getTopLeft(find.text('2.')).dx, one.dx);
  });

  testWidgets('pairs plies into numbered fullmove rows', (tester) async {
    await _pump(
      tester,
      MoveListCard(t: _t, entries: _line(['e4', 'e5', 'Nf3']), currentIndex: 2),
    );
    // Three plies → two rows: "1." (e4 e5) and "2." (Nf3 + empty cell).
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('3.'), findsNothing);
    expect(find.textContaining('Nf3'), findsOneWidget);
  });

  testWidgets('black-first entries open their own row', (tester) async {
    // A study from a Black-to-move FEN: the first ply is Black's.
    await _pump(
      tester,
      MoveListCard(
        t: _t,
        entries: const [
          MoveListEntry(san: 'Re8', moveNumber: 24, isWhite: false),
          MoveListEntry(san: 'Qd2', moveNumber: 25, isWhite: true),
        ],
        currentIndex: 0,
      ),
    );
    expect(find.text('24.'), findsOneWidget);
    expect(find.text('25.'), findsOneWidget);
  });

  testWidgets('onSelect fires with the tapped ply index', (tester) async {
    int? tapped;
    await _pump(
      tester,
      MoveListCard(
        t: _t,
        entries: _line(['e4', 'e5', 'Nf3', 'Nc6']),
        currentIndex: 3,
        onSelect: (i) => tapped = i,
      ),
    );
    await tester.tap(find.textContaining('e5'));
    expect(tapped, 1);
  });

  testWidgets('read-only when onSelect is null', (tester) async {
    await _pump(
      tester,
      MoveListCard(t: _t, entries: _line(['e4', 'e5']), currentIndex: 1),
    );
    expect(
      find.descendant(
        of: find.byType(MoveListCard),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('quality glyph renders in the current cell', (tester) async {
    await _pump(
      tester,
      MoveListCard(
        t: _t,
        entries: const [
          MoveListEntry(
            san: 'Qh5',
            moveNumber: 1,
            isWhite: true,
            quality: MoveQuality.blunder,
          ),
        ],
        currentIndex: 0,
        onSelect: (_) {},
      ),
    );
    expect(find.textContaining('??'), findsOneWidget);
  });

  testWidgets('empty list shows the placeholder', (tester) async {
    await _pump(
      tester,
      MoveListCard(t: _t, entries: const [], currentIndex: -1),
    );
    expect(find.text('commentator.moves'), findsOneWidget);
  });

  testWidgets('SAN stays LTR under an RTL ancestor', (tester) async {
    await _pump(
      tester,
      MoveListCard(t: _t, entries: _line(['e4', 'e5']), currentIndex: 1),
      direction: TextDirection.rtl,
    );
    // The list body forces LTR regardless of the app locale's direction.
    final body = tester.widget<Directionality>(
      find
          .descendant(
            of: find.byType(MoveListCard),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(body.textDirection, TextDirection.ltr);
  });
}
