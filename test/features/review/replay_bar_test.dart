import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/theme/app_theme.dart';
import 'package:karpachess/core/theme/app_typography.dart';
import 'package:karpachess/core/theme/themes.dart';
import 'package:karpachess/core/ui/replay_bar.dart';

String fakeT(String key, [Map<String, Object?>? params]) {
  if (key == 'replay.position') return '${params?['i']} / ${params?['total']}';
  return key;
}

/// Hosts a ReplayBar whose index is plain widget state, like Review does.
class ReplayHost extends StatefulWidget {
  const ReplayHost({super.key, required this.plies});

  final int plies;

  @override
  State<ReplayHost> createState() => ReplayHostState();
}

class ReplayHostState extends State<ReplayHost> {
  int index = -1;

  @override
  Widget build(BuildContext context) {
    return ReplayBar(
      t: fakeT,
      count: widget.plies,
      index: index,
      onSeek: (i) => setState(() => index = i),
    );
  }
}

Future<ReplayHostState> pumpBar(WidgetTester tester, {int plies = 4}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.build(AppThemes.fallback, AppFont.classic),
    home: Scaffold(body: Center(child: ReplayHost(plies: plies))),
  ));
  return tester.state<ReplayHostState>(find.byType(ReplayHost));
}

void main() {
  testWidgets('seek buttons step and jump through the plies', (tester) async {
    final host = await pumpBar(tester);
    expect(find.text('0 / 4'), findsOneWidget);

    // Next steps forward.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(host.index, 0);
    expect(find.text('1 / 4'), findsOneWidget);

    // Last jumps to the final ply.
    await tester.tap(find.byIcon(Icons.last_page));
    await tester.pump();
    expect(host.index, 3);
    expect(find.text('4 / 4'), findsOneWidget);

    // Prev steps back, first rewinds to the start position.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(host.index, 2);
    await tester.tap(find.byIcon(Icons.first_page));
    await tester.pump();
    expect(host.index, -1);
    expect(find.text('0 / 4'), findsOneWidget);
  });

  testWidgets('prev/next do nothing at the ends', (tester) async {
    final host = await pumpBar(tester);

    // At the start position, prev/first are disabled.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(host.index, -1);

    await tester.tap(find.byIcon(Icons.last_page));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(host.index, 3);
  });

  testWidgets('autoplay ticks forward and stops at the last ply',
      (tester) async {
    final host = await pumpBar(tester, plies: 3);

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump();
    expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    expect(host.index, 0);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(host.index, 1);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(host.index, 2);

    // Reaching the last ply stops autoplay (timer cancelled, icon reverts).
    await tester.pump(const Duration(milliseconds: 1400));
    expect(host.index, 2);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_outline), findsNothing);
  });

  testWidgets('manual seek while playing cancels autoplay', (tester) async {
    final host = await pumpBar(tester);

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(host.index, 0);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(host.index, 1);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

    // No further ticks arrive.
    await tester.pump(const Duration(milliseconds: 3000));
    expect(host.index, 1);
  });
}
