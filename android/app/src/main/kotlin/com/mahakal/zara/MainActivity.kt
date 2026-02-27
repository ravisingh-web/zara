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
        private const val CHANNEL = "com.mahakal.zara/main"
        private const val PREFS = "zara_guardian_prefs"
        private const val KEY_COUNT = "wrong_password_count"
    }

    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getWrongPasswordCount" -> {
                    val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val count = prefs.getInt(KEY_COUNT, 0)
                    result.success(count)
                }
                "incrementWrongPasswordCount" -> {
                    val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val current = prefs.getInt(KEY_COUNT, 0)
                    val newCount = current + 1
                    prefs.edit().putInt(KEY_COUNT, newCount).apply()
                    result.success(newCount)
                }
                "resetWrongPasswordCount" -> {
                    val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    prefs.edit().putInt(KEY_COUNT, 0).apply()
                    result.success(true)
                }
                "checkAccessibilityEnabled" -> {
                    val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
                    val services = am?.getEnabledAccessibilityServiceList(
                        AccessibilityServiceInfo.FEEDBACK_GENERIC
                    )
                    val enabled = services?.any { it.id?.contains(packageName) == true } ?: false
                    result.success(enabled)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun checkPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }
}

