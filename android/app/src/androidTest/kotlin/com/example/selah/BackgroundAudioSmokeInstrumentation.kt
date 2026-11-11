package com.example.selah

import android.app.Activity
import android.app.Instrumentation
import android.app.Notification
import android.app.NotificationManager
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Bundle

/** Emulator-only smoke test. Select a narrated translation before running.
 * Start Bible playback during the initial wait. No private user data is read.
 */
object BackgroundAudioSmoke {
    fun run(instrumentation: Instrumentation) {
        val targetContext = instrumentation.targetContext
        val uiAutomation = instrumentation.uiAutomation
        val result = Bundle()
        var code = Activity.RESULT_OK
        try {
            targetContext.startActivity(Intent(Intent.ACTION_MAIN)
                .setClassName(targetContext.packageName, "com.example.selah.MainActivity")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            val manager = targetContext.getSystemService(NotificationManager::class.java)
            var controller: MediaController? = null
            for (attempt in 0..600) {
                val notification = manager.activeNotifications.firstOrNull {
                    it.notification.extras.containsKey(Notification.EXTRA_MEDIA_SESSION)
                }?.notification
                @Suppress("DEPRECATION")
                val token = notification?.extras?.getParcelable<MediaSession.Token>(Notification.EXTRA_MEDIA_SESSION)
                if (token != null) {
                    val candidate = MediaController(targetContext, token)
                    if (candidate.playbackState?.state == PlaybackState.STATE_PLAYING &&
                        (candidate.metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0) > 2000) {
                        controller = candidate
                        break
                    }
                }
                Thread.sleep(200)
            }
            val player = checkNotNull(controller) { "Start narrated Bible playback within two minutes" }
            val original = player.metadata!!.getString(MediaMetadata.METADATA_KEY_TITLE)
            uiAutomation.executeShellCommand("input keyevent 3").close()
            Thread.sleep(1500)
            check(player.playbackState?.state == PlaybackState.STATE_PLAYING) { "Playback paused on Home" }
            uiAutomation.executeShellCommand("input keyevent 223").close()
            Thread.sleep(1500)
            val duration = player.metadata!!.getLong(MediaMetadata.METADATA_KEY_DURATION)
            player.transportControls.seekTo(duration - 1200)
            var continued = false
            for (attempt in 0..150) {
                if (player.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) != original &&
                    player.playbackState?.state == PlaybackState.STATE_PLAYING) {
                    continued = true
                    break
                }
                Thread.sleep(200)
            }
            check(continued) { "Next chapter did not start with screen locked" }
            player.transportControls.pause()
            Thread.sleep(700)
            check(player.playbackState?.state == PlaybackState.STATE_PAUSED) { "Notification pause failed" }
            player.transportControls.play()
            Thread.sleep(700)
            check(player.playbackState?.state == PlaybackState.STATE_PLAYING) { "Notification resume failed" }
            player.transportControls.stop()
            result.putString("stream", "PASS: Home, locked-screen next chapter, media pause/resume/stop\n")
        } catch (error: Throwable) {
            code = Activity.RESULT_CANCELED
            result.putString("stream", "FAIL: ${error.message}\n")
        } finally {
            uiAutomation.executeShellCommand("input keyevent 224").close()
        }
        instrumentation.finish(code, result)
    }
}
