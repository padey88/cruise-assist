package my.kulnem.cruise_assist

import android.app.Activity
import android.content.Intent
import android.hardware.usb.UsbManager
import android.os.Bundle

/** USB attachment entry point. No UI is shown; permission is requested by the service. */
class UsbAccessoryActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val accessory = if (android.os.Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY, UsbAccessory::class.java)
        } else {
            @Suppress("DEPRECATION") intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY)
        }
        val service = Intent(this, ProjectionService::class.java)
            .setAction(ProjectionService.ACTION_START)
            .putExtra(UsbManager.EXTRA_ACCESSORY, accessory)
        try {
            startForegroundService(service)
        } catch (e: RuntimeException) {
            ProjectionEvents.emit(mapOf(
                "type" to "state", "state" to "error",
                "message" to "Android blocked USB projection startup: ${e.message}",
            ))
        }
        finish()
    }
}
