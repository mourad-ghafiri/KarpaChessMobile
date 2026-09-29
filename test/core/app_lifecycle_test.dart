import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/audio/sound_providers.dart';
import 'package:karpachess/core/audio/sound_service.dart';
import 'package:karpachess/core/lifecycle/app_lifecycle.dart';
import 'package:karpachess/engine/application/engine_providers.dart';
import 'package:karpachess/prefs/application/prefs_controller.dart';
import 'package:karpachess/prefs/domain/prefs.dart';
import 'package:karpachess/prefs/domain/prefs_repository.dart';

import '../features/practice/fake_engine_service.dart';

class _MemoryPrefsRepository implements PrefsRepository {
  Prefs? stored;

  @override
  Future<Prefs?> load() async => stored;

  @override
  Future<void> save(Prefs prefs) async => stored = prefs;

  @override
  Future<void> clear() async => stored = null;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  void enter(List<AppLifecycleState> states) {
    for (final state in states) {
      binding.handleAppLifecycleStateChanged(state);
    }
  }

  test('leaving the foreground holds the engine once; returning releases it',
      () {
    final engine = FakeEngineService();
    final container = ProviderContainer(overrides: [
      engineServiceProvider.overrideWithValue(engine),
      soundServiceProvider.overrideWithValue(const SilentSoundService()),
      prefsRepositoryProvider.overrideWithValue(_MemoryPrefsRepository()),
    ]);
    addTearDown(container.dispose);
    enter([AppLifecycleState.resumed]);
    container.read(appLifecycleGuardProvider);

    // hide and pause both mean "gone": one hold, not two.
    enter([
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(engine.suspendCalls, 1);
    expect(engine.resumeCalls, 0);

    // show and resume both mean "back": one release.
    enter([
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(engine.suspendCalls, 1);
    expect(engine.resumeCalls, 1);
  });
}
