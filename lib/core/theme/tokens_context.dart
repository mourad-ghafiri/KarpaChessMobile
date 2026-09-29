import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_typography.dart';
import 'themes.dart';

/// `context.tokens` — the one way widgets read theme colors.
/// `context.type` — the one way widgets read type styles and families.
extension TokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppThemes.fallback;

  AppTypography get type =>
      Theme.of(this).extension<AppTypography>() ??
      const AppTypography(AppFont.classic);
}
