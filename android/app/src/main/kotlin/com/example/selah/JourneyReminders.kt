package com.example.selah

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.util.Calendar

object JourneyReminders {
    private const val CHANNEL = "selah_quiet_moment"
    private const val ACTION = "com.example.selah.QUIET_MOMENT"
    private fun key(slot: String, name: String) = if (slot == "morning") name else "bedtime_$name"
    private fun id(slot: String) = if (slot == "morning") 8201 else 8211
    private fun defaultHour(slot: String) = if (slot == "morning") 8 else 21
    private fun prefs(context: Context) = context.getSharedPreferences("selah_reminder_v1", Context.MODE_PRIVATE)
    fun allowed(context: Context): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }
    fun status(context: Context): Map<String, Any> {
        val p = prefs(context)
        return mapOf("enabled" to (p.getBoolean("enabled", false) && allowed(context)),
            "hour" to p.getInt("hour", 8), "minute" to p.getInt("minute", 0),
            "bedtime_enabled" to (p.getBoolean("bedtime_enabled", false) && allowed(context)),
            "bedtime_hour" to p.getInt("bedtime_hour", 21), "bedtime_minute" to p.getInt("bedtime_minute", 0))
    }
    fun configure(context: Context, enabled: Boolean, hour: Int, minute: Int, slot: String = "morning"): Boolean {
        require(slot == "morning" || slot == "bedtime")
        require(hour in 0..23 && minute in 0..59)
        val actual = enabled && allowed(context)
        prefs(context).edit().putBoolean(key(slot, "enabled"), actual)
            .putInt(key(slot, "hour"), hour).putInt(key(slot, "minute"), minute).apply()
        if (!actual) (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id(slot))
        schedule(context)
        return actual
    }
    fun schedule(context: Context) {
        for (slot in listOf("morning", "bedtime")) scheduleSlot(context, slot)
    }
    private fun scheduleSlot(context: Context, slot: String) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = PendingIntent.getBroadcast(context, id(slot), Intent(context, JourneyReminderReceiver::class.java)
            .setAction(ACTION).putExtra("slot", slot), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarm.cancel(intent)
        val p = prefs(context)
        if (!p.getBoolean(key(slot, "enabled"), false) || !allowed(context)) return
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.getInt(key(slot, "hour"), defaultHour(slot)))
            set(Calendar.MINUTE, p.getInt(key(slot, "minute"), 0))
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, intent)
    }
    fun show(context: Context, slot: String = "morning") {
        if (slot != "morning" && slot != "bedtime") return
        if (!prefs(context).getBoolean(key(slot, "enabled"), false) || !allowed(context)) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "A quiet moment", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(context, id(slot) + 1, Intent(context, MainActivity::class.java)
            .setAction(MainActivity.FOCUS_READ).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(if (slot == "morning") "Begin your day with God" else "A quiet moment before sleep")
            .setContentText(if (slot == "morning") "Pause and read a verse in SELAH." else "End your day with a verse and a moment of prayer.")
            .setContentIntent(open).setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
        manager.notify(id(slot), builder.build())
    }
}

class JourneyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.example.selah.QUIET_MOMENT") JourneyReminders.show(context, intent.getStringExtra("slot") ?: "morning")
        JourneyReminders.schedule(context)
    }
}
