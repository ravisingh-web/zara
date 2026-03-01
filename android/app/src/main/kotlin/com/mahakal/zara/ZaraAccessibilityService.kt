package com.mahakal.zara

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ZaraAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "ZARA_ACCESSIBILITY"
        const val CHANNEL = "com.mahakal.zara/accessibility"

        // Guardian constants
        private const val PREFS       = "zara_guardian_prefs"
        private const val KEY_COUNT   = "wrong_password_count"
        private const val KEY_LAST    = "last_password_attempt"
        private const val THRESHOLD   = 2

        private val LOCK_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.keyguard"
        )
        private val PASSWORD_WORDS = setOf(
            "wrong", "incorrect", "invalid", "error"
        )

        // Singleton — Flutter side se access ke liye
        var instance: ZaraAccessibilityService? = null
            private set
    }

    private var methodChannel: MethodChannel? = null
    private var prefs: SharedPreferences? = null
    private var isMonitoring = false
    private val handler = Handler(Looper.getMainLooper())

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        prefs    = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        // ✅ Full access config — ALL events, ALL packages
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED     or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED   or
                AccessibilityEvent.TYPE_VIEW_CLICKED              or
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED         or
                AccessibilityEvent.TYPE_VIEW_SCROLLED             or
                AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
            feedbackType      = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags             =
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS              or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 50
            packageNames      = null   // null = monitor ALL packages
        }

        createNotificationChannel()
        startForeground(1001, buildNotification("Z.A.R.A. Guardian", "God Mode Active — Monitoring"))
        isMonitoring = true

        Log.d(TAG, "✅ ZaraAccessibilityService connected — God Mode ACTIVE")
        sendEvent("onServiceStatusChanged", mapOf("enabled" to true))
    }

    override fun onInterrupt() {
        isMonitoring = false
        instance     = null
        Log.w(TAG, "⚠️ Service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FLUTTER METHOD CHANNEL SETUP
    // Called from MainActivity after engine is ready
    // ══════════════════════════════════════════════════════════════════════════

    fun attachToEngine(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {

                // ── Status ──────────────────────────────────────────────────
                "isEnabled" -> {
                    result.success(isMonitoring)
                }

                // ── Open any app by package name ────────────────────────────
                "openApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val ok  = openApp(pkg)
                    result.success(ok)
                }

                // ── Click any visible text on screen ────────────────────────
                "clickText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val ok   = clickNodeWithText(text)
                    result.success(ok)
                }

                // ── Click node by resource-id ───────────────────────────────
                "clickById" -> {
                    val id = call.argument<String>("id") ?: ""
                    val ok = clickNodeById(id)
                    result.success(ok)
                }

                // ── Type text into focused field ────────────────────────────
                "typeText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val ok   = typeTextInFocused(text)
                    result.success(ok)
                }

                // ── Scroll down (reels, feeds, lists) ──────────────────────
                "scrollDown" -> {
                    val steps = call.argument<Int>("steps") ?: 1
                    scrollDown(steps)
                    result.success(true)
                }

                // ── Scroll up ───────────────────────────────────────────────
                "scrollUp" -> {
                    val steps = call.argument<Int>("steps") ?: 1
                    scrollUp(steps)
                    result.success(true)
                }

                // ── Swipe (custom gesture) ──────────────────────────────────
                "swipe" -> {
                    val x1 = call.argument<Int>("x1") ?: 540
                    val y1 = call.argument<Int>("y1") ?: 1400
                    val x2 = call.argument<Int>("x2") ?: 540
                    val y2 = call.argument<Int>("y2") ?: 400
                    val ms = call.argument<Int>("durationMs") ?: 300
                    performSwipe(x1.toFloat(), y1.toFloat(), x2.toFloat(), y2.toFloat(), ms.toLong())
                    result.success(true)
                }

                // ── Tap at coordinates ──────────────────────────────────────
                "tapAt" -> {
                    val x  = call.argument<Int>("x") ?: 0
                    val y  = call.argument<Int>("y") ?: 0
                    tapAt(x.toFloat(), y.toFloat())
                    result.success(true)
                }

                // ── Press back button ───────────────────────────────────────
                "pressBack" -> {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    result.success(true)
                }

                // ── Press home button ───────────────────────────────────────
                "pressHome" -> {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    result.success(true)
                }

                // ── Press recents ───────────────────────────────────────────
                "pressRecents" -> {
                    performGlobalAction(GLOBAL_ACTION_RECENTS)
                    result.success(true)
                }

                // ── Take screenshot (Android 9+) ────────────────────────────
                "takeScreenshot" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                // ── Pull down notification shade ────────────────────────────
                "openNotifications" -> {
                    performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
                    result.success(true)
                }

                // ── Pull down quick settings ────────────────────────────────
                "openQuickSettings" -> {
                    performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)
                    result.success(true)
                }

                // ── Get current foreground app package ──────────────────────
                "getForegroundApp" -> {
                    val pkg = rootInActiveWindow?.packageName?.toString() ?: ""
                    result.success(pkg)
                }

                // ── Find text on screen ─────────────────────────────────────
                "findTextOnScreen" -> {
                    val text  = call.argument<String>("text") ?: ""
                    val found = findNodeWithText(text) != null
                    result.success(found)
                }

                else -> result.notImplemented()
            }
        }
        Log.d(TAG, "✅ MethodChannel attached to Flutter engine")
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GOD MODE ACTIONS
    // ══════════════════════════════════════════════════════════════════════════

    // ── Open App ──────────────────────────────────────────────────────────────
    private fun openApp(packageName: String): Boolean {
        if (packageName.isEmpty()) return false
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                Log.d(TAG, "✅ Opened app: $packageName")
                true
            } else {
                Log.w(TAG, "⚠️ App not found: $packageName")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ openApp error: ${e.message}")
            false
        }
    }

    // ── Click node by visible text ────────────────────────────────────────────
    private fun clickNodeWithText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val node = findNodeWithText(text) ?: return false
        val clicked = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        if (!clicked) {
            // Try clicking parent
            val parent = node.parent
            if (parent != null) return parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        Log.d(TAG, "✅ Clicked text: $text — result: $clicked")
        return clicked
    }

    // ── Click node by resource ID ─────────────────────────────────────────────
    private fun clickNodeById(id: String): Boolean {
        val root  = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByViewId(id)
        if (nodes.isNullOrEmpty()) return false
        val clicked = nodes[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
        Log.d(TAG, "✅ Clicked id: $id — result: $clicked")
        return clicked
    }

    // ── Type text in currently focused field ──────────────────────────────────
    private fun typeTextInFocused(text: String): Boolean {
        val root    = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        return if (focused != null) {
            val args = Bundle()
            args.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text
            )
            val ok = focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            Log.d(TAG, "✅ Typed text: $text — result: $ok")
            ok
        } else {
            // Fallback: find any editable field
            val editable = findEditableNode(root)
            if (editable != null) {
                editable.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                val args = Bundle()
                args.putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text
                )
                editable.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            } else {
                false
            }
        }
    }

    // ── Scroll down N times ───────────────────────────────────────────────────
    private fun scrollDown(steps: Int = 1) {
        repeat(steps) {
            val screenH = resources.displayMetrics.heightPixels.toFloat()
            val screenW = resources.displayMetrics.widthPixels.toFloat()
            performSwipe(
                screenW / 2, screenH * 0.75f,
                screenW / 2, screenH * 0.25f,
                400
            )
            Thread.sleep(300)
        }
    }

    // ── Scroll up N times ─────────────────────────────────────────────────────
    private fun scrollUp(steps: Int = 1) {
        repeat(steps) {
            val screenH = resources.displayMetrics.heightPixels.toFloat()
            val screenW = resources.displayMetrics.widthPixels.toFloat()
            performSwipe(
                screenW / 2, screenH * 0.25f,
                screenW / 2, screenH * 0.75f,
                400
            )
            Thread.sleep(300)
        }
    }

    // ── Swipe gesture ─────────────────────────────────────────────────────────
    private fun performSwipe(x1: Float, y1: Float, x2: Float, y2: Float, durationMs: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val path = Path().apply {
            moveTo(x1, y1)
            lineTo(x2, y2)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription) {
                Log.d(TAG, "✅ Swipe completed")
            }
            override fun onCancelled(gestureDescription: GestureDescription) {
                Log.w(TAG, "⚠️ Swipe cancelled")
            }
        }, null)
    }

    // ── Tap at coordinates ────────────────────────────────────────────────────
    private fun tapAt(x: Float, y: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val path = Path().apply { moveTo(x, y) }
        val stroke  = GestureDescription.StrokeDescription(path, 0, 50)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(gesture, null, null)
        Log.d(TAG, "✅ Tap at ($x, $y)")
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ACCESSIBILITY EVENTS — Guardian Mode
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = event.packageName?.toString() ?: return

        // Guardian: wrong password detection
        if (LOCK_PACKAGES.contains(pkg)) {
            val text = event.text?.joinToString(" ").orEmpty().lowercase()
            if (PASSWORD_WORDS.any { text.contains(it) }) {
                handleWrongPassword(pkg)
            }
        }

        // Notify Flutter of window changes (useful for God Mode awareness)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            sendEvent("onWindowChanged", mapOf("package" to pkg))
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GUARDIAN — Wrong password handler (unchanged from original)
    // ══════════════════════════════════════════════════════════════════════════

    private fun handleWrongPassword(pkg: String) {
        val p   = prefs ?: return
        val now = System.currentTimeMillis()
        if (now - p.getLong(KEY_LAST, 0) > 30000) {
            p.edit().putInt(KEY_COUNT, 0).apply()
        }
        val count = p.getInt(KEY_COUNT, 0) + 1
        p.edit().putInt(KEY_COUNT, count).putLong(KEY_LAST, now).apply()

        sendEvent("onSecurityEvent", mapOf("type" to "wrong_password", "count" to count))

        if (count >= THRESHOLD) captureIntruderPhoto()
    }

    private fun captureIntruderPhoto() {
        try {
            val ts  = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val dir = getExternalFilesDir(null)?.absolutePath + "/Pictures/ZARA_Intruders"
            File(dir).mkdirs()
            val file = File(dir, "intruder_$ts.jpg")
            file.createNewFile()
            sendEvent("onSecurityEvent", mapOf(
                "type" to "photo_captured",
                "path" to file.absolutePath
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Photo error: ${e.message}")
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPER UTILITIES
    // ══════════════════════════════════════════════════════════════════════════

    private fun findNodeWithText(text: String): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        // Exact match first
        var nodes = root.findAccessibilityNodeInfosByText(text)
        if (!nodes.isNullOrEmpty()) return nodes[0]
        // Case-insensitive recursive search
        return findNodeRecursive(root, text.lowercase())
    }

    private fun findNodeRecursive(node: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? {
        val nodeText = node.text?.toString()?.lowercase() ?: ""
        val nodeDesc = node.contentDescription?.toString()?.lowercase() ?: ""
        if (nodeText.contains(text) || nodeDesc.contains(text)) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findNodeRecursive(child, text)
            if (found != null) return found
        }
        return null
    }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findEditableNode(child)
            if (found != null) return found
        }
        return null
    }

    private fun sendEvent(method: String, data: Map<String, Any>) {
        handler.post {
            try {
                methodChannel?.invokeMethod(method, data)
            } catch (e: Exception) {
                Log.e(TAG, "sendEvent error: ${e.message}")
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NOTIFICATION
    // ══════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "zara_guardian",
            "Z.A.R.A. Guardian",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "God Mode — Z.A.R.A. device control"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, "zara_guardian")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
