import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/i18n/i18n_service.dart';

class FakeAssetBundle extends CachingAssetBundle {
  FakeAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('FakeAssetBundle: no asset for $key');
    }
    return ByteData.sublistView(utf8.encode(value));
  }
}

FakeAssetBundle fixtureBundle() {
  return FakeAssetBundle({
    'assets/data/i18n/en.json': json.encode({
      'language': {'name': 'English', 'code': 'en'},
      'ui': {
        'greet': 'Hello {name}!',
        'onlyEnglish': 'English only',
        'progress': '{done} of {total} done',
        'repeat': '{word} and {word}',
      },
      'deep': {
        'a': {'b': 'leaf'},
      },
    }),
    'assets/data/i18n/fr.json': json.encode({
      'language': {'name': 'Français', 'code': 'fr'},
      'ui': {
        'greet': 'Bonjour {name} !',
      },
    }),
    'assets/data/i18n/ar.json': json.encode({
      'language': {'name': 'العربية'},
    }),
  });
}

void main() {
  group('resolveLang', () {
    test('exact match', () {
      expect(I18nService.resolveLang('fr'), 'fr');
      expect(I18nService.resolveLang('ja'), 'ja');
    });

    test('case-insensitive and primary-subtag match', () {
      expect(I18nService.resolveLang('FR'), 'fr');
      expect(I18nService.resolveLang('fr-CA'), 'fr');
      expect(I18nService.resolveLang('zh_Hans'), 'zh');
      expect(I18nService.resolveLang('ar-EG'), 'ar');
      // The app's Portuguese is European (docs/TRANSLATION_PT.md); a
      // Brazilian device is served that bundle rather than English.
      expect(I18nService.resolveLang('pt-BR'), 'pt');
    });

    test('unsupported, null, or empty fall back to en', () {
      expect(I18nService.resolveLang('de'), 'en');
      expect(I18nService.resolveLang('de-AT'), 'en');
      expect(I18nService.resolveLang(null), 'en');
      expect(I18nService.resolveLang(''), 'en');
    });
  });

  group('load + t', () {
    test('current-language lookup with params', () async {
      final i18n = await I18nService.load('fr', bundle: fixtureBundle());
      expect(i18n.lang, 'fr');
      expect(i18n.t('ui.greet', {'name': 'Karpa'}), 'Bonjour Karpa !');
    });

    test('missing in lang falls back to English value', () async {
      final i18n = await I18nService.load('fr', bundle: fixtureBundle());
      expect(i18n.t('ui.onlyEnglish'), 'English only');
    });

    test('missing everywhere falls back to the key itself', () async {
      final i18n = await I18nService.load('fr', bundle: fixtureBundle());
      expect(i18n.t('no.such.key'), 'no.such.key');
      expect(i18n.t('no.such.key', {'x': 1}), 'no.such.key');
    });

    test('non-string leaves are treated as missing', () async {
      final i18n = await I18nService.load('en', bundle: fixtureBundle());
      // 'deep.a' resolves to a map, 'language' to a map: both fall through.
      expect(i18n.t('deep.a'), 'deep.a');
      expect(i18n.t('language'), 'language');
      expect(i18n.t('deep.a.b'), 'leaf');
      expect(i18n.t('deep.a.b.c'), 'deep.a.b.c');
    });

    test('params interpolation semantics', () async {
      final i18n = await I18nService.load('en', bundle: fixtureBundle());
      // No params map: tokens are left verbatim.
      expect(i18n.t('ui.greet'), 'Hello {name}!');
      // Missing or null param: token kept verbatim.
      expect(i18n.t('ui.greet', {}), 'Hello {name}!');
      expect(i18n.t('ui.greet', {'name': null}), 'Hello {name}!');
      // Values are stringified; every occurrence is replaced.
      expect(i18n.t('ui.progress', {'done': 2, 'total': 10}), '2 of 10 done');
      expect(i18n.t('ui.repeat', {'word': 'x'}), 'x and x');
    });

    test('has() checks current language then English', () async {
      final i18n = await I18nService.load('fr', bundle: fixtureBundle());
      expect(i18n.has('ui.greet'), isTrue);
      expect(i18n.has('ui.onlyEnglish'), isTrue); // English only
      expect(i18n.has('no.such.key'), isFalse);
      expect(i18n.has('deep.a'), isFalse); // map, not a string leaf
    });

    test('unsupported lang resolves to en and never throws', () async {
      final i18n = await I18nService.load('xx', bundle: fixtureBundle());
      expect(i18n.lang, 'en');
      expect(i18n.t('ui.onlyEnglish'), 'English only');
    });

    test('regional tag resolves to its primary subtag', () async {
      final i18n = await I18nService.load('fr-CA', bundle: fixtureBundle());
      expect(i18n.lang, 'fr');
      expect(i18n.t('ui.greet', {'name': 'A'}), 'Bonjour A !');
    });

    test('supported lang with a missing asset still loads (English text)',
        () async {
      // 'es' is supported but absent from the fake bundle: load must not
      // throw, and lookups fall back to English.
      final i18n = await I18nService.load('es', bundle: fixtureBundle());
      expect(i18n.lang, 'es');
      expect(i18n.t('ui.greet', {'name': 'B'}), 'Hello B!');
    });
  });

  group('direction', () {
    test('ar is RTL', () async {
      final i18n = await I18nService.load('ar', bundle: fixtureBundle());
      expect(i18n.isRtl, isTrue);
      expect(i18n.textDirection, TextDirection.rtl);
    });

    test('fr and en are LTR', () async {
      final fr = await I18nService.load('fr', bundle: fixtureBundle());
      final en = await I18nService.load('en', bundle: fixtureBundle());
      expect(fr.isRtl, isFalse);
      expect(fr.textDirection, TextDirection.ltr);
      expect(en.isRtl, isFalse);
    });
  });

  group('languageNames', () {
    test('reads each bundle\'s language.name, code fallback when absent',
        () async {
      final names = await I18nService.languageNames(bundle: fixtureBundle());
      expect(names['en'], 'English');
      expect(names['fr'], 'Français');
      expect(names['ar'], 'العربية');
      // Langs without a fixture bundle fall back to their code.
      expect(names['es'], 'es');
      expect(names.keys, containsAll(I18nService.supportedLangs));
    });
  });

  test('supportedLangs is the switcher\'s display order', () {
    expect(I18nService.supportedLangs, [
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
    ]);
  });

  group('flags', () {
    test('every supported language has exactly one flag region', () {
      expect(I18nService.flagRegions.keys.toSet(),
          I18nService.supportedLangs.toSet());
    });

    test('regions are ISO 3166-1 alpha-2 codes', () {
      final alpha2 = RegExp(r'^[A-Z]{2}$');
      for (final region in I18nService.flagRegions.values) {
        expect(region, matches(alpha2));
      }
    });

    test('flagFor spells the region in regional indicators', () {
      expect(I18nService.flagFor('en'), '🇺🇸');
      expect(I18nService.flagFor('ar'), '🇸🇦');
      expect(I18nService.flagFor('pt'), '🇵🇹');
      expect(I18nService.flagFor('zh'), '🇨🇳');
    });

    test('a language with no region has no flag', () {
      expect(I18nService.flagFor('xx'), isEmpty);
    });
  });
}
