package com.mahakal.zara

import android.content.Context
import android.content.Intent
import android.os.Bundle
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
        private const val TAG          = "ZARA_MAIN"
        private const val CHANNEL_MAIN = "com.mahakal.zara/main"
        private const val CHANNEL_ACC  = "com.mahakal.zara/accessibility"
        private const val PREFS        = "zara_guardian_prefs"
        private const val KEY_COUNT    = "wrong_password_count"
    }

    private var mainChannel : MethodChannel? = null
    private var accChannel  : MethodChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // ── Channel 1: Main (password count, accessibility check) ────────────
        mainChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_MAIN)
        mainChannel?.setMethodCallHandler { call, result ->
            when (call.method) {

                "getWrongPasswordCount" -> {
                    val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    result.success(prefs.getInt(KEY_COUNT, 0))
                }
                "incrementWrongPasswordCount" -> {
                    val prefs   = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val newCount = prefs.getInt(KEY_COUNT, 0) + 1
                    prefs.edit().putInt(KEY_COUNT, newCount).apply()
                    result.success(newCount)
                }
                "resetWrongPasswordCount" -> {
                    val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    prefs.edit().putInt(KEY_COUNT, 0).apply()
                    result.success(true)
                }
                "checkAccessibilityEnabled" -> {
                    result.success(isAccessibilityEnabled())
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── Channel 2: Accessibility / God Mode ──────────────────────────────
        // If service already running → attach engine to it
        ZaraAccessibilityService.instance?.attachToEngine(engine)

        // Also set up fallback handler on this channel for when service
        // is not yet running (openApp via PackageManager, openSettings)
        accChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_ACC)
        accChannel?.setMethodCallHandler { call, result ->
            val service = ZaraAccessibilityService.instance

            when (call.method) {

                "isEnabled" -> {
                    result.success(service != null && isAccessibilityEnabled())
                }

                // Fallback app opener — works even without accessibility service
                "openApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    try {
                        val intent = packageManager.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "openApp fallback error: ${e.message}")
                        result.success(false)
                    }
                }

                "openSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                // All other calls → delegate to running service
                else -> {
                    if (service != null) {
                        // Service has its own channel handler — just ack
                        result.success(null)
                    } else {
                        result.error(
                            "SERVICE_NOT_RUNNING",
                            "Accessibility Service nahi chal rahi. Settings mein enable karein.",
                            null
                        )
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Re-attach if service started after activity
        flutterEngine?.let { engine ->
            ZaraAccessibilityService.instance?.attachToEngine(engine)
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
        val services = am?.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )
        return services?.any { it.id?.contains(packageName) == true } ?: false
    }

    fun checkPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }
}
