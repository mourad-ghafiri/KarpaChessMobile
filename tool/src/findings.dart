import 'dart:io';

/// What a gate has to say about one file.
///
/// Two levels and no more. An **error** is a fact: the id does not match the
/// filename, the move is illegal, the position repeats. It is never a matter of
/// taste and it must be zero before anything ships. A **flag** is a screen — it
/// says "look at this", and a human decides.
enum Level { error, flag }

class Finding {
  const Finding(this.level, this.subject, this.message);

  const Finding.error(String subject, String message)
      : this(Level.error, subject, message);

  const Finding.flag(String subject, String message)
      : this(Level.flag, subject, message);

  /// The puzzle id, lesson file or manifest the finding is about.
  final String subject;
  final String message;
  final Level level;
}

/// Prints findings and returns the process exit code.
///
/// Errors first, then flags: the list you must act on should not be buried
/// under the list you merely have to read.
int report(List<Finding> findings, String summary) {
  const red = '\x1B[31m';
  const yellow = '\x1B[33m';
  const green = '\x1B[32m';
  const off = '\x1B[0m';

  final errors = findings.where((f) => f.level == Level.error).toList();
  final flags = findings.where((f) => f.level == Level.flag).toList();

  for (final f in errors) {
    stdout.writeln('$red✗$off ${f.subject}: ${f.message}');
  }
  for (final f in flags) {
    stdout.writeln('$yellow⚠$off ${f.subject}: ${f.message}');
  }

  final errorText =
      errors.isEmpty ? '${green}0 errors$off' : '$red${errors.length} error(s)$off';
  final flagText =
      flags.isEmpty ? '${green}0 flags$off' : '$yellow${flags.length} flag(s)$off';
  stdout.writeln('\n$summary: $errorText, $flagText');
  return errors.isEmpty ? 0 : 1;
}
