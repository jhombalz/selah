package com.example.selah

import org.junit.Assert.*
import org.junit.Test

class FocusClockTest {
    @Test fun onlyContinuousEligibleTimeCounts() {
        val clock = FocusClock("2026-11-08")
        clock.pulse(clock.day, 0, true, 300000)
        clock.pulse(clock.day, 1000, true, 300000)
        assertEquals(1000L, clock.earnedMillis)
        clock.pulse(clock.day, 1500, false, 300000)
        clock.pulse(clock.day, 90000, false, 300000)
        clock.pulse(clock.day, 91000, true, 300000)
        assertEquals(1000L, clock.earnedMillis)
        clock.pulse(clock.day, 92000, true, 300000)
        assertEquals(2000L, clock.earnedMillis)
    }
    @Test fun sleepGapsAndClockReversalDoNotEarnCredit() {
        val clock = FocusClock("2026-11-08")
        clock.pulse(clock.day, 10000, true, 300000)
        clock.pulse(clock.day, 60000, true, 300000)
        clock.pulse(clock.day, 59000, true, 300000)
        assertEquals(0L, clock.earnedMillis)
    }
    @Test fun dailyResetAndRestoredProgress() {
        val clock = FocusClock("2026-11-08", 299000)
        clock.pulse(clock.day, 0, true, 300000)
        clock.pulse(clock.day, 1000, true, 300000)
        assertEquals(300000L, clock.earnedMillis)
        clock.pulse("2026-11-09", 2000, true, 300000)
        assertEquals(0L, clock.earnedMillis)
        clock.pulse("2026-11-09", 3000, true, 300000)
        assertEquals(1000L, clock.earnedMillis)
    }
}
