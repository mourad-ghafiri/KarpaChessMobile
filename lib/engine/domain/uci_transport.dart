/// Raw line-oriented I/O with a UCI engine process. Implemented over the
/// Stockfish FFI plugin in production and by fakes in tests.
abstract interface class UciTransport {
  /// Starts the engine process. Completes when it is accepting input.
  Future<void> start();

  /// Engine stdout, one UCI line per event (trimmed, no newlines).
  Stream<String> get lines;

  /// Writes one line to engine stdin.
  void send(String line);

  /// Terminates the engine process.
  Future<void> dispose();
}
