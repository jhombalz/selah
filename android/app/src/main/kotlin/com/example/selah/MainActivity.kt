package com.example.selah

import android.content.Intent
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
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acceptAction(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    override fun onResume() { super.onResume(); FocusStore.resumed(true); handler.post(heartbeat) }
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
    override fun onDestroy() { FocusStore.reading(false); super.onDestroy() }
}
