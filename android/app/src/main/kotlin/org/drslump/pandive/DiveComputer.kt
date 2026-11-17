package org.drslump.pandive

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Puente a libdivecomputer vía el wrapper JNI nativo (libpandive_dc.so).
 *  - Capacidad: nº y lista de modelos soportados.
 *  - Descarga: conecta por BLE (BleConnection) y vuelca las inmersiones a JSON.
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

    /** Sink del EventChannel de progreso (lo fija MainActivity). */
    @Volatile
    var progressSink: EventChannel.EventSink? = null

    /** Llamado desde C (JNI) en cada DC_EVENT_PROGRESS. */
    @JvmStatic
    fun reportProgress(current: Int, maximum: Int) {
        val sink = progressSink ?: return
        main.post { sink.success(mapOf("current" to current, "maximum" to maximum)) }
    }

    /**
     * Conecta al dispositivo [address], descarga las inmersiones del modelo
     * [vendor]/[product] y devuelve el JSON del wrapper nativo. Bloqueante:
     * llamar desde un hilo de trabajo.
     */
    fun download(
        context: Context, vendor: String, product: String, address: String,
        fingerprint: String, maxDives: Int,
    ): String {
        val conn = BleConnection(context.applicationContext, address)
        try {
            if (!conn.connect(20000)) {
                val msg = (conn.error() ?: "no se pudo conectar")
                    .replace("\\", " ").replace("\"", "'")
                return "{\"error\":\"$msg\"}"
            }
            return nativeDownload(vendor, product, conn, fingerprint, maxDives)
        } finally {
            conn.close()
        }
    }
}
