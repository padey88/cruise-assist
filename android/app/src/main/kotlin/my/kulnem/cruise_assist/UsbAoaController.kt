package my.kulnem.cruise_assist

import android.content.Context
import android.hardware.usb.UsbAccessory
import android.hardware.usb.UsbManager
import android.os.ParcelFileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

/** Owns the single Android Open Accessory connection and its blocking I/O thread. */
class UsbAoaController(private val context: Context) {
    interface Listener {
        fun onEvent(event: Map<String, Any?>)
    }

    private val usb = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val lock = Object()
    private var descriptor: ParcelFileDescriptor? = null
    private var input: FileInputStream? = null
    private var output: FileOutputStream? = null
    private var reader: Thread? = null
    private val running = AtomicBoolean(false)
    @Volatile private var active: UsbAccessory? = null

    val isOpen: Boolean get() = running.get()

    fun descriptors(): List<Map<String, Any?>> = accessories().map { describe(it) }

    fun describe(accessory: UsbAccessory): Map<String, Any?> = mapOf(
        "manufacturer" to accessory.manufacturer,
        "model" to accessory.model,
        "description" to accessory.description,
        "version" to accessory.version,
        "serial" to safeSerial(accessory),
        "uri" to accessory.uri,
        "hasPermission" to hasPermission(accessory),
    )

    /** Starts permission negotiation or opens an accessory already approved by Android. */
    fun start() {
        val found = accessories()
        emit("accessories", mapOf("items" to found.map { describe(it) }))
        if (found.isEmpty()) {
            emit("state", mapOf("state" to "idle", "message" to "No USB accessory attached"))
            return
        }
        val accessory = found.first()
        active = accessory
        if (!hasPermission(accessory)) {
            val permission = HeadUnitDiagnostics.requestPermission(context, usb, accessory)
            if (!permission) {
                emit("state", mapOf("state" to "awaitingPermission", "accessory" to describe(accessory)))
            }
            return
        }
        open(accessory)
    }

    fun onPermissionResult(accessory: UsbAccessory?, granted: Boolean) {
        if (!granted || accessory == null) {
            emit("state", mapOf("state" to "error", "message" to "USB accessory permission denied"))
            return
        }
        active = accessory
        open(accessory)
    }

    fun open(accessory: UsbAccessory) {
        close()
        active = accessory
        val opened = try {
            usb.openAccessory(accessory)
        } catch (e: SecurityException) {
            emit("state", mapOf("state" to "error", "message" to "USB permission was revoked: ${e.message}"))
            null
        } catch (e: IOException) {
            emit("state", mapOf("state" to "error", "message" to "Could not open USB accessory: ${e.message}"))
            null
        }
        if (opened == null) {
            if (running.get()) return
            emit("state", mapOf("state" to "error", "message" to "Android could not open the USB accessory"))
            return
        }

        val inputStream = FileInputStream(opened.fileDescriptor)
        val outputStream = FileOutputStream(opened.fileDescriptor)
        synchronized(lock) {
            descriptor = opened
            input = inputStream
            output = outputStream
        }
        running.set(true)
        emit("state", mapOf("state" to "attached", "accessory" to describe(accessory)))
        emit("diagnostic", HeadUnitDiagnostics.accessoryDiagnostic(describe(accessory)))
        reader = Thread({ readLoop(inputStream) }, "cruise-aoa-read").also { it.start() }
    }

    /** Writes raw diagnostic bytes. The head-unit framing protocol is intentionally unknown. */
    fun write(bytes: ByteArray) {
        if (!running.get()) throw IOException("No USB accessory is open")
        val stream = synchronized(lock) { output } ?: throw IOException("USB output is closed")
        try {
            stream.write(bytes)
            stream.flush()
            emit("diagnostic", HeadUnitDiagnostics.packetDiagnostic("tx", bytes))
        } catch (e: IOException) {
            emit("state", mapOf("state" to "error", "message" to "USB write failed: ${e.message}"))
            close()
            throw e
        }
    }

    fun onDetached(accessory: UsbAccessory?) {
        if (accessory == null || active == null || sameAccessory(accessory, active!!)) {
            close()
            emit("state", mapOf("state" to "idle", "message" to "USB accessory detached"))
        }
    }

    fun close() {
        running.set(false)
        val resources = synchronized(lock) {
            val current = Triple(descriptor, input, output)
            descriptor = null
            input = null
            output = null
            current
        }
        // Closing the descriptor wakes a thread blocked in read().
        try { resources.second?.close() } catch (_: IOException) {}
        try { resources.third?.close() } catch (_: IOException) {}
        try { resources.first?.close() } catch (_: IOException) {}
        reader?.interrupt()
        reader = null
    }

    private fun readLoop(stream: FileInputStream) {
        val buffer = ByteArray(16 * 1024)
        while (running.get()) {
            try {
                val count = stream.read(buffer)
                if (count < 0) break
                if (count > 0) {
                    val bytes = buffer.copyOf(count)
                    emit("diagnostic", HeadUnitDiagnostics.packetDiagnostic("rx", bytes))
                }
            } catch (e: IOException) {
                if (running.get()) {
                    emit("state", mapOf("state" to "error", "message" to "USB read failed: ${e.message}"))
                }
                break
            }
        }
        val wasOpen = running.getAndSet(false)
        close()
        if (wasOpen) {
            emit("state", mapOf("state" to "idle", "message" to "USB accessory connection closed"))
        }
    }

    private fun accessories(): List<UsbAccessory> = try {
        usb.accessoryList?.toList() ?: emptyList()
    } catch (e: SecurityException) {
        emit("state", mapOf("state" to "error", "message" to "USB access denied: ${e.message}"))
        emptyList()
    }

    private fun hasPermission(accessory: UsbAccessory): Boolean = try {
        usb.hasPermission(accessory)
    } catch (_: SecurityException) {
        false
    }

    private fun safeSerial(accessory: UsbAccessory): String? = try {
        accessory.serial
    } catch (_: SecurityException) {
        null
    }

    private fun sameAccessory(a: UsbAccessory, b: UsbAccessory): Boolean =
        a.manufacturer == b.manufacturer && a.model == b.model && a.version == b.version

    private fun emit(type: String, data: Map<String, Any?>) {
        ProjectionEvents.emit(mapOf("type" to type) + data)
    }
}
