/// The translation seams the domain depends on.
///
/// Deliberately its own file, with no imports at all: domain layers are pure
/// Dart, and `i18n_service.dart` pulls in `package:flutter/services.dart` to
/// read the asset bundle. Depending on the function type instead of the
/// service is what keeps the coach, the hint composer and the review
/// explainer testable with a plain closure.
library;

/// Looks up a message and fills its `{name}` tokens.
typedef Translate = String Function(String key, [Map<String, Object?>? params]);

/// Looks up a count-bearing message and fills its `{name}` tokens, with `{n}`
/// bound to the count.
///
/// The count is passed through rather than used to pick a word first: which
/// form a number takes is the language's business, not the caller's.
typedef Pluralize = String Function(String key, int count,
    [Map<String, Object?>? params]);
