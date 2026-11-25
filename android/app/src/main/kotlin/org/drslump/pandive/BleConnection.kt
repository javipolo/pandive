package org.drslump.pandive

import android.annotation.SuppressLint
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
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

        // Heinrichs Weikamp (OSTC) con módulo BLE Telit/Stollmann: servicio
        // "Terminal I/O" con control de flujo por créditos.
        private val HW_TELIT_SERVICE =
            UUID.fromString("0000fefb-0000-1000-8000-00805f9b34fb")
        private val T_DATA_TX = UUID.fromString("00000001-0000-1000-8000-008025000000")
        private val T_DATA_RX = UUID.fromString("00000002-0000-1000-8000-008025000000")
        private val T_CRED_TX = UUID.fromString("00000003-0000-1000-8000-008025000000")
        private val T_CRED_RX = UUID.fromString("00000004-0000-1000-8000-008025000000")
        private const val MAX_CREDIT = 254
        private const val MIN_CREDIT = 32
    }

    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private var notifyChar: BluetoothGattCharacteristic? = null

    // Modo crédito (Telit/HW): características dedicadas de datos y créditos.
    private var creditMode = false
    private var dataTx: BluetoothGattCharacteristic? = null // device->host (notify)
    private var dataRx: BluetoothGattCharacteristic? = null // host->device (write)
    private var credTx: BluetoothGattCharacteristic? = null // device->host (indicate)
    private var credRx: BluetoothGattCharacteristic? = null // host->device (write)
    @Volatile private var hwCredit = 0

    private val incoming = LinkedBlockingQueue<ByteArray>()
    // Confirmación de escritura (with-response): Android solo admite una
    // operación GATT a la vez, así que esperamos onCharacteristicWrite.
    private val writeAck = ArrayBlockingQueue<Boolean>(1)
    private val connectLatch = CountDownLatch(1)
    @Volatile private var connectError: String? = null
    @Volatile private var ready = false
    @Volatile private var setupStarted = false // evita doble descubrimiento
    // Emparejamiento LE en curso (OSTC): connect() espera más (diálogo de PIN).
    @Volatile private var bonding = false
    private var bondReceiver: BroadcastReceiver? = null

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.i(TAG, "Conectado; prioridad alta + MTU")
                // Intervalo de conexión corto -> descarga más rápida.
                g.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                // Nota: NO forzamos 2M PHY; algunos módulos (Mares) fallan la
                // transferencia de datos aunque el control (ACK) funcione.
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
            if (setupStarted) return // el stack puede descubrir dos veces
            setupStarted = true
            if (selectHwTelit(g)) {
                creditMode = true
                // El Telit solo acepta el CCCD con el enlace LE cifrado (y lo
                // rechaza con 0xC0, que Android no trata como "falta
                // autenticación", así que no empareja solo). Sin bond,
                // emparejar ahora: con el enlace LE abierto, createBond()
                // empareja por LE (por BR/EDR, como Ajustes, no serviría).
                if (g.device.bondState == BluetoothDevice.BOND_NONE) {
                    bondThenStart(g)
                } else {
                    startTelit(g)
                }
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
            c.value?.let { onData(c, it.copyOf()) }
        }

        override fun onCharacteristicChanged(
            g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray
        ) {
            onData(c, value.copyOf())
        }

        override fun onDescriptorWrite(
            g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int
        ) {
            if (d.uuid != CCCD) return
            if (status != BluetoothGatt.GATT_SUCCESS) {
                if (creditMode && g.device.bondState == BluetoothDevice.BOND_BONDED) {
                    // Bond solo de Bluetooth clásico (emparejado desde Ajustes):
                    // el enlace LE sigue sin cifrar.
                    fail("El OSTC rechaza la conexión ($status). Olvida el " +
                        "dispositivo en Ajustes > Bluetooth y vuelve a " +
                        "intentarlo: Pandive lo emparejará por BLE.")
                } else {
                    fail("No se pudieron activar notificaciones ($status)")
                }
                return
            }
            if (!creditMode) {
                ready = true
                connectLatch.countDown()
                return
            }
            // Secuencia Telit: créditos (indicate) -> datos (notify) -> crédito inicial.
            if (d.characteristic.uuid == T_CRED_TX) {
                writeCccd(g, dataTx!!, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else if (d.characteristic.uuid == T_DATA_TX) {
                hwCredit = MAX_CREDIT
                writeCredit(g, MAX_CREDIT)
                ready = true
                connectLatch.countDown()
            }
        }

        override fun onCharacteristicWrite(
            g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int
        ) {
            writeAck.offer(status == BluetoothGatt.GATT_SUCCESS)
        }
    }

    // Enruta un paquete recibido: datos a la cola; créditos (Telit) suman saldo.
    private fun onData(c: BluetoothGattCharacteristic, value: ByteArray) {
        if (creditMode && c.uuid == T_CRED_TX) {
            if (value.isNotEmpty()) hwCredit += value[0].toInt() and 0xFF
            return
        }
        incoming.put(value)
        if (creditMode) {
            hwCredit--
            if (hwCredit <= MIN_CREDIT) {
                hwCredit += MAX_CREDIT - MIN_CREDIT
                gatt?.let { writeCredit(it, MAX_CREDIT - MIN_CREDIT) }
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
                        BluetoothGattCharacteristic.PROPERTY_INDICATE)) != 0 &&
                        c.getDescriptor(CCCD) != null) n = c
            }
            if (w != null && n != null) {
                writeChar = w; notifyChar = n
                Log.i(TAG, "Servicio ${s.uuid} write=${w.uuid} notify=${n.uuid}")
                return true
            }
        }
        return false
    }

    // Paso 1 Telit: indicaciones en créditos TX (la secuencia sigue en onDescriptorWrite).
    private fun startTelit(g: BluetoothGatt) {
        writeCccd(g, credTx!!, BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)
    }

    // Empareja por LE (el OSTC puede mostrar un PIN; Android abre su diálogo)
    // y, al quedar emparejado, sigue con la secuencia Telit.
    @SuppressLint("MissingPermission")
    private fun bondThenStart(g: BluetoothGatt) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                @Suppress("DEPRECATION")
                val dev = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                if (dev?.address?.equals(address, ignoreCase = true) != true) return
                when (intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)) {
                    BluetoothDevice.BOND_BONDED -> {
                        Log.i(TAG, "Emparejado por LE")
                        unregisterBond()
                        bonding = false
                        startTelit(g)
                    }
                    BluetoothDevice.BOND_NONE -> {
                        unregisterBond()
                        bonding = false
                        fail("No se pudo emparejar con el ordenador de buceo")
                    }
                }
            }
        }
        bondReceiver = receiver
        context.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
        bonding = true
        Log.i(TAG, "Sin emparejar; createBond() sobre el enlace LE")
        if (!g.device.createBond()) {
            unregisterBond()
            bonding = false
            fail("No se pudo iniciar el emparejamiento")
        }
    }

    private fun unregisterBond() {
        bondReceiver?.let { try { context.unregisterReceiver(it) } catch (_: Exception) {} }
        bondReceiver = null
    }

    // Detecta el servicio Telit/HW (OSTC) y sus 4 características por UUID.
    private fun selectHwTelit(g: BluetoothGatt): Boolean {
        val s = g.getService(HW_TELIT_SERVICE) ?: return false
        dataTx = s.getCharacteristic(T_DATA_TX)
        dataRx = s.getCharacteristic(T_DATA_RX)
        credTx = s.getCharacteristic(T_CRED_TX)
        credRx = s.getCharacteristic(T_CRED_RX)
        val ok = dataTx != null && dataRx != null && credTx != null && credRx != null
        if (ok) Log.i(TAG, "OSTC Telit: control de flujo por créditos")
        return ok
    }

    @SuppressLint("MissingPermission")
    private fun writeCccd(
        g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray
    ) {
        g.setCharacteristicNotification(c, true)
        val cccd = c.getDescriptor(CCCD) ?: return fail("sin descriptor CCCD")
        @Suppress("DEPRECATION")
        run { cccd.value = value; g.writeDescriptor(cccd) }
    }

    // Envía [n] créditos UART al módulo (característica de créditos RX).
    @SuppressLint("MissingPermission")
    private fun writeCredit(g: BluetoothGatt, n: Int) {
        val c = credRx ?: return
        @Suppress("DEPRECATION")
        run {
            c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            c.value = byteArrayOf(n.toByte())
            g.writeCharacteristic(c)
        }
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
        val adapter = manager.adapter
        // Descubrir por escaneo ANTES de conectar: conectar por MAC cruda a un
        // dispositivo no cacheado da device_type=Unknown y el connect falla
        // (timeout). El escaneo lo cachea con su tipo de dirección correcto
        // (igual que la pantalla de escaneo, que sí funciona) y usamos su
        // BluetoothDevice para conectar.
        val scanned = scanFor(adapter, 15000)
        val device = scanned ?: adapter.getRemoteDevice(address)
        gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        var ok = connectLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
        // Emparejando (el usuario puede estar tecleando el PIN): margen extra.
        if (!ok && bonding) ok = connectLatch.await(60000, TimeUnit.MILLISECONDS)
        if (!ok) {
            connectError =
                if (scanned == null) "No se encontró el dispositivo" else "Timeout de conexión"
            return false
        }
        return ready
    }

    /** Escanea hasta encontrar [address] (o agotar [timeoutMs]); devuelve el
     *  dispositivo descubierto (con su tipo correcto) o null. */
    @SuppressLint("MissingPermission")
    private fun scanFor(adapter: BluetoothAdapter, timeoutMs: Long): BluetoothDevice? {
        val scanner = adapter.bluetoothLeScanner ?: return null
        var found: BluetoothDevice? = null
        val latch = CountDownLatch(1)
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (result.device.address.equals(address, ignoreCase = true)) {
                    found = result.device
                    latch.countDown()
                }
            }
        }
        val filters = listOf(ScanFilter.Builder().setDeviceAddress(address).build())
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        scanner.startScan(filters, settings, cb)
        latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        scanner.stopScan(cb)
        return found
    }

    fun error(): String? = connectError

    /** Lee el siguiente paquete recibido, o null si no llega nada en [timeoutMs]. */
    fun bleRead(timeoutMs: Int): ByteArray? =
        incoming.poll(timeoutMs.toLong(), TimeUnit.MILLISECONDS)

    /** Escribe [data] sin esperar confirmación (fire-and-forget, como
     *  Subsurface): el protocolo alterna escritura->lectura, así que no hay
     *  solape, y evitar la espera por callback acelera mucho la descarga. */
    @SuppressLint("MissingPermission")
    fun bleWrite(data: ByteArray): Boolean {
        val g = gatt ?: return false
        val c = (if (creditMode) dataRx else writeChar) ?: return false
        val noResp = c.properties and
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
        val mode = if (noResp) BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            else BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        writeAck.clear()
        @Suppress("DEPRECATION")
        val sent = run { c.writeType = mode; c.value = data; g.writeCharacteristic(c) }
        if (!sent) return false
        // Android solo admite una operación GATT a la vez: esperar a que termine
        // (también en no-response; evita perder paquetes). Timeout -> seguimos.
        return writeAck.poll(2000, TimeUnit.MILLISECONDS) != false
    }

    @SuppressLint("MissingPermission")
    fun close() {
        unregisterBond()
        try { gatt?.disconnect(); gatt?.close() } catch (_: Exception) {}
        gatt = null
    }
}
