import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/errors/app_errors.dart';
import 'core/i18n/i18n_service.dart';
import 'core/legal/licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // First, so that nothing — not even a failed restore — escapes the sink.
  AppErrors.install();
  registerAppLicenses();

  final container = await bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const KarpaChessApp(),
    ),
  );
}

/// Exposed for tests that need the same first-boot language resolution.
String resolveFirstBootLang(String candidate) =>
    I18nService.resolveLang(candidate);
