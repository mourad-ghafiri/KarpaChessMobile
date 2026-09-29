import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';

/// Registers the notices Flutter cannot collect on its own.
///
/// Flutter's license page already lists every Dart package with a LICENSE
/// file — chessground, dartchess and the engine module (`karpa_engine`,
/// which carries Stockfish's full GPL-3.0 text) among them. What it cannot
/// see is anything bundled as an asset or credited inside a package: the
/// three typefaces (SIL OFL 1.1, whose terms require the notice to travel
/// with the fonts), Stockfish itself by name, and the app's own artwork: the
/// ten piece sets and the launcher icon, dedicated to the public domain
/// (CC0 1.0). CC0 asks for no notice; this one says where the artwork comes
/// from and that it is free to reuse.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Stockfish'], _stockfish);
    yield LicenseEntryWithLineBreaks(['${AppInfo.name} artwork'], _artwork);
    final ofl = await rootBundle.loadString('assets/licenses/OFL-1.1.txt');
    for (final (font, copyright) in _fonts) {
      yield LicenseEntryWithLineBreaks([font], '$copyright\n\n$ofl');
    }
  });
}

const _stockfish = '''
Stockfish 19 — https://stockfishchess.org

Copyright (C) 2004-2026 The Stockfish developers (see the AUTHORS file).

Stockfish is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. Its complete license text is listed under karpa_engine, the KarpaChess module that embeds it.

${AppInfo.name} is distributed under the same license (${AppInfo.license}). Its complete source code is published at ${AppInfo.sourceUrl}.''';

const _artwork = '''
The ${AppInfo.name} chess pieces (the Classic, Wood, Marble, Diagram, Modern, Deco, Facet, Silhouette, Soft and Bold sets) and the launcher icon are original artwork, drawn from code published with the app's source (tool/gen_pieces.py and tool/gen_icon.py).

To the extent possible under law, the ${AppInfo.name} authors have waived all copyright and related or neighboring rights to this artwork under Creative Commons CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/''';

/// Each bundled typeface with the copyright line from its own name table.
const _fonts = [
  (
    'Fraunces',
    'Copyright 2020 The Fraunces Project Authors '
        '(github.com/undercasetype/Fraunces)',
  ),
  (
    'Inter',
    'Copyright 2016 The Inter Project Authors (https://github.com/rsms/inter)',
  ),
  (
    'JetBrains Mono',
    'Copyright 2020 The JetBrains Mono Project Authors '
        '(https://github.com/JetBrains/JetBrainsMono)',
  ),
];
