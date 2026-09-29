#import "KarpaEnginePlugin.h"
#import "../native/karpa_bridge.h"

@implementation KarpaEnginePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if (registrar == NULL) {
    // Anchor the FFI symbols against dead-code stripping; never executed.
    ke_register_listener(NULL);
    ke_start();
    ke_send(NULL);
    ke_stop();
    ke_free(NULL);
    ke_is_running();
  }
}
@end
