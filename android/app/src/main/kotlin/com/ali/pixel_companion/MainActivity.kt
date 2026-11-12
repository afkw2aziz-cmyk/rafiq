package com.ali.pixel_companion

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val channelName = "pixelcompanion/calendar"
    private val notifChannelName = "pixelcompanion/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (!hasCalendarPermission()) {
                    result.error("permission", "READ/WRITE_CALENDAR required", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "calendars" -> runAsync(result) { calendars() }
                    "events" -> {
                        val from = call.argument<Long>("from") ?: 0L
                        val to = call.argument<Long>("to") ?: 0L
                        runAsync(result) { events(from, to) }
                    }
                    "insert" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        runAsync(result) { insert(args) }
                    }
                    "delete" -> {
                        val id = call.argument<Long>("id")
                            ?: call.argument<Int>("id")?.toLong()
                            ?: -1L
                        runAsync(result) { delete(id) }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notifChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(isNotificationAccessGranted())
                    "drain" -> result.success(NotificationBridge.drain())
                    "peek" -> result.success(NotificationBridge.peek())
                    else -> result.notImplemented()
                }
            }
    }

    /** True when the user has granted Notification Access to this app. */
    private fun isNotificationAccessGranted(): Boolean {
        val flat = android.provider.Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val expected = "$packageName/${PixelNotificationListener::class.java.name}"
        return flat.split(":").any { it == expected }
    }


    private fun hasCalendarPermission(): Boolean {
        return checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** Runs a blocking CalendarProvider query off the main thread and replies on it. */
    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        Thread {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (e: SecurityException) {
                runOnUiThread { result.error("permission", e.message, null) }
            } catch (e: Exception) {
                runOnUiThread { result.error("calendar", e.message ?: "calendar error", null) }
            }
        }.start()
    }

    private fun calendars(): List<Map<String, Any?>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
        )
        val out = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            null,
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "name" to c.getString(1),
                        "account" to c.getString(2),
                        "primary" to (c.getInt(3) == 1),
                        "access" to c.getInt(4),
                    ),
                )
            }
        }
        return out
    }

    private fun events(from: Long, to: Long): List<Map<String, Any?>> {
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        builder.appendPath(from.toString())
        builder.appendPath(to.toString())
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.ALL_DAY,
        )
        val out = mutableListOf<Map<String, Any?>>()
        contentResolver.query(builder.build(), projection, null, null, "BEGIN ASC")
            ?.use { c ->
                while (c.moveToNext()) {
                    out.add(
                        mapOf(
                            "id" to c.getLong(0),
                            "title" to (c.getString(1) ?: ""),
                            "start" to c.getLong(2),
                            "end" to c.getLong(3),
                            "location" to (c.getString(4) ?: ""),
                            "calendar" to (c.getString(5) ?: ""),
                            "allDay" to (c.getInt(6) == 1),
                        ),
                    )
                }
            }
        return out
    }

    private fun insert(args: Map<String, Any?>): Int? {
        val calendarId = writableCalendarId() ?: return null
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, args["title"] as? String ?: "Event")
            put(CalendarContract.Events.DTSTART, (args["start"] as? Number)?.toLong() ?: 0L)
            put(CalendarContract.Events.DTEND, (args["end"] as? Number)?.toLong() ?: 0L)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(CalendarContract.Events.DESCRIPTION, args["description"] as? String ?: "")
            put(CalendarContract.Events.EVENT_LOCATION, args["location"] as? String ?: "")
        }
        val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            ?: return null
        return ContentUris.parseId(uri).toInt()
    }

    private fun writableCalendarId(): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
        )
        val selection =
            "${CalendarContract.Calendars.VISIBLE}=1 AND " +
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL}>=?"
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
            "${CalendarContract.Calendars.IS_PRIMARY} DESC",
        )?.use { c ->
            if (c.moveToFirst()) return c.getLong(0)
        }
        // Fallback: first visible calendar at all.
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars._ID),
            null,
            null,
            null,
        )?.use { c ->
            if (c.moveToFirst()) return c.getLong(0)
        }
        return null
    }

    private fun delete(id: Long): Boolean {
        if (id < 0) return false
        val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id)
        return contentResolver.delete(uri, null, null) > 0
    }
}
