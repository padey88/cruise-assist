package my.kulnem.cruise_assist

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.hardware.usb.UsbAccessory
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.IBinder

/** Lifecycle owner for USB/AOA diagnostics; it does not implement video projection. */
class ProjectionService : Service() {
    private var controller: UsbAoaController? = null
    private var receiverRegistered = false
    private var foreground = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                HeadUnitDiagnostics.PERMISSION_ACTION -> {
                    val accessory = accessoryFrom(intent)
                    controller?.onPermissionResult(
                        accessory,
                        intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false),
                    )
                }
                UsbManager.ACTION_USB_ACCESSORY_DETACHED -> {
                    controller?.onDetached(accessoryFrom(intent))
                    stopProjection()
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val filter = IntentFilter().apply {
            addAction(HeadUnitDiagnostics.PERMISSION_ACTION)
            addAction(UsbManager.ACTION_USB_ACCESSORY_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag") registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopProjection()
            return START_NOT_STICKY
        }
        startForegroundNotification()
        ProjectionStateHolder.update(this, "idle")
        if (controller == null) controller = UsbAoaController(this)
        controller?.start()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        controller?.close()
        controller = null
        if (receiverRegistered) {
            unregisterReceiver(receiver)
            receiverRegistered = false
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun stopProjection() {
        controller?.close()
        controller = null
        ProjectionStateHolder.update(this, "idle")
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else @Suppress("DEPRECATION") stopForeground(true)
        foreground = false
        stopSelf()
    }

    private fun startForegroundNotification() {
        if (foreground) return
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this, 1, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            this, 2, Intent(this, ProjectionService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = android.app.Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Cruise Assist")
            .setContentText("USB head-unit diagnostics active")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .addAction(android.app.Notification.Action.Builder(null, "Stop", stopIntent).build())
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        foreground = true
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_ID, "Head-unit connection", NotificationManager.IMPORTANCE_LOW,
        ).apply { description = "USB accessory connection and diagnostic status" })
    }

    private fun accessoryFrom(intent: Intent): UsbAccessory? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY, UsbAccessory::class.java)
        } else {
            @Suppress("DEPRECATION") intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY)
        }

    companion object {
        const val ACTION_START = "my.kulnem.cruise_assist.projection.START"
        const val ACTION_STOP = "my.kulnem.cruise_assist.projection.STOP"
        private const val CHANNEL_ID = "head_unit"
        private const val NOTIFICATION_ID = 41
    }
}
