import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// The host side of every program in `test/device/`: `flutter drive` runs the
/// program inside the app on a simulator or device, and this driver, on the
/// Mac, collects its results and writes each screenshot it takes to
/// `build/screenshots/<name>.png` (the name carries its own folder).
///
/// Why these files live in `test/` without a `_test.dart` suffix: a plain
/// `flutter test` collects every `*_test.dart` under `test/` and runs it on
/// the Mac, with no simulator and no Stockfish, and `flutter test -d <device>`
/// only treats files in a root `integration_test/` folder as on-device tests.
/// `flutter drive` takes any path, so these run through it instead:
///
///     flutter drive --driver=test/device/driver.dart \
///       --target=test/device/<program>.dart -d <device>
///
/// - `engine_smoke.dart` — real Stockfish on the device.
/// - `app_flow.dart` — the app end to end, tabs, an engine game, RTL.
/// - `store_screenshots.dart` — the store set, into
///   `build/screenshots/raw/<device>/`; `tool/store_screenshots.sh` runs it on
///   each simulator and files the checked shots into `screenshots/`.
/// - `layout_audit.dart` — every screen on one device, into
///   `build/screenshots/audit/<device>/`, for judging layouts by eye.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
