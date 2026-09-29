import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/ui/picker_strip.dart';

// The app's one horizontal picker: a filmstrip on a phone, and a grid where a
// surface can show every choice at once (Settings on a tablet).

List<Widget> _choices(int n) => [
  for (var i = 0; i < n; i++)
    SizedBox(key: ValueKey('c$i'), width: 100, height: 50),
];

Future<void> _pump(WidgetTester tester, PickerStrip strip) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        // The Settings dialog's content width on a tablet.
        child: SizedBox(width: 646, child: strip),
      ),
    ),
  ),
);

Offset _at(WidgetTester tester, int i) =>
    tester.getTopLeft(find.byKey(ValueKey('c$i')));

void main() {
  testWidgets('a strip keeps every choice on one scrolling row', (
    tester,
  ) async {
    await _pump(tester, PickerStrip(children: _choices(10)));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(_at(tester, 9).dy, _at(tester, 0).dy);
  });

  testWidgets('columns lay the choices out as rows of equal cells', (
    tester,
  ) async {
    await _pump(tester, PickerStrip(columns: 5, children: _choices(10)));
    expect(find.byType(SingleChildScrollView), findsNothing);
    // Two rows of five: the sixth choice starts the second row, under the
    // first.
    expect(_at(tester, 4).dy, _at(tester, 0).dy);
    expect(_at(tester, 5).dy, greaterThan(_at(tester, 0).dy));
    expect(_at(tester, 5).dx, _at(tester, 0).dx);
    // Each choice is centred in an equal cell: (646 - 4 * 12) / 5 = 119.6
    // wide, so neighbours sit 131.6 apart.
    expect(
      _at(tester, 1).dx - _at(tester, 0).dx,
      moreOrLessEquals(131.6, epsilon: 0.01),
    );
  });

  testWidgets('a short last row keeps the grid, not the stretch', (
    tester,
  ) async {
    await _pump(tester, PickerStrip(columns: 5, children: _choices(7)));
    // Choices 6 and 7 sit in the first two cells of the second row.
    expect(_at(tester, 5).dx, _at(tester, 0).dx);
    expect(_at(tester, 6).dx, _at(tester, 1).dx);
  });

  testWidgets('a choice wider than its cell scales down, never overflows', (
    tester,
  ) async {
    // 140dp cards in 119.6dp cells — a selected card's thicker border on a
    // small tablet's Settings dialog came out 0.4dp too wide.
    await _pump(
      tester,
      PickerStrip(
        columns: 5,
        children: [
          for (var i = 0; i < 5; i++)
            SizedBox(key: ValueKey('c$i'), width: 140, height: 50),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const ValueKey('c0'))).width,
      moreOrLessEquals((646 - 4 * 12) / 5, epsilon: 0.01),
    );
  });
}
