package org.drslump.pandive

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannel = "pandive/dc"
    private val scanChannel = "pandive/dc/scan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, methodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supportedCount" -> result.success(DiveComputer.nativeSupportedCount())
                    "supportedList" -> result.success(DiveComputer.nativeSupportedList())
                    else -> result.notImplemented()
                }
            }

        EventChannel(messenger, scanChannel).setStreamHandler(BleScanner(this))
    }
}
