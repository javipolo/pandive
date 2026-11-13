package org.drslump.pandive

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Escaneo BLE nativo. Emite por EventChannel un mapa {name, id, rssi, likely}
 * por cada dispositivo encontrado. onListen arranca el escaneo, onCancel lo para.
 *
 * Los permisos (BLUETOOTH_SCAN/CONNECT o localización en <=11) se piden desde
 * Dart antes de suscribirse.
 */
class BleScanner(private val context: Context) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var scanning = false

    // Palabras clave de ordenadores de buceo habituales (para destacarlos).
    private val keywords = listOf(
        "peregrine", "perdix", "petrel", "teric", "nerd", "tern", // Shearwater
        "mares", "puck", "quad", "genius", "sirius",               // Mares
        "suunto", "eon", "d5",                                     // Suunto
        "shearwater", "garmin", "descent", "oceanic", "aqualung",
        "scubapro", "galileo", "ratio", "divesoft",
    )

    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            emit(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { emit(it) }
        }

        override fun onScanFailed(errorCode: Int) {
            main.post { sink?.error("scan_failed", "Escaneo BLE falló ($errorCode)", null) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun emit(result: ScanResult) {
        val name = result.scanRecord?.deviceName ?: return // solo con nombre
        if (name.isBlank()) return
        val likely = keywords.any { name.lowercase().contains(it) }
        val data = mapOf(
            "name" to name,
            "id" to result.device.address,
            "rssi" to result.rssi,
            "likely" to likely,
        )
        main.post { sink?.success(data) }
    }

    @SuppressLint("MissingPermission")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) {
            events?.error("bt_off", "Bluetooth desactivado", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            events?.error("no_scanner", "No hay escáner BLE disponible", null)
            return
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        try {
            scanner.startScan(null, settings, callback)
            scanning = true
        } catch (e: SecurityException) {
            events?.error("perm", "Falta permiso de Bluetooth: ${e.message}", null)
        }
    }

    @SuppressLint("MissingPermission")
    override fun onCancel(arguments: Any?) {
        stop()
        sink = null
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        if (!scanning) return
        scanning = false
        try {
            val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            manager?.adapter?.bluetoothLeScanner?.stopScan(callback)
        } catch (_: SecurityException) {
        }
    }
}
