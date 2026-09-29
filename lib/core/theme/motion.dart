import 'package:flutter/animation.dart';

/// Motion tokens: every animated transition in the app uses one of these
/// durations and curves, so movement feels like one system.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasis = Curves.easeInOutCubic;
}
