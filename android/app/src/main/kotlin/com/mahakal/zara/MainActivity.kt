package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// MainActivity.kt — Z.A.R.A. v8.0
//
// ✅ FIX: Engine attach race condition — AccessibilityService might connect
//         AFTER configureFlutterEngine(). Now we handle both orderings:
//         (a) Service already up when Activity starts → attach immediately
//         (b) Service connects AFTER Activity → service calls attachToEngine()
//
// ✅ NEW: "getScreenContext" on main channel — Flutter can request live
//         screen text without going through the accessibility sub-channel
//
// ✅ NEW: "checkAllPermissions" — returns a map of all critical permission
//         states in one call so Flutter can show a unified permission guard
//
// ✅ All existing channels and methods preserved
// ══════════════════════════════════════════════════════════════════════════════

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_MAIN  = "com.mahakal.zara/main"
        private const val CHANNEL_ACC   = "com.mahakal.zara/accessibility"
        private const val CHANNEL_NOTIF = "com.mahakal.zara/notifications"
        private const val CHANNEL_FG    = "com.mahakal.zara/foreground"
        private const val PREFS         = "zara_guardian_prefs"
        private const val KEY_COUNT     = "wrong_password_count"
    }

    // ── Keep a reference so the Accessibility Service can call back into it
    //    when it connects AFTER the engine is already configured.
    private var flutterEngine: FlutterEngine? = null

    // ══════════════════════════════════════════════════════════════════════════
    // ENGINE CONFIGURATION
    // ══════════════════════════════════════════════════════════════════════════

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        flutterEngine = engine

        // ── 1. Accessibility Service — attach if already running ──────────────
        //    If ZaraAccessibilityService connected before this Activity,
        //    attach now. Otherwise the service will call attachToEngine()
        //    from onServiceConnected() using the stored engine reference.
        val accSvc = ZaraAccessibilityService.instance
        if (accSvc != null) {
            accSvc.attachToEngine(engine)
        }
        // Store engine so service can attach later if it connects after us
        ZaraAccessibilityService.pendingEngine = engine

        // ── 2. Notification Listener channel ─────────────────────────────────
        ZaraNotificationService.methodChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger, CHANNEL_NOTIF)

        // ── 3. Foreground Service channel ─────────────────────────────────────
        ZaraForegroundService.methodChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger, CHANNEL_FG)

        // ── 4. Auto-start foreground service ──────────────────────────────────
        ZaraForegroundService.start(this)

        // ── 5. Main control channel ────────────────────────────────────────────
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_MAIN)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Guardian prefs ────────────────────────────────────────
                    "getWrongPasswordCount" ->
                        result.success(
                            getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                                .getInt(KEY_COUNT, 0))

                    "resetWrongPasswordCount" -> {
                        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            .edit().putInt(KEY_COUNT, 0).apply()
                        result.success(true)
                    }

                    // ── Accessibility ─────────────────────────────────────────
                    "checkAccessibilityEnabled" ->
                        result.success(isAccessibilityEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        })
                        result.success(true)
                    }

                    // ── Notification listener ─────────────────────────────────
                    "checkNotificationListenerEnabled" ->
                        result.success(ZaraNotificationService.isEnabled(this))

                    "openNotificationListenerSettings" -> {
                        ZaraNotificationService.openSettings(this)
                        result.success(true)
                    }

                    // ── Foreground Service ────────────────────────────────────
                    "startForegroundService" -> {
                        ZaraForegroundService.start(this)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        ZaraForegroundService.stop(this)
                        result.success(true)
                    }

                    // ── Orb control ───────────────────────────────────────────
                    "showOrb" -> {
                        ZaraForegroundService.instance?.showOrb(
                            call.argument<String>("state") ?: "idle")
                        result.success(true)
                    }
                    "hideOrb" -> {
                        ZaraForegroundService.instance?.hideOrb()
                        result.success(true)
                    }
                    "updateOrb" -> {
                        ZaraForegroundService.instance?.updateOrbState(
                            call.argument<String>("state") ?: "idle")
                        result.success(true)
                    }

                    // Audio amplitude → orb pulse reacts to Zara's voice level
                    "updateOrbAmplitude" -> {
                        val amp = (call.argument<Double>("amplitude") ?: 0.0).toFloat()
                        ZaraForegroundService.instance?.updateOrbAmplitude(amp)
                        result.success(true)
                    }

                    // ── Overlay permission ────────────────────────────────────
                    "checkOverlayPermission" ->
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                            Settings.canDrawOverlays(this))

                    "openOverlaySettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                ).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
                            )
                        }
                        result.success(true)
                    }

                    // ── NEW: Screen context (God Mode vision) ─────────────────
                    // Flutter calls this to get all visible text on screen.
                    // ZaraProvider passes it to Gemini for contextual answers.
                    "getScreenContext" -> {
                        val ctx = ZaraAccessibilityService.instance?.getScreenContextPublic()
                            ?: ""
                        result.success(ctx)
                    }

                    // ── NEW: Unified permission status map ────────────────────
                    // Returns all critical permissions in one call.
                    // Flutter PermissionGuard reads this on startup.
                    "checkAllPermissions" -> {
                        result.success(mapOf(
                            "accessibility"        to isAccessibilityEnabled(),
                            "overlay"              to (Build.VERSION.SDK_INT < Build.VERSION_CODES.M
                                                       || Settings.canDrawOverlays(this)),
                            "notificationListener" to ZaraNotificationService.isEnabled(this),
                            "foregroundService"    to (ZaraForegroundService.instance != null),
                        ))
                    }

                    else -> result.notImplemented()
                }
            }

        // ── 6. Accessibility sub-channel fallback ──────────────────────────────
        //    Handles direct calls to the accessibility channel when the service
        //    is not yet attached to the engine (e.g. very first launch).
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_ACC)
            .setMethodCallHandler { call, result ->
                val svc = ZaraAccessibilityService.instance

                when (call.method) {
                    "isEnabled" ->
                        result.success(svc != null && isAccessibilityEnabled())

                    // MainActivity-level openApp fallback — works even without
                    // accessibility service (just launches the app normally)
                    "openApp" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        try {
                            val i = packageManager.getLaunchIntentForPackage(pkg)
                            if (i != null) {
                                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(i)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    // All other accessibility commands go to the service
                    else -> svc?.handleMethodCall(call, result) ?: result.success(false)
                }
            }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE — clean up pending engine reference
    // ══════════════════════════════════════════════════════════════════════════

    override fun onDestroy() {
        super.onDestroy()
        // Clear pending engine so service doesn't try to attach to a dead engine
        if (ZaraAccessibilityService.pendingEngine === flutterEngine) {
            ZaraAccessibilityService.pendingEngine = null
        }
        flutterEngine = null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    private fun isAccessibilityEnabled(): Boolean {
        return try {
            val mgr = getSystemService(Context.ACCESSIBILITY_SERVICE)
                    as android.view.accessibility.AccessibilityManager
            mgr.getEnabledAccessibilityServiceList(
                android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK
            ).any { it.resolveInfo.serviceInfo.packageName == packageName }
        } catch (e: Exception) {
            false
        }
    }
}
