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
            check(posted.extras.getCharSequence(Notification.EXTRA_TITLE).toString() == "A quiet moment awaits")
            check(posted.extras.getCharSequence(Notification.EXTRA_TEXT).toString() == "Open SELAH when you are ready.")
            check(posted.contentIntent != null)
            check(!JourneyReminders.configure(context, false, 8, 30))
            check(JourneyReminders.status(context)["enabled"] == false)
            result.putString("stream", "PASS: native reminder enable, schedule, generic notification, tap intent, and disable\n")
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
        }
        finish(code, result)
    }
}
