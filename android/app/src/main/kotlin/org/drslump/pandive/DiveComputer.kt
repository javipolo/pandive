package org.drslump.pandive

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridge to libdivecomputer via the native JNI wrapper (libpandive_dc.so).
 *  - Capability: number and list of supported models.
 *  - Download: connects over BLE (BleConnection) and dumps the dives as JSON.
 */
object DiveComputer {
    init {
        System.loadLibrary("pandive_dc")
    }

    external fun nativeSupportedCount(): Int
    external fun nativeSupportedList(): String
    external fun nativeMatchName(name: String): String
    external fun nativeDownload(
        vendor: String, product: String, conn: BleConnection, fingerprint: String,
        maxDives: Int,
    ): String

    private val main = Handler(Looper.getMainLooper())

    /** Sink of the progress EventChannel (set by MainActivity). */
    @Volatile
    var progressSink: EventChannel.EventSink? = null

    /** Called from C (JNI) on each DC_EVENT_PROGRESS. */
    @JvmStatic
    fun reportProgress(current: Int, maximum: Int) {
        val sink = progressSink ?: return
        main.post { sink.success(mapOf("current" to current, "maximum" to maximum)) }
    }

    /**
     * Connects to device [address], downloads the dives of model
     * [vendor]/[product] and returns the native wrapper's JSON. Blocking:
     * call from a worker thread.
     */
    fun download(
        context: Context, vendor: String, product: String, address: String,
        fingerprint: String, maxDives: Int,
    ): String {
        val conn = BleConnection(context.applicationContext, address)
        try {
            if (!conn.connect(20000)) {
                val msg = (conn.error() ?: "could not connect")
                    .replace("\\", " ").replace("\"", "'")
                return "{\"error\":\"$msg\"}"
            }
            return nativeDownload(vendor, product, conn, fingerprint, maxDives)
        } finally {
            conn.close()
        }
    }
}
