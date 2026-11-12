package org.drslump.pandive

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "pandive/dc"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supportedCount" -> result.success(DiveComputer.nativeSupportedCount())
                    "supportedList" -> result.success(DiveComputer.nativeSupportedList())
                    else -> result.notImplemented()
                }
            }
    }
}
