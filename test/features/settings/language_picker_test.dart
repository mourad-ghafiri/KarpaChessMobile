import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/features/settings/presentation/settings_widgets.dart';

// Each bundle's own `language.name`, which is what the switcher shows.
const _names = {
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'ar': 'العربية',
  'zh': '中文',
  'ru': 'Русский',
  'id': 'Bahasa Indonesia',
  'ja': '日本語',
  'hi': 'हिन्दी',
  'tr': 'Türkçe',
  'it': 'Italiano',
  'pt': 'Português',
};

/// The Language section's width on a 360dp phone: the settings sheet's 20dp
/// gutters and the section card's 16dp padding come off each side.
const _phoneSectionWidth = 360.0 - 2 * 20 - 2 * 16;

Future<void> _pump(
  WidgetTester tester, {
  double textScale = 1.0,
  String selected = 'en',
  ValueChanged<String>? onSelect,
}) async {
  await tester.pumpWidget(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: _phoneSectionWidth,
                  child: LanguagePicker(
                    names: _names,
                    selected: selected,
                    onSelect: onSelect ?? (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Offset _cardAt(WidgetTester tester, String name) =>
    tester.getTopLeft(find.widgetWithText(LanguageChoiceCard, name));

void main() {
  testWidgets('a 360dp phone shows every language in two columns',
      (tester) async {
    await _pump(tester);
    expect(find.byType(LanguageChoiceCard), findsNWidgets(_names.length));
    final english = _cardAt(tester, 'English');
    final french = _cardAt(tester, 'Français');
    expect(french.dy, english.dy);
    expect(french.dx, greaterThan(english.dx));
  });

  testWidgets('at 1.3× text the same phone falls back to one column',
      (tester) async {
    await _pump(tester, textScale: 1.3);
    final english = _cardAt(tester, 'English');
    final french = _cardAt(tester, 'Français');
    expect(french.dx, english.dx);
    expect(french.dy, greaterThan(english.dy));
  });

  testWidgets('every card clears the 44dp tap target at 1× and 1.3×',
      (tester) async {
    // A RenderFlex overflow at either scale fails the test on its own.
    for (final scale in const [1.0, 1.3]) {
      await _pump(tester, textScale: scale);
      for (final card in find.byType(LanguageChoiceCard).evaluate()) {
        expect(card.size!.height, greaterThanOrEqualTo(44));
      }
    }
  });

  testWidgets('tapping a card selects its language', (tester) async {
    String? picked;
    await _pump(tester, onSelect: (lang) => picked = lang);
    await tester.tap(find.text('Português'));
    expect(picked, 'pt');
  });

  testWidgets('a screen reader hears each name once, with its state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, selected: 'pt');
    expect(find.bySemanticsLabel('Português'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Português')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('English')),
      isSemantics(isButton: true, isSelected: false),
    );
    semantics.dispose();
  });
}
