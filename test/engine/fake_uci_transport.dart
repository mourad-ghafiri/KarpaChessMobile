import 'dart:async';

import 'package:karpachess/engine/domain/uci_transport.dart';

/// Scriptable in-memory UCI engine for tests. Responds to the handshake
/// automatically and answers `go` according to [onGo].
class FakeUciTransport implements UciTransport {
  FakeUciTransport({this.onGo});

  /// Called for each `go`; returns the lines to emit (info + bestmove).
  /// When null, replies `bestmove e2e4` after an optional [searchDelay].
  List<String> Function(String positionFen, String goArgs)? onGo;

  Duration searchDelay = Duration.zero;

  /// Every line the service sent, in order.
  final List<String> sent = [];

  /// FEN of the last `position fen ...` command.
  String? lastFen;

  /// The `moves` of the last `position` command (empty when it had none).
  List<String> lastMoves = const [];

  /// Number of `go` commands received.
  int goCount = 0;

  /// Whether a search is "running" (go received, bestmove not yet emitted).
  bool searching = false;

  /// How many [start] calls throw before one succeeds — an engine library
  /// that failed to load, or a boot that timed out.
  int failStarts = 0;

  final _lines = StreamController<String>.broadcast();
  bool _started = false;

  @override
  Stream<String> get lines => _lines.stream;

  void emit(String line) => _lines.add(line);

  @override
  Future<void> start() async {
    if (failStarts > 0) {
      failStarts--;
      throw StateError('engine failed to start');
    }
    _started = true;
  }

  @override
  void send(String line) {
    if (!_started) throw StateError('send before start');
    sent.add(line);
    if (line == 'uci') {
      emit('id name FakeFish');
      emit('uciok');
    } else if (line == 'isready') {
      emit('readyok');
    } else if (line.startsWith('position fen ')) {
      final rest = line.substring('position fen '.length);
      final at = rest.indexOf(' moves ');
      lastFen = at == -1 ? rest : rest.substring(0, at);
      lastMoves = at == -1
          ? const []
          : rest.substring(at + ' moves '.length).split(' ');
    } else if (line.startsWith('go')) {
      goCount++;
      searching = true;
      final fen = lastFen ?? '';
      final args = line.length > 2 ? line.substring(3) : '';
      Future<void>.delayed(searchDelay).then((_) {
        if (!searching) return;
        final reply = onGo?.call(fen, args) ??
            ['info depth 10 score cp 34 pv e2e4', 'bestmove e2e4'];
        for (final l in reply) {
          emit(l);
        }
        searching = false;
      });
    } else if (line == 'stop') {
      if (searching) {
        searching = false;
        emit('bestmove e2e4');
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _lines.close();
  }
}
