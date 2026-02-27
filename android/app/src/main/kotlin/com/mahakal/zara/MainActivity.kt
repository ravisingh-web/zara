// android/app/src/main/kotlin/com/mahakal/zara/MainActivity.kt
// Z.A.R.A. — Main Activity with Platform Channels
// ✅ Real Working • Null-Safe • Proper Service Communication • 100% Hardcode

package com.mahakal.zara

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import android.accessibilityservice.AccessibilityServiceInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.ContextCompat
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ZARA_MAIN"
        private const val CHANNEL_MAIN = "com.mahakal.zara/main"
        private const val CHANNEL_ACCESSIBILITY = "com.mahakal.zara/accessibility"
        private const val CHANNEL_GUARDIAN = "com.mahakal.zara/guardian"
        private const val PREFS_NAME = "zara_guardian_prefs"
        private const val KEY_WRONG_PASSWORD_COUNT = "wrong_password_count"
    }

    private var mainChannel: MethodChannel? = null
    private var accessibilityChannel: MethodChannel? = null
    private var guardianChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "Z.A.R.A. MainActivity created")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Log.d(TAG, "Android 14+ detected")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mainChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_MAIN)
        mainChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    result.success(getDeviceInfo())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    result.success(requestIgnoreBatteryOptimizations())
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        accessibilityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_ACCESSIBILITY)
        accessibilityChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {                    openAccessibilitySettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        guardianChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_GUARDIAN)
        guardianChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "resetWrongPasswordCount" -> {
                    resetWrongPasswordCount()
                    result.success(true)
                }
                "getWrongPasswordCount" -> {
                    result.success(getWrongPasswordCount())
                }
                "incrementWrongPasswordCount" -> {
                    val newCount = incrementWrongPasswordCount()
                    result.success(newCount)
                    if (newCount >= 2) {
                        sendGuardianEvent("intruder_detected", mapOf("count" to newCount))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        mainChannel?.setMethodCallHandler(null)
        accessibilityChannel?.setMethodCallHandler(null)
        guardianChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    private fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "model" to (Build.MODEL ?: "Unknown"),
            "manufacturer" to (Build.MANUFACTURER ?: "Unknown"),
            "brand" to (Build.BRAND ?: "Unknown"),
            "device" to (Build.DEVICE ?: "Unknown"),
            "androidVersion" to (Build.VERSION.RELEASE ?: "Unknown"),
            "sdkInt" to Build.VERSION.SDK_INT,
            "securityPatch" to (Build.VERSION.SECURITY_PATCH ?: "Unknown"),
            "packageName" to packageName
        )
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = android.net.Uri.parse("package:$packageName")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    true
                } else {
                    true
                }
            } else {
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
            enabledServices.any {
                it.id?.contains(packageName, ignoreCase = true) == true &&
                it.id?.contains("ZaraAccessibilityService", ignoreCase = true) == true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun openAccessibilitySettings() {        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }
    }

    private fun getWrongPasswordCount(): Int {
        return try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.getInt(KEY_WRONG_PASSWORD_COUNT, 0)
        } catch (e: Exception) {
            0
        }
    }

    private fun incrementWrongPasswordCount(): Int {
        return try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val current = prefs.getInt(KEY_WRONG_PASSWORD_COUNT, 0)
            val newCount = current + 1
            prefs.edit().putInt(KEY_WRONG_PASSWORD_COUNT, newCount).apply()
            newCount
        } catch (e: Exception) {
            0
        }
    }

    private fun resetWrongPasswordCount() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putInt(KEY_WRONG_PASSWORD_COUNT, 0).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Reset error: ${e.message}")
        }
    }

    private fun sendGuardianEvent(type: String, data: Map<String, Any>) {
        val event = mapOf(
            "type" to type,
            "data" to data,
            "timestamp" to System.currentTimeMillis()
        )
        accessibilityChannel?.invokeMethod("onSecurityEvent", event)    }

    fun checkPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
               android.content.pm.PackageManager.PERMISSION_GRANTED
    }
}
