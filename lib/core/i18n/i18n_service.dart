/// Minimal i18n runtime.
///
/// Keys are dot-paths into a nested JSON object: `t('ui.button.flip')` reads
/// `bundle['ui']['button']['flip']`. Parameters replace `{name}` tokens in the
/// looked-up string. Missing keys fall back to the English bundle, then to the
/// key itself.
///
/// A message whose wording changes with a count is not a string but a map of
/// CLDR plural categories, read through [I18nService.plural]. Callers hand
/// over the number and never the word: see `plural_rules.dart`.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../errors/app_errors.dart';
import 'plural_rules.dart';
// Re-exported so a widget that already imports the service keeps seeing the
// seams; the domain imports `translate.dart` directly and stays Flutter-free.
export 'translate.dart' show Translate, Pluralize;

/// Immutable translation service holding one language bundle plus the English
/// fallback bundle. Construct via [I18nService.load].
class I18nService {
  I18nService._(this._lang, this._bundle, this._fallback);

  /// All supported language codes, in display order.
  static const supportedLangs = [
    'en',
    'fr',
    'es',
    'ar',
    'zh',
    'ru',
    'id',
    'ja',
    'hi',
    'tr',
    'it',
    'pt',
  ];

  /// Languages rendered right-to-left.
  static const rtlLangs = ['ar'];

  /// The region whose flag stands beside each language in the switcher, as
  /// an ISO 3166-1 alpha-2 code.
  ///
  /// A language is not a country, so every entry is a decision, made once
  /// and here. English is the United States because the corpus is written
  /// in American spelling. Arabic is Modern Standard Arabic, written for
  /// every Arab country, and takes Saudi Arabia's flag, as language pickers
  /// conventionally do. Portuguese is Portugal because the translation is
  /// European (docs/TRANSLATION_PT.md), and Chinese is the mainland's
  /// because it is Simplified. Spanish takes Spain's, although it is
  /// written neutral.
  static const flagRegions = {
    'en': 'US',
    'fr': 'FR',
    'es': 'ES',
    'ar': 'SA',
    'zh': 'CN',
    'ru': 'RU',
    'id': 'ID',
    'ja': 'JP',
    'hi': 'IN',
    'tr': 'TR',
    'it': 'IT',
    'pt': 'PT',
  };

  /// The flag emoji for [lang]: its [flagRegions] code spelled in
  /// regional-indicator symbols, which iOS, Android and macOS all draw as
  /// the flag itself. Empty for a language with no region.
  static String flagFor(String lang) {
    final region = flagRegions[lang];
    if (region == null) return '';
    return String.fromCharCodes([
      for (final unit in region.codeUnits) 0x1F1E6 + unit - 0x41,
    ]);
  }

  static const _assetDir = 'assets/data/i18n';

  static final _placeholderRe = RegExp(r'\{(\w+)\}');

  final String _lang;
  final Map<String, dynamic> _bundle;
  final Map<String, dynamic> _fallback;

  /// Resolve a preferred language: exact match, then primary-subtag match
  /// (e.g. 'fr-CA' -> 'fr'), else 'en'.
  static String resolveLang(String? candidate) {
    if (candidate == null || candidate.isEmpty) return 'en';
    final normalized = candidate.toLowerCase();
    if (supportedLangs.contains(normalized)) return normalized;
    final primary = normalized.split(RegExp(r'[-_]')).first;
    if (supportedLangs.contains(primary)) return primary;
    return 'en';
  }

  /// Loads [lang] plus the English fallback bundle from [bundle]
  /// (default: [rootBundle]). Never throws for a supported lang.
  static Future<I18nService> load(String lang, {AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final resolved = resolveLang(lang);
    final fallback = await _fetch(assets, 'en');
    final current =
        resolved == 'en' ? fallback : await _fetch(assets, resolved);
    return I18nService._(resolved, current, fallback);
  }

  /// Native language display names for the switcher, read from each bundle's
  /// own 'language.name' key (e.g. 'fr' -> 'Français').
  static Future<Map<String, String>> languageNames({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final names = <String, String>{};
    for (final code in supportedLangs) {
      final data = await _fetch(assets, code);
      final name = _lookup(data, 'language.name');
      names[code] = name ?? code;
    }
    return names;
  }

  String get lang => _lang;

  bool get isRtl => rtlLangs.contains(_lang);

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// Dot-path lookup with `{param}` interpolation.
  ///
  /// Missing in the current language falls back to the English value, then to
  /// the key itself. Every `{name}` token is replaced with
  /// `params['name'].toString()`; tokens without a (non-null) param are kept
  /// verbatim.
  String t(String key, [Map<String, Object?>? params]) {
    final raw = _lookup(_bundle, key) ?? _lookup(_fallback, key) ?? key;
    return params == null ? raw : _interpolate(raw, params);
  }

  /// A count-bearing message: [key] names a map of CLDR plural categories,
  /// and [count] selects one of them for the current language.
  ///
  ///     "moveCount": { "one": "{n} move", "other": "{n} moves" }
  ///     plural('commentator.moveCount', 1)   // "1 move"
  ///
  /// `{n}` is bound to [count] on top of [params], so a caller never has to
  /// pass the number twice. Resolution walks the current language's category,
  /// then its `other`, then English's category, then English's `other`, then
  /// the key itself — the same widening [t] does, one rung longer because
  /// `other` is the category every language is guaranteed to have.
  String plural(String key, int count, [Map<String, Object?>? params]) {
    const fallbackCategory = PluralCategory.other;
    final category = PluralRules.categoryFor(_lang, count);
    final raw = _lookup(_bundle, '$key.${category.name}') ??
        _lookup(_bundle, '$key.${fallbackCategory.name}') ??
        _lookup(_fallback, '$key.${category.name}') ??
        _lookup(_fallback, '$key.${fallbackCategory.name}') ??
        key;
    return _interpolate(raw, {...?params, 'n': count});
  }

  /// True if the key exists (as a string leaf) in the current language or
  /// English bundle.
  bool has(String key) =>
      _lookup(_bundle, key) != null || _lookup(_fallback, key) != null;

  // -- private -----------------------------------------------------

  /// Replaces every `{name}` token with `params['name']`. A token with no
  /// (non-null) param is kept verbatim.
  static String _interpolate(String raw, Map<String, Object?> params) =>
      raw.replaceAllMapped(_placeholderRe, (m) {
        final value = params[m[1]];
        return value != null ? value.toString() : m[0]!;
      });

  static Future<Map<String, dynamic>> _fetch(
      AssetBundle assets, String lang) async {
    try {
      final raw = await assets.loadString('$_assetDir/$lang.json');
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (error) {
      AppErrors.note('failed to load the "$lang" bundle, using English: $error');
    }
    return const <String, dynamic>{};
  }

  /// Walks [key] as a dot-path through nested maps. Returns string leaves
  /// only — a path that ends on a map, list, number, or nothing yields null.
  static String? _lookup(Map<String, dynamic> obj, String key) {
    Object? cur = obj;
    for (final part in key.split('.')) {
      if (cur is! Map) return null;
      cur = cur[part];
    }
    return cur is String ? cur : null;
  }
}
