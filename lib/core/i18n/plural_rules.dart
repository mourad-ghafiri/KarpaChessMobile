/// CLDR cardinal plural categories for the app's twelve languages.
///
/// A count-bearing message cannot be one string: "1 point" and "2 points"
/// differ in English, and the split is not the same split elsewhere. Russian
/// needs three forms, Arabic six, and Japanese, Chinese and Indonesian one.
/// Choosing between them is a property of the LANGUAGE, so it lives here and
/// not in the code that happens to know the number.
///
/// The rules are the CLDR cardinal rules, restricted to integers — the app
/// counts pieces, pawns, points, moves and patterns, never a fraction. The
/// operand names below are CLDR's: `n` is the absolute value, `i` its integer
/// part, `v` the number of visible fraction digits (always 0 here).
library;

/// The CLDR cardinal categories. `other` is the only one every language has,
/// and so the only one that is always a valid fallback.
enum PluralCategory { zero, one, two, few, many, other }

/// Resolves a count to its [PluralCategory] for a language.
abstract final class PluralRules {
  /// The category [count] falls into in [lang].
  ///
  /// Unknown languages resolve as English. The sign is discarded: CLDR's `n`
  /// is an absolute value, and "down 1 point" reads off the same form as
  /// "up 1 point".
  static PluralCategory categoryFor(String lang, int count) =>
      (_rules[lang] ?? _english)(count.abs());

  /// The categories [lang] can actually produce for the counts this app
  /// shows, and therefore exactly the forms a bundle must supply.
  ///
  /// Derived by evaluating the rule rather than being typed out a second
  /// time, so it cannot drift from [categoryFor]. The domain stops at
  /// [_maxCount] because that is the honest ceiling on a chess count — which
  /// is also why Romance `many` (1000000, 2000000 …) is absent: it exists in
  /// CLDR but is unreachable here, and a translator should not be asked to
  /// write a form for a million pawns. Were such a count ever shown, it would
  /// fall back to `other`, as any missing category does.
  static Set<PluralCategory> requiredCategories(String lang) =>
      _required[lang] ??= {
        for (var n = 0; n <= _maxCount; n++) categoryFor(lang, n),
      };

  /// The largest count the app can put in front of a noun: 8 pawns, 16
  /// pieces, a few hundred moves in the longest master game in the library.
  static const _maxCount = 999;

  static final Map<String, Set<PluralCategory>> _required = {};

  static PluralCategory _english(int n) =>
      n == 1 ? PluralCategory.one : PluralCategory.other;

  /// `one` also covers zero: French and Hindi say "0 point", not "0 points".
  static PluralCategory _oneIsZeroOrOne(int n) =>
      n == 0 || n == 1 ? PluralCategory.one : PluralCategory.other;

  static PluralCategory _onlyOther(int _) => PluralCategory.other;

  /// one: i % 10 = 1 and i % 100 != 11
  /// few: i % 10 = 2..4 and i % 100 != 12..14
  /// many: everything else integral
  static PluralCategory _russian(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return PluralCategory.one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return PluralCategory.few;
    }
    return PluralCategory.many;
  }

  /// zero: n = 0 · one: n = 1 · two: n = 2
  /// few: n % 100 = 3..10 · many: n % 100 = 11..99 · other: the rest
  static PluralCategory _arabic(int n) {
    if (n == 0) return PluralCategory.zero;
    if (n == 1) return PluralCategory.one;
    if (n == 2) return PluralCategory.two;
    final mod100 = n % 100;
    if (mod100 >= 3 && mod100 <= 10) return PluralCategory.few;
    if (mod100 >= 11 && mod100 <= 99) return PluralCategory.many;
    return PluralCategory.other;
  }

  static const Map<String, PluralCategory Function(int)> _rules = {
    'en': _english,
    'es': _english,
    'it': _english,
    'pt': _oneIsZeroOrOne,
    'tr': _english,
    'fr': _oneIsZeroOrOne,
    'hi': _oneIsZeroOrOne,
    'ru': _russian,
    'ar': _arabic,
    'id': _onlyOther,
    'zh': _onlyOther,
    'ja': _onlyOther,
  };
}
