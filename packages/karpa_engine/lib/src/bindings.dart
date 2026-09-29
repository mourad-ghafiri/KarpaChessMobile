import 'dart:ffi';
import 'dart:io';

/// FFI bindings to the karpa_bridge C API.
class KarpaBridgeBindings {
  KarpaBridgeBindings(DynamicLibrary library)
      : registerListener = library.lookupFunction<
            Void Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>),
            void Function(
                Pointer<NativeFunction<Void Function(Pointer<Char>)>>)>(
          'ke_register_listener',
        ),
        start = library.lookupFunction<Int32 Function(), int Function()>(
          'ke_start',
        ),
        send = library.lookupFunction<Void Function(Pointer<Char>),
            void Function(Pointer<Char>)>('ke_send'),
        stop = library.lookupFunction<Void Function(), void Function()>(
          'ke_stop',
        ),
        free = library.lookupFunction<Void Function(Pointer<Char>),
            void Function(Pointer<Char>)>('ke_free'),
        isRunning = library.lookupFunction<Int32 Function(), int Function()>(
          'ke_is_running',
        );

  /// The engine library: a shared object on Android; on Apple platforms a
  /// framework the app links at launch, so its symbols are already in the
  /// process.
  factory KarpaBridgeBindings.open() => KarpaBridgeBindings(
        Platform.isAndroid
            ? DynamicLibrary.open('libkarpa_engine.so')
            : DynamicLibrary.process(),
      );

  /// Test double: inject Dart implementations for every entry point.
  KarpaBridgeBindings.fake({
    required this.registerListener,
    required this.start,
    required this.send,
    required this.stop,
    required this.free,
    required this.isRunning,
  });

  final void Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>)
      registerListener;
  final int Function() start;
  final void Function(Pointer<Char>) send;
  final void Function() stop;
  final void Function(Pointer<Char>) free;
  final int Function() isRunning;
}
