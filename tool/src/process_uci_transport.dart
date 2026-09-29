import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:karpachess/engine/domain/uci_transport.dart';

/// [UciTransport] over a Stockfish **subprocess**, for the content tooling.
///
/// The app talks to Stockfish in-process through the FFI bridge, which needs a
/// Flutter host to link against. A `dart run tool/…` script has no such host,
/// so it drives the same engine over stdin/stdout instead. Only the pipe
/// differs: `UciEngineService` — the queueing, MultiPV-aware, White-normalising
/// client — is reused verbatim, which is the whole point. The tooling must
/// judge chess with the engine the app ships, never with a search of its own.
///
/// **One process.** A gate boots this once and reuses it for the whole corpus
/// (`ucinewgame` + `position` + `go` per puzzle). Never one process per puzzle,
/// never two at a time.
class ProcessUciTransport implements UciTransport {
  ProcessUciTransport(this.executable);

  /// Path to a UCI engine binary.
  final String executable;

  final StreamController<String> _lines = StreamController<String>.broadcast();
  Process? _process;

  /// The engine's own `id name` line, once it has booted — so a run can record
  /// which engine judged it rather than leaving that to memory.
  String? get identity => _identity;
  String? _identity;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> start() async {
    if (_process != null) return;
    final process = await Process.start(executable, const []);
    _process = process;

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || _lines.isClosed) return;
      if (_identity == null && trimmed.startsWith('id name ')) {
        _identity = trimmed.substring('id name '.length);
      }
      _lines.add(trimmed);
    });

    // Stockfish is quiet on stderr, so anything here is a real problem (a
    // missing NNUE net aborts the process). Swallowing it would leave the
    // client waiting for a `uciok` that is never coming.
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stderr.writeln('[stockfish] $line'));

    unawaited(process.exitCode.then((code) {
      _process = null;
      if (code != 0 && !_lines.isClosed) {
        stderr.writeln('[stockfish] exited with code $code');
      }
    }));
  }

  @override
  void send(String line) {
    final process = _process;
    if (process == null) {
      throw StateError('ProcessUciTransport: send("$line") before start()');
    }
    process.stdin.writeln(line);
  }

  @override
  Future<void> dispose() async {
    final process = _process;
    _process = null;
    if (process != null) {
      try {
        process.stdin.writeln('quit');
        await process.stdin.flush();
      } on Object {
        // Already gone; the kill below is the backstop.
      }
      // A stray engine pinning a core is exactly what we must not leave behind.
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    if (!_lines.isClosed) await _lines.close();
  }
}

/// Where the tooling looks for a Stockfish binary, in order of preference.
///
/// There is deliberately **no fallback to a hand-rolled search**. If no engine
/// is found the caller is told how to build one and the screen does not run —
/// a silent downgrade to a toy evaluation is how `rivals()` came to exist.
abstract final class StockfishBinary {
  /// Set this to point the gates at a specific binary.
  static const envVar = 'KARPA_STOCKFISH';

  /// Built from the app's own vendored sources by
  /// `packages/karpa_engine/tool/build_host.sh` — the engine the app ships.
  static const hostBuild =
      'packages/karpa_engine/stockfish/src/stockfish';

  /// The first binary that exists, or null.
  static String? locate() {
    final override = Platform.environment[envVar];
    if (override != null && override.isNotEmpty) {
      return File(override).existsSync() ? override : null;
    }
    if (File(hostBuild).existsSync()) return hostBuild;
    final onPath = _which('stockfish');
    return onPath;
  }

  /// [locate], or an explanation of how to get one.
  static String require() {
    final found = locate();
    if (found != null) return found;
    throw StateError(
      'No Stockfish binary found.\n'
      '  Build the one the app ships:\n'
      '    sh packages/karpa_engine/tool/build_host.sh\n'
      '  or point at another:\n'
      '    $envVar=/path/to/stockfish dart run tool/puzzles.dart check --engine\n'
      'The screen does not run without an engine — it will not fall back to a\n'
      'search of its own.',
    );
  }

  static String? _which(String name) {
    final result = Process.runSync('which', [name]);
    if (result.exitCode != 0) return null;
    final path = (result.stdout as String).trim();
    return path.isEmpty ? null : path;
  }
}
