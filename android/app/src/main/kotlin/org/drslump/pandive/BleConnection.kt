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
 * BLE GATT connection to a dive computer, exposed as a synchronous byte
 * stream (bleRead/bleWrite) that the native libdivecomputer bridge uses as
 * custom I/O. GATT operations (async) are serialized with latches.
 *
 * Characteristic selection: generic by properties (one with Write/
 * WriteNoResponse to write, another with Notify/Indicate to read), preferring
 * the known serial services (Shearwater, Mares).
 */
class BleConnection(private val context: Context, private val address: String) {
    companion object {
        private const val TAG = "PandiveBLE"
        private val CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        // Known "serial" services, in order of preference.
        private val PREFERRED_SERVICES = listOf(
            "fe25c237-0ece-443c-b0aa-e02033e7029d", // Shearwater Petrel/Perdix/Peregrine/Tern
            "1aa44039-1667-4b29-87cc-dfecaaf31d97", // Shearwater Perdix 3
            "544e326b-5b72-c6b0-1c46-41c1bc448118", // Mares BlueLink
        ).map { it.lowercase() }

        // Heinrichs Weikamp (OSTC) with Telit/Stollmann BLE module: "Terminal
        // I/O" service with credit-based flow control.
        private val HW_TELIT_SERVICE =
            UUID.fromString("0000fefb-0000-1000-8000-00805f9b34fb")
        private val T_DATA_TX = UUID.fromString("00000002-0000-1000-8000-008025000000")
        private val T_DATA_RX = UUID.fromString("00000001-0000-1000-8000-008025000000")
        private val T_CRED_TX = UUID.fromString("00000004-0000-1000-8000-008025000000")
        private val T_CRED_RX = UUID.fromString("00000003-0000-1000-8000-008025000000")
        private const val MAX_CREDIT = 254
        private const val MIN_CREDIT = 32
    }

    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private var notifyChar: BluetoothGattCharacteristic? = null

    // Credit mode (Telit/HW): dedicated data and credit characteristics.
    private var creditMode = false
    private var dataTx: BluetoothGattCharacteristic? = null // device->host (notify)
    private var dataRx: BluetoothGattCharacteristic? = null // host->device (write)
    private var credTx: BluetoothGattCharacteristic? = null // device->host (indicate)
    private var credRx: BluetoothGattCharacteristic? = null // host->device (write)
    @Volatile private var hwCredit = 0

    private val incoming = LinkedBlockingQueue<ByteArray>()
    // Write confirmation (with-response): Android only allows one GATT
    // operation at a time, so we wait for onCharacteristicWrite.
    private val writeAck = ArrayBlockingQueue<Boolean>(1)
    private val connectLatch = CountDownLatch(1)
    @Volatile private var connectError: String? = null
    @Volatile private var ready = false
    @Volatile private var setupStarted = false // avoids double discovery
    // LE pairing in progress (OSTC): connect() waits longer (PIN dialog).
    @Volatile private var bonding = false
    private var bondTried = false
    private var bondReceiver: BroadcastReceiver? = null

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.i(TAG, "Conectado; prioridad alta + MTU")
                // Short connection interval -> faster download.
                g.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                // Note: we do NOT force 2M PHY; some modules (Mares) fail data
                // transfer even though control (ACK) works.
                if (!g.requestMtu(247)) g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                if (!ready) {
                    connectError = "Disconnected (status $status)"
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
                fail("Service discovery failed ($status)")
                return
            }
            if (setupStarted) return // the stack may discover twice
            setupStarted = true
            if (selectHwTelit(g)) {
                creditMode = true
                // Unpaired: the OSTC doesn't require it (if it rejects the CCCD,
                // onDescriptorWrite pairs and retries).
                startTelit(g)
                return
            }
            if (!selectCharacteristics(g)) {
                fail("No read/write characteristic found")
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
                // Safety net (OSTC firmware that requires encryption): the
                // Telit answers with its own code that Android doesn't treat as
                // "insufficient authentication", so it won't pair by itself. Pair
                // with the LE link open (createBond() goes over LE) and retry.
                if (creditMode && !bondTried &&
                        g.device.bondState == BluetoothDevice.BOND_NONE) {
                    Log.i(TAG, "CCCD rejected ($status); pairing and retrying")
                    bondTried = true
                    bondThenStart(g)
                } else {
                    fail("Could not enable notifications ($status)")
                }
                return
            }
            if (!creditMode) {
                ready = true
                connectLatch.countDown()
                return
            }
            // Telit sequence: credits (indicate) -> data (notify) -> initial credit.
            if (d.characteristic.uuid == T_CRED_TX) {
                writeCccd(g, dataTx!!, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else if (d.characteristic.uuid == T_DATA_TX) {
                // Ready once the initial credit is confirmed (onCharacteristicWrite):
                // Android only allows one GATT operation at a time.
                hwCredit = MAX_CREDIT
                writeCredit(g, MAX_CREDIT)
            }
        }

        override fun onCharacteristicWrite(
            g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int
        ) {
            if (creditMode && c.uuid == T_CRED_RX) {
                // Credits: not the data write that bleWrite is waiting for.
                if (!ready) {
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        fail("Could not send the initial credit ($status)")
                        return
                    }
                    ready = true
                    connectLatch.countDown()
                }
                return
            }
            writeAck.offer(status == BluetoothGatt.GATT_SUCCESS)
        }
    }

    // Routes a received packet: data to the queue; credits (Telit) add to the balance.
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

    // Telit step 1: indications on credits TX (the sequence continues in onDescriptorWrite).
    private fun startTelit(g: BluetoothGatt) {
        writeCccd(g, credTx!!, BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)
    }

    // Pairs over LE (Android shows its confirmation dialog)
    // and, once paired, continues with the Telit sequence.
    @SuppressLint("MissingPermission")
    private fun bondThenStart(g: BluetoothGatt) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                @Suppress("DEPRECATION")
                val dev = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                if (dev?.address?.equals(address, ignoreCase = true) != true) return
                when (intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)) {
                    BluetoothDevice.BOND_BONDED -> {
                        Log.i(TAG, "Paired over LE")
                        unregisterBond()
                        bonding = false
                        startTelit(g)
                    }
                    BluetoothDevice.BOND_NONE -> {
                        unregisterBond()
                        bonding = false
                        fail("Could not pair with the dive computer")
                    }
                }
            }
        }
        bondReceiver = receiver
        context.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
        bonding = true
        Log.i(TAG, "Unpaired; createBond() over the LE link")
        if (!g.device.createBond()) {
            unregisterBond()
            bonding = false
            fail("Could not start pairing")
        }
    }

    private fun unregisterBond() {
        bondReceiver?.let { try { context.unregisterReceiver(it) } catch (_: Exception) {} }
        bondReceiver = null
    }

    // Detects the Telit/HW (OSTC) service and its 4 characteristics by UUID.
    private fun selectHwTelit(g: BluetoothGatt): Boolean {
        val s = g.getService(HW_TELIT_SERVICE) ?: return false
        dataTx = s.getCharacteristic(T_DATA_TX)
        dataRx = s.getCharacteristic(T_DATA_RX)
        credTx = s.getCharacteristic(T_CRED_TX)
        credRx = s.getCharacteristic(T_CRED_RX)
        val ok = dataTx != null && dataRx != null && credTx != null && credRx != null
        if (ok) Log.i(TAG, "OSTC Telit: credit-based flow control")
        return ok
    }

    @SuppressLint("MissingPermission")
    private fun writeCccd(
        g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray
    ) {
        g.setCharacteristicNotification(c, true)
        val cccd = c.getDescriptor(CCCD) ?: return fail("no CCCD descriptor")
        @Suppress("DEPRECATION")
        run { cccd.value = value; g.writeDescriptor(cccd) }
    }

    // Sends [n] UART credits to the module (credits RX characteristic).
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
        val n = notifyChar ?: return fail("no notify characteristic")
        g.setCharacteristicNotification(n, true)
        val cccd = n.getDescriptor(CCCD) ?: return fail("no CCCD descriptor")
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
        // Discover by scanning BEFORE connecting: connecting by raw MAC to a
        // non-cached device gives device_type=Unknown and the connect fails
        // (timeout). The scan caches it with its correct address type
        // (same as the scan screen, which works) and we use its
        // BluetoothDevice to connect.
        val scanned = scanFor(adapter, 15000)
        val device = scanned ?: adapter.getRemoteDevice(address)
        gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        var ok = connectLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
        // Pairing (the user may be typing the PIN): extra time.
        if (!ok && bonding) ok = connectLatch.await(60000, TimeUnit.MILLISECONDS)
        if (!ok) {
            connectError =
                if (scanned == null) "Device not found" else "Connection timed out"
            return false
        }
        return ready
    }

    /** Scans until [address] is found (or [timeoutMs] runs out); returns the
     *  discovered device (with its correct type) or null. */
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

    /** Reads the next received packet, or null if nothing arrives within [timeoutMs]. */
    fun bleRead(timeoutMs: Int): ByteArray? =
        incoming.poll(timeoutMs.toLong(), TimeUnit.MILLISECONDS)

    /** Writes [data] without waiting for confirmation (fire-and-forget, like
     *  Subsurface): the protocol alternates write->read, so there is no
     *  overlap, and skipping the callback wait speeds up the download a lot. */
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
        // Android only allows one GATT operation at a time: wait for it to finish
        // (also for no-response; avoids losing packets). Timeout -> carry on.
        return writeAck.poll(2000, TimeUnit.MILLISECONDS) != false
    }

    @SuppressLint("MissingPermission")
    fun close() {
        unregisterBond()
        try { gatt?.disconnect(); gatt?.close() } catch (_: Exception) {}
        gatt = null
    }
}
