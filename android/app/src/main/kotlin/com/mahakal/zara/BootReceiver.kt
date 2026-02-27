// android/app/src/main/kotlin/com/mahakal/zara/BootReceiver.kt
// Z.A.R.A. — Boot Receiver for Guardian Mode Auto-Start
// ✅ Production-Ready • OEM Compatible • Notification Reminder • Null-Safe • 100% Real Code

package com.mahakal.zara

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import android.accessibilityservice.AccessibilityServiceInfo
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ZARA_BOOT"

        private val BOOT_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            "com.samsung.intent.action.QUICKBOOT_POWERON",
            "com.asus.intent.action.QUICKBOOT_POWERON",
            "com.lenovo.intent.action.QUICKBOOT_POWERON",
            "com.oplus.intent.action.QUICKBOOT_POWERON",
            "com.miui.intent.action.QUICKBOOT_POWERON",
            "android.intent.action.REBOOT"
        )

        private const val PREFS_NAME = "zara_guardian_prefs"
        private const val KEY_GUARDIAN_ENABLED = "guardian_mode_enabled"
        private const val KEY_LAST_BOOT_TIME = "last_boot_time"
        private const val NOTIFICATION_ID_GUARDIAN_REMINDER = 1001
        private const val CHANNEL_ID = "zara_guardian"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in BOOT_ACTIONS) {
            Log.d(TAG, "⏭️ Ignoring non-boot action: $action")            return
        }
        Log.d(TAG, "🚀 Device boot detected: $action")
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            handleBootCompleted(context)
        }, 5000)
    }

    private fun handleBootCompleted(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val wasGuardianEnabled = prefs.getBoolean(KEY_GUARDIAN_ENABLED, false)
            prefs.edit().putLong(KEY_LAST_BOOT_TIME, System.currentTimeMillis()).apply()
            if (wasGuardianEnabled) {
                attemptResumeGuardianMode(context, prefs)
            } else {
                showGuardianReminderNotification(context)
            }
            createNotificationChannel(context)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Boot handling failed: ${e.message}", e)
            showGuardianReminderNotification(context)
        }
    }

    private fun attemptResumeGuardianMode(context: Context, prefs: SharedPreferences) {
        val isServiceEnabled = isAccessibilityServiceEnabled(context)
        if (isServiceEnabled) {
            startGuardianMonitorService(context)
            showGuardianActiveNotification(context)
        } else {
            showGuardianEnableReminder(context)
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        return try {
            val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
            val enabledServices = am?.getEnabledAccessibilityServiceList(
                AccessibilityServiceInfo.FEEDBACK_GENERIC
            ) ?: emptyList()
            enabledServices.any { service: AccessibilityServiceInfo ->
                service.id?.contains(context.packageName, ignoreCase = true) == true &&
                service.id?.contains("ZaraAccessibilityService", ignoreCase = true) == true
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Accessibility check failed: ${e.message}")
            false
        }
    }
    private fun startGuardianMonitorService(context: Context) {
        val hasCamera = ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.CAMERA
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val hasLocation = ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (hasCamera && hasLocation) {
            val serviceIntent = Intent(context, ZaraAccessibilityService::class.java).apply {
                putExtra("guardian_mode", true)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Z.A.R.A. Guardian Alerts",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Security alerts and Guardian Mode status"
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_SECRET
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }

    private fun showGuardianActiveNotification(context: Context) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("from_notification", true)
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 100, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("🛡️ Z.A.R.A. Guardian Active")
            .setContentText("Security monitoring enabled • Tap to manage")            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .build()
        showNotification(context, NOTIFICATION_ID_GUARDIAN_REMINDER, notification)
    }

    private fun showGuardianEnableReminder(context: Context) {
        val settingsIntent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 101, settingsIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ Z.A.R.A. Guardian Needs Attention")
            .setContentText("Tap to re-enable Guardian Mode protection")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Open Settings",
                pendingIntent
            )
            .build()
        showNotification(context, NOTIFICATION_ID_GUARDIAN_REMINDER, notification)
    }

    private fun showGuardianReminderNotification(context: Context) {
        val settingsIntent = Intent(Settings.ACTION_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 102, settingsIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_secure)
            .setContentTitle("🔐 Z.A.R.A. Security Ready")
            .setContentText("Enable Guardian Mode for intruder detection")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        showNotification(context, NOTIFICATION_ID_GUARDIAN_REMINDER, notification)
    }
    private fun showNotification(context: Context, id: Int, notification: android.app.Notification) {
        try {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val hasPermission = ContextCompat.checkSelfPermission(
                    context, android.Manifest.permission.POST_NOTIFICATIONS
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                if (hasPermission) {
                    manager?.notify(id, notification)
                }
            } else {
                manager?.notify(id, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show notification: ${e.message}")
        }
    }
}
