// KarpaChess first-party Stockfish bridge.
//
// Runs the Stockfish UCI engine on a dedicated thread inside the app
// process, exchanging UCI text through in-memory stream buffers:
//   - input:  ke_send() enqueues a line; a blocking streambuf feeds it to
//             the engine's std::cin.
//   - output: a line-splitting streambuf on std::cout hands each complete
//             line to the registered listener (a Dart NativeCallable), with
//             ownership of a heap copy transferred to Dart.
//
// No OS pipes, no polling threads, no Stockfish source patches.

#ifndef KARPA_BRIDGE_H_
#define KARPA_BRIDGE_H_

#ifdef __cplusplus
extern "C" {
#endif

// Receives one UCI line. The string is heap-allocated by the bridge and
// ownership transfers to the callee, which must release it with ke_free().
typedef void (*ke_line_listener)(char* line);

// Registers the output listener. Pass nullptr to unregister.
void ke_register_listener(ke_line_listener listener);

// Starts the engine thread. Returns 0 on success, 1 if already running.
int ke_start(void);

// Enqueues one UCI command line (without trailing newline).
void ke_send(const char* line);

// Sends `quit`, joins the engine thread and releases the buffers.
// The bridge is restartable: ke_start() may be called again afterwards.
void ke_stop(void);

// Frees a line received by the listener.
void ke_free(char* line);

// 1 while the engine thread is running.
int ke_is_running(void);

#ifdef __cplusplus
}
#endif

#endif  // KARPA_BRIDGE_H_
