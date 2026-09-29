# KarpaChess first-party Stockfish build (Android).
cmake_minimum_required(VERSION 3.18)
project(karpa_engine CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Android 15+ requires 16KB page-size compatible libraries.
set(CMAKE_SHARED_LINKER_FLAGS
    "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")

# The default NNUE network (see stockfish/src/evaluate.h) is downloaded at
# build time and embedded into the binary via Stockfish's incbin mechanism
# (the assembler resolves the file name against this build directory).
#
# Every net is VERIFIED before it is embedded: its file name carries the
# first 12 hex digits of its SHA-256 (Stockfish's own convention, checked the
# same way by its Makefile). An unverified net is never trusted — a failed
# download once saved an HTTP error page under the net's name, and Stockfish
# exits the whole process when the net it embedded does not load.
#
# Downloads land once in a shared cache beside the package, so clean builds
# and every ABI reuse one verified copy instead of fetching ~94 MB each time.
#
# Stockfish 19 retired the second (small) network: there is one net now, and
# `evaluate.h` names it in a single EvalFileDefaultName.
set(KE_NNUE_NET "nn-1a298aa575a0.nnue")
set(KE_NNUE_CACHE "${CMAKE_CURRENT_SOURCE_DIR}/../.nnue")
file(MAKE_DIRECTORY "${KE_NNUE_CACHE}")

# Sets ${out_var} to TRUE when ${path} exists and its SHA-256 starts with the
# prefix encoded in ${net}'s name.
function(ke_nnue_verified net path out_var)
  set(${out_var} FALSE PARENT_SCOPE)
  if(NOT EXISTS "${path}")
    return()
  endif()
  string(REGEX REPLACE "^nn-([0-9a-f]+)\\.nnue$" "\\1" expected "${net}")
  file(SHA256 "${path}" actual)
  string(SUBSTRING "${actual}" 0 12 actual_prefix)
  if(actual_prefix STREQUAL expected)
    set(${out_var} TRUE PARENT_SCOPE)
  endif()
endfunction()

foreach(net ${KE_NNUE_NET})
  set(cached "${KE_NNUE_CACHE}/${net}")
  ke_nnue_verified(${net} "${cached}" ke_ok)
  if(NOT ke_ok)
    file(REMOVE "${cached}")
    # ABI-unique partial name: Gradle may configure several ABIs at once.
    set(partial "${cached}.${ANDROID_ABI}.part")
    set(attempt 0)
    while(NOT ke_ok AND attempt LESS 3)
      math(EXPR attempt "${attempt} + 1")
      message(STATUS "Downloading NNUE network ${net} (attempt ${attempt})")
      file(DOWNLOAD "https://tests.stockfishchess.org/api/nn/${net}"
           "${partial}"
           TLS_VERIFY ON
           STATUS ke_download_status)
      list(GET ke_download_status 0 ke_download_code)
      if(ke_download_code EQUAL 0)
        ke_nnue_verified(${net} "${partial}" ke_ok)
      endif()
      if(NOT ke_ok)
        file(REMOVE "${partial}")
      endif()
    endwhile()
    if(NOT ke_ok)
      message(FATAL_ERROR
        "Could not download a verified ${net}: ${ke_download_status}")
    endif()
    file(RENAME "${partial}" "${cached}")
  endif()
  configure_file("${cached}" "${CMAKE_BINARY_DIR}/${net}" COPYONLY)
endforeach()

file(GLOB_RECURSE KE_STOCKFISH_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/../stockfish/src/*.cpp")
list(FILTER KE_STOCKFISH_SOURCES EXCLUDE REGEX "main\\.cpp$")
# Stockfish 19 added `src/universal/`: the runtime-dispatch entry points for
# the `*-universal` ARCHes. Its own Makefile keeps them in OTHER_SRCS and
# links them only for those builds, but we glob the tree, so they have to be
# dropped by hand. Each defines its own `main()` — which does not belong in a
# shared library — and reaches for a platform this target may not be:
# entry_x86 needs <cpuid.h>, entry_arm64 and entry_riscv64 need <sys/auxv.h>,
# and the dispatch relies on ELF `__start_*`/`__stop_*` section symbols.
list(FILTER KE_STOCKFISH_SOURCES EXCLUDE REGEX "/universal/")

add_library(karpa_engine SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/../native/karpa_bridge.cpp"
  ${KE_STOCKFISH_SOURCES}
)

target_include_directories(karpa_engine PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../stockfish/src")

# Base defines shared by every ABI.
set(KE_DEFS -DUSE_PTHREADS -DNDEBUG)
set(KE_OPTS -O3 -fno-exceptions -funroll-loops)

if(ANDROID_ABI STREQUAL "arm64-v8a")
  # Portable 64-bit ARM: the NEON kernels of Stockfish's official `armv8`
  # build, compiled for the NDK's baseline armv8-a. Deliberately NOT
  # armv8.2-a+dotprod: dot-product instructions (and the LSE atomics that
  # -march=armv8.2-a licenses the compiler to emit) raise SIGILL on the
  # ARMv8.0 cores (Cortex-A53, A73) still inside many budget phones, which
  # kills the whole app the moment the engine searches.
  list(APPEND KE_DEFS -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8)
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
  list(APPEND KE_DEFS -DUSE_NEON=7)
  list(APPEND KE_OPTS -mfpu=neon)
elseif(ANDROID_ABI STREQUAL "x86_64")
  # Emulators and Chromebooks.
  list(APPEND KE_DEFS -DIS_64BIT -DUSE_POPCNT -DUSE_SSE41 -DUSE_SSSE3 -DUSE_SSE2)
  list(APPEND KE_OPTS -msse4.1 -mpopcnt)
endif()

target_compile_options(karpa_engine PRIVATE ${KE_OPTS} ${KE_DEFS})
target_link_options(karpa_engine PRIVATE -Wl,-z,max-page-size=16384)
target_link_libraries(karpa_engine log)
