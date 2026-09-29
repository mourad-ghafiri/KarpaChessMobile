import 'dart:convert';
import 'dart:io';

import 'src/findings.dart';

/// Nothing personal or machine-specific in what this checkout would publish.
///
///   dart run tool/shareable.dart
///
/// It scans exactly the files a push — or a new repository made from this
/// checkout — would carry: the tracked files plus the untracked ones that
/// `.gitignore` does not exclude (`git ls-files --cached --others
/// --exclude-standard`). The git-ignored local files (build output,
/// `.dart_tool/`, `android/local.properties`, `ios/Flutter/Generated.xcconfig`
/// and more) are full of absolute paths to this machine, and that is fine
/// exactly as long as they stay ignored.
///
/// Errors:
/// - this machine's home directory or account name, read from the
///   environment when the gate runs, so neither is ever written into the repo;
/// - any absolute home path (`/Users/<name>/`, `/home/<name>/`) in text;
/// - a signing team in an Xcode project. `DEVELOPMENT_TEAM` belongs in the
///   git-ignored `ios/Flutter/Signing.xcconfig`; Xcode's Signing tab writes
///   it into `project.pbxproj` instead, so move it back when that happens;
/// - generated output and local configuration;
/// - credential files, judged by NAME only — the gate never opens them.
void main(List<String> args) {
  final files = _publishable();
  final identity = _MachineIdentity.fromEnvironment();
  final findings = <Finding>[
    for (final path in files) ..._check(path, identity),
  ];
  exit(report(findings, 'checked ${files.length} publishable files'));
}

List<String> _publishable() {
  final result = Process.runSync(
    'git',
    ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    stdoutEncoding: utf8,
  );
  if (result.exitCode != 0) {
    stderr.writeln('git ls-files failed: ${result.stderr}');
    exit(2);
  }
  return (result.stdout as String)
      .split('\u0000')
      .where((path) => path.isNotEmpty)
      .toList()
    ..sort();
}

/// Directories only a build, a tool or an IDE writes.
const _generatedDirs = {
  'build',
  '.dart_tool',
  'Pods',
  '.symlinks',
  'ephemeral',
  'xcuserdata',
  'DerivedData',
  '.gradle',
  '.cxx',
  '.kotlin',
  '__pycache__',
  '.idea',
};

/// Files that record this machine: SDK locations, absolute project paths,
/// Finder metadata.
const _generatedFiles = {
  'local.properties',
  'Generated.xcconfig',
  'flutter_export_environment.sh',
  '.flutter-plugins',
  '.flutter-plugins-dependencies',
  '.DS_Store',
};

/// A credential's file name. Such a file is reported, never read.
bool _isCredentialName(String name) =>
    name == 'key.properties' ||
    name == 'Signing.xcconfig' ||
    name.startsWith('.env') ||
    const ['.jks', '.keystore', '.p12', '.p8', '.pem', '.pfx', '.mobileprovision']
        .any(name.endsWith);

/// An absolute path into someone's home directory.
final _homePath = RegExp(r'/(?:Users|home)/[A-Za-z0-9._-]+/');

final _signingTeam = RegExp(r'DEVELOPMENT_TEAM\s*=\s*"?[A-Za-z0-9]+"?\s*;');

Iterable<Finding> _check(String path, _MachineIdentity identity) sync* {
  final segments = path.split('/');
  final name = segments.last;
  if (segments.any(_generatedDirs.contains) || _generatedFiles.contains(name)) {
    yield Finding.error(path, 'generated or machine-local file — ignore it');
    return;
  }
  if (_isCredentialName(name)) {
    yield Finding.error(path, 'a credential file by its name — never publish it');
    return;
  }

  final file = File(path);
  if (!file.existsSync()) return; // tracked, but deleted in this checkout
  final bytes = file.readAsBytesSync();
  if (identity.appearsIn(bytes)) {
    yield Finding.error(path, "contains this machine's home path or account name");
  }
  if (_isBinary(bytes)) return;

  final text = utf8.decode(bytes, allowMalformed: true);
  if (_homePath.hasMatch(text)) {
    yield Finding.error(path, 'contains an absolute home-directory path');
  }
  if (path.endsWith('.pbxproj') && _signingTeam.hasMatch(text)) {
    yield Finding.error(path,
        'names a signing team — keep DEVELOPMENT_TEAM in ios/Flutter/Signing.xcconfig');
  }
}

/// A NUL byte in the first 8 KB, the heuristic git itself uses.
bool _isBinary(List<int> bytes) =>
    bytes.take(8192).any((byte) => byte == 0);

/// This machine's home path and account name, as byte patterns.
class _MachineIdentity {
  _MachineIdentity(this._needles);

  factory _MachineIdentity.fromEnvironment() {
    final env = Platform.environment;
    final home = env['HOME'];
    final names = {
      if (home != null && home.contains('/')) home.split('/').last,
      if (env['USER'] != null) env['USER']!,
    };
    return _MachineIdentity([
      if (home != null && home.length > 1) home,
      // A very short account name would match ordinary words.
      for (final name in names)
        if (name.length >= 5) name,
    ]);
  }

  final List<String> _needles;

  bool appearsIn(List<int> bytes) {
    final haystack = latin1.decode(bytes, allowInvalid: true).toLowerCase();
    return _needles.any((needle) => haystack.contains(needle.toLowerCase()));
  }
}
