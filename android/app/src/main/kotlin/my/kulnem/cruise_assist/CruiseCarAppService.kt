package my.kulnem.cruise_assist

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Placeholder manifest target for a future androidx.car.app implementation.
 * Disabled in the manifest, so it cannot expose a car-app surface without the dependency.
 */
class CruiseCarAppService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
}
