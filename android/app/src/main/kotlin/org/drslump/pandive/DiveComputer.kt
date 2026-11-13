package org.drslump.pandive

import android.content.Context

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
    external fun nativeDownload(vendor: String, product: String, conn: BleConnection): String

    /**
     * Conecta al dispositivo [address], descarga las inmersiones del modelo
     * [vendor]/[product] y devuelve el JSON del wrapper nativo. Bloqueante:
     * llamar desde un hilo de trabajo.
     */
    fun download(context: Context, vendor: String, product: String, address: String): String {
        val conn = BleConnection(context.applicationContext, address)
        try {
            if (!conn.connect(20000)) {
                val msg = (conn.error() ?: "no se pudo conectar")
                    .replace("\\", " ").replace("\"", "'")
                return "{\"error\":\"$msg\"}"
            }
            return nativeDownload(vendor, product, conn)
        } finally {
            conn.close()
        }
    }
}
