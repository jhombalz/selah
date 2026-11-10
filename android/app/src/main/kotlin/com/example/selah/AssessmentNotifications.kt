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

object AssessmentNotifications {
    private const val CHANNEL = "selah_assessment_timer"
    private const val ID = 8401
    private fun prefs(context: Context) = context.getSharedPreferences("selah_assessment_timer_v1", Context.MODE_PRIVATE)
    private fun alarmIntent(context: Context) = PendingIntent.getBroadcast(context, ID,
        Intent(context, AssessmentTimerReceiver::class.java).setAction("com.example.selah.ASSESSMENT_EXPIRED"),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun allowed(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }
    fun sync(context: Context, id: String?, level: Int?, deadline: Long?) {
        if (id == null) {
            prefs(context).edit().clear().apply()
            context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context))
            context.getSystemService(NotificationManager::class.java).cancel(ID)
            return
        }
        require(level != null && level in 1..5 && deadline != null && deadline > 0)
        val p = prefs(context)
        if (p.getString("id", null) != id) p.edit().putBoolean("expiredNotified", false).apply()
        p.edit().putString("id", id).putInt("level", level).putLong("deadline", deadline).apply()
        schedule(context)
        show(context)
    }
    fun schedule(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val pending = alarmIntent(context)
        alarm.cancel(pending)
        val p = prefs(context)
        if (!p.contains("id")) return
        val deadline = p.getLong("deadline", 0)
        if (deadline <= System.currentTimeMillis()) { show(context); return }
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deadline, pending)
    }
    fun show(context: Context) {
        val p = prefs(context)
        if (!p.contains("id") || !allowed(context)) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Assessment timer", NotificationManager.IMPORTANCE_LOW))
        val deadline = p.getLong("deadline", 0)
        val expired = deadline <= System.currentTimeMillis()
        if (expired && p.getBoolean("expiredNotified", false)) return
        val open = PendingIntent.getActivity(context, ID, Intent(context, MainActivity::class.java)
            .setAction("com.example.selah.ASSESSMENT").addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_launcher_monochrome).setContentIntent(open)
            .setContentTitle(if (expired) "Assessment time is up" else "Level ${p.getInt("level", 1)} assessment running")
            .setContentText(if (expired) "Open SELAH to view your result." else "The timer cannot pause. Tap to return.")
            .setVisibility(Notification.VISIBILITY_PRIVATE).setOnlyAlertOnce(true)
            .setOngoing(!expired).setAutoCancel(expired)
        if (!expired) builder.setWhen(deadline).setShowWhen(true).setUsesChronometer(true).setChronometerCountDown(true)
        manager.notify(ID, builder.build())
        if (expired) p.edit().putBoolean("expiredNotified", true).apply()
    }
}

class AssessmentTimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AssessmentNotifications.schedule(context)
    }
}
