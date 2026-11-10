package my.kulnem.cruise_assist

import android.content.Context
import java.util.concurrent.ConcurrentLinkedQueue

/** In-process bridge to Flutter. Events are also kept briefly for late channel listeners. */
object ProjectionEvents {
    @Volatile var sink: ((Map<String, Any?>) -> Unit)? = null
    private val recent = ConcurrentLinkedQueue<Map<String, Any?>>()

    fun emit(event: Map<String, Any?>) {
        recent.add(event)
        while (recent.size > 64) recent.poll()
        sink?.invoke(event)
    }

    fun snapshot(): List<Map<String, Any?>> = recent.toList()

    fun setListener(listener: ((Map<String, Any?>) -> Unit)?) {
        sink = listener
        if (listener != null) snapshot().forEach(listener)
    }
}

object ProjectionStateHolder {
    @Volatile var state: String = "idle"
        private set

    @Suppress("UNUSED_PARAMETER")
    fun update(context: Context, value: String) {
        state = value
        ProjectionEvents.emit(mapOf("type" to "state", "state" to value))
    }
}
