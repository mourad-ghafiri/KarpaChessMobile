#
# KarpaChess first-party Stockfish build (macOS).
# Same sources as iOS; arch-conditional NNUE kernels
# (Apple Silicon dotprod / Intel SSE4.1).
#
Pod::Spec.new do |s|
  s.name             = 'karpa_engine'
  s.version          = '1.0.0'
  s.summary          = "KarpaChess's first-party Stockfish engine module."
  s.homepage         = 'https://github.com/mourad-ghafiri/KarpaChessMobile'
  s.license          = { :type => 'GPL-3.0-or-later', :file => 'stockfish/Copying.txt' }
  s.author           = 'KarpaChess'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*',
                       'native/*.{h,cpp}',
                       'stockfish/src/**/*.{h,cpp}'
  # `universal/` holds Stockfish 19's runtime-dispatch entry points, which
  # upstream links only for an `ARCH=*-universal` build. They each define a
  # `main()` and include <cpuid.h> / <sys/auxv.h>, neither of which exists on
  # an Apple arm64 target, so globbing them in breaks the build.
  s.exclude_files    = 'stockfish/src/main.cpp',
                       'stockfish/src/incbin/UNLICENCE',
                       'stockfish/src/universal/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.osx.deployment_target = '10.15'
  s.library = 'c++'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  # Apple's required-reason API declaration: Stockfish's tablebase loader
  # references fstat(). Without it App Store Connect rejects the upload.
  s.resource_bundles = {
    'karpa_engine_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }

  # The default network (Stockfish 19 has one), fetched and verified against
  # the SHA-256 prefix in its name (see tool/fetch_nnue.sh), then embedded
  # via incbin.
  s.script_phase = [
    {
      :execution_position => :before_compile,
      :name => 'Fetch NNUE (verified)',
      :script => 'sh "${PODS_TARGET_SRCROOT}/tool/fetch_nnue.sh" nn-1a298aa575a0.nnue "$PWD"'
    },
  ]

  # Profile gets Release's optimized engine: `flutter run --profile` is how
  # engine timings are measured, and an -Os/assert build would mislead them.
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS[config=Debug]' =>
      '$(inherited) -std=c++17 -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT',
    'OTHER_CPLUSPLUSFLAGS[config=Debug][arch=arm64]' =>
      '$(inherited) -std=c++17 -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -DUSE_NEON_DOTPROD',
    'OTHER_CPLUSPLUSFLAGS[config=Release][arch=arm64]' =>
      '$(inherited) -std=c++17 -fno-exceptions -DNDEBUG -O3 -funroll-loops -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -DUSE_NEON_DOTPROD',
    'OTHER_CPLUSPLUSFLAGS[config=Release][arch=x86_64]' =>
      '$(inherited) -std=c++17 -fno-exceptions -DNDEBUG -O3 -funroll-loops -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -DUSE_SSE41 -DUSE_SSSE3 -DUSE_SSE2 -msse4.1 -mpopcnt',
    'OTHER_CPLUSPLUSFLAGS[config=Profile][arch=arm64]' =>
      '$(inherited) -std=c++17 -fno-exceptions -DNDEBUG -O3 -funroll-loops -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -DUSE_NEON_DOTPROD',
    'OTHER_CPLUSPLUSFLAGS[config=Profile][arch=x86_64]' =>
      '$(inherited) -std=c++17 -fno-exceptions -DNDEBUG -O3 -funroll-loops -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -DUSE_SSE41 -DUSE_SSSE3 -DUSE_SSE2 -msse4.1 -mpopcnt'
  }
end
