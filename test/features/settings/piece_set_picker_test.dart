import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/board_themes.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/core/ui/picker_strip.dart';
import 'package:karpachess/features/board/presentation/piece_sets.dart';
import 'package:karpachess/features/settings/presentation/settings_widgets.dart';

Future<void> _pump(
  WidgetTester tester, {
  required PieceSetId selected,
  ValueChanged<PieceSetId>? onSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
      home: Scaffold(
        body: PickerStrip(
          children: [
            for (final option in PieceSetId.values)
              PieceSetPreviewCard(
                pieceSet: option,
                colorway: BoardColorTheme.walnut,
                label: option.name,
                selected: option == selected,
                onTap: () => onSelect?.call(option),
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every set is offered, the current one announced as selected',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, selected: PieceSetId.wood);

    expect(find.byType(PieceSetPreviewCard),
        findsNWidgets(PieceSetId.values.length));
    for (final option in PieceSetId.values) {
      expect(find.text(option.name), findsOneWidget);
    }
    // One node per card: the name, once, as a selectable button.
    expect(find.bySemanticsLabel('wood'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('wood')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('classic')),
      isSemantics(isButton: true, isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('a preview shows its own set on the given colorway',
      (tester) async {
    await _pump(tester, selected: PieceSetId.classic);

    final card = find.widgetWithText(PieceSetPreviewCard, 'diagram');
    final images = tester
        .widgetList<Image>(find.descendant(of: card, matching: find.byType(Image)))
        .map((i) => (i.image as AssetImage).assetName)
        .toList();
    expect(images, hasLength(4));
    expect(images, everyElement(startsWith('assets/pieces/diagram/')));

    final squares = tester
        .widgetList<ColoredBox>(
            find.descendant(of: card, matching: find.byType(ColoredBox)))
        .map((b) => b.color)
        .toSet();
    expect(squares, {
      BoardColorTheme.walnut.lightSquare,
      BoardColorTheme.walnut.darkSquare,
    });
  });

  testWidgets('tapping a set selects it', (tester) async {
    PieceSetId? chosen;
    await _pump(tester,
        selected: PieceSetId.classic, onSelect: (s) => chosen = s);

    await tester.tap(find.text('bold'));
    expect(chosen, PieceSetId.bold);
  });
}
