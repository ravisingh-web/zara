package com.mahakal.zara

import android.content.Context
import android.content.Intent
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

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // 1. Accessibility Service — God Mode
        ZaraAccessibilityService.instance?.attachToEngine(engine)

        // 2. Notification Listener — Proactive alerts
        ZaraNotificationService.methodChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger, CHANNEL_NOTIF)

        // 3. Foreground Service — Background alive + Orb
        ZaraForegroundService.methodChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger, CHANNEL_FG)

        // 4. Auto-start foreground service
        ZaraForegroundService.start(this)

        // 5. Main control channel
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_MAIN)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWrongPasswordCount" ->
                        result.success(
                            getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_COUNT, 0))

                    "resetWrongPasswordCount" -> {
                        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            .edit().putInt(KEY_COUNT, 0).apply()
                        result.success(true)
                    }

                    "checkAccessibilityEnabled" ->
                        result.success(isAccessibilityEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK })
                        result.success(true)
                    }

                    "checkNotificationListenerEnabled" ->
                        result.success(ZaraNotificationService.isEnabled(this))

                    "openNotificationListenerSettings" -> {
                        ZaraNotificationService.openSettings(this)
                        result.success(true)
                    }

                    "startForegroundService" -> {
                        ZaraForegroundService.start(this); result.success(true) }

                    "stopForegroundService" -> {
                        ZaraForegroundService.stop(this); result.success(true) }

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

                    "checkOverlayPermission" -> result.success(
                        android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M ||
                        android.provider.Settings.canDrawOverlays(this))

                    "openOverlaySettings" -> {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            startActivity(
                                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK })
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // 6. Accessibility channel fallback
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_ACC)
            .setMethodCallHandler { call, result ->
                val svc = ZaraAccessibilityService.instance
                when (call.method) {
                    "isEnabled" -> result.success(svc != null && isAccessibilityEnabled())
                    "openApp" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        try {
                            val i = packageManager.getLaunchIntentForPackage(pkg)
                            if (i != null) {
                                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(i)
                                result.success(true)
                            } else result.success(false)
                        } catch (e: Exception) { result.success(false) }
                    }
                    else -> svc?.handleMethodCall(call, result) ?: result.success(false)
                }
            }
    }

    private fun isAccessibilityEnabled(): Boolean {
        return try {
            val mgr = getSystemService(Context.ACCESSIBILITY_SERVICE)
                    as android.view.accessibility.AccessibilityManager
            mgr.getEnabledAccessibilityServiceList(
                android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK
            ).any { it.resolveInfo.serviceInfo.packageName == packageName }
        } catch (e: Exception) { false }
    }
}
