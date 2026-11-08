package com.example.selah

import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import java.util.Calendar
import java.util.Locale

object FocusStore {
    private lateinit var context: Context
    private lateinit var clock: FocusClock
    private val prefs get() = context.getSharedPreferences("selah_focus_v1", Context.MODE_PRIVATE)
    private var initialized = false
    private var readingScreen = false
    private var resumed = false
    private var focused = false
    private var lastSave = 0L
    var serviceConnected = false
    var enabled = false
        private set
    var consented = false
        private set
    var pendingEnable = false
        private set
    var goalMinutes = 10
        private set
    var packages: Set<String> = emptySet()
        private set

    @Synchronized fun initialize(value: Context) {
        if (initialized) return
        context = value.applicationContext
        enabled = prefs.getBoolean("enabled", false)
        consented = prefs.getBoolean("consented", false)
        pendingEnable = prefs.getBoolean("pendingEnable", false)
        goalMinutes = prefs.getInt("goalMinutes", 10).coerceIn(5, 180)
        packages = prefs.getStringSet("packages", emptySet())!!.toSet() - protectedPackages()
        clock = FocusClock(prefs.getString("day", today())!!,
            prefs.getLong("earnedMillis", 0L).coerceIn(0L, 180L * 60000))
        initialized = true
        pulse()
    }

    private fun today(): String {
        val date = Calendar.getInstance()
        return String.format(Locale.ROOT, "%04d-%02d-%02d", date.get(Calendar.YEAR),
            date.get(Calendar.MONTH) + 1, date.get(Calendar.DAY_OF_MONTH))
    }

    fun deviceAvailable(): Boolean =
        (context.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive &&
        !(context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked

    fun accessibilityEnabled(): Boolean {
        val component = ComponentName(context, FocusAccessibilityService::class.java)
        return Settings.Secure.getString(context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)?.split(':')?.any {
                ComponentName.unflattenFromString(it) == component
            } == true
    }

    fun protectedPackages(): Set<String> {
        val result = mutableSetOf(context.packageName, "android", "com.android.systemui",
            "com.android.settings", "com.android.permissioncontroller",
            "com.google.android.permissioncontroller", "com.android.packageinstaller",
            "com.google.android.packageinstaller")
        val manager = context.packageManager
        @Suppress("DEPRECATION")
        manager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            .forEach { result.add(it.activityInfo.packageName) }
        @Suppress("DEPRECATION")
        manager.resolveActivity(Intent(Settings.ACTION_SETTINGS), 0)?.activityInfo?.packageName?.let(result::add)
        runCatching { (context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)?.defaultDialerPackage }
            .getOrNull()?.let(result::add)
        runCatching { Telephony.Sms.getDefaultSmsPackage(context) }.getOrNull()?.let(result::add)
        return result
    }

    private fun eligible(): Boolean = enabled && consented && packages.isNotEmpty() &&
        readingScreen && resumed && focused && deviceAvailable()

    @Synchronized fun pulse() {
        if (!initialized) return
        val now = SystemClock.elapsedRealtime()
        val oldDay = clock.day
        val wasComplete = clock.earnedMillis >= goalMinutes * 60000L
        val changed = clock.pulse(today(), now, eligible(), goalMinutes * 60000L)
        if (changed && (now - lastSave >= 5000 || oldDay != clock.day ||
                    (!wasComplete && clock.earnedMillis >= goalMinutes * 60000L))) persist()
    }

    private fun persist() {
        prefs.edit().putBoolean("enabled", enabled).putBoolean("consented", consented)
            .putBoolean("pendingEnable", pendingEnable).putInt("goalMinutes", goalMinutes)
            .putStringSet("packages", packages).putString("day", clock.day)
            .putLong("earnedMillis", clock.earnedMillis).apply()
        lastSave = SystemClock.elapsedRealtime()
    }

    @Synchronized fun reading(value: Boolean) { pulse(); readingScreen = value; pulse(); if (!value) persist() }
    @Synchronized fun resumed(value: Boolean) { pulse(); resumed = value; pulse(); if (!value) persist() }
    @Synchronized fun focused(value: Boolean) { pulse(); focused = value; pulse(); if (!value) persist() }
    @Synchronized fun consent() { consented = true; persist() }

    @Synchronized fun configure(minutes: Int, selected: Set<String>) {
        require(minutes in 5..180) { "Choose 5 to 180 minutes." }
        pulse()
        goalMinutes = minutes
        packages = selected - protectedPackages()
        if (packages.isEmpty()) { enabled = false; pendingEnable = false }
        pulse(); persist()
    }

    @Synchronized fun enable(value: Boolean) {
        pulse()
        if (value) {
            require(consented) { "Please review and accept the accessibility disclosure." }
            require(packages.isNotEmpty()) { "Select at least one app first." }
        }
        pendingEnable = value && !(accessibilityEnabled() && serviceConnected)
        enabled = value && !pendingEnable
        pulse(); persist()
    }

    @Synchronized fun connected(value: Boolean) {
        serviceConnected = value
        if (value && pendingEnable && consented && packages.isNotEmpty()) {
            pendingEnable = false; enabled = true; persist()
        }
    }

    @Synchronized fun shouldBlock(packageName: String): Boolean {
        pulse()
        return enabled && consented && serviceConnected && packageName in packages &&
            clock.earnedMillis < goalMinutes * 60000L
    }

    @Synchronized fun snapshot(): MutableMap<String, Any?> {
        pulse()
        val remaining = (goalMinutes * 60000L - clock.earnedMillis).coerceAtLeast(0)
        return mutableMapOf("enabled" to enabled, "consented" to consented,
            "pendingEnable" to pendingEnable, "goalMinutes" to goalMinutes,
            "selectedPackages" to packages.sorted(), "day" to clock.day,
            "earnedSeconds" to clock.earnedMillis / 1000,
            "remainingSeconds" to (remaining + 999) / 1000,
            "completed" to (remaining == 0L),
            "reading" to (eligible() && remaining > 0),
            "accessibilityEnabled" to accessibilityEnabled(),
            "serviceConnected" to serviceConnected)
    }
}
