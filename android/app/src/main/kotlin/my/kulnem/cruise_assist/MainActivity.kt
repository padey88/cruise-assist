package my.kulnem.cruise_assist

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methods = "my.kulnem.cruise_assist/projection"
    private val events = "my.kulnem.cruise_assist/projection_events"
    private val deviceChannel = "my.kulnem.cruise_assist/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methods).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        startForegroundService(Intent(this, ProjectionService::class.java).setAction(ProjectionService.ACTION_START))
                        result.success(null)
                    }
                    "stop" -> {
                        startForegroundService(Intent(this, ProjectionService::class.java).setAction(ProjectionService.ACTION_STOP))
                        result.success(null)
                    }
                    "status" -> result.success(mapOf("state" to ProjectionStateHolder.state))
                    "accessories" -> result.success(UsbAoaController(this).descriptors())
                    "diagnostics" -> result.success(ProjectionEvents.snapshot())
                    "write" -> {
                        result.error("not_supported", "Raw writes require the running service; protocol framing is unknown", null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: RuntimeException) {
                result.error("projection_start_failed", e.message, null)
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, events).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                    ProjectionEvents.setListener { event -> runOnUiThread { eventSink.success(event) } }
                }

                override fun onCancel(arguments: Any?) {
                    ProjectionEvents.setListener(null)
                }
            },
        )
        // Device info channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    result.success(mapOf(
                        "model" to Build.MODEL,
                        "manufacturer" to Build.MANUFACTURER,
                        "sdk" to Build.VERSION.SDK_INT.toString(),
                        "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"),
                        "androidVersion" to Build.VERSION.RELEASE,
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ProjectionEvents.setListener(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
