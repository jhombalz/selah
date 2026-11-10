package com.example.selah

import android.app.Activity
import android.app.Instrumentation
import android.app.Notification
import android.app.NotificationManager
import android.os.Bundle

/** Device smoke test; run on a test emulator, never a user's phone. */
class JourneySmokeInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        val context = targetContext
        val preferences = context.getSharedPreferences("selah_reminder_v1", 0)
        val previous = preferences.all.toMap()
        val timerPreferences = context.getSharedPreferences("selah_assessment_timer_v1", 0)
        val previousTimer = timerPreferences.all.toMap()
        val result = Bundle()
        var code = Activity.RESULT_OK
        try {
            check(JourneyReminders.configure(context, true, 8, 30)) { "Test emulator notification permission is required" }
            check(JourneyReminders.status(context)["enabled"] == true)
            JourneyReminders.show(context)
            val manager = context.getSystemService(NotificationManager::class.java)
            var notification: Notification? = null
            for (attempt in 0..30) {
                notification = manager.activeNotifications.firstOrNull { it.id == 8201 }?.notification
                if (notification != null) break
                Thread.sleep(100)
            }
            val posted = checkNotNull(notification) { "Notification was not delivered" }
            check(posted.extras.getCharSequence(Notification.EXTRA_TITLE).toString() == "Begin your day with God")
            check(posted.extras.getCharSequence(Notification.EXTRA_TEXT).toString() == "Pause and read a verse in SELAH.")
            check(posted.contentIntent != null)
            check(JourneyReminders.configure(context, true, 21, 15, "bedtime"))
            check(JourneyReminders.status(context)["bedtime_enabled"] == true)
            check(JourneyReminders.status(context)["hour"] == 8)
            check(JourneyReminders.status(context)["bedtime_hour"] == 21)
            JourneyReminders.show(context, "bedtime")
            var bedtime: Notification? = null
            for (attempt in 0..30) {
                bedtime = manager.activeNotifications.firstOrNull { it.id == 8211 }?.notification
                if (bedtime != null) break
                Thread.sleep(100)
            }
            check(checkNotNull(bedtime).extras.getCharSequence(Notification.EXTRA_TITLE).toString() == "A quiet moment before sleep")
            check(bedtime?.contentIntent != posted.contentIntent)
            check(!JourneyReminders.configure(context, false, 8, 30))
            check(JourneyReminders.status(context)["enabled"] == false)
            check(JourneyReminders.status(context)["bedtime_enabled"] == true)
            check(!JourneyReminders.configure(context, false, 21, 15, "bedtime"))
            AssessmentNotifications.sync(context, "timer-smoke", 1, System.currentTimeMillis() + 60000)
            fun waitForTitle(title: String): Notification {
                for (attempt in 0..30) {
                    val value = manager.activeNotifications.firstOrNull { it.id == 8401 }?.notification
                    if (value?.extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() == title) return value
                    Thread.sleep(100)
                }
                error("Assessment notification missing: $title")
            }
            val running = waitForTitle("Level 1 assessment running")
            check(running.flags and Notification.FLAG_ONGOING_EVENT != 0)
            check(running.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
            check(running.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
            check(running.contentIntent != null)
            AssessmentNotifications.sync(context, "timer-smoke", 1, System.currentTimeMillis() - 1000)
            val expired = waitForTitle("Assessment time is up")
            check(expired.flags and Notification.FLAG_ONGOING_EVENT == 0)
            AssessmentNotifications.sync(context, null, null, null)
            result.putString("stream", "PASS: morning/bedtime reminders and assessment countdown, expiry, tap intent and cancellation\n")
        } catch (error: Throwable) {
            code = Activity.RESULT_CANCELED
            result.putString("stream", "FAIL: ${error.message}\n")
        } finally {
            val editor = preferences.edit().clear()
            previous.forEach { (key, value) ->
                when (value) { is Boolean -> editor.putBoolean(key, value); is Int -> editor.putInt(key, value) }
            }
            editor.commit()
            JourneyReminders.schedule(context)
            val timerEditor = timerPreferences.edit().clear()
            previousTimer.forEach { (key, value) ->
                when (value) {
                    is Boolean -> timerEditor.putBoolean(key, value)
                    is Int -> timerEditor.putInt(key, value)
                    is Long -> timerEditor.putLong(key, value)
                    is String -> timerEditor.putString(key, value)
                }
            }
            timerEditor.commit()
            AssessmentNotifications.schedule(context)
        }
        finish(code, result)
    }
}
