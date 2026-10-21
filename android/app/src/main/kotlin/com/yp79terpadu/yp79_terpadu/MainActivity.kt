package com.yp79terpadu.yp79_terpadu

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// MainActivity dengan mode ujian (anti-cheat ringan → sedang):
///
/// - FLAG_SECURE saat ujian (screenshot & recents thumbnail diblokir)
/// - Immersive sticky + enforcer (status bar muncul → langsung disembunyikan)
/// - Fokus hilang (overlay/pindah app) → alarm + catat pelanggaran + balik ke app
/// - Back/Home/Recents fisik diblokir saat mode ujian
/// - Lock Task (pinning) dicoba; kalau bukan device owner, tetap aman
///   (mode ini "soft kiosk" — tanpa device owner pun tetap berfungsi).
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yp79terpadu.yp79_terpadu/exam"
    private var isExamLocked = false
    private var ch: MethodChannel? = null
    private var volumeObserver: android.database.ContentObserver? = null
    private val handler = Handler(Looper.getMainLooper())
    private var volumeEnforcer: Runnable? = null
    private var immersiveEnforcer: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        applyImmersive()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    private fun applyImmersive() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE)
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        // blok gesture nav (Android 10+): seluruh layar jadi exclusion
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                window.decorView.post {
                    val w = window.decorView.width
                    val h = window.decorView.height
                    if (w > 0 && h > 0) {
                        val rect = Rect(0, 0, w, h)
                        window.decorView.systemGestureExclusionRects = listOf(rect)
                    }
                }
            } catch (_: Exception) {}
        }
    }

    private fun startImmersiveEnforcer() {
        stopImmersiveEnforcer()
        immersiveEnforcer = object : Runnable {
            override fun run() {
                if (isExamLocked) {
                    applyImmersive()
                    handler.postDelayed(this, 500)
                }
            }
        }
        handler.post(immersiveEnforcer!!)
    }

    private fun stopImmersiveEnforcer() {
        immersiveEnforcer?.let { handler.removeCallbacks(it) }
        immersiveEnforcer = null
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isExamLocked && hasFocus) {
            handler.postDelayed({ applyImmersive() }, 300)
            // balik fokus = kembali ke layar ujian -> alarm & volume-lock MATI lagi
            handler.postDelayed({
                stopVolumeEnforcer()
                try {
                    stopService(Intent(this, ExamAlarmService::class.java))
                } catch (_: Exception) {}
            }, 250)
        }
        if (isExamLocked && !hasFocus) {
            // tutup overlay/floating/chat head yang coba nimpa ujian
            try { sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)) } catch (_: Exception) {}
            handler.postDelayed({
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }, 300)
            reportIntrusion()
        }
    }

    private var lastIntrusionAt = 0L
    private fun reportIntrusion() {
        val now = System.currentTimeMillis()
        if (now - lastIntrusionAt < 3000) return
        lastIntrusionAt = now
        try { enforceAlarmVolume() } catch (_: Exception) {}
        try {
            val intent = Intent(this, ExamAlarmService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
        } catch (_: Exception) {}
        try { ch?.invokeMethod("onIntrusion", null) } catch (_: Exception) {}
    }

    override fun onResume() {
        super.onResume()
        if (isExamLocked) {
            applyImmersive()
            startImmersiveEnforcer()
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isExamLocked) {
            reportIntrusion()
            handler.postDelayed({
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }, 200)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isExamLocked) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_MENU -> {
                    // blok tombol fisik / 3-button nav
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        if (isInMultiWindowMode && isExamLocked) {
            handler.post {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }
            reportIntrusion()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ch!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.argument<Boolean>("secure") ?: false
                    if (secure) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                "enterKiosk" -> {
                    val ok = enterExamMode()
                    result.success(ok)
                }
                "exitKiosk" -> {
                    exitExamMode()
                    result.success(true)
                }
                "alarmStart" -> {
                    startAlarm()
                    result.success(true)
                }
                "alarmStop" -> {
                    stopAlarm()
                    result.success(true)
                }
                "isKioskActive" -> {
                    result.success(isExamLocked)
                }
                "isDeviceOwner" -> {
                    result.success(isDeviceOwner())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isDeviceOwner(): Boolean {
        return try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            dpm.isDeviceOwnerApp(packageName)
        } catch (_: Exception) {
            false
        }
    }

    /// Mode ujian: FLAG_SECURE + immersive + (bila device owner) lock task.
    /// Tanpa device owner pun tetap berfungsi — soft kiosk.
    private fun enterExamMode(): Boolean {
        isExamLocked = true
        applyImmersive()
        startImmersiveEnforcer()
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, ExamDeviceAdminReceiver::class.java)
            if (dpm.isDeviceOwnerApp(packageName)) {
                try {
                    dpm.setLockTaskPackages(admin, arrayOf(packageName))
                } catch (_: Exception) {}
                try {
                    dpm.setLockTaskFeatures(admin, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        // minta pinning — di HP biasa muncul "Got it / No thanks"
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                startLockTask()
            }
        } catch (_: Exception) {}
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        return true
    }

    private fun exitExamMode() {
        isExamLocked = false
        stopVolumeEnforcer()
        stopImmersiveEnforcer()
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
            }
        } catch (_: Exception) {}
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
    }

    /// Volume hanya stream ALARM dipaksa max (media tidak disentuh).
    private fun enforceAlarmVolume() {
        try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            try {
                audio.setStreamVolume(
                    AudioManager.STREAM_ALARM,
                    audio.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
            } catch (_: Exception) {}
        } catch (_: Exception) {}
    }

    private fun startVolumeEnforcer() {
        stopVolumeEnforcer()
        volumeObserver = object : android.database.ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                if (isExamLocked) enforceAlarmVolume()
            }
        }
        try {
            contentResolver.registerContentObserver(android.provider.Settings.System.CONTENT_URI, true, volumeObserver!!)
        } catch (_: Exception) {}
        volumeEnforcer = object : Runnable {
            override fun run() {
                if (isExamLocked) {
                    enforceAlarmVolume()
                    handler.postDelayed(this, 1500)
                }
            }
        }
        handler.post(volumeEnforcer!!)
    }

    private fun stopVolumeEnforcer() {
        volumeEnforcer?.let { handler.removeCallbacks(it) }
        volumeEnforcer = null
        volumeObserver?.let {
            try { contentResolver.unregisterContentObserver(it) } catch (_: Exception) {}
        }
        volumeObserver = null
    }

    private fun startAlarm() {
        try { enforceAlarmVolume() } catch (_: Exception) {}
        try { startVolumeEnforcer() } catch (_: Exception) {}
        val intent = Intent(this, ExamAlarmService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAlarm() {
        stopService(Intent(this, ExamAlarmService::class.java))
    }

    override fun onDestroy() {
        if (!isExamLocked) stopAlarm()
        stopVolumeEnforcer()
        stopImmersiveEnforcer()
        super.onDestroy()
    }
}
