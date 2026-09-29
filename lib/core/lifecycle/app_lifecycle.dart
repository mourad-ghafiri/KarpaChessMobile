import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/application/engine_providers.dart';
import '../../features/practice/application/practice_controller.dart';

/// Battery contract: when the app leaves the foreground, NOTHING keeps
/// burning — the engine is held (its running search stopped) and the
/// practice clock freezes. On return both resume, and the search that was
/// stopped runs again, so a reply, a review or an analysis that was under
/// way when the app went away still arrives. Watched once from the app root.
final appLifecycleGuardProvider = Provider<AppLifecycleGuard>((ref) {
  final guard = AppLifecycleGuard(ref);
  ref.onDispose(guard.dispose);
  return guard;
});

class AppLifecycleGuard {
  AppLifecycleGuard(this._ref) {
    _listener = AppLifecycleListener(
      onHide: _sleep,
      onPause: _sleep,
      onShow: _wake,
      onResume: _wake,
    );
  }

  final Ref _ref;
  late final AppLifecycleListener _listener;
  bool _sleeping = false;

  void _sleep() {
    if (_sleeping) return;
    _sleeping = true;
    _ref.read(engineServiceProvider).suspend();
    _ref.read(practiceControllerProvider.notifier).pauseClock();
  }

  void _wake() {
    if (!_sleeping) return;
    _sleeping = false;
    _ref.read(engineServiceProvider).resume();
    _ref.read(practiceControllerProvider.notifier).resumeClock();
  }

  void dispose() => _listener.dispose();
}
