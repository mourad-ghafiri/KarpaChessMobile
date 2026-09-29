import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';

void main() {
  testWidgets('theme builds without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: const Scaffold(body: Text('KarpaChess')),
      ),
    );
    expect(find.text('KarpaChess'), findsOneWidget);
  });
}
