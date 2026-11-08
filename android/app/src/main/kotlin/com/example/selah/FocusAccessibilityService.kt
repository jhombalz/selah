package com.example.selah

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent

/** Observes foreground package changes only; never retrieves screen content. */
class FocusAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var foregroundPackage = ""
    private var lastGate = 0L
    private val check = object : Runnable {
        override fun run() { enforce(); handler.postDelayed(this, 1500) }
    }
    override fun onCreate() { super.onCreate(); FocusStore.initialize(this) }

    override fun onServiceConnected() {
        super.onServiceConnected()
        FocusStore.initialize(this)
        FocusStore.connected(true)
        handler.post(check)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        foregroundPackage = event.packageName?.toString() ?: return
        enforce()
    }

    private fun enforce() {
        if (foregroundPackage.isEmpty() || foregroundPackage == packageName ||
            !FocusStore.deviceAvailable() || !FocusStore.shouldBlock(foregroundPackage)) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastGate < 1200) return
        lastGate = now
        val blocked = foregroundPackage
        // Opening Home first races with the gate activity and can hide it.
        // The gate handles Back by returning Home, never to the selected app.
        try {
            startActivity(Intent(this, FocusBlockActivity::class.java)
                .putExtra("blockedPackage", blocked)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS))
        } catch (_: RuntimeException) {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    override fun onInterrupt() = Unit
    override fun onDestroy() {
        handler.removeCallbacks(check)
        FocusStore.connected(false)
        super.onDestroy()
    }
}
