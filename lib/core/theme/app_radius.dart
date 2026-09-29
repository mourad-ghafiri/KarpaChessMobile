/// Corner-radius tokens — every rounded surface uses one of these three,
/// so the app reads as one material system (HIG consistency).
abstract final class AppRadius {
  /// Cards, toasts, sheets, dialogs.
  static const double card = 16;

  /// Buttons, swatches, list tiles, small controls.
  static const double control = 12;

  /// Pills, chips, the action bar.
  static const double chip = 999;
}
