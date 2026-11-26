package org.drslump.pandive

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val methodChannel = "pandive/dc"
    private val scanChannel = "pandive/dc/scan"
    private val main = Handler(Looper.getMainLooper())

    // Incoming file (.ddb, SSI CSV, sites JSON, .ssrf; open with / share),
    // waiting to be consumed. Dart detects the kind from the content.
    private var pendingOpenPath: String? = null
    private var openSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        pendingOpenPath = extractFile(intent)

        MethodChannel(messenger, methodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "matchName" -> result.success(
                        DiveComputer.nativeMatchName(call.argument<String>("name") ?: ""))
                    "btEnabled" -> result.success(isBluetoothOn())
                    "enableBt" -> { requestEnableBt(); result.success(null) }
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

    // Download on a worker thread (blocking); replies on the main thread.
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
                "{\"error\":\"${(e.message ?: "failed").replace("\"", "'")}\"}"
            }
            main.post { result.success(json) }
        }.start()
    }

    // Launches the system dialog to turn Bluetooth on.
    @Suppress("DEPRECATION")
    private fun requestEnableBt() {
        try {
            startActivity(Intent(android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE))
        } catch (_: Exception) {}
    }

    // Is Bluetooth on?
    private fun isBluetoothOn(): Boolean {
        val mgr = getSystemService(BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
        return mgr?.adapter?.isEnabled == true
    }

    // share_plus launches the chooser with startActivityForResult (for the result
    // callback), which prevents FLAG_ACTIVITY_NEW_TASK and makes the target app
    // stack on OUR task (you had to leave it to get back to Pandive).
    // We add NEW_TASK to ACTION_CHOOSER and to its inner intent (EXTRA_INTENT) so
    // the target opens in its own task. We don't use the share result.
    @Suppress("DEPRECATION")
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        if (intent.action == Intent.ACTION_CHOOSER) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        super.startActivityForResult(intent, requestCode, options)
    }

    // App already open: a new file arrives -> notify Flutter (or keep it pending).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val p = extractFile(intent) ?: return
        val sink = openSink
        if (sink != null) main.post { sink.success(p) } else pendingOpenPath = p
    }

    // Extracts the file from a VIEW/SEND intent and copies it to a readable temp
    // file that keeps the original name (and so its extension) when known.
    private fun extractFile(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> @Suppress("DEPRECATION")
                (intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
            else -> null
        }
        if (uri == null) return null
        return try {
            val name = displayName(uri)?.replace(Regex("[^A-Za-z0-9._-]"), "_")
                ?: "file"
            val dest = File(cacheDir, "opened-${System.currentTimeMillis()}-$name")
            contentResolver.openInputStream(uri)!!.use { input ->
                dest.outputStream().use { input.copyTo(it) }
            }
            dest.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
            ?: uri.lastPathSegment
    } catch (_: Exception) {
        uri.lastPathSegment
    }
}
