package org.drslump.pandive

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannel = "pandive/dc"
    private val scanChannel = "pandive/dc/scan"
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, methodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supportedCount" -> result.success(DiveComputer.nativeSupportedCount())
                    "supportedList" -> result.success(DiveComputer.nativeSupportedList())
                    "download" -> handleDownload(call, result)
                    else -> result.notImplemented()
                }
            }

        EventChannel(messenger, scanChannel).setStreamHandler(BleScanner(this))

        EventChannel(messenger, "pandive/dc/progress").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    DiveComputer.progressSink = events
                }
                override fun onCancel(args: Any?) {
                    DiveComputer.progressSink = null
                }
            }
        )
    }

    // Descarga en un hilo de trabajo (bloqueante); responde en el hilo principal.
    private fun handleDownload(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val vendor = call.argument<String>("vendor") ?: ""
        val product = call.argument<String>("product") ?: ""
        val address = call.argument<String>("address") ?: ""
        val fingerprint = call.argument<String>("fingerprint") ?: ""
        val maxDives = call.argument<Int>("maxDives") ?: 0
        Thread {
            val json = try {
                DiveComputer.download(this, vendor, product, address, fingerprint, maxDives)
            } catch (e: Exception) {
                "{\"error\":\"${(e.message ?: "fallo").replace("\"", "'")}\"}"
            }
            main.post { result.success(json) }
        }.start()
    }
}
