import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/i18n/plural_rules.dart';

/// The CLDR cardinal rules, pinned by their boundaries.
///
/// These are the cases that separate a correct table from a plausible one:
/// the teens Russian sends to `many` even though they end in 1, 2, 3; the
/// `% 100` window Arabic uses; and the languages that put zero with one.
void main() {
  PluralCategory cat(String lang, int n) => PluralRules.categoryFor(lang, n);

  group('one/other languages', () {
    for (final lang in ['en', 'es', 'it', 'tr']) {
      test('$lang: only 1 is one, zero is other', () {
        expect(cat(lang, 0), PluralCategory.other);
        expect(cat(lang, 1), PluralCategory.one);
        expect(cat(lang, 2), PluralCategory.other);
        expect(cat(lang, 21), PluralCategory.other);
        expect(PluralRules.requiredCategories(lang),
            {PluralCategory.one, PluralCategory.other});
      });
    }
  });

  group('languages that count zero as one', () {
    for (final lang in ['fr', 'hi', 'pt']) {
      test('$lang: 0 and 1 are one', () {
        expect(cat(lang, 0), PluralCategory.one);
        expect(cat(lang, 1), PluralCategory.one);
        expect(cat(lang, 2), PluralCategory.other);
        expect(PluralRules.requiredCategories(lang),
            {PluralCategory.one, PluralCategory.other});
      });
    }
  });

  group('single-form languages', () {
    for (final lang in ['id', 'zh', 'ja']) {
      test('$lang: every count is other', () {
        for (final n in [0, 1, 2, 5, 11, 21, 100, 999]) {
          expect(cat(lang, n), PluralCategory.other, reason: 'n=$n');
        }
        expect(PluralRules.requiredCategories(lang), {PluralCategory.other});
      });
    }
  });

  test('ru: one/few/many, and the teens are many', () {
    expect(cat('ru', 1), PluralCategory.one);
    expect(cat('ru', 21), PluralCategory.one);
    expect(cat('ru', 101), PluralCategory.one);

    expect(cat('ru', 2), PluralCategory.few);
    expect(cat('ru', 4), PluralCategory.few);
    expect(cat('ru', 22), PluralCategory.few);

    expect(cat('ru', 0), PluralCategory.many);
    expect(cat('ru', 5), PluralCategory.many);
    expect(cat('ru', 9), PluralCategory.many);
    // 11..14 end in 1..4 but are many, which is the whole trap.
    expect(cat('ru', 11), PluralCategory.many);
    expect(cat('ru', 12), PluralCategory.many);
    expect(cat('ru', 14), PluralCategory.many);
    expect(cat('ru', 111), PluralCategory.many);
    expect(cat('ru', 114), PluralCategory.many);

    // `other` is unreachable for integers, so a bundle must not carry it.
    expect(PluralRules.requiredCategories('ru'),
        {PluralCategory.one, PluralCategory.few, PluralCategory.many});
  });

  test('ar: all six categories, on a % 100 window', () {
    expect(cat('ar', 0), PluralCategory.zero);
    expect(cat('ar', 1), PluralCategory.one);
    expect(cat('ar', 2), PluralCategory.two);

    expect(cat('ar', 3), PluralCategory.few);
    expect(cat('ar', 10), PluralCategory.few);
    expect(cat('ar', 103), PluralCategory.few);

    expect(cat('ar', 11), PluralCategory.many);
    expect(cat('ar', 99), PluralCategory.many);

    // 100, 101 and 102 fall through every window to `other`; only a bare
    // 2 is `two`.
    expect(cat('ar', 100), PluralCategory.other);
    expect(cat('ar', 101), PluralCategory.other);
    expect(cat('ar', 102), PluralCategory.other);

    expect(PluralRules.requiredCategories('ar'), PluralCategory.values.toSet());
  });

  test('the sign is discarded — down 1 point reads like up 1 point', () {
    expect(cat('en', -1), PluralCategory.one);
    expect(cat('ru', -22), PluralCategory.few);
  });

  test('an unknown language resolves as English rather than throwing', () {
    expect(cat('kl', 1), PluralCategory.one);
    expect(cat('kl', 2), PluralCategory.other);
  });
}
