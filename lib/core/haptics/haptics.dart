import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prefs/application/prefs_controller.dart';

/// Central haptics gate: pref-controlled, mobile-only, and deliberately
/// sparse — only touches that deserve physical confirmation get one.
abstract final class Haptics {
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static void selection(bool enabled) {
    if (enabled && _supported) HapticFeedback.selectionClick();
  }

  static void light(bool enabled) {
    if (enabled && _supported) HapticFeedback.lightImpact();
  }

  static void medium(bool enabled) {
    if (enabled && _supported) HapticFeedback.mediumImpact();
  }
}

/// Convenience for controllers/screens holding a [Ref] or [WidgetRef].
extension HapticsRefX on Ref {
  bool get _hapticsOn => read(prefsControllerProvider).haptics;
  void hapticSelection() => Haptics.selection(_hapticsOn);
  void hapticLight() => Haptics.light(_hapticsOn);
  void hapticMedium() => Haptics.medium(_hapticsOn);
}

extension HapticsWidgetRefX on WidgetRef {
  bool get _hapticsOn => read(prefsControllerProvider).haptics;
  void hapticSelection() => Haptics.selection(_hapticsOn);
  void hapticLight() => Haptics.light(_hapticsOn);
  void hapticMedium() => Haptics.medium(_hapticsOn);
}
