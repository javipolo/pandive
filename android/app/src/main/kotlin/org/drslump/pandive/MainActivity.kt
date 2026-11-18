package org.drslump.pandive

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val methodChannel = "pandive/dc"
    private val scanChannel = "pandive/dc/scan"
    private val main = Handler(Looper.getMainLooper())

    // Fichero .ddb entrante (abrir con / compartir), pendiente de consumir.
    private var pendingOpenPath: String? = null
    private var openSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        pendingOpenPath = extractDdb(intent)

        MethodChannel(messenger, methodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "matchName" -> result.success(
                        DiveComputer.nativeMatchName(call.argument<String>("name") ?: ""))
                    "btEnabled" -> result.success(isBluetoothOn())
                    "download" -> handleDownload(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, "pandive/open").setMethodCallHandler { call, result ->
            if (call.method == "consume") {
                result.success(pendingOpenPath.also { pendingOpenPath = null })
            } else {
                result.notImplemented()
            }
        }
        EventChannel(messenger, "pandive/open/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(a: Any?, e: EventChannel.EventSink?) { openSink = e }
                override fun onCancel(a: Any?) { openSink = null }
            }
        )

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

    // ¿Está el Bluetooth encendido?
    private fun isBluetoothOn(): Boolean {
        val mgr = getSystemService(BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
        return mgr?.adapter?.isEnabled == true
    }

    // App ya abierta: llega un nuevo .ddb -> avisar a Flutter (o dejar pendiente).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val p = extractDdb(intent) ?: return
        val sink = openSink
        if (sink != null) main.post { sink.success(p) } else pendingOpenPath = p
    }

    // Extrae el .ddb de un intent VIEW/SEND y lo copia a un temporal legible.
    private fun extractDdb(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> @Suppress("DEPRECATION")
                (intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
            else -> null
        }
        if (uri == null) return null
        return try {
            val dest = File(cacheDir, "opened-${System.currentTimeMillis()}.ddb")
            contentResolver.openInputStream(uri)!!.use { input ->
                dest.outputStream().use { input.copyTo(it) }
            }
            dest.absolutePath
        } catch (_: Exception) {
            null
        }
    }
}
