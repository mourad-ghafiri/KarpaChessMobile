import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/i18n/i18n_providers.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/features/commentator/data/commentator_store.dart';
import 'package:karpachess/features/commentator/presentation/studio_screen.dart';

import '../practice/fake_engine_service.dart';
import 'fakes.dart' show MemoryCommentatorStore;

Future<ProviderContainer> pumpStudio(WidgetTester tester) async {
  final container = ProviderContainer(overrides: [
    engineServiceProvider.overrideWithValue(FakeEngineService()),
    commentatorStoreProvider.overrideWithValue(MemoryCommentatorStore()),
  ]);
  addTearDown(container.dispose);
  await container.read(i18nProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
        home: const Scaffold(body: StudioScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

void main() {
  // This file began as two throwaway probes named "probe A" and "probe B",
  // written to chase a hang when the Studio is mounted a second time in one
  // suite. The probes are the symptom; the invariant is what matters, so it
  // is written down here instead of left as scaffolding.
  //
  // Mounting twice exercises teardown: a provider container, an engine and
  // any timers the screen starts must all be released by `addTearDown`, or
  // the second mount inherits the first one's state and blocks.
  testWidgets('the studio mounts cleanly', (tester) async {
    await pumpStudio(tester);
    expect(find.byType(StudioScreen), findsOneWidget);
  });

  testWidgets('and mounts again after a full teardown', (tester) async {
    await pumpStudio(tester);
    expect(find.byType(StudioScreen), findsOneWidget);
  });
}
