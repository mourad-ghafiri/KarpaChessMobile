import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prefs/application/prefs_controller.dart';
import 'i18n_service.dart';

/// The loaded translation bundle for the current language pref.
/// Re-loads automatically when the language changes.
final i18nProvider = FutureProvider<I18nService>((ref) {
  final lang = ref.watch(prefsControllerProvider.select((p) => p.lang));
  return I18nService.load(lang);
});

/// Native display names of every supported language (for the switcher).
final languageNamesProvider = FutureProvider<Map<String, String>>(
  (ref) => I18nService.languageNames(),
);
