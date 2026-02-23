// android/app/src/main/kotlin/com/mahakal/zara/ZaraAccessibilityService.kt
// Z.A.R.A. — Accessibility Service with AUTO-TYPE Capability

package com.mahakal.zara

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.mahakal.zara.MainActivity

class ZaraAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "ZaraAccessibility"
        const val CHANNEL = "com.mahakal.zara/accessibility"

        var instance: ZaraAccessibilityService? = null
        private var methodChannel: MethodChannel? = null

        private var wrongPasswordCount = 0
        private var lastUnlockAttempt = 0L
        private val LOCK_SCREEN_PACKAGES = listOf("com.android.systemui", "com.android.keyguard")

        private var typeTextQueue = mutableListOf<String>()
        private var isTyping = false
        private val handler = Handler(Looper.getMainLooper())

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        fun sendToFlutter(eventType: String, data: Map<String, Any>) {
            methodChannel?.invokeMethod("onSecurityEvent", mapOf(
                "type" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        val info = AccessibilityServiceInfo().apply {
            // ✅ Fix: Added 'D' to BOTH STATE_CHANGED and CONTENT_CHANGED
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                        AccessibilityEvent.TYPE_VIEW_CLICKED or
                        AccessibilityEvent.TYPE_VIEW_FOCUSED or
                        AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                   AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                   AccessibilityServiceInfo.FLAG_REQUEST_TOUCH_EXPLORATION_MODE
            notificationTimeout = 100
        }
        setServiceInfo(info)

        createNotificationChannel()
        startForegroundNotification()

        Log.d(TAG, "✅ Z.A.R.A. Accessibility Service Connected with Auto-Type")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> handleWindowStateChange(event)
            AccessibilityEvent.TYPE_VIEW_CLICKED -> handleViewClicked(event)
            AccessibilityEvent.TYPE_VIEW_FOCUSED -> handleViewFocused(event)
        }
    }

    private fun handleWindowStateChange(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return

        if (LOCK_SCREEN_PACKAGES.contains(packageName)) {
            sendToFlutter("lock_screen", mapOf("visible" to true, "package" to packageName))
        }
    }

    private fun handleViewClicked(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return

        if (LOCK_SCREEN_PACKAGES.contains(packageName)) {
            val nodeInfo = event.source
            val text = nodeInfo?.text?.toString()?.lowercase() ?: ""

            if (text.contains("wrong") || text.contains("incorrect") ||
                text.contains("invalid") || text.contains("galat")) {
                wrongPasswordCount++
                lastUnlockAttempt = System.currentTimeMillis()

                Log.w(TAG, "⚠️ Wrong password attempt #$wrongPasswordCount")
                sendToFlutter("wrong_password", mapOf(
                    "count" to wrongPasswordCount,
                    "timestamp" to lastUnlockAttempt
                ))

                if (wrongPasswordCount >= 2) {
                    triggerIntruderCapture()
                }
            }
        }
    }

    private fun handleViewFocused(event: AccessibilityEvent) {
        val nodeInfo = event.source ?: return

        if (nodeInfo.className?.contains("EditText", ignoreCase = true) == true ||
            nodeInfo.className?.contains("TextInput", ignoreCase = true) == true) {

            Log.d(TAG, "📝 Text input field focused: ${nodeInfo.packageName}")
            sendToFlutter("text_field_focused", mapOf(
                "package" to nodeInfo.packageName.toString(),
                "hint" to (nodeInfo.hintText?.toString() ?: ""),
                "canEdit" to nodeInfo.isEditable
            ))

            if (typeTextQueue.isNotEmpty() && !isTyping) {
                processTypeQueue(nodeInfo)
            }
        }
    }

    fun typeText(text: String) {
        Log.d(TAG, "⌨️ Queuing text for auto-type: ${text.length} chars")
        typeTextQueue.add(text)

        if (!isTyping) {
            findAndFocusTextField()
        }
    }

    private fun findAndFocusTextField() {
        if (rootInActiveWindow == null) {
            Log.w(TAG, "⚠️ No active window for text input")
            return
        }

        val textField = findTextField(rootInActiveWindow)
        if (textField != null) {
            Log.d(TAG, "✓ Text field found, clicking to focus...")
            textField.performAction(AccessibilityNodeInfo.ACTION_CLICK)

            handler.postDelayed({
                if (textField.isFocused) {
                    processTypeQueue(textField)
                } else {
                    textField.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                    handler.postDelayed({ processTypeQueue(textField) }, 500)
                }
            }, 300)
        } else {
            Log.w(TAG, "⚠️ No text field found in current window")
            sendToFlutter("auto_type_error", mapOf("message" to "No text input field found"))
        }
    }

    private fun findTextField(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null

        if (node.isEditable && node.isEnabled && node.isVisibleToUser) {
            return node
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val found = findTextField(child)
            child?.recycle()
            if (found != null) return found
        }
        return null
    }

    private fun processTypeQueue(textField: AccessibilityNodeInfo) {
        if (typeTextQueue.isEmpty()) {
            isTyping = false
            return
        }

        isTyping = true
        val textToType = typeTextQueue.removeAt(0)

        Log.d(TAG, "⌨️ Typing ${textToType.length} characters...")
        typeViaClipboard(textField, textToType)
    }

    private fun typeViaClipboard(textField: AccessibilityNodeInfo, text: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val arguments = android.os.Bundle()
                arguments.putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
                textField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)

                Log.d(TAG, "✓ Text set successfully via ACTION_SET_TEXT")
                sendToFlutter("auto_type_success", mapOf(
                    "characters" to text.length,
                    "method" to "clipboard"
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Type via clipboard failed: ${e.message}")
            typeViaKeystrokes(textField, text)
        }

        isTyping = false

        if (typeTextQueue.isNotEmpty()) {
            handler.postDelayed({ findAndFocusTextField() }, 500)
        }
    }

    private fun typeViaKeystrokes(textField: AccessibilityNodeInfo, text: String) {
        Log.d(TAG, "⌨️ Fallback: Typing via keystrokes...")

        for ((index, char) in text.withIndex()) {
            handler.postDelayed({
                val event = AccessibilityEvent.obtain(AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED)
                event.packageName = textField.packageName
                event.className = textField.className
                event.text.add(char.toString())

                if (index == text.length - 1) {
                    Log.d(TAG, "✓ Keystroke typing completed")
                    sendToFlutter("auto_type_success", mapOf(
                        "characters" to text.length,
                        "method" to "keystrokes"
                    ))
                }
            }, (index * 50).toLong())
        }
        isTyping = false
    }

    fun clickOnText(text: String): Boolean {
        Log.d(TAG, "👆 Clicking on: $text")

        val node = findNodeByText(rootInActiveWindow, text)
        if (node != null) {
            val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            node.recycle()
            Log.d(TAG, "✓ Click ${if (result) "successful" else "failed"}")
            return result
        }

        Log.w(TAG, "⚠️ Node not found: $text")
        return false
    }

    private fun findNodeByText(node: AccessibilityNodeInfo?, text: String): AccessibilityNodeInfo? {
        if (node == null) return null

        val nodeText = node.text?.toString()?.lowercase() ?: ""
        if (nodeText.contains(text.lowercase())) {
            return node
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val found = findNodeByText(child, text)
            child?.recycle()
            if (found != null) return found
        }
        return null
    }

    fun openApp(packageName: String): Boolean {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                Log.d(TAG, "✓ App opened: $packageName")
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Open app failed: ${e.message}")
        }
        return false
    }

    private fun triggerIntruderCapture() {
        Log.e(TAG, "🚨 INTRUDER DETECTED! Triggering camera…")
        sendToFlutter("intruder_detected", mapOf(
            "action" to "capture_photo",
            "wrongAttempts" to wrongPasswordCount
        ))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "zara_guardian",
                "Z.A.R.A. Guardian Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Security monitoring + Auto-type capability"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, "zara_guardian")
            .setContentTitle("Z.A.R.A. Guardian + Auto-Type Active")
            .setContentText("Ready to code, Sir...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(1, notification)
    }

    override fun onInterrupt() {
        Log.w(TAG, "⚠️ Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "❌ Accessibility Service Destroyed")
    }

    fun resetWrongPasswordCount() {
        wrongPasswordCount = 0
        Log.d(TAG, "✓ Wrong password count reset")
    }
}
