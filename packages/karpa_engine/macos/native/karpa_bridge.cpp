// See karpa_bridge.h for the design overview.

#include "karpa_bridge.h"

#include <atomic>
#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <iostream>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>

#include <memory>
#include <utility>

#include "../stockfish/src/attacks.h"
#include "../stockfish/src/misc.h"
#include "../stockfish/src/position.h"
#include "../stockfish/src/tune.h"
#include "../stockfish/src/uci.h"

namespace {

std::atomic<ke_line_listener> g_listener{nullptr};

// ---------------------------------------------------------------------------
// Engine stdin: a blocking line queue exposed as a std::streambuf.
// ---------------------------------------------------------------------------
class QueueInBuf final : public std::streambuf {
 public:
  void push(const std::string& line) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      queue_.push_back(line + '\n');
    }
    ready_.notify_one();
  }

  // Wakes the engine with EOF; std::getline then fails and uci.loop exits
  // even if no `quit` was processed.
  void close() {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      closed_ = true;
    }
    ready_.notify_all();
  }

 protected:
  int_type underflow() override {
    std::unique_lock<std::mutex> lock(mutex_);
    ready_.wait(lock, [this] { return !queue_.empty() || closed_; });
    if (queue_.empty()) return traits_type::eof();
    current_ = std::move(queue_.front());
    queue_.pop_front();
    char* begin = &current_[0];
    setg(begin, begin, begin + current_.size());
    return traits_type::to_int_type(*gptr());
  }

 private:
  std::mutex mutex_;
  std::condition_variable ready_;
  std::deque<std::string> queue_;
  std::string current_;
  bool closed_ = false;
};

// ---------------------------------------------------------------------------
// Engine stdout: split into lines, each handed to the listener as a heap
// copy (ownership transfers — the Dart side frees via ke_free). Stockfish
// serializes its own output (sync_cout), but we lock anyway for safety.
// ---------------------------------------------------------------------------
class ListenerOutBuf final : public std::streambuf {
 protected:
  int_type overflow(int_type ch) override {
    if (ch == traits_type::eof()) return ch;
    std::lock_guard<std::mutex> lock(mutex_);
    append(static_cast<char>(ch));
    return ch;
  }

  std::streamsize xsputn(const char* data, std::streamsize count) override {
    std::lock_guard<std::mutex> lock(mutex_);
    for (std::streamsize i = 0; i < count; ++i) append(data[i]);
    return count;
  }

 private:
  void append(char ch) {
    if (ch == '\n') {
      emit();
    } else if (ch != '\r') {
      line_ += ch;
    }
  }

  void emit() {
    ke_line_listener listener = g_listener.load();
    if (listener != nullptr && !line_.empty()) {
      char* copy = static_cast<char*>(std::malloc(line_.size() + 1));
      if (copy != nullptr) {
        std::memcpy(copy, line_.c_str(), line_.size() + 1);
        listener(copy);
      }
    }
    line_.clear();
  }

  std::mutex mutex_;
  std::string line_;
};

struct BridgeState {
  QueueInBuf in;
  ListenerOutBuf out;
  std::streambuf* saved_cin = nullptr;
  std::streambuf* saved_cout = nullptr;
  std::thread engine_thread;
};

std::mutex g_state_mutex;
BridgeState* g_state = nullptr;
std::atomic<bool> g_running{false};

void engine_main() {
  using namespace Stockfish;
  // Mirrors Stockfish 19's main(): init once-idempotent tables, then loop.
  // `Attacks::init` replaced `Bitboards::init` in 19, and `UCIEngine` now
  // takes an owned `CommandLine` rather than raw argc/argv.
  Attacks::init();
  Position::init();

  char binary_name[] = "stockfish";
  char* argv[] = {binary_name};
  auto cli = CommandLine(1, argv);
  auto uci = std::make_unique<UCIEngine>(std::move(cli));
  Tune::init(uci->engine_options());
  uci->loop();

  g_running.store(false);
}

}  // namespace

extern "C" {

void ke_register_listener(ke_line_listener listener) {
  g_listener.store(listener);
}

int ke_start(void) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  if (g_state != nullptr) return 1;

  g_state = new BridgeState();
  g_state->saved_cin = std::cin.rdbuf(&g_state->in);
  g_state->saved_cout = std::cout.rdbuf(&g_state->out);
  g_running.store(true);
  g_state->engine_thread = std::thread(engine_main);
  return 0;
}

void ke_send(const char* line) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  if (g_state == nullptr || line == nullptr) return;
  g_state->in.push(line);
}

void ke_stop(void) {
  BridgeState* state;
  {
    std::lock_guard<std::mutex> lock(g_state_mutex);
    state = g_state;
    if (state == nullptr) return;
    g_state = nullptr;
  }
  state->in.push("quit");
  state->in.close();
  if (state->engine_thread.joinable()) state->engine_thread.join();
  std::cin.rdbuf(state->saved_cin);
  std::cout.rdbuf(state->saved_cout);
  g_running.store(false);
  delete state;
}

void ke_free(char* line) { std::free(line); }

int ke_is_running(void) { return g_running.load() ? 1 : 0; }

}  // extern "C"
