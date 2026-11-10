package com.example.selah

import android.content.Intent
import android.content.ActivityNotFoundException
import android.speech.RecognizerIntent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        const val FOCUS_READ = "com.example.selah.FOCUS_READ"
        const val FOCUS_SETTINGS = "com.example.selah.FOCUS_SETTINGS"
    }
    private val handler = Handler(Looper.getMainLooper())
    private var pendingAction: String? = null
    private var reminderResult: MethodChannel.Result? = null
    private var reminderHour = 8
    private var reminderMinute = 0
    private var reminderSlot = "morning"
    private var voiceResult: MethodChannel.Result? = null
    private val heartbeat = object : Runnable {
        override fun run() {
            FocusStore.pulse()
            if (FocusStore.snapshot()["reading"] == true) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        FocusStore.initialize(this)
        acceptAction(intent)
        super.onCreate(savedInstanceState)
    }

    private fun acceptAction(value: Intent?) {
        when (value?.action) {
            FOCUS_READ -> pendingAction = "read"
            FOCUS_SETTINGS -> pendingAction = "settings"
            "com.example.selah.JOURNEY" -> pendingAction = "journey"
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acceptAction(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selah/voice")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") { result.notImplemented(); return@setMethodCallHandler }
                if (voiceResult != null) { result.error("BUSY", "Voice input is already open.", null); return@setMethodCallHandler }
                val language = call.argument<String>("language") ?: "en-PH"
                if (language !in listOf("en-PH", "fil-PH", "ceb-PH")) {
                    result.error("LANGUAGE", "Choose a supported language option.", null)
                    return@setMethodCallHandler
                }
                val request = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                    .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    .putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak your reflection")
                voiceResult = result
                try {
                    @Suppress("DEPRECATION")
                    startActivityForResult(request, 8301)
                } catch (_: ActivityNotFoundException) {
                    voiceResult = null
                    result.error("UNAVAILABLE", "No speech recognition app is available. Enable your phone’s voice input service or use keyboard dictation.", null)
                } catch (_: Exception) {
                    voiceResult = null
                    result.error("VOICE", "Voice input could not start. Check your phone’s speech service and microphone permissions.", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selah/journey")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "reminderStatus" -> result.success(JourneyReminders.status(this))
                        "reminder" -> {
                            val enabled = call.argument<Boolean>("enabled") == true
                            val hour = call.argument<Int>("hour") ?: 8
                            val minute = call.argument<Int>("minute") ?: 0
                            val slot = call.argument<String>("slot") ?: "morning"
                            require(slot == "morning" || slot == "bedtime")
                            require(hour in 0..23 && minute in 0..59)
                            if (enabled && android.os.Build.VERSION.SDK_INT >= 33 &&
                                checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                if (reminderResult != null) { result.error("BUSY", "A permission request is already open.", null) }
                                else {
                                    reminderHour = hour; reminderMinute = minute; reminderSlot = slot; reminderResult = result
                                    requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 8203)
                                }
                            } else result.success(JourneyReminders.configure(this, enabled, hour, minute, slot))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("REMINDER", error.message, null) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selah/focus")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> {
                            val status = FocusStore.snapshot()
                            status["action"] = pendingAction
                            pendingAction = null
                            result.success(status)
                        }
                        "apps" -> Thread {
                            try {
                                val excluded = FocusStore.protectedPackages()
                                @Suppress("DEPRECATION")
                                val launchable = packageManager.queryIntentActivities(
                                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
                                val apps = launchable.distinctBy { it.activityInfo.packageName }
                                    .filter { it.activityInfo.packageName !in excluded }
                                    .mapNotNull { entry ->
                                        try {
                                            val bitmap = Bitmap.createBitmap(80, 80, Bitmap.Config.ARGB_8888)
                                            entry.loadIcon(packageManager).apply { setBounds(0, 0, 80, 80); draw(Canvas(bitmap)) }
                                            val png = ByteArrayOutputStream()
                                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, png)
                                            bitmap.recycle()
                                            mapOf("packageName" to entry.activityInfo.packageName,
                                                "name" to entry.loadLabel(packageManager).toString(), "icon" to png.toByteArray())
                                        } catch (_: Exception) { null }
                                    }.sortedBy { (it["name"] as String).lowercase() }
                                runOnUiThread { result.success(apps) }
                            } catch (_: Exception) {
                                runOnUiThread { result.error("APP_LIST", "Apps could not be loaded. Please retry.", null) }
                            }
                        }.start()
                        "configure" -> {
                            val minutes = call.argument<Number>("goalMinutes")?.toInt() ?: 10
                            val selected = call.argument<List<String>>("selectedPackages")?.toSet() ?: emptySet()
                            @Suppress("DEPRECATION")
                            val allowed = packageManager.queryIntentActivities(
                                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
                                .map { it.activityInfo.packageName }.toSet()
                            FocusStore.configure(minutes, selected.intersect(allowed))
                            result.success(null)
                        }
                        "consent" -> { FocusStore.consent(); result.success(null) }
                        "enable" -> { FocusStore.enable(call.argument<Boolean>("enabled") == true); result.success(null) }
                        "reading" -> { FocusStore.reading(call.argument<Boolean>("visible") == true); result.success(null) }
                        "accessibilitySettings" -> {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("FOCUS_SETUP", error.message ?: "Focus Mode could not be updated.", null)
                }
            }
    }

    override fun onResume() { super.onResume(); FocusStore.resumed(true); handler.post(heartbeat); JourneyReminders.schedule(this) }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 8203) {
            val result = reminderResult; reminderResult = null
            result?.success(JourneyReminders.configure(this,
                grantResults.firstOrNull() == android.content.pm.PackageManager.PERMISSION_GRANTED, reminderHour, reminderMinute, reminderSlot))
        }
    }
    override fun onPause() {
        handler.removeCallbacks(heartbeat)
        FocusStore.resumed(false)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onPause()
    }
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        FocusStore.focused(hasFocus)
    }
    @Deprecated("Android activity-result callback used by the system speech dialog")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8301) return
        val result = voiceResult ?: return
        voiceResult = null
        result.success(if (resultCode == android.app.Activity.RESULT_OK)
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null)
    }
    override fun onDestroy() {
        voiceResult?.error("CLOSED", "Voice input closed. Your existing reflection is unchanged.", null)
        voiceResult = null
        FocusStore.reading(false); super.onDestroy()
    }
}
