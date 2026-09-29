import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/karpa_engine_transport.dart';
import '../domain/engine_service.dart';
import '../domain/uci_engine_service.dart';

/// The app-wide engine. Lazy: the Stockfish process only starts on the first
/// search request.
final engineServiceProvider = Provider<EngineService>((ref) {
  final service = UciEngineService(KarpaEngineTransport());
  ref.onDispose(service.dispose);
  return service;
});
