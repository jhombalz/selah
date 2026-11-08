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
            "hour" to p.getInt("hour", 8), "minute" to p.getInt("minute", 0))
    }
    fun configure(context: Context, enabled: Boolean, hour: Int, minute: Int): Boolean {
        require(hour in 0..23 && minute in 0..59)
        val actual = enabled && allowed(context)
        prefs(context).edit().putBoolean("enabled", actual).putInt("hour", hour).putInt("minute", minute).apply()
        if (!actual) (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(8201)
        schedule(context)
        return actual
    }
    fun schedule(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = PendingIntent.getBroadcast(context, 8201, Intent(context, JourneyReminderReceiver::class.java)
            .setAction("com.example.selah.QUIET_MOMENT"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarm.cancel(intent)
        val p = prefs(context)
        if (!p.getBoolean("enabled", false) || !allowed(context)) return
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.getInt("hour", 8)); set(Calendar.MINUTE, p.getInt("minute", 0))
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, intent)
    }
    fun show(context: Context) {
        if (!prefs(context).getBoolean("enabled", false) || !allowed(context)) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "A quiet moment", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(context, 8202, Intent(context, MainActivity::class.java)
            .setAction("com.example.selah.JOURNEY").addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_launcher_monochrome).setContentTitle("A quiet moment awaits")
            .setContentText("Open SELAH when you are ready.").setContentIntent(open).setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
        manager.notify(8201, builder.build())
    }
}

class JourneyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.example.selah.QUIET_MOMENT") JourneyReminders.show(context)
        JourneyReminders.schedule(context)
    }
}
