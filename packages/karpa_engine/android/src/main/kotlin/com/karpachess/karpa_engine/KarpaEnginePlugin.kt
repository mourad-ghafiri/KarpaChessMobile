package com.karpachess.karpa_engine

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registration anchor. The engine is consumed purely over dart:ffi
 * (libkarpa_engine.so); nothing platform-channel-based lives here.
 */
class KarpaEnginePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
