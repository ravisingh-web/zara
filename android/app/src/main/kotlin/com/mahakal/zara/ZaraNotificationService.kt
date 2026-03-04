package com.mahakal.zara

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel

// Z.A.R.A. — Notification Listener
// Proactive: WhatsApp/Gmail sun ke Flutter ko batao
// "Sir, Rohit ka message aaya hai, kya reply karoon?"

class ZaraNotificationService : NotificationListenerService() {

    companion object {
        const val TAG     = "ZARA_NOTIF"
        const val CHANNEL = "com.mahakal.zara/notifications"
        var instance: ZaraNotificationService? = null
            private set
        var methodChannel: MethodChannel? = null

        fun isEnabled(context: android.content.Context): Boolean {
            val cn   = android.content.ComponentName(context, ZaraNotificationService::class.java)
            val flat = android.provider.Settings.Secure.getString(
                context.contentResolver, "enabled_notification_listeners") ?: return false
            return flat.contains(cn.flattenToString())
        }

        fun openSettings(context: android.content.Context) {
            val intent = android.content.Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        }

        val WATCHED_APPS = mapOf(
            "com.whatsapp"              to "WhatsApp",
            "com.whatsapp.w4b"          to "WhatsApp Business",
            "com.google.android.gm"     to "Gmail",
            "com.instagram.android"     to "Instagram",
            "org.telegram.messenger"    to "Telegram",
            "com.google.android.apps.messaging" to "SMS",
            "com.samsung.android.messaging"     to "SMS",
        )
    }

    private val handler          = Handler(Looper.getMainLooper())
    private val lastNotifTime    = mutableMapOf<String, Long>()
    private val COOLDOWN_MS      = 30_000L

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "✅ ZaraNotificationService started")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg     = sbn.packageName ?: return
        val appName = WATCHED_APPS[pkg] ?: return

        // Spam cooldown
        val now = System.currentTimeMillis()
        if (now - (lastNotifTime[pkg] ?: 0L) < COOLDOWN_MS) return
        lastNotifTime[pkg] = now

        val extras  = sbn.notification?.extras ?: return
        val title   = extras.getCharSequence("android.title")?.toString() ?: ""
        val text    = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: text

        if (title.isEmpty() && text.isEmpty()) return

        val preview    = if (bigText.length > 60) "${bigText.take(60)}..." else bigText
        val senderName = extractName(title)
        val zaraAlert  = buildAlert(appName, pkg, senderName, preview, title)

        Log.d(TAG, "📱 $appName | $title: $text")

        handler.post {
            methodChannel?.invokeMethod("onProactiveNotification", mapOf(
                "app"       to appName,
                "package"   to pkg,
                "title"     to title,
                "text"      to text,
                "zaraAlert" to zaraAlert,
                "timestamp" to now,
            ))
        }
    }

    private fun buildAlert(app: String, pkg: String, sender: String, preview: String, title: String): String {
        return when (pkg) {
            "com.whatsapp", "com.whatsapp.w4b" ->
                if (sender.isNotEmpty())
                    "Sir, $sender ka WhatsApp message aaya — \"$preview\" — kya reply karoon?"
                else "Sir, WhatsApp pe nayi message aayi. Dekhein?"
            "com.google.android.gm" ->
                "Sir, Gmail mein nayi email aayi${if (title.isNotEmpty()) " — $title" else ""}. Padhoon?"
            "org.telegram.messenger" ->
                "Sir, Telegram pe ${if (sender.isNotEmpty()) "$sender ka" else "ek"} message aaya. Reply dena hai?"
            else ->
                "Sir, $app pe notification — ${if (title.isNotEmpty()) title else preview}."
        }
    }

    private fun extractName(title: String): String {
        if (title.isEmpty() || title.length > 40) return ""
        // "Name @ Group" format
        val g = Regex("^(.+?)\\s*@\\s*.+$").find(title)
        return g?.groupValues?.getOrNull(1)?.trim() ?: title.trim()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {}
}
