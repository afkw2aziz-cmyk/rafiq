package com.ali.pixel_companion

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Opt-in notification awareness for PixelCompanion.
 *
 * Privacy design:
 *  - Only app label + title are captured. The notification body/text and any
 *    extras are never read, stored, or forwarded to Dart.
 *  - Nothing is persisted: the buffer lives in memory and is capped.
 *  - The service is inert until the user grants Notification Access in system
 *    settings AND enables the skill in-app; see [NotificationBridge].
 */
class PixelNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        instance = this
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val sbn = sbn ?: return
        val n = sbn.notification ?: return
        // Skip our own notifications and ongoing/group-summary noise.
        if (sbn.packageName == packageName) return
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        if ((n.flags and Notification.FLAG_ONGOING_EVENT) != 0) return

        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        if (title.isNullOrEmpty()) return

        val appLabel = appLabelFor(sbn.packageName)
        NotificationBridge.record(
            app = appLabel,
            title = title.take(120),
            at = sbn.postTime,
            packageName = sbn.packageName,
        )
    }

    private fun appLabelFor(pkg: String): String = try {
        val pm = packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) {
        pkg
    }

    companion object {
        @Volatile
        var instance: PixelNotificationListener? = null
            private set
    }
}

/** Shared, in-memory, capped buffer bridging the listener to Dart. */
object NotificationBridge {
    const val CAP = 50
    private val buffer = CopyOnWriteArrayList<Map<String, Any>>()

    fun record(app: String, title: String, at: Long, packageName: String) {
        if (buffer.size >= CAP) buffer.removeAt(0)
        buffer.add(
            mapOf(
                "app" to app,
                "title" to title,
                "at" to at,
                "package" to packageName,
            ),
        )
    }

    fun drain(): List<Map<String, Any>> {
        val snapshot = buffer.toList()
        buffer.clear()
        return snapshot
    }

    fun peek(): List<Map<String, Any>> = buffer.toList()
}
