package com.example.selah

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.ScrollView

class FocusBlockActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var remaining: TextView
    private var blocked = ""
    private val refresh = object : Runnable {
        override fun run() {
            if (!FocusStore.shouldBlock(blocked)) { finish(); return }
            val seconds = (FocusStore.snapshot()["remainingSeconds"] as Number).toLong()
            remaining.text = String.format(java.util.Locale.ROOT, "%02d:%02d", seconds / 60, seconds % 60)
            handler.postDelayed(this, 1000)
        }
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FocusStore.initialize(this)
        blocked = intent.getStringExtra("blockedPackage") ?: ""
        if (!FocusStore.shouldBlock(blocked)) { finish(); return }
        val appName = try { packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(blocked, 0)).toString() } catch (_: Exception) { "this app" }
        val cream = Color.rgb(250, 247, 239)
        val gold = Color.rgb(216, 187, 121)
        val green = Color.rgb(36, 75, 62)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(dp(28), dp(32), dp(28), dp(32)); setBackgroundColor(green)
        }
        layout.addView(ImageView(this).apply { setImageResource(R.mipmap.ic_launcher) },
            LinearLayout.LayoutParams(dp(80), dp(80)).apply { bottomMargin = dp(24) })
        fun text(value: String, size: Float, color: Int = cream) = TextView(this).apply {
            this.text = value; textSize = size; setTextColor(color); gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(8))
        }
        layout.addView(text("Pause before $appName", 29f).apply { typeface = Typeface.SERIF })
        layout.addView(text("You chose time in Scripture before time in your selected apps.", 16f))
        remaining = text("", 44f, gold).apply { typeface = Typeface.DEFAULT_BOLD }
        layout.addView(remaining)
        layout.addView(text("of reading left in today's goal", 14f))
        fun button(label: String, filled: Boolean, action: () -> Unit) {
            layout.addView(Button(this).apply {
                text = label; isAllCaps = false; textSize = 16f
                setTextColor(if (filled) green else cream)
                background = GradientDrawable().apply { cornerRadius = dp(24).toFloat()
                    setColor(if (filled) gold else Color.TRANSPARENT) }
                setOnClickListener { action() }
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(54))
                .apply { topMargin = dp(10) })
        }
        button("Read in SELAH", true) { openSelah(MainActivity.FOCUS_READ) }
        button("Back to Home", false) { goHome() }
        setContentView(ScrollView(this).apply { isFillViewport = true; addView(layout) })
    }

    private fun openSelah(action: String) {
        startActivity(Intent(this, MainActivity::class.java).setAction(action)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
        finish()
    }
    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }
    @Suppress("DEPRECATION")
    override fun onBackPressed() { goHome() }
    override fun onResume() { super.onResume(); if (::remaining.isInitialized) handler.post(refresh) }
    override fun onPause() { handler.removeCallbacks(refresh); super.onPause() }
}
