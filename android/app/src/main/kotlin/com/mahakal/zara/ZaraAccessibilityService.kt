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
import java.util.concurrent.Executors

// ══════════════════════════════════════════════════════════════════════════════
// Z.A.R.A. God Mode Accessibility Service v3.0
// Full autonomous device control:
//   Instagram — scroll reels, like, comment, search
//   Flipkart  — search product, select size, add to cart, go to payment
//   WhatsApp  — open contact, send message
//   YouTube   — search, play first result
// ══════════════════════════════════════════════════════════════════════════════

class ZaraAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG     = "ZARA_GOD"
        const val CHANNEL = "com.mahakal.zara/accessibility"

        private const val PREFS     = "zara_guardian_prefs"
        private const val KEY_COUNT = "wrong_password_count"
        private const val KEY_LAST  = "last_password_attempt"
        private const val THRESHOLD = 2

        private val LOCK_PACKAGES  = setOf("com.android.systemui", "com.android.keyguard")
        private val PASSWORD_WORDS = setOf("wrong", "incorrect", "invalid", "error")

        var instance: ZaraAccessibilityService? = null
            private set
    }

    private var methodChannel: MethodChannel? = null
    private var prefs: SharedPreferences?     = null
    private var isMonitoring                  = false
    private val handler                       = Handler(Looper.getMainLooper())
    private val executor                      = Executors.newSingleThreadExecutor()
    private var currentPackage                = ""

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        prefs    = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED   or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_CLICKED           or
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED      or
                AccessibilityEvent.TYPE_VIEW_SCROLLED          or
                AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
            feedbackType        = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags               =
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS             or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 50
            packageNames        = null
        }

        createNotificationChannel()
        startForeground(1001, buildNotification("Z.A.R.A. God Mode", "Device Control Active"))
        isMonitoring = true
        Log.d(TAG, "God Mode ACTIVE")
        sendEvent("onServiceStatusChanged", mapOf("enabled" to true))
    }

    override fun onInterrupt() { isMonitoring = false; instance = null }
    override fun onDestroy()   { super.onDestroy(); instance = null }

    // ══════════════════════════════════════════════════════════════════════════
    // FLUTTER ENGINE ATTACH
    // ══════════════════════════════════════════════════════════════════════════

    fun attachToEngine(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            executor.execute {
                @Suppress("UNCHECKED_CAST")
                val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
                val res  = processCommand(call.method, args)
                handler.post { result.success(res) }
            }
        }
        Log.d(TAG, "Engine attached")
    }

    fun handleMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        executor.execute {
            @Suppress("UNCHECKED_CAST")
            val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
            val res  = processCommand(call.method, args)
            handler.post { result.success(res) }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND ROUTER
    // ══════════════════════════════════════════════════════════════════════════

    private fun processCommand(method: String, args: Map<String, Any>): Any {
        return when (method) {
            // Status
            "isEnabled"        -> isMonitoring
            "getForegroundApp" -> currentPackage
            "findTextOnScreen" -> findNodeWithText(str(args, "text")) != null

            // Basic
            "openApp"           -> openApp(str(args, "package"))
            "clickText"         -> clickNodeWithText(str(args, "text"))
            "clickById"         -> clickNodeById(str(args, "id"))
            "typeText"          -> typeTextInFocused(str(args, "text"))
            "scrollDown"        -> { scrollDown(int(args, "steps", 3)); true }
            "scrollUp"          -> { scrollUp(int(args, "steps", 3)); true }
            "pressBack"         -> { performGlobalAction(GLOBAL_ACTION_BACK); true }
            "pressHome"         -> { performGlobalAction(GLOBAL_ACTION_HOME); true }
            "pressRecents"      -> { performGlobalAction(GLOBAL_ACTION_RECENTS); true }
            "takeScreenshot"    -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT); true }
            "openNotifications" -> { performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS); true }
            "openQuickSettings" -> { performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS); true }
            "tapAt" -> {
                tapAt(int(args, "x", 540).toFloat(), int(args, "y", 960).toFloat())
                true
            }
            "swipe" -> {
                performSwipe(
                    int(args, "x1", 540).toFloat(), int(args, "y1", 1400).toFloat(),
                    int(args, "x2", 540).toFloat(), int(args, "y2", 400).toFloat(),
                    int(args, "durationMs", 350).toLong()
                )
                true
            }

            // High-level flows
            "instagramOpenReels"    -> instagramOpenReels()
            "instagramScrollReels"  -> { instagramScrollReels(int(args, "count", 1)); true }
            "instagramLikeReel"     -> instagramLikeCurrentReel()
            "instagramPostComment"  -> instagramPostComment(str(args, "text"))
            "instagramSearchUser"   -> instagramSearchUser(str(args, "username"))
            "flipkartSearchProduct" -> flipkartSearchProduct(str(args, "query"))
            "flipkartSelectSize"    -> flipkartSelectSize(str(args, "size"))
            "flipkartAddToCart"     -> flipkartAddToCart()
            "flipkartGoToPayment"   -> flipkartGoToPayment()
            "whatsappSendMessage"   -> whatsappSendMessage(str(args, "contact"), str(args, "message"))
            "youtubeSearch"         -> youtubeSearch(str(args, "query"))
            "youtubePlayFirst"      -> youtubePlayFirstResult()

            else -> { Log.w(TAG, "Unknown: $method"); false }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // INSTAGRAM FLOWS
    // ══════════════════════════════════════════════════════════════════════════

    private fun instagramOpenReels(): Boolean {
        if (!openApp("com.instagram.android")) return false
        sleep(1800)
        if (clickNodeWithContentDesc("Reels")) return true
        val w = resources.displayMetrics.widthPixels.toFloat()
        val h = resources.displayMetrics.heightPixels.toFloat()
        tapAt(w * 0.5f, h * 0.965f)
        sleep(800)
        return true
    }

    // Scroll reels — natural upward swipe from 78% to 22% of screen height
    private fun instagramScrollReels(count: Int) {
        val w = resources.displayMetrics.widthPixels.toFloat()
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(count) {
            performSwipe(w / 2f, h * 0.78f, w / 2f, h * 0.22f, 350)
            sleep(700)
        }
        Log.d(TAG, "Scrolled reels x$count")
    }

    // Like reel — try heart button, then double-tap center
    private fun instagramLikeCurrentReel(): Boolean {
        if (clickNodeById("com.instagram.android:id/like_button")) return true
        if (clickNodeWithContentDesc("Like")) return true
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels / 2f
        tapAt(w, h); sleep(130); tapAt(w, h)
        Log.d(TAG, "Liked reel (double-tap)")
        return true
    }

    private fun instagramPostComment(text: String): Boolean {
        sleep(500)
        if (!clickNodeById("com.instagram.android:id/row_feed_comment_tv") &&
            !clickNodeWithContentDesc("Comment")) return false
        sleep(900)
        if (!typeTextInFocused(text)) return false
        sleep(400)
        clickNodeWithText("Post")
        Log.d(TAG, "Commented: $text")
        return true
    }

    private fun instagramSearchUser(username: String): Boolean {
        if (!openApp("com.instagram.android")) return false
        sleep(1800)
        clickNodeWithContentDesc("Search and Explore")
        sleep(900)
        if (!clickNodeById("com.instagram.android:id/action_bar_search_edit_text"))
            clickNodeWithText("Search")
        sleep(700)
        typeTextInFocused(username)
        sleep(1300)
        clickNodeWithText(username)
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FLIPKART SHOPPING FLOW
    // search → open product → select size → add to cart → payment page
    // ══════════════════════════════════════════════════════════════════════════

    private fun flipkartSearchProduct(query: String): Boolean {
        if (!openApp("com.flipkart.android")) return false
        sleep(2200)

        // Open search
        if (!clickNodeById("com.flipkart.android:id/search_widget_textbox") &&
            !clickNodeWithText("Search for Products, Brands and More")) {
            tapAt(resources.displayMetrics.widthPixels / 2f, 160f)
        }
        sleep(700)
        typeTextInFocused(query)
        sleep(500)

        // Submit search
        val editable = findEditableNode(rootInActiveWindow ?: return false)
        performGlobalAction(66) // KEYCODE_ENTER — submit search
        sleep(2500)

        // Tap first non-ad product (usually 3rd clickable)
        val clickables = findAllClickableNodes(rootInActiveWindow ?: return false)
        val product    = clickables.getOrNull(3) ?: clickables.firstOrNull() ?: return false
        product.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        sleep(2500)
        Log.d(TAG, "Flipkart: opened product for '$query'")
        return true
    }

    private fun flipkartSelectSize(size: String): Boolean {
        sleep(500)
        val targets = listOf(size, size.uppercase(), size.lowercase())
        for (t in targets) { if (clickNodeWithText(t)) { Log.d(TAG, "Size selected: $size"); return true } }
        Log.w(TAG, "Size not found: $size")
        return false
    }

    private fun flipkartAddToCart(): Boolean {
        sleep(300)
        val ok = clickNodeWithText("ADD TO CART") || clickNodeWithText("Add to Cart")
        if (ok) { Log.d(TAG, "Added to cart"); sleep(1200) }
        return ok
    }

    private fun flipkartGoToPayment(): Boolean {
        sleep(500)
        if (!clickNodeWithContentDesc("Cart") && !clickNodeWithText("Cart"))
            clickNodeById("com.flipkart.android:id/cart_icon")
        sleep(1800)
        val ok = clickNodeWithText("PLACE ORDER") || clickNodeWithText("Place Order")
        if (ok) { Log.d(TAG, "Going to payment"); sleep(1500) }
        return ok
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP — open chat, send message
    // ══════════════════════════════════════════════════════════════════════════

    private fun whatsappSendMessage(contact: String, message: String): Boolean {
        if (!openApp("com.whatsapp")) return false
        sleep(1800)

        // Search contact
        if (!clickNodeById("com.whatsapp:id/menuitem_search"))
            clickNodeWithContentDesc("Search")
        sleep(700)
        typeTextInFocused(contact)
        sleep(1300)

        // Click contact result
        if (!clickNodeWithText(contact)) {
            val nodes = findAllClickableNodes(rootInActiveWindow ?: return false)
            nodes.getOrNull(1)?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        sleep(1200)

        // Type and send
        typeTextInFocused(message)
        sleep(400)
        if (!clickNodeById("com.whatsapp:id/send"))
            clickNodeWithContentDesc("Send")

        Log.d(TAG, "WhatsApp: sent to $contact")
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // YOUTUBE
    // ══════════════════════════════════════════════════════════════════════════

    private fun youtubeSearch(query: String): Boolean {
        if (!openApp("com.google.android.youtube")) return false
        sleep(1800)
        if (!clickNodeWithContentDesc("Search"))
            clickNodeById("com.google.android.youtube:id/menu_item_1")
        sleep(700)
        typeTextInFocused(query)
        sleep(500)
        val editable = findEditableNode(rootInActiveWindow ?: return false)
        performGlobalAction(66) // KEYCODE_ENTER
        sleep(2200)
        Log.d(TAG, "YouTube search: $query")
        return true
    }

    private fun youtubePlayFirstResult(): Boolean {
        sleep(600)
        val clickables = findAllClickableNodes(rootInActiveWindow ?: return false)
        val target     = clickables.getOrNull(2) ?: clickables.firstOrNull() ?: return false
        target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        Log.d(TAG, "YouTube: playing first result")
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PRIMITIVE ACTIONS
    // ══════════════════════════════════════════════════════════════════════════

    private fun openApp(pkg: String): Boolean {
        if (pkg.isEmpty()) return false
        return try {
            val i = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
            true
        } catch (e: Exception) { Log.e(TAG, "openApp: ${e.message}"); false }
    }

    private fun clickNodeWithText(text: String): Boolean {
        val node = findNodeWithText(text) ?: return false
        return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            .also { if (!it) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) }
    }

    private fun clickNodeWithContentDesc(desc: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val node = findNodeByDesc(root, desc.lowercase()) ?: return false
        return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            .also { if (!it) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) }
    }

    private fun clickNodeById(id: String): Boolean {
        val root  = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByViewId(id)
        return if (nodes.isNullOrEmpty()) false
        else nodes[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    private fun typeTextInFocused(text: String): Boolean {
        val root    = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: findEditableNode(root) ?: return false
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun scrollDown(steps: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(steps) { performSwipe(w, h * 0.78f, w, h * 0.22f, 360); sleep(400) }
    }

    private fun scrollUp(steps: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(steps) { performSwipe(w, h * 0.22f, w, h * 0.78f, 360); sleep(400) }
    }

    private fun performSwipe(x1: Float, y1: Float, x2: Float, y2: Float, ms: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val path    = Path().apply { moveTo(x1, y1); lineTo(x2, y2) }
        val stroke  = GestureDescription.StrokeDescription(path, 0, ms)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(gesture, null, null)
    }

    private fun tapAt(x: Float, y: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val path    = Path().apply { moveTo(x, y); lineTo(x + 1f, y + 1f) }
        val stroke  = GestureDescription.StrokeDescription(path, 0, 50)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(gesture, null, null)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NODE FINDERS
    // ══════════════════════════════════════════════════════════════════════════

    private fun findNodeWithText(text: String): AccessibilityNodeInfo? {
        val root  = rootInActiveWindow ?: return null
        val exact = root.findAccessibilityNodeInfosByText(text)
        if (!exact.isNullOrEmpty()) return exact[0]
        return traverseFind(root) { n ->
            val t = n.text?.toString()?.lowercase() ?: ""
            val d = n.contentDescription?.toString()?.lowercase() ?: ""
            t.contains(text.lowercase()) || d.contains(text.lowercase())
        }
    }

    private fun findNodeByDesc(node: AccessibilityNodeInfo, desc: String): AccessibilityNodeInfo? =
        traverseFind(node) { it.contentDescription?.toString()?.lowercase()?.contains(desc) == true }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? =
        traverseFind(node) { it.isEditable }

    private fun findAllClickableNodes(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        fun walk(n: AccessibilityNodeInfo) {
            if (n.isClickable) out.add(n)
            for (i in 0 until n.childCount) walk(n.getChild(i) ?: return)
        }
        walk(node)
        return out
    }

    private fun traverseFind(
        node: AccessibilityNodeInfo,
        predicate: (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (predicate(node)) return node
        for (i in 0 until node.childCount) {
            val found = traverseFind(node.getChild(i) ?: continue, predicate)
            if (found != null) return found
        }
        return null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ACCESSIBILITY EVENT
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = event.packageName?.toString() ?: return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            currentPackage = pkg
            sendEvent("onWindowChanged", mapOf("package" to pkg))
        }

        if (LOCK_PACKAGES.contains(pkg)) {
            val text = event.text?.joinToString(" ").orEmpty().lowercase()
            if (PASSWORD_WORDS.any { text.contains(it) }) handleWrongPassword(pkg)
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GUARDIAN
    // ══════════════════════════════════════════════════════════════════════════

    private fun handleWrongPassword(pkg: String) {
        val p   = prefs ?: return
        val now = System.currentTimeMillis()
        if (now - p.getLong(KEY_LAST, 0) > 30_000) p.edit().putInt(KEY_COUNT, 0).apply()
        val count = p.getInt(KEY_COUNT, 0) + 1
        p.edit().putInt(KEY_COUNT, count).putLong(KEY_LAST, now).apply()
        sendEvent("onSecurityEvent", mapOf("type" to "wrong_password", "count" to count))
        if (count >= THRESHOLD)
            sendEvent("onSecurityEvent", mapOf("type" to "capture_photo", "count" to count))
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    private fun sendEvent(method: String, data: Map<String, Any>) {
        handler.post {
            try { methodChannel?.invokeMethod(method, data) }
            catch (e: Exception) { Log.e(TAG, "sendEvent: ${e.message}") }
        }
    }

    private fun str(args: Map<String, Any>, key: String, default: String = "") =
        args[key]?.toString() ?: default

    private fun int(args: Map<String, Any>, key: String, default: Int = 0) =
        (args[key] as? Int) ?: (args[key]?.toString()?.toIntOrNull()) ?: default

    private fun sleep(ms: Long) = try { Thread.sleep(ms) } catch (_: InterruptedException) {}

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val ch = NotificationChannel(
            "zara_god", "Z.A.R.A. God Mode", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Device control"; setShowBadge(false) }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(ch)
    }

    private fun buildNotification(title: String, text: String): Notification =
        NotificationCompat.Builder(this, "zara_god")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle(title).setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW).setOngoing(true).build()
}
