package my.kulnem.cruise_assist

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbAccessory
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log

/** Non-proprietary protocol observations, retained in logcat for a later real-unit capture. */
object HeadUnitDiagnostics {
    private const val TAG = "CruiseHeadUnit"
    const val PERMISSION_ACTION = "my.kulnem.cruise_assist.USB_PERMISSION"
    private const val MAX_PACKET_LOG = 64

    fun requestPermission(context: Context, usb: UsbManager, accessory: UsbAccessory): Boolean {
        val intent = Intent(PERMISSION_ACTION).setPackage(context.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        val pending = PendingIntent.getBroadcast(context, 0, intent, flags)
        return try {
            usb.requestPermission(accessory, pending)
            true
        } catch (e: RuntimeException) {
            Log.e(TAG, "Unable to request accessory permission", e)
            false
        }
    }

    fun accessoryDiagnostic(accessory: Map<String, Any?>): Map<String, Any?> {
        val manufacturer = accessory["manufacturer"]?.toString().orEmpty()
        val model = accessory["model"]?.toString().orEmpty()
        val signature = "$manufacturer $model".trim()
        val classifier = when {
            signature.contains("Ativa", true) -> "possible-ativa"
            signature.contains("Perodua", true) -> "possible-perodua"
            signature.contains("Android", true) && signature.contains("Accessory", true) ->
                "generic-aoa-accessory"
            else -> "unrecognised-aoa-accessory"
        }
        Log.i(TAG, "AOA descriptor classifier=$classifier manufacturer=${quoted(manufacturer)} " +
            "model=${quoted(model)} vendorId=${accessory["vendorId"]} productId=${accessory["productId"]}")
        return mapOf("kind" to "accessory", "classifier" to classifier, "accessory" to accessory)
    }

    fun packetDiagnostic(direction: String, bytes: ByteArray): Map<String, Any?> {
        val prefix = bytes.copyOf(minOf(bytes.size, MAX_PACKET_LOG))
        val hex = prefix.joinToString("") { "%02x".format(it) }
        val ascii = prefix.joinToString("") { byte ->
            val value = byte.toInt() and 0xff
            if (value in 32..126) value.toChar().toString() else "."
        }
        val handshake = recogniseHandshake(prefix)
        Log.i(TAG, "$direction bytes=${bytes.size} first64=$hex ascii=$ascii signature=$handshake")
        return mapOf(
            "kind" to "packet",
            "direction" to direction,
            "length" to bytes.size,
            "first64Hex" to hex,
            "first64Ascii" to ascii,
            "signature" to handshake,
            "truncated" to (bytes.size > MAX_PACKET_LOG),
        )
    }

    /** Observations only: no claim that these identify the original proprietary protocol. */
    private fun recogniseHandshake(bytes: ByteArray): String {
        if (bytes.isEmpty()) return "empty"
        val text = String(bytes, Charsets.US_ASCII)
        return when {
            text.contains("AOA", true) -> "contains-aoa-text"
            text.contains("SMART", true) || text.contains("LINK", true) -> "contains-smartlink-text"
            bytes.size >= 4 && bytes[0] == 0x50.toByte() && bytes[1] == 0x4e.toByte() &&
                bytes[2] == 0x47.toByte() && bytes[3] == 0x4d.toByte() -> "pngm-prefix"
            else -> "unclassified"
        }
    }

    private fun quoted(value: String): String = value.replace("\n", "\\n").replace("\r", "\\r")
}
