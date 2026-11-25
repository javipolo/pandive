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
 * Native BLE scan. Emits over the EventChannel a map {name, id, rssi, likely}
 * for each device found. onListen starts the scan, onCancel stops it.
 *
 * Permissions (BLUETOOTH_SCAN/CONNECT or location on <=11) are requested from
 * Dart before subscribing.
 */
class BleScanner(private val context: Context) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var scanning = false

    // Keywords of common dive computers (to highlight them).
    private val keywords = listOf(
        "peregrine", "perdix", "petrel", "teric", "nerd", "tern", // Shearwater
        "mares", "puck", "quad", "genius", "sirius",               // Mares
        "suunto", "eon", "d5",                                     // Suunto
        "shearwater", "garmin", "descent", "oceanic", "aqualung",
        "scubapro", "galileo", "ratio", "divesoft",
        "ostc", "hw ", "heinrichs", "mclean", "cressi", "deepblu", "cosmiq",
    )

    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            emit(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { emit(it) }
        }

        override fun onScanFailed(errorCode: Int) {
            main.post { sink?.error("scan_failed", "BLE scan failed ($errorCode)", null) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun emit(result: ScanResult) {
        val name = result.scanRecord?.deviceName ?: return // only named ones
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
            events?.error("bt_off", "Bluetooth is off", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            events?.error("no_scanner", "No BLE scanner available", null)
            return
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        try {
            scanner.startScan(null, settings, callback)
            scanning = true
        } catch (e: SecurityException) {
            events?.error("perm", "Missing Bluetooth permission: ${e.message}", null)
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
