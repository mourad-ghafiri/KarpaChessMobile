/// Type-checked readers for values decoded from stored JSON.
///
/// Stored data outlives the code that wrote it: an older build, a hand-edited
/// backup or a half-applied migration can leave a field of the wrong type.
/// An `as` cast then throws a `TypeError` that no `on FormatException`
/// catches, and when that happens while restoring prefs at startup the app
/// never opens. These readers turn a wrong-typed field into "absent", so the
/// caller's own default applies to that one field and the rest of the blob
/// still loads. Well-typed input reads exactly as the casts did.
library;

/// [value] when it is a String, else null.
String? readString(Object? value) => value is String ? value : null;

/// [value] when it is a bool, else null.
bool? readBool(Object? value) => value is bool ? value : null;

/// [value] as an int when it is any number (JSON has no int/double
/// distinction on every platform), else null.
int? readInt(Object? value) => value is num ? value.toInt() : null;

/// The Strings in [value] when it is a list, else empty. Non-string
/// entries are skipped, as the old `whereType<String>()` did.
Set<String> readStringSet(Object? value) =>
    value is List ? value.whereType<String>().toSet() : const {};

/// The ints in [value] when it is a list, else empty. Non-int entries are
/// skipped, as the old `whereType<int>()` did.
Set<int> readIntSet(Object? value) =>
    value is List ? value.whereType<int>().toSet() : const {};

/// [value] when it is a map, else empty.
Map<Object?, Object?> readMap(Object? value) =>
    value is Map ? value : const {};

/// The Strings in [value], in order, when it is a list, else empty.
/// Unlike [readStringSet] this keeps order and duplicates, which a move
/// list or a tree path depends on.
List<String> readStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

/// The ints in [value], in order, when it is a list, else empty. Any
/// number is read as an int; a non-numeric entry is skipped rather than
/// throwing, so one mangled entry costs its own position and not the blob.
List<int> readIntList(Object? value) => value is List
    ? [
        for (final v in value)
          if (v is num) v.toInt(),
      ]
    : const [];

/// The string-keyed entries of [value] when it is a map, else empty.
/// `jsonDecode` yields `Map<String, dynamic>`, but a stored blob that has
/// been through another codec may not, so the keys are re-spelled rather
/// than cast.
Map<String, Object?> readStringMap(Object? value) => value is Map
    ? {for (final e in value.entries) '${e.key}': e.value}
    : const {};
