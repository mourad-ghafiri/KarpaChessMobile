import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karpa_engine/karpa_engine.dart';

/// In-memory scripted bridge: records sends, lets tests inject output lines
/// through the registered NativeCallable exactly like the C++ side would.
class FakeBridge {
  FakeBridge() {
    bindings = KarpaBridgeBindings.fake(
      registerListener: (fn) => _listener = fn,
      start: () {
        running = true;
        startCalls++;
        return 0;
      },
      send: (ptr) => sent.add(ptr.cast<Utf8>().toDartString()),
      stop: () {
        running = false;
        stopCalls++;
      },
      free: (ptr) {
        freed++;
        malloc.free(ptr);
      },
      isRunning: () => running ? 1 : 0,
    );
  }

  late final KarpaBridgeBindings bindings;
  Pointer<NativeFunction<Void Function(Pointer<Char>)>>? _listener;
  final sent = <String>[];
  var running = false;
  var startCalls = 0;
  var stopCalls = 0;
  var freed = 0;

  /// Emits a line to Dart the way the native side does: malloc'd copy,
  /// ownership transferred.
  void emit(String line) {
    final fn = _listener;
    expect(fn, isNotNull, reason: 'no listener registered');
    final callable = fn!
        .asFunction<void Function(Pointer<Char>)>();
    callable(line.toNativeUtf8().cast());
  }
}

void main() {
  test('start performs the uci handshake and streams lines', () async {
    final bridge = FakeBridge();
    final engine = KarpaEngine(bindings: bridge.bindings);

    final startFuture = engine.start();
    // The engine sent 'uci'; answer like Stockfish.
    await Future<void>.delayed(Duration.zero);
    expect(bridge.sent, ['uci']);
    bridge.emit('id name Stockfish 19');
    bridge.emit('uciok');
    await startFuture;

    final collected = <String>[];
    final sub = engine.lines.listen(collected.add);
    bridge.emit('readyok');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(collected, ['readyok']);
    expect(bridge.freed, 3);
    await sub.cancel();
    await engine.close();
    expect(bridge.stopCalls, 1);
  });

  test('send after dispose throws; restart works', () async {
    final bridge = FakeBridge();
    final engine = KarpaEngine(bindings: bridge.bindings);

    final start1 = engine.start();
    await Future<void>.delayed(Duration.zero);
    bridge.emit('uciok');
    await start1;
    engine.send('isready');
    expect(bridge.sent, ['uci', 'isready']);

    await engine.dispose();
    expect(() => engine.send('uci'), throwsStateError);
    expect(bridge.stopCalls, 1);

    // Restartable: same instance boots again.
    final start2 = engine.start();
    await Future<void>.delayed(Duration.zero);
    bridge.emit('uciok');
    await start2;
    expect(bridge.startCalls, 2);
    engine.send('isready');
    expect(bridge.sent.last, 'isready');
    await engine.close();
  });
}
