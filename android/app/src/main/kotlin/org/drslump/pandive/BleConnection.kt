package org.drslump.pandive

import android.annotation.SuppressLint
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/**
 * Conexión BLE GATT a un ordenador de buceo, expuesta como un flujo de bytes
 * síncrono (bleRead/bleWrite) que el puente nativo con libdivecomputer usa como
 * I/O personalizado. Las operaciones GATT (async) se serializan con latches.
 *
 * Selección de característica: genérica por propiedades (una con Write/
 * WriteNoResponse para escribir, otra con Notify/Indicate para leer), dando
 * preferencia a los servicios serie conocidos (Shearwater, Mares).
 */
class BleConnection(private val context: Context, private val address: String) {
    companion object {
        private const val TAG = "PandiveBLE"
        private val CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        // Servicios "serie" conocidos, en orden de preferencia.
        private val PREFERRED_SERVICES = listOf(
            "fe25c237-0ece-443c-b0aa-e02033e7029d", // Shearwater Petrel/Perdix/Peregrine/Tern
            "1aa44039-1667-4b29-87cc-dfecaaf31d97", // Shearwater Perdix 3
            "544e326b-5b72-c6b0-1c46-41c1bc448118", // Mares BlueLink
        ).map { it.lowercase() }
    }

    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private var notifyChar: BluetoothGattCharacteristic? = null

    private val incoming = LinkedBlockingQueue<ByteArray>()
    private val connectLatch = CountDownLatch(1)
    @Volatile private var connectError: String? = null
    @Volatile private var ready = false
    @Volatile private var writeLatch: CountDownLatch? = null
    @Volatile private var writeOk = false

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.i(TAG, "Conectado; prioridad alta + MTU")
                // Intervalo de conexión corto -> descarga más rápida.
                g.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                if (!g.requestMtu(247)) g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                if (!ready) {
                    connectError = "Desconectado (status $status)"
                    connectLatch.countDown()
                }
            }
        }

        override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
            Log.i(TAG, "MTU=$mtu; descubriendo servicios")
            g.discoverServices()
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                fail("Fallo al descubrir servicios ($status)")
                return
            }
            if (!selectCharacteristics(g)) {
                fail("No se encontró característica de lectura/escritura")
                return
            }
            enableNotifications(g)
        }

        @Deprecated("API < 33")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            @Suppress("DEPRECATION")
            c.value?.let { incoming.put(it.copyOf()) }
        }

        override fun onCharacteristicChanged(
            g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray
        ) {
            incoming.put(value.copyOf())
        }

        @Deprecated("API < 33")
        override fun onCharacteristicWrite(
            g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int
        ) {
            writeOk = status == BluetoothGatt.GATT_SUCCESS
            writeLatch?.countDown()
        }

        override fun onDescriptorWrite(
            g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int
        ) {
            if (d.uuid == CCCD) {
                ready = status == BluetoothGatt.GATT_SUCCESS
                if (!ready) connectError = "No se pudieron activar notificaciones ($status)"
                connectLatch.countDown()
            }
        }
    }

    private fun fail(msg: String) {
        connectError = msg
        connectLatch.countDown()
    }

    private fun selectCharacteristics(g: BluetoothGatt): Boolean {
        val services = g.services
        val ordered = PREFERRED_SERVICES.mapNotNull { pref ->
            services.firstOrNull { it.uuid.toString().lowercase() == pref }
        } + services
        for (s in ordered) {
            var w: BluetoothGattCharacteristic? = null
            var n: BluetoothGattCharacteristic? = null
            for (c in s.characteristics) {
                val p = c.properties
                if (w == null && (p and (BluetoothGattCharacteristic.PROPERTY_WRITE or
                        BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE)) != 0) w = c
                if (n == null && (p and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or
                        BluetoothGattCharacteristic.PROPERTY_INDICATE)) != 0) n = c
            }
            if (w != null && n != null) {
                writeChar = w; notifyChar = n
                Log.i(TAG, "Servicio ${s.uuid} write=${w.uuid} notify=${n.uuid}")
                return true
            }
        }
        return false
    }

    @SuppressLint("MissingPermission")
    private fun enableNotifications(g: BluetoothGatt) {
        val n = notifyChar ?: return fail("sin característica notify")
        g.setCharacteristicNotification(n, true)
        val cccd = n.getDescriptor(CCCD) ?: return fail("sin descriptor CCCD")
        val value = if (n.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0)
            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        else BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        @Suppress("DEPRECATION")
        run { cccd.value = value; g.writeDescriptor(cccd) }
    }

    @SuppressLint("MissingPermission")
    fun connect(timeoutMs: Long): Boolean {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val device = manager.adapter.getRemoteDevice(address)
        gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        val ok = connectLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
        if (!ok) { connectError = "Timeout de conexión"; return false }
        return ready
    }

    fun error(): String? = connectError

    /** Lee el siguiente paquete recibido, o null si no llega nada en [timeoutMs]. */
    fun bleRead(timeoutMs: Int): ByteArray? =
        incoming.poll(timeoutMs.toLong(), TimeUnit.MILLISECONDS)

    /** Escribe [data] y espera confirmación. Devuelve true si OK. */
    @SuppressLint("MissingPermission")
    fun bleWrite(data: ByteArray): Boolean {
        val g = gatt ?: return false
        val c = writeChar ?: return false
        val latch = CountDownLatch(1)
        writeLatch = latch
        writeOk = false
        val mode = if (c.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0)
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        else BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        @Suppress("DEPRECATION")
        run { c.writeType = mode; c.value = data; g.writeCharacteristic(c) }
        if (!latch.await(5, TimeUnit.SECONDS)) return false
        return writeOk
    }

    @SuppressLint("MissingPermission")
    fun close() {
        try { gatt?.disconnect(); gatt?.close() } catch (_: Exception) {}
        gatt = null
    }
}
