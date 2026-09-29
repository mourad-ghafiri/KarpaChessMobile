import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'src/bindings.dart';

export 'src/bindings.dart' show KarpaBridgeBindings;

/// KarpaChess's first-party Stockfish engine.
///
/// The engine runs on a native thread inside the app process; UCI lines go
/// in through [send] and come back on [lines], pushed by the native side
/// through a [NativeCallable.listener] — no polling, no reader isolates.
/// Instances are restartable: after [dispose], a new [KarpaEngine] (or the
/// same one) may [start] again.
class KarpaEngine {
  KarpaEngine({KarpaBridgeBindings? bindings})
      : _bindings = bindings ?? KarpaBridgeBindings.open();

  final KarpaBridgeBindings _bindings;
  final _lines = StreamController<String>.broadcast();
  NativeCallable<Void Function(Pointer<Char>)>? _listener;
  bool _started = false;

  /// Engine stdout, one UCI line per event.
  Stream<String> get lines => _lines.stream;

  bool get isRunning => _bindings.isRunning() != 0;

  /// Boots the engine thread. Completes once the engine answers `uci`
  /// with `uciok`, proving the full in/out path works.
  Future<void> start({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_started) return;

    _listener = NativeCallable<Void Function(Pointer<Char>)>.listener(
      _onNativeLine,
    );
    _bindings.registerListener(_listener!.nativeFunction);

    final result = _bindings.start();
    if (result != 0 && !isRunning) {
      throw StateError('karpa_engine failed to start (code $result)');
    }
    _started = true;

    final uciok = lines.firstWhere((line) => line.trim() == 'uciok');
    send('uci');
    await uciok.timeout(timeout, onTimeout: () {
      throw TimeoutException('Stockfish did not answer uci', timeout);
    });
  }

  void _onNativeLine(Pointer<Char> line) {
    try {
      _lines.add(line.cast<Utf8>().toDartString());
    } finally {
      _bindings.free(line);
    }
  }

  /// Sends one UCI command (no trailing newline needed).
  void send(String command) {
    if (!_started) throw StateError('KarpaEngine not started');
    final pointer = command.toNativeUtf8();
    try {
      _bindings.send(pointer.cast());
    } finally {
      malloc.free(pointer);
    }
  }

  /// Stops the engine thread gracefully and releases the listener.
  /// The stream stays open across restarts; call [close] to end it.
  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    _bindings.stop();
    _bindings.registerListener(nullptr);
    _listener?.close();
    _listener = null;
  }

  /// Fully closes this instance (stream included).
  Future<void> close() async {
    await dispose();
    await _lines.close();
  }
}
