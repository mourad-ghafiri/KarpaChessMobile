import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/core/app_info.dart';

void main() {
  // Settings › About and the licenses page state AppInfo.version; the stores
  // read pubspec's. A release that bumps one and not the other would ship
  // saying the wrong version.
  test('AppInfo.version matches the version name in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*([^\s+]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
    expect(AppInfo.version, match!.group(1));
  });

  test('the source address is a public https URL', () {
    expect(Uri.parse(AppInfo.sourceUrl).isScheme('https'), isTrue);
  });
}
