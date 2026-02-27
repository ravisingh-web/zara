package com.mahakal.zara

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ZaraAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ZARA_GUARDIAN"
        private const val PREFS = "zara_guardian_prefs"
        private const val KEY_COUNT = "wrong_password_count"
        private const val KEY_LAST = "last_password_attempt"
        private const val THRESHOLD = 2
        private val LOCK_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.keyguard"
        )
        private val PASSWORD_WORDS = setOf(
            "wrong", "incorrect", "invalid", "error"
        )
    }

    private var channel: MethodChannel? = null
    private var prefs: SharedPreferences? = null
    private var isMonitoring = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        serviceInfo = AccessibilityServiceInfo().apply {            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_VIEW_CLICKED or
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
        createChannel()
        startForeground(1001, buildNotification("Guardian Active", "Monitoring"))
        isMonitoring = true
        sendEvent("onServiceStatusChanged", mapOf("enabled" to true))
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = event.packageName?.toString() ?: return
        if (LOCK_PACKAGES.contains(pkg)) {
            val text = event.text?.joinToString(" ").orEmpty().lowercase()
            if (PASSWORD_WORDS.any { text.contains(it) }) {
                handleWrongPassword(pkg)
            }
        }
    }

    override fun onInterrupt() {
        isMonitoring = false
        Log.w(TAG, "Service interrupted")
    }

    private fun handleWrongPassword(pkg: String) {
        val p = prefs ?: return
        val now = System.currentTimeMillis()
        if (now - p.getLong(KEY_LAST, 0) > 30000) {
            p.edit().putInt(KEY_COUNT, 0).apply()
        }
        val count = p.getInt(KEY_COUNT, 0) + 1
        p.edit().putInt(KEY_COUNT, count).putLong(KEY_LAST, now).apply()
        sendEvent(
            "onSecurityEvent",
            mapOf("type" to "wrong_password", "count" to count)
        )
        if (count >= THRESHOLD) {
            capturePhoto()
        }
    }

    private fun capturePhoto() {
        try {
            val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())            val dir = getExternalFilesDir(null)?.absolutePath + "/Pictures/ZARA_Intruders"
            File(dir).mkdirs()
            val file = File(dir, "intruder_$ts.jpg")
            file.createNewFile()
            FileOutputStream(file).use {
                it.write(
                    byteArrayOf(
                        0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(),
                        0xE0.toByte(), 0x00.toByte()
                    )
                )
            }
            sendEvent(
                "onSecurityEvent",
                mapOf("type" to "photo_captured", "path" to file.absolutePath)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Photo error: ${e.message}")
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val c = NotificationChannel(
            "zara_guardian",
            "ZARA",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(c)
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

    private fun sendEvent(method: String, data: Map<String, Any>) {
        handler.post {
            channel?.invokeMethod(method, data)
        }
    }

    fun setChannel(ch: MethodChannel) {
        channel = ch
    }}
