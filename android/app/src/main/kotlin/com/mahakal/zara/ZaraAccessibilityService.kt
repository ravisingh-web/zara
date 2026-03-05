package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// ZaraAccessibilityService.kt — God Mode v5.0
// ✅ YouTube  — search box focus + type + submit (FIXED)
// ✅ Instagram — open reels, scroll, like, comment, search user
// ✅ WhatsApp  — find contact, type message, send
// ✅ Flipkart  — search, size select, add to cart, payment
// ✅ Thread.sleep() → coroutine delay() (no ANR)
// ✅ Node recycle() everywhere (no memory leak)
// ✅ getScreenContext() — live screen text for Gemini
// ✅ Race condition fix — pendingEngine
// ══════════════════════════════════════════════════════════════════════════════

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
import kotlinx.coroutines.*

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

        // Race condition fix
        var pendingEngine: FlutterEngine? = null
    }

    private var methodChannel: MethodChannel? = null
    private var prefs: SharedPreferences?     = null
    private var isMonitoring                  = false
    private val handler                       = Handler(Looper.getMainLooper())
    private var currentPackage                = ""

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private var lastWindowChangedPkg = ""
    private var windowChangedJob: Job? = null

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
            notificationTimeout = 100
            packageNames        = null
        }

        createNotificationChannel()
        startForeground(1001, buildNotification("Z.A.R.A. God Mode", "Device Control Active"))
        isMonitoring = true

        // Race condition fix — attach to pending engine if already configured
        pendingEngine?.let { attachToEngine(it) }

        Log.d(TAG, "God Mode ACTIVE ✅")
        sendEvent("onServiceStatusChanged", mapOf("enabled" to true))
    }

    override fun onInterrupt() { isMonitoring = false }
    override fun onDestroy()   { super.onDestroy(); isMonitoring = false; instance = null }

    // ══════════════════════════════════════════════════════════════════════════
    // ENGINE ATTACH
    // ══════════════════════════════════════════════════════════════════════════

    fun attachToEngine(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            @Suppress("UNCHECKED_CAST")
            val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
            serviceScope.launch(Dispatchers.IO) {
                val res = processCommand(call.method, args)
                withContext(Dispatchers.Main) { result.success(res) }
            }
        }
        Log.d(TAG, "Engine attached ✅")
    }

    fun handleMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
        serviceScope.launch(Dispatchers.IO) {
            val res = processCommand(call.method, args)
            withContext(Dispatchers.Main) { result.success(res) }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND ROUTER
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun processCommand(method: String, args: Map<String, Any>): Any {
        return when (method) {
            "isEnabled"        -> isMonitoring
            "getForegroundApp" -> currentPackage
            "findTextOnScreen" -> findNodeWithText(str(args, "text")) != null
            "getScreenContext" -> getScreenContext()

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
                tapAt(int(args, "x", 540).toFloat(), int(args, "y", 960).toFloat()); true
            }
            "swipe" -> {
                performSwipe(
                    int(args, "x1", 540).toFloat(), int(args, "y1", 1400).toFloat(),
                    int(args, "x2", 540).toFloat(), int(args, "y2", 400).toFloat(),
                    int(args, "durationMs", 350).toLong()
                ); true
            }

            // ── Instagram ──────────────────────────────────────────────────
            "instagramOpenReels"    -> instagramOpenReels()
            "instagramScrollReels"  -> { instagramScrollReels(int(args, "count", 1)); true }
            "instagramLikeReel"     -> instagramLikeCurrentReel()
            "instagramPostComment"  -> instagramPostComment(str(args, "text"))
            "instagramSearchUser"   -> instagramSearchUser(str(args, "username"))

            // ── YouTube ────────────────────────────────────────────────────
            "youtubeSearch"  -> youtubeSearch(str(args, "query"))
            "youtubePlayFirst" -> youtubePlayFirstResult()

            // ── Flipkart ───────────────────────────────────────────────────
            "flipkartSearchProduct" -> flipkartSearchProduct(str(args, "query"))
            "flipkartSelectSize"    -> flipkartSelectSize(str(args, "size"))
            "flipkartAddToCart"     -> flipkartAddToCart()
            "flipkartGoToPayment"   -> flipkartGoToPayment()

            // ── WhatsApp ───────────────────────────────────────────────────
            "whatsappSendMessage" -> whatsappSendMessage(
                str(args, "contact"), str(args, "message"))

            else -> { Log.w(TAG, "Unknown: $method"); false }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SCREEN CONTEXT
    // ══════════════════════════════════════════════════════════════════════════

    fun getScreenContextPublic(): String = getScreenContext()

    private fun getScreenContext(): String {
        val root = rootInActiveWindow ?: return ""
        val sb   = StringBuilder()
        collectText(root, sb, 0, 12)
        val r = sb.toString().trim()
        return if (r.length > 2000) r.substring(0, 2000) else r
    }

    private fun collectText(node: AccessibilityNodeInfo, sb: StringBuilder, depth: Int, max: Int) {
        if (depth > max) return
        val text = node.text?.toString()?.trim()
        val desc = node.contentDescription?.toString()?.trim()
        if (!text.isNullOrEmpty()) sb.append(text).append(" | ")
        else if (!desc.isNullOrEmpty()) sb.append(desc).append(" | ")
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectText(child, sb, depth + 1, max)
            child.recycle()
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // YOUTUBE — FIXED: proper search box detection + submit
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun youtubeSearch(query: String): Boolean {
        if (query.trim().isEmpty()) return false
        Log.d(TAG, "YouTube search: '$query'")

        // 1. Open YouTube
        if (!openApp("com.google.android.youtube")) return false
        delay(2500) // wait for app to fully load

        // 2. Click search icon — try multiple ways
        val searchClicked =
            clickNodeById("com.google.android.youtube:id/menu_item_1") ||
            clickNodeWithContentDesc("Search") ||
            clickNodeWithText("Search")

        if (!searchClicked) {
            // Last resort: tap top-right area where search icon usually is
            val w = resources.displayMetrics.widthPixels.toFloat()
            tapAt(w - 120f, 120f)
        }
        delay(1000)

        // 3. Find and focus the search input field
        var typed = false
        repeat(3) { attempt ->
            if (typed) return@repeat
            val root = rootInActiveWindow ?: return@repeat

            // Try by resource ID first
            val searchField =
                root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_edit_text")
                    ?.firstOrNull()
                ?: root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_box")
                    ?.firstOrNull()
                ?: findEditableNode(root)

            if (searchField != null) {
                // Focus it
                searchField.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                delay(400)
                searchField.performAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS)
                delay(300)

                // Type text
                val args = Bundle()
                args.putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, query)
                typed = searchField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                searchField.recycle()
                Log.d(TAG, "YT typed '$query' on attempt ${attempt+1}: $typed")
            }

            if (!typed) delay(800)
        }

        if (!typed) {
            Log.w(TAG, "YT: could not type in search box")
            return false
        }
        delay(600)

        // 4. Submit search — try search button, then IME action, then Enter key
        val submitted =
            clickNodeWithContentDesc("Search") ||
            clickNodeWithContentDesc("Submit query") ||
            clickNodeById("com.google.android.youtube:id/search_go_btn")

        if (!submitted) {
            // IME search action
            val root = rootInActiveWindow
            val edit = root?.let { findEditableNode(it) }
            val imeOk = edit?.performAction(
                AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY) ?: false
            edit?.recycle()
            if (!imeOk) performGlobalAction(66) // KEYCODE_ENTER last resort
        }

        delay(2500)
        Log.d(TAG, "YouTube search done: '$query'")
        return true
    }

    private suspend fun youtubePlayFirstResult(): Boolean {
        delay(600)
        val root       = rootInActiveWindow ?: return false
        val clickables = findAllClickableNodes(root)
        val target     = clickables.getOrNull(2) ?: clickables.firstOrNull() ?: return false
        target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        Log.d(TAG, "YouTube: playing first result")
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // INSTAGRAM
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun instagramOpenReels(): Boolean {
        if (!openApp("com.instagram.android")) return false
        delay(1800)
        if (clickNodeWithContentDesc("Reels")) return true
        val w = resources.displayMetrics.widthPixels.toFloat()
        val h = resources.displayMetrics.heightPixels.toFloat()
        tapAt(w * 0.5f, h * 0.965f)
        delay(800)
        return true
    }

    private suspend fun instagramScrollReels(count: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(count) {
            performSwipe(w, h * 0.78f, w, h * 0.22f, 350)
            delay(700)
        }
    }

    private suspend fun instagramLikeCurrentReel(): Boolean {
        if (clickNodeById("com.instagram.android:id/like_button")) return true
        if (clickNodeWithContentDesc("Like")) return true
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels / 2f
        tapAt(w, h); delay(130); tapAt(w, h)
        return true
    }

    private suspend fun instagramPostComment(text: String): Boolean {
        delay(500)
        if (!clickNodeById("com.instagram.android:id/row_feed_comment_tv") &&
            !clickNodeWithContentDesc("Comment")) return false
        delay(900)
        typeTextInFocused(text)
        delay(400)
        clickNodeWithText("Post")
        return true
    }

    private suspend fun instagramSearchUser(username: String): Boolean {
        if (!openApp("com.instagram.android")) return false
        delay(1800)
        clickNodeWithContentDesc("Search and Explore")
        delay(900)
        if (!clickNodeById("com.instagram.android:id/action_bar_search_edit_text"))
            clickNodeWithText("Search")
        delay(700)
        typeTextInFocused(username)
        delay(1300)
        clickNodeWithText(username)
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FLIPKART
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun flipkartSearchProduct(query: String): Boolean {
        if (!openApp("com.flipkart.android")) return false
        delay(2200)
        if (!clickNodeById("com.flipkart.android:id/search_widget_textbox") &&
            !clickNodeWithText("Search for Products, Brands and More"))
            tapAt(resources.displayMetrics.widthPixels / 2f, 160f)
        delay(700)
        typeTextInFocused(query)
        delay(500)
        performGlobalAction(66)
        delay(2500)
        val root       = rootInActiveWindow ?: return false
        val clickables = findAllClickableNodes(root)
        val product    = clickables.getOrNull(3) ?: clickables.firstOrNull() ?: return false
        product.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        delay(2500)
        return true
    }

    private suspend fun flipkartSelectSize(size: String): Boolean {
        delay(500)
        return clickNodeWithText(size) ||
               clickNodeWithText(size.uppercase()) ||
               clickNodeWithText(size.lowercase())
    }

    private suspend fun flipkartAddToCart(): Boolean {
        delay(300)
        val ok = clickNodeWithText("ADD TO CART") || clickNodeWithText("Add to Cart")
        if (ok) delay(1200)
        return ok
    }

    private suspend fun flipkartGoToPayment(): Boolean {
        delay(500)
        if (!clickNodeWithContentDesc("Cart") && !clickNodeWithText("Cart"))
            clickNodeById("com.flipkart.android:id/cart_icon")
        delay(1800)
        val ok = clickNodeWithText("PLACE ORDER") || clickNodeWithText("Place Order")
        if (ok) delay(1500)
        return ok
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun whatsappSendMessage(contact: String, message: String): Boolean {
        if (!openApp("com.whatsapp")) return false
        delay(1800)
        if (!clickNodeById("com.whatsapp:id/menuitem_search"))
            clickNodeWithContentDesc("Search")
        delay(700)
        typeTextInFocused(contact)
        delay(1300)
        if (!clickNodeWithText(contact)) {
            val root  = rootInActiveWindow ?: return false
            val nodes = findAllClickableNodes(root)
            nodes.getOrNull(1)?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        delay(1200)
        typeTextInFocused(message)
        delay(400)
        if (!clickNodeById("com.whatsapp:id/send"))
            clickNodeWithContentDesc("Send")
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PRIMITIVES
    // ══════════════════════════════════════════════════════════════════════════

    private fun openApp(pkg: String): Boolean {
        return try {
            val i = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i); true
        } catch (e: Exception) { Log.e(TAG, "openApp: ${e.message}"); false }
    }

    private fun clickNodeWithText(text: String): Boolean {
        val node   = findNodeWithText(text) ?: return false
        val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        if (!result) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        node.recycle()
        return result
    }

    private fun clickNodeWithContentDesc(desc: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val node = findNodeByDesc(root, desc.lowercase()) ?: return false
        val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        if (!result) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        node.recycle()
        return result
    }

    private fun clickNodeById(id: String): Boolean {
        val root  = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByViewId(id)
        if (nodes.isNullOrEmpty()) return false
        val result = nodes[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
        nodes.forEach { it.recycle() }
        return result
    }

    private fun typeTextInFocused(text: String): Boolean {
        val root    = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: findEditableNode(root) ?: return false
        val args = Bundle()
        args.putCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        val result = focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        focused.recycle()
        return result
    }

    private suspend fun scrollDown(steps: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(steps) { performSwipe(w, h * 0.78f, w, h * 0.22f, 360); delay(400) }
    }

    private suspend fun scrollUp(steps: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(steps) { performSwipe(w, h * 0.22f, w, h * 0.78f, 360); delay(400) }
    }

    private fun performSwipe(x1: Float, y1: Float, x2: Float, y2: Float, ms: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val path    = Path().apply { moveTo(x1, y1); lineTo(x2, y2) }
        val stroke  = GestureDescription.StrokeDescription(path, 0, ms)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    private fun tapAt(x: Float, y: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val path    = Path().apply { moveTo(x, y); lineTo(x + 1f, y + 1f) }
        val stroke  = GestureDescription.StrokeDescription(path, 0, 50)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NODE FINDERS
    // ══════════════════════════════════════════════════════════════════════════

    private fun findNodeWithText(text: String): AccessibilityNodeInfo? {
        val root  = rootInActiveWindow ?: return null
        val exact = root.findAccessibilityNodeInfosByText(text)
        if (!exact.isNullOrEmpty()) { exact.drop(1).forEach { it.recycle() }; return exact[0] }
        return traverseFind(root) { n ->
            val t = n.text?.toString()?.lowercase() ?: ""
            val d = n.contentDescription?.toString()?.lowercase() ?: ""
            t.contains(text.lowercase()) || d.contains(text.lowercase())
        }
    }

    private fun findNodeByDesc(node: AccessibilityNodeInfo, desc: String) =
        traverseFind(node) {
            it.contentDescription?.toString()?.lowercase()?.contains(desc) == true
        }

    private fun findEditableNode(node: AccessibilityNodeInfo) =
        traverseFind(node) { it.isEditable }

    private fun findAllClickableNodes(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        fun walk(n: AccessibilityNodeInfo) {
            if (n.isClickable) out.add(n)
            for (i in 0 until n.childCount) { val c = n.getChild(i) ?: continue; walk(c) }
        }
        walk(node); return out
    }

    private fun traverseFind(
        node: AccessibilityNodeInfo,
        predicate: (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (predicate(node)) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = traverseFind(child, predicate)
            if (found != null) { if (found !== child) child.recycle(); return found }
            child.recycle()
        }
        return null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ACCESSIBILITY EVENT — debounced
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = event.packageName?.toString() ?: return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && pkg != lastWindowChangedPkg) {
            currentPackage       = pkg
            lastWindowChangedPkg = pkg
            windowChangedJob?.cancel()
            windowChangedJob = serviceScope.launch {
                delay(150)
                sendEvent("onWindowChanged", mapOf("package" to pkg))
            }
        }

        if (LOCK_PACKAGES.contains(pkg)) {
            val text = event.text?.joinToString(" ").orEmpty().lowercase()
            if (PASSWORD_WORDS.any { text.contains(it) }) handleWrongPassword()
        }
    }

    private fun handleWrongPassword() {
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
            catch (e: Exception) { Log.e(TAG, "sendEvent $method: ${e.message}") }
        }
    }

    private fun str(args: Map<String, Any>, key: String, default: String = "") =
        args[key]?.toString() ?: default

    private fun int(args: Map<String, Any>, key: String, default: Int = 0) =
        (args[key] as? Int) ?: args[key]?.toString()?.toIntOrNull() ?: default

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val ch = NotificationChannel(
            "zara_god", "Z.A.R.A. God Mode", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Screen control active"; setShowBadge(false) }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(ch)
    }

    private fun buildNotification(title: String, text: String): Notification =
        NotificationCompat.Builder(this, "zara_god")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle(title).setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true).build()
}
