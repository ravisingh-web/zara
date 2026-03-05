package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// ZaraAccessibilityService.kt — God Mode v4.0
// ✅ FIX: Thread.sleep() removed — coroutine delays (no ANR risk)
// ✅ FIX: rootInActiveWindow null-safety throughout
// ✅ FIX: Node recycling — recycle() called after use (memory leak fix)
// ✅ NEW: getScreenContext() — sends real-time screen text to Flutter
// ✅ NEW: Debounced onWindowChanged — not spamming Flutter on every event
// ✅ All God Mode flows preserved: Instagram, Flipkart, WhatsApp, YouTube
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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

        // Race condition fix: MainActivity stores engine here so service
        // can attach even if it connects after configureFlutterEngine()
        var pendingEngine: FlutterEngine? = null
    }

    // ── Channel + Prefs ────────────────────────────────────────────────────────
    private var methodChannel: MethodChannel? = null
    private var prefs: SharedPreferences?     = null
    private var isMonitoring                  = false
    private val handler                       = Handler(Looper.getMainLooper())
    private var currentPackage                = ""

    // ── Coroutine scope — SupervisorJob so one failed command doesn't cancel rest
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // ── Debounce: don't spam Flutter on every accessibility event ─────────────
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

        // ── Race condition fix (case b): service connected AFTER engine ───────
        // If MainActivity already configured the engine, attach now.
        pendingEngine?.let { attachToEngine(it) }

        Log.d(TAG, "God Mode ACTIVE ✅")
        sendEvent("onServiceStatusChanged", mapOf("enabled" to true))
    }

    override fun onInterrupt() {
        isMonitoring = false
        Log.d(TAG, "God Mode interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        isMonitoring = false
        instance     = null
        Log.d(TAG, "God Mode stopped")
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FLUTTER ENGINE ATTACH
    // ══════════════════════════════════════════════════════════════════════════

    fun attachToEngine(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            @Suppress("UNCHECKED_CAST")
            val args = (call.arguments as? Map<String, Any>) ?: emptyMap()

            // Run commands in coroutine on IO dispatcher — no main thread blocking
            serviceScope.launch(Dispatchers.IO) {
                val res = processCommand(call.method, args)
                withContext(Dispatchers.Main) {
                    result.success(res)
                }
            }
        }
        Log.d(TAG, "Engine attached ✅")
    }

    // Called from MainActivity channel fallback
    fun handleMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
        serviceScope.launch(Dispatchers.IO) {
            val res = processCommand(call.method, args)
            withContext(Dispatchers.Main) {
                result.success(res)
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND ROUTER
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun processCommand(method: String, args: Map<String, Any>): Any {
        return when (method) {
            // ── Status ──────────────────────────────────────────────────────
            "isEnabled"        -> isMonitoring
            "getForegroundApp" -> currentPackage
            "findTextOnScreen" -> findNodeWithText(str(args, "text")) != null

            // ── NEW: Real-time screen context for Flutter/Gemini ────────────
            // Returns all visible text on screen as a single string.
            // ZaraProvider can pass this to Gemini for contextual responses.
            "getScreenContext" -> getScreenContext()

            // ── Basic gestures ───────────────────────────────────────────────
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

            // ── High-level God Mode flows ────────────────────────────────────
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

            else -> { Log.w(TAG, "Unknown command: $method"); false }
        }
    }

    // Public wrapper — called by MainActivity's "getScreenContext" handler
    fun getScreenContextPublic(): String = getScreenContext()

    // ══════════════════════════════════════════════════════════════════════════
    // NEW: SCREEN CONTEXT READER
    // Collects all visible text from the current screen's node tree.
    // Flutter calls this before sending prompt to Gemini so Zara can
    // answer contextually: "main abhi kya dekh rahi hoon" type questions.
    // ══════════════════════════════════════════════════════════════════════════

    private fun getScreenContext(): String {
        val root = rootInActiveWindow ?: return ""
        val sb   = StringBuilder()
        collectText(root, sb, depth = 0, maxDepth = 12)
        val result = sb.toString().trim()
        if (result.length > 2000) return result.substring(0, 2000)
        return result
    }

    private fun collectText(
        node: AccessibilityNodeInfo,
        sb: StringBuilder,
        depth: Int,
        maxDepth: Int
    ) {
        if (depth > maxDepth) return
        val text = node.text?.toString()?.trim()
        val desc = node.contentDescription?.toString()?.trim()

        if (!text.isNullOrEmpty()) sb.append(text).append(" | ")
        else if (!desc.isNullOrEmpty()) sb.append(desc).append(" | ")

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectText(child, sb, depth + 1, maxDepth)
            child.recycle()   // ✅ FIX: recycle child nodes — prevents memory leak
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // INSTAGRAM FLOWS
    // All Thread.sleep() replaced with coroutine delay() — no ANR risk
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
        val w = resources.displayMetrics.widthPixels.toFloat()
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(count) {
            performSwipe(w / 2f, h * 0.78f, w / 2f, h * 0.22f, 350)
            delay(700)
        }
        Log.d(TAG, "Scrolled reels x$count")
    }

    private suspend fun instagramLikeCurrentReel(): Boolean {
        if (clickNodeById("com.instagram.android:id/like_button")) return true
        if (clickNodeWithContentDesc("Like")) return true
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels / 2f
        tapAt(w, h); delay(130); tapAt(w, h)
        Log.d(TAG, "Liked reel (double-tap)")
        return true
    }

    private suspend fun instagramPostComment(text: String): Boolean {
        delay(500)
        if (!clickNodeById("com.instagram.android:id/row_feed_comment_tv") &&
            !clickNodeWithContentDesc("Comment")) return false
        delay(900)
        if (!typeTextInFocused(text)) return false
        delay(400)
        clickNodeWithText("Post")
        Log.d(TAG, "Commented: $text")
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
    // FLIPKART SHOPPING FLOW
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun flipkartSearchProduct(query: String): Boolean {
        if (!openApp("com.flipkart.android")) return false
        delay(2200)

        if (!clickNodeById("com.flipkart.android:id/search_widget_textbox") &&
            !clickNodeWithText("Search for Products, Brands and More")) {
            tapAt(resources.displayMetrics.widthPixels / 2f, 160f)
        }
        delay(700)
        typeTextInFocused(query)
        delay(500)

        performGlobalAction(66) // KEYCODE_ENTER
        delay(2500)

        val root       = rootInActiveWindow ?: return false
        val clickables = findAllClickableNodes(root)
        val product    = clickables.getOrNull(3) ?: clickables.firstOrNull() ?: return false
        product.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        delay(2500)
        Log.d(TAG, "Flipkart: opened product for '$query'")
        return true
    }

    private suspend fun flipkartSelectSize(size: String): Boolean {
        delay(500)
        val targets = listOf(size, size.uppercase(), size.lowercase())
        for (t in targets) {
            if (clickNodeWithText(t)) {
                Log.d(TAG, "Size selected: $size")
                return true
            }
        }
        Log.w(TAG, "Size not found: $size")
        return false
    }

    private suspend fun flipkartAddToCart(): Boolean {
        delay(300)
        val ok = clickNodeWithText("ADD TO CART") || clickNodeWithText("Add to Cart")
        if (ok) { Log.d(TAG, "Added to cart"); delay(1200) }
        return ok
    }

    private suspend fun flipkartGoToPayment(): Boolean {
        delay(500)
        if (!clickNodeWithContentDesc("Cart") && !clickNodeWithText("Cart"))
            clickNodeById("com.flipkart.android:id/cart_icon")
        delay(1800)
        val ok = clickNodeWithText("PLACE ORDER") || clickNodeWithText("Place Order")
        if (ok) { Log.d(TAG, "Going to payment"); delay(1500) }
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

        Log.d(TAG, "WhatsApp: sent to $contact")
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // YOUTUBE
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun youtubeSearch(query: String): Boolean {
        if (!openApp("com.google.android.youtube")) return false
        delay(1800)
        if (!clickNodeWithContentDesc("Search"))
            clickNodeById("com.google.android.youtube:id/menu_item_1")
        delay(700)
        typeTextInFocused(query)
        delay(500)
        performGlobalAction(66) // KEYCODE_ENTER
        delay(2200)
        Log.d(TAG, "YouTube search: $query")
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
        repeat(steps) {
            performSwipe(w, h * 0.78f, w, h * 0.22f, 360)
            delay(400)
        }
    }

    private suspend fun scrollUp(steps: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(steps) {
            performSwipe(w, h * 0.22f, w, h * 0.78f, 360)
            delay(400)
        }
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
    // NODE FINDERS — all recycle() after use
    // ══════════════════════════════════════════════════════════════════════════

    private fun findNodeWithText(text: String): AccessibilityNodeInfo? {
        val root  = rootInActiveWindow ?: return null
        val exact = root.findAccessibilityNodeInfosByText(text)
        if (!exact.isNullOrEmpty()) {
            // Return first, recycle rest
            exact.drop(1).forEach { it.recycle() }
            return exact[0]
        }
        return traverseFind(root) { n ->
            val t = n.text?.toString()?.lowercase() ?: ""
            val d = n.contentDescription?.toString()?.lowercase() ?: ""
            t.contains(text.lowercase()) || d.contains(text.lowercase())
        }
    }

    private fun findNodeByDesc(node: AccessibilityNodeInfo, desc: String): AccessibilityNodeInfo? =
        traverseFind(node) {
            it.contentDescription?.toString()?.lowercase()?.contains(desc) == true
        }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? =
        traverseFind(node) { it.isEditable }

    private fun findAllClickableNodes(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        fun walk(n: AccessibilityNodeInfo) {
            if (n.isClickable) out.add(n)
            for (i in 0 until n.childCount) {
                val child = n.getChild(i) ?: continue
                walk(child)
                // Note: don't recycle here — caller needs these nodes
            }
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
            val child = node.getChild(i) ?: continue
            val found = traverseFind(child, predicate)
            if (found != null) {
                // Recycle child if it's not the found node
                if (found !== child) child.recycle()
                return found
            }
            child.recycle()
        }
        return null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ACCESSIBILITY EVENT
    // Debounced: only fires Flutter event if package actually changed,
    // with 150ms debounce to avoid spamming on rapid transitions.
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = event.packageName?.toString() ?: return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (pkg != lastWindowChangedPkg) {
                currentPackage        = pkg
                lastWindowChangedPkg  = pkg

                // Debounce — cancel previous job if another event fires within 150ms
                windowChangedJob?.cancel()
                windowChangedJob = serviceScope.launch {
                    delay(150)
                    sendEvent("onWindowChanged", mapOf("package" to pkg))
                }
            }
        }

        if (LOCK_PACKAGES.contains(pkg)) {
            val text = event.text?.joinToString(" ").orEmpty().lowercase()
            if (PASSWORD_WORDS.any { text.contains(it) }) {
                handleWrongPassword(pkg)
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GUARDIAN — wrong password detection
    // ══════════════════════════════════════════════════════════════════════════

    private fun handleWrongPassword(pkg: String) {
        val p   = prefs ?: return
        val now = System.currentTimeMillis()
        if (now - p.getLong(KEY_LAST, 0) > 30_000) {
            p.edit().putInt(KEY_COUNT, 0).apply()
        }
        val count = p.getInt(KEY_COUNT, 0) + 1
        p.edit().putInt(KEY_COUNT, count).putLong(KEY_LAST, now).apply()
        sendEvent("onSecurityEvent", mapOf("type" to "wrong_password", "count" to count))
        if (count >= THRESHOLD) {
            sendEvent("onSecurityEvent", mapOf("type" to "capture_photo", "count" to count))
        }
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
            .setOngoing(true)
            .build()
}
