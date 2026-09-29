// Integrity checks over the REAL translation bundles shipped as assets.
//
// Pure dart:io — reads the JSON files straight from the repository so the
// suite catches translation drift without needing a Flutter binding.
//
// Every check here ASSERTS. An earlier version printed its findings and
// passed regardless, so a bundle could have lost three hundred keys in
// silence.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/i18n/plural_rules.dart';

const _langs = [
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
const _dir = 'assets/data/i18n';

final _placeholderRe = RegExp(r'\{(\w+)\}');
final _tagRe = RegExp(r'</?(\w+)>');

final _categoryNames = PluralCategory.values.map((c) => c.name).toSet();

/// A node is a plural message when every one of its children is a CLDR
/// category name — `{one: …, other: …}`. Nothing else in the bundle uses
/// those words as keys, so the shape is unambiguous.
bool _isPluralNode(Map<String, dynamic> node) =>
    node.isNotEmpty &&
    node.keys.every(_categoryNames.contains) &&
    node.values.every((v) => v is String);

/// One bundle, split into plain leaves and plural messages.
class _Bundle {
  _Bundle(this.leaves, this.plurals);

  /// dot-path -> string, excluding anything under a plural message.
  final Map<String, String> leaves;

  /// dot-path of the message -> category name -> string.
  final Map<String, Map<String, String>> plurals;

  /// The name of every message, plural or not — what key parity compares.
  Set<String> get messageKeys => {...leaves.keys, ...plurals.keys};

  /// The text a key carries, for checks that do not care about category.
  Iterable<MapEntry<String, String>> get everyString sync* {
    yield* leaves.entries;
    for (final entry in plurals.entries) {
      for (final form in entry.value.entries) {
        yield MapEntry('${entry.key}.${form.key}', form.value);
      }
    }
  }
}

_Bundle _parse(Map<String, dynamic> root) {
  final leaves = <String, String>{};
  final plurals = <String, Map<String, String>>{};

  void walk(Map<String, dynamic> node, String prefix) {
    node.forEach((key, value) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (value is String) {
        leaves[path] = value;
      } else if (value is Map<String, dynamic>) {
        if (_isPluralNode(value)) {
          plurals[path] = value.cast<String, String>();
        } else {
          walk(value, path);
        }
      } else {
        fail('$path is neither a map nor a string: ${value.runtimeType}');
      }
    });
  }

  walk(root, '');
  return _Bundle(leaves, plurals);
}

/// Languages whose typography carries its own spacing.
///
/// Japanese and Chinese write 「（互角）」 and 「——已易位」, where the punctuation
/// occupies a full-width cell and an ASCII space beside it is an error their
/// own contracts forbid (docs/TRANSLATION_JA.md, docs/TRANSLATION_ZH.md). The
/// edge-space check below exists to catch an editor silently stripping a
/// load-bearing space, and that can only happen in a language that uses
/// spaces between words — so it does not apply to these two.
const _unspacedScripts = {'zh', 'ja'};

Set<String> _placeholders(String value) =>
    _placeholderRe.allMatches(value).map((m) => m[1]!).toSet();

List<String> _tags(String value) =>
    (_tagRe.allMatches(value).map((m) => m[0]!).toList())..sort();

void main() {
  late final Map<String, _Bundle> bundles;

  setUpAll(() {
    bundles = {
      for (final lang in _langs)
        lang: _parse(
            json.decode(File('$_dir/$lang.json').readAsStringSync())
                as Map<String, dynamic>),
    };
  });

  test('all ${_langs.length} bundles exist and parse as JSON objects', () {
    for (final lang in _langs) {
      expect(File('$_dir/$lang.json').existsSync(), isTrue,
          reason: 'missing bundle: $lang');
      expect(bundles[lang]!.messageKeys, isNotEmpty,
          reason: 'empty bundle: $lang');
    }
  });

  test('English bundle still carries a plausible number of messages', () {
    // A tripwire against a truncated or half-written bundle, not a spec.
    expect(bundles['en']!.messageKeys.length, greaterThan(400));
  });

  test('every language carries exactly the English message set', () {
    final en = bundles['en']!.messageKeys;
    final problems = <String>[];
    for (final lang in _langs.where((l) => l != 'en')) {
      final mine = bundles[lang]!.messageKeys;
      for (final key in (mine.difference(en).toList()..sort())) {
        problems.add('[$lang] has a key en does not: $key');
      }
      for (final key in (en.difference(mine).toList()..sort())) {
        problems.add('[$lang] is missing: $key');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('a plural message is plural in every language', () {
    final enPlurals = bundles['en']!.plurals.keys.toSet();
    final problems = <String>[];
    for (final lang in _langs.where((l) => l != 'en')) {
      final mine = bundles[lang]!.plurals.keys.toSet();
      for (final key in (enPlurals.difference(mine).toList()..sort())) {
        problems.add('[$lang] $key is a plain string; en makes it plural');
      }
      for (final key in (mine.difference(enPlurals).toList()..sort())) {
        problems.add('[$lang] $key is plural; en makes it a plain string');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('each plural message carries exactly its language\'s CLDR categories',
      () {
    final problems = <String>[];
    for (final lang in _langs) {
      final want = PluralRules.requiredCategories(lang)
          .map((c) => c.name)
          .toSet();
      bundles[lang]!.plurals.forEach((key, forms) {
        final got = forms.keys.toSet();
        // A missing category silently renders another language's wording;
        // a spare one is dead weight shipped to every user.
        for (final c in (want.difference(got).toList()..sort())) {
          problems.add('[$lang] $key is missing the "$c" form');
        }
        for (final c in (got.difference(want).toList()..sort())) {
          problems.add('[$lang] $key has "$c", which $lang never selects');
        }
      });
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('placeholder name sets match en for every message', () {
    final en = bundles['en']!;
    final problems = <String>[];
    for (final lang in _langs.where((l) => l != 'en')) {
      bundles[lang]!.leaves.forEach((key, value) {
        final enValue = en.leaves[key];
        if (enValue == null) return;
        final got = _placeholders(value);
        final want = _placeholders(enValue);
        if (got.length != want.length || !got.containsAll(want)) {
          problems.add('[$lang] $key: en=${want.toList()..sort()} '
              '$lang=${got.toList()..sort()}');
        }
      });
      // Every form of a plural message must take the same parameters as
      // English's `other`, whichever categories the language happens to use.
      bundles[lang]!.plurals.forEach((key, forms) {
        final enOther = en.plurals[key]?[PluralCategory.other.name];
        if (enOther == null) return;
        final want = _placeholders(enOther);
        forms.forEach((category, value) {
          final got = _placeholders(value);
          if (got.length != want.length || !got.containsAll(want)) {
            problems.add('[$lang] $key.$category: en=${want.toList()..sort()} '
                '$lang=${got.toList()..sort()}');
          }
        });
      });
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('html-lite tags match en, in the same order', () {
    final en = {for (final e in bundles['en']!.everyString) e.key: e.value};
    final problems = <String>[];
    for (final lang in _langs.where((l) => l != 'en')) {
      for (final entry in bundles[lang]!.everyString) {
        // A plural form is compared against English's `other`, since the
        // other categories may not exist there.
        final enValue = en[entry.key] ??
            en['${entry.key.substring(0, entry.key.lastIndexOf('.'))}'
                '.${PluralCategory.other.name}'];
        if (enValue == null) continue;
        if (_tags(entry.value).join() != _tags(enValue).join()) {
          problems.add('[$lang] ${entry.key}: en=${_tags(enValue)} '
              '$lang=${_tags(entry.value)}');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('no value is empty, and edge whitespace matches en', () {
    final en = {for (final e in bundles['en']!.everyString) e.key: e.value};
    final problems = <String>[];
    for (final lang in _langs) {
      for (final entry in bundles[lang]!.everyString) {
        if (entry.value.trim().isEmpty) {
          problems.add('[$lang] ${entry.key} is empty');
          continue;
        }
        if (lang == 'en') continue;
        final enValue = en[entry.key];
        if (enValue == null) continue;
        // Several keys are sentence fragments whose leading or trailing
        // space is load-bearing (" (equal)"), and an editor will strip it.
        //
        // But a space beside full-width punctuation is itself an error in
        // Japanese and Chinese — 「（互角）」 carries its own spacing. So the
        // rule is only that a translation must not LOSE a space it needs,
        // and a full-width edge character is proof that it does not.
        if (_unspacedScripts.contains(lang)) continue;
        if (enValue.startsWith(' ') && !entry.value.startsWith(' ')) {
          problems.add('[$lang] ${entry.key}: dropped en\'s leading space');
        }
        if (enValue.endsWith(' ') && !entry.value.endsWith(' ')) {
          problems.add('[$lang] ${entry.key}: dropped en\'s trailing space');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
