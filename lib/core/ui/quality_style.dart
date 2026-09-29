import 'dart:ui';

import '../../engine/domain/move_classifier.dart';
import '../theme/app_tokens.dart';

/// The single visual mapping for move quality — color + glyph — used by
/// review cards, board badges and recap dials alike.
extension MoveQualityStyle on MoveQuality {
  /// Theme-aware quality color.
  Color colorOf(AppTokens tokens) => switch (this) {
        MoveQuality.brilliant => tokens.brilliant,
        MoveQuality.best => tokens.best,
        MoveQuality.good => tokens.good,
        MoveQuality.inaccuracy => tokens.inaccuracy,
        MoveQuality.mistake => tokens.mistake,
        MoveQuality.blunder => tokens.blunder,
      };

  String get glyph => switch (this) {
        MoveQuality.brilliant => '!!',
        MoveQuality.best => '★',
        MoveQuality.good => '✓',
        MoveQuality.inaccuracy => '?!',
        MoveQuality.mistake => '?',
        MoveQuality.blunder => '??',
      };
}
