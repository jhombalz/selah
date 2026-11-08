package com.example.selah

/** Counts only continuous, foreground reading, using elapsed time, not wall time. */
class FocusClock(var day: String, var earnedMillis: Long = 0L) {
    private var previousElapsed: Long? = null
    private var previousEligible = false

    fun pulse(today: String, elapsed: Long, eligible: Boolean, goalMillis: Long): Boolean {
        val before = earnedMillis
        if (today != day) {
            day = today
            earnedMillis = 0
            previousElapsed = elapsed
            previousEligible = eligible
            return true
        }
        val delta = previousElapsed?.let { elapsed - it } ?: 0L
        // Discard long gaps, e.g. suspended processes or device sleep.
        if (previousEligible && eligible && delta in 0L..5000L && earnedMillis < goalMillis) {
            earnedMillis = (earnedMillis + delta).coerceAtMost(goalMillis)
        }
        previousElapsed = elapsed
        previousEligible = eligible
        return earnedMillis != before
    }
}
