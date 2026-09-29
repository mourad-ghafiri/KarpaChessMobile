import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/layout/mode_panes.dart';
import 'package:karpachess/core/ui/mode_header_bar.dart';
import 'package:karpachess/core/ui/player_card.dart';

// ModePanes' four compositions. Phones must keep the geometry they have
// always had (users call it perfect); portrait tablets stack with ONE board
// rect shared by every mode; landscape tablets let the board fill the height.
// The expected numbers are worked from the formulas in mode_panes.dart, and
// the working is left in the comments so a failure is quick to check.

ModeLayout _at(double w, double h) =>
    ModePanes.layoutFor(BoxConstraints.tight(Size(w, h)));

/// Placeholder slots, keyed, in the shapes the six modes use.
Widget _mode({
  bool above = true,
  bool below = true,
  bool lead = false,
  bool overlay = false,
  bool toast = false,
}) => ModePanes(
  topBar: const SizedBox.expand(key: Key('top')),
  topBarHeight: ModeHeaderBar.height,
  leadContent: lead
      ? const SizedBox(key: Key('lead'), width: 120, height: 18)
      : null,
  aboveBoard: above ? const SizedBox.expand(key: Key('above')) : null,
  belowBoard: below ? const SizedBox.expand(key: Key('below')) : null,
  aboveHeight: PlayerBarCard.height,
  belowHeight: PlayerBarCard.height,
  overlayBar: overlay ? const SizedBox(key: Key('overlay'), height: 56) : null,
  toast: toast ? const SizedBox(key: Key('toast'), height: 100) : null,
  boardBuilder: (context, size) =>
      SizedBox(key: const Key('board'), width: size, height: size),
  panel: const SizedBox.expand(key: Key('panel')),
  actionBar: const SizedBox(key: Key('bar'), height: 64),
);

/// Every slot combination the six board modes use: Learn (lead, above,
/// drawing), Sharpen (above), the trainer (lead, above, drawing), Play and
/// the Studio (both cards), Review (header only).
final _modes = <String, Widget Function()>{
  'learn': () => _mode(lead: true, below: false, overlay: true),
  'sharpen': () => _mode(below: false),
  'puzzles': () => _mode(lead: true, below: false, overlay: true),
  'play': () => _mode(overlay: true),
  'studio': () => _mode(),
  'review': () => _mode(above: false, below: false),
};

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget child, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
}

Rect _board(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('board')));

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: 0.01));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: 0.01));
  expect(actual.width, moreOrLessEquals(expected.width, epsilon: 0.01));
  expect(actual.height, moreOrLessEquals(expected.height, epsilon: 0.01));
}

void main() {
  group('layoutFor', () {
    test('phones take the branches they always had', () {
      expect(_at(390, 763), ModeLayout.compact);
      expect(_at(440, 860), ModeLayout.compact);
      expect(_at(320, 640), ModeLayout.compact);
      expect(_at(832, 419), ModeLayout.landscapeCompact);
      expect(_at(750, 369), ModeLayout.landscapeCompact);
      expect(_at(700, 360), ModeLayout.landscapeCompact);
    });

    test('portrait tablets stack; landscape tablets split', () {
      // iPad Pro 13" as a route and as a tab beside the rail, the iPad mini,
      // an Android tablet, an iPad in Split View.
      expect(_at(1032, 1332), ModeLayout.stacked);
      expect(_at(959, 1332), ModeLayout.stacked);
      expect(_at(744, 1089), ModeLayout.stacked);
      expect(_at(671, 1089), ModeLayout.stacked);
      expect(_at(800, 1208), ModeLayout.stacked);
      expect(_at(678, 988), ModeLayout.stacked);
      expect(_at(1376, 988), ModeLayout.twoPane);
      expect(_at(1303, 988), ModeLayout.twoPane);
      expect(_at(1133, 700), ModeLayout.twoPane);
      expect(_at(1280, 728), ModeLayout.twoPane);
      // flutter_test's default surface: the screen tests run two-pane.
      expect(_at(800, 600), ModeLayout.twoPane);
    });

    test('only the phone column has no room for a move list', () {
      expect(ModeLayout.compact.listsMoves, isFalse);
      expect(ModeLayout.landscapeCompact.listsMoves, isTrue);
      expect(ModeLayout.stacked.listsMoves, isTrue);
      expect(ModeLayout.twoPane.listsMoves, isTrue);
    });
  });

  group('phones keep their geometry', () {
    testWidgets('portrait: the board spans the screen minus 8dp a side', (
      tester,
    ) async {
      for (final size in const [Size(390, 763), Size(440, 860)]) {
        for (final entry in _modes.entries) {
          await _pump(tester, size, entry.value());
          final board = _board(tester);
          expect(board.width, size.width - 16, reason: '${entry.key} @ $size');
          expect(board.left, 8, reason: '${entry.key} @ $size');
        }
      }
    });

    testWidgets('portrait 390x763, Play: the board sits where it always has', (
      tester,
    ) async {
      await _pump(tester, const Size(390, 763), _modes['play']!());
      // fixed = 48 header + 76 + 76 cards + 2*6 gaps + 4 = 216; the pane
      // keeps 132 (the drawing clearance 60 + 64 - 82 is less). Board =
      // min(390 - 16, 763 - 216 - 132 - 4) = 374. Leftover 763 - 216 - 374
      // = 173 lifts the group by min(0.2 * 173, 173 - 132) = 34.6, so the
      // board's top is 48 + 34.6 + 76 + 6 = 164.6.
      _expectRect(_board(tester), const Rect.fromLTWH(8, 164.6, 374, 374));
    });

    testWidgets('portrait 320x640, Play: a short phone is height-bound', (
      tester,
    ) async {
      await _pump(tester, const Size(320, 640), _modes['play']!());
      // Board = min(304, 640 - 352) = 288; leftover 136 lifts it by
      // min(27.2, 136 - 132) = 4: top 48 + 4 + 76 + 6 = 134, centred.
      _expectRect(_board(tester), const Rect.fromLTWH(16, 134, 288, 288));
    });

    testWidgets('landscape 832x419: the board takes the full height', (
      tester,
    ) async {
      await _pump(tester, const Size(832, 419), _modes['play']!());
      // availH 419 - 8 = 411, availW 832 - 16 - 12 = 804, pane
      // min(max(804 - 411, 260), 420) = 393; board min(411, 804 - 393) = 411.
      _expectRect(_board(tester), const Rect.fromLTWH(8, 4, 411, 411));
    });
  });

  group('stacked (portrait tablets)', () {
    testWidgets('every mode gets the same board rect', (tester) async {
      // 13" iPad as a route: header 48, lead 48, cards 76, fixed = 264;
      // floor = 0.22 * 1332 = 293.04; board = min(1016, 1332 - 264 -
      // 293.04) = 774.96, height-bound, so no slack. The column is the board
      // plus 8 a side (790.96), centred: x = (1032 - 790.96) / 2 = 120.52,
      // the board 8 inside it; top = 48 + 48 + 76 + 6 = 178.
      const expected = Rect.fromLTWH(128.52, 178, 774.96, 774.96);
      for (final entry in _modes.entries) {
        await _pump(tester, const Size(1032, 1332), entry.value());
        _expectRect(_board(tester), expected);
        expect(tester.takeException(), isNull, reason: entry.key);
      }
    });

    testWidgets('the rail costs a height-bound board nothing', (tester) async {
      await _pump(tester, const Size(959, 1332), _modes['play']!());
      expect(_board(tester).width, moreOrLessEquals(774.96, epsilon: 0.01));
    });

    testWidgets('the lead row always has room for its content', (tester) async {
      await _pump(tester, const Size(744, 1089), _modes['learn']!());
      expect(find.byKey(const Key('lead')), findsOneWidget);
    });

    testWidgets('header, cards, board and bar share the column', (
      tester,
    ) async {
      await _pump(tester, const Size(1032, 1332), _modes['play']!());
      final board = _board(tester);
      final top = tester.getRect(find.byKey(const Key('top')));
      final above = tester.getRect(find.byKey(const Key('above')));
      final bar = tester.getRect(find.byKey(const Key('bar')));
      // The cards span the board; the header and the bar span it plus 8dp a
      // side — a phone's insets, centred.
      expect(above.left, moreOrLessEquals(board.left, epsilon: 0.01));
      expect(above.width, moreOrLessEquals(board.width, epsilon: 0.01));
      expect(top.left, moreOrLessEquals(board.left - 8, epsilon: 0.01));
      expect(bar.width, moreOrLessEquals(board.width + 16, epsilon: 0.01));
      expect(bar.bottom, 1332);
    });

    testWidgets('the float docks on the action bar, inside the column', (
      tester,
    ) async {
      await _pump(
        tester,
        const Size(1032, 1332),
        _mode(overlay: true, toast: true),
      );
      final bar = tester.getRect(find.byKey(const Key('bar')));
      final overlay = tester.getRect(find.byKey(const Key('overlay')));
      expect(overlay.bottom, moreOrLessEquals(bar.top, epsilon: 0.01));
      expect(overlay.left, moreOrLessEquals(bar.left + 12, epsilon: 0.01));
      expect(overlay.right, moreOrLessEquals(bar.right - 12, epsilon: 0.01));
    });

    testWidgets('no overflow at 1.3x text or in a small window', (
      tester,
    ) async {
      for (final entry in _modes.entries) {
        await _pump(
          tester,
          const Size(1032, 1332),
          entry.value(),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull, reason: '${entry.key} @1.3');
        await _pump(tester, const Size(600, 700), entry.value());
        expect(tester.takeException(), isNull, reason: '${entry.key} small');
      }
    });
  });

  group('two-pane (landscape tablets)', () {
    testWidgets('the board fills the height; the pane takes the rest', (
      tester,
    ) async {
      await _pump(tester, const Size(1376, 988), _modes['play']!());
      // board = min(988 - 16, 1376 - 28 - 320, 1000) = 972; pane =
      // clamp(1376 - 28 - 972) = 376; the group fills the window.
      _expectRect(_board(tester), const Rect.fromLTWH(8, 8, 972, 972));
      final above = tester.getRect(find.byKey(const Key('above')));
      expect(above.left, moreOrLessEquals(992, epsilon: 0.01));
      expect(above.width, moreOrLessEquals(376, epsilon: 0.01));
    });

    testWidgets('a narrower window keeps the pane at its floor', (
      tester,
    ) async {
      await _pump(tester, const Size(1303, 988), _modes['play']!());
      // board = min(972, 1303 - 348) = 955; pane = 320; the row is 972 tall,
      // so the board is centred in it: top 8 + (972 - 955) / 2 = 16.5.
      _expectRect(_board(tester), const Rect.fromLTWH(8, 16.5, 955, 955));
    });

    testWidgets('surplus width becomes symmetric margin', (tester) async {
      await _pump(tester, const Size(1280, 728), _modes['play']!());
      // board = 712 (height-bound); pane = clamp(1280 - 28 - 712 = 540) =
      // 460; group 712 + 12 + 460 + 16 = 1200, centred: 40 a side.
      _expectRect(_board(tester), const Rect.fromLTWH(48, 8, 712, 712));
    });
  });
}
