import 'dart:async';

import 'package:karpa_engine/karpa_engine.dart';

import '../../core/errors/app_errors.dart';
import '../domain/uci_transport.dart';

/// [UciTransport] over the first-party karpa_engine module.
class KarpaEngineTransport implements UciTransport {
  KarpaEngineTransport({KarpaEngine? engine})
      : _engine = engine ?? KarpaEngine();

  final KarpaEngine _engine;
  bool _started = false;

  @override
  Stream<String> get lines => _engine.lines;

  @override
  Future<void> start() async {
    if (_started) return;
    await _engine.start();
    _started = true;
  }

  @override
  void send(String line) {
    if (!_started) {
      AppErrors.note('engine transport dropped "$line" (not started)');
      return;
    }
    _engine.send(line);
  }

  @override
  Future<void> dispose() async {
    _started = false;
    await _engine.close();
  }
}
