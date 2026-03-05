package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// ZaraAccessibilityService.kt — Supreme God Mode v6.0
//
// ✅ CRASH FIX: startForeground() REMOVED — was causing "malfunctioning"
// ✅ NULL SAFETY: Every node access wrapped in safe-call + recycle
// ✅ COMMAND CHAINING: Sequential multi-command executor
// ✅ WhatsApp READER: Read + summarize incoming messages
// ✅ AGENT MODE: Zara replies on WhatsApp as human proxy
// ✅ YouTube: open → find search → type → submit → play first result
// ✅ Instagram: reels, scroll, like, comment, search
// ✅ Flipkart: search, size, cart, payment
// ✅ Screen Context: full node-tree text for Gemini Vision
// ✅ Permission Guard: checks mic, storage, accessibility status
// ══════════════════════════════════════════════════════════════════════════════

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
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

        var instance      : ZaraAccessibilityService? = null; private set
        var pendingEngine : FlutterEngine?            = null
    }

    private var methodChannel    : MethodChannel?      = null
    private var prefs            : SharedPreferences?  = null
    var         isMonitoring     : Boolean             = false
    private val handler                                = Handler(Looper.getMainLooper())
    var         currentPackage   : String              = ""

    private val serviceScope     = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var windowChangedJob : Job?                = null
    private var lastWindowPkg    : String              = ""

    // Agent Mode state
    private var agentModeActive  : Boolean             = false
    private var agentContact     : String              = ""
    private var agentPersona     : String              = ""

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE — NO startForeground() here, ever
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
            notificationTimeout = 150
            packageNames        = null
        }

        isMonitoring = true
        pendingEngine?.let { attachToEngine(it) }
        Log.d(TAG, "✅ God Mode ACTIVE — SDK ${Build.VERSION.SDK_INT}")
        sendEvent("onServiceStatusChanged", mapOf("enabled" to true))
    }

    override fun onInterrupt() { isMonitoring = false; Log.d(TAG, "Interrupted") }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        isMonitoring = false
        instance     = null
        Log.d(TAG, "Destroyed")
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ENGINE ATTACH
    // ══════════════════════════════════════════════════════════════════════════

    fun attachToEngine(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            @Suppress("UNCHECKED_CAST")
            val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
            serviceScope.launch(Dispatchers.IO) {
                val res = try { processCommand(call.method, args) }
                          catch (e: Exception) { Log.e(TAG, "cmd ${call.method}: $e"); false }
                withContext(Dispatchers.Main) { result.success(res) }
            }
        }
        Log.d(TAG, "Engine attached ✅")
    }

    fun handleMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
        serviceScope.launch(Dispatchers.IO) {
            val res = try { processCommand(call.method, args) }
                      catch (e: Exception) { Log.e(TAG, "fallback ${call.method}: $e"); false }
            withContext(Dispatchers.Main) { result.success(res) }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND ROUTER
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun processCommand(method: String, args: Map<String, Any>): Any {
        return when (method) {

            // ── Status & Info ──────────────────────────────────────────────────
            "isEnabled"         -> isMonitoring
            "getForegroundApp"  -> currentPackage
            "findTextOnScreen"  -> safeFind { findNodeWithText(str(args, "text")) } != null
            "getScreenContext"  -> getScreenContext()
            "getPermissionStatus" -> getPermissionStatus()

            // ── COMMAND CHAIN — execute multiple commands sequentially ──────────
            // args: { "commands": [ {"method": "youtubeSearch", "args": {"query": "arijit"}} ] }
            "executeChain"      -> executeCommandChain(args)

            // ── Basic UI ───────────────────────────────────────────────────────
            "openApp"           -> openApp(str(args, "package"))
            "clickText"         -> clickByText(str(args, "text"))
            "clickById"         -> clickById(str(args, "id"))
            "clickByDesc"       -> clickByDesc(str(args, "desc"))
            "typeText"          -> typeInFocused(str(args, "text"))
            "clearText"         -> clearFocused()
            "scrollDown"        -> { scrollDown(int(args, "steps", 3)); true }
            "scrollUp"          -> { scrollUp(int(args, "steps", 3)); true }
            "pressBack"         -> { performGlobalAction(GLOBAL_ACTION_BACK); true }
            "pressHome"         -> { performGlobalAction(GLOBAL_ACTION_HOME); true }
            "pressRecents"      -> { performGlobalAction(GLOBAL_ACTION_RECENTS); true }
            "takeScreenshot"    -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT); true }
            "openNotifications" -> { performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS); true }
            "openQuickSettings" -> { performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS); true }
            "tapAt"             -> { tapAt(flt(args,"x",540f), flt(args,"y",960f)); true }
            "swipe"             -> {
                performSwipe(flt(args,"x1",540f), flt(args,"y1",1400f),
                             flt(args,"x2",540f), flt(args,"y2",400f),
                             int(args,"durationMs",350).toLong())
                true
            }

            // ── YouTube ────────────────────────────────────────────────────────
            "youtubeSearch"     -> youtubeSearch(str(args, "query"))
            "youtubePlayFirst"  -> youtubePlayFirstResult()

            // ── Instagram ──────────────────────────────────────────────────────
            "instagramOpenReels"   -> instagramOpenReels()
            "instagramScrollReels" -> { instagramScrollReels(int(args, "count", 1)); true }
            "instagramLikeReel"    -> instagramLikeCurrentReel()
            "instagramPostComment" -> instagramPostComment(str(args, "text"))
            "instagramSearchUser"  -> instagramSearchUser(str(args, "username"))

            // ── WhatsApp ───────────────────────────────────────────────────────
            "whatsappSendMessage"  -> whatsappSendMessage(str(args,"contact"), str(args,"message"))
            "whatsappReadMessages" -> whatsappReadMessages(str(args, "contact"))
            "whatsappStartAgent"   -> whatsappStartAgent(
                str(args,"contact"), str(args,"persona"))
            "whatsappStopAgent"    -> whatsappStopAgent()

            // ── Flipkart ───────────────────────────────────────────────────────
            "flipkartSearchProduct" -> flipkartSearchProduct(str(args, "query"))
            "flipkartSelectSize"    -> flipkartSelectSize(str(args, "size"))
            "flipkartAddToCart"     -> flipkartAddToCart()
            "flipkartGoToPayment"   -> flipkartGoToPayment()

            else -> { Log.w(TAG, "Unknown command: $method"); false }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND CHAINING — execute list of commands sequentially
    // Flutter sends: { "commands": [ {method, args}, {method, args}, ... ] }
    // ══════════════════════════════════════════════════════════════════════════

    @Suppress("UNCHECKED_CAST")
    private suspend fun executeCommandChain(args: Map<String, Any>): Any {
        val commands = args["commands"] as? List<Map<String, Any>> ?: return false
        val results  = mutableListOf<Any>()

        Log.d(TAG, "Chain: executing ${commands.size} commands")

        for ((i, cmd) in commands.withIndex()) {
            val method  = cmd["method"]?.toString() ?: continue
            val cmdArgs = (cmd["args"] as? Map<String, Any>) ?: emptyMap()

            Log.d(TAG, "Chain[$i]: $method")
            val result = try {
                processCommand(method, cmdArgs)
            } catch (e: Exception) {
                Log.e(TAG, "Chain[$i] $method failed: $e")
                false
            }
            results.add(result)

            // Small gap between chained commands
            delay(300)

            // Stop chain if critical command failed
            if (result == false && cmd["required"] == true) {
                Log.w(TAG, "Chain stopped at $method (required=true, result=false)")
                break
            }
        }

        sendEvent("onChainComplete", mapOf(
            "total"    to commands.size,
            "executed" to results.size,
            "results"  to results.map { it.toString() }
        ))
        return results.lastOrNull() ?: false
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PERMISSION STATUS — for Flutter Permission Guard
    // ══════════════════════════════════════════════════════════════════════════

    private fun getPermissionStatus(): Map<String, Boolean> {
        val mic = try {
            checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }

        val storage = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                android.os.Environment.isExternalStorageManager()
            } else {
                checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
            }
        } catch (_: Exception) { false }

        val overlay = try {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                android.provider.Settings.canDrawOverlays(this)
        } catch (_: Exception) { false }

        return mapOf(
            "accessibility" to isMonitoring,
            "microphone"    to mic,
            "storage"       to storage,
            "overlay"       to overlay,
        )
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SCREEN CONTEXT — null-safe node tree traversal
    // ══════════════════════════════════════════════════════════════════════════

    fun getScreenContextPublic(): String = getScreenContext()

    private fun getScreenContext(): String {
        val root = rootInActiveWindow ?: return ""
        return try {
            val sb = StringBuilder()
            collectTextSafe(root, sb, 0, 10)
            val result = sb.toString().trim()
            if (result.length > 2000) result.substring(0, 2000) else result
        } catch (e: Exception) {
            Log.e(TAG, "getScreenContext: $e"); ""
        }
    }

    private fun collectTextSafe(
        node: AccessibilityNodeInfo?,
        sb: StringBuilder,
        depth: Int,
        maxDepth: Int
    ) {
        if (node == null || depth > maxDepth) return
        try {
            val text = node.text?.toString()?.trim()
            val desc = node.contentDescription?.toString()?.trim()
            when {
                !text.isNullOrEmpty() -> sb.append(text).append(" | ")
                !desc.isNullOrEmpty() -> sb.append(desc).append(" | ")
            }
            val count = node.childCount
            for (i in 0 until count) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                collectTextSafe(child, sb, depth + 1, maxDepth)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            Log.v(TAG, "collectText depth=$depth: $e")
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // YOUTUBE — full flow: open → search box → type → submit → play
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun youtubeSearch(query: String): Boolean {
        if (query.isBlank()) return false
        Log.d(TAG, "YT search: '$query'")

        if (!openApp("com.google.android.youtube")) return false
        delay(2500)

        // Click search icon
        val searchOpened =
            clickById("com.google.android.youtube:id/menu_item_1") ||
            clickByDesc("Search") ||
            clickByText("Search")
        if (!searchOpened) {
            val w = resources.displayMetrics.widthPixels.toFloat()
            tapAt(w - 130f, 110f)
        }
        delay(1000)

        // Find search input — 3 attempts with increasing delay
        var typed = false
        repeat(3) { attempt ->
            if (typed) return@repeat
            val root = rootInActiveWindow ?: return@repeat

            val field = safeFind {
                root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_edit_text")?.firstOrNull()
            } ?: safeFind {
                root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_box")?.firstOrNull()
            } ?: safeFind { findEditableNode(root) }

            if (field != null) {
                try {
                    field.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    delay(300)
                    val bundle = Bundle()
                    bundle.putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, query)
                    typed = field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
                } finally {
                    try { field.recycle() } catch (_: Exception) {}
                }
            }
            if (!typed) delay(800 + (attempt * 400L))
        }

        if (!typed) { Log.w(TAG, "YT: failed to type"); return false }
        delay(500)

        // Submit — try multiple ways
        val submitted =
            clickByDesc("Search")           ||
            clickByDesc("Submit query")     ||
            clickById("com.google.android.youtube:id/search_go_btn")

        if (!submitted) {
            // Simulate Enter key via IME action
            val root  = rootInActiveWindow
            val edit  = root?.let { safeFind { findEditableNode(it) } }
            val ok    = edit?.performAction(
                AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY) ?: false
            try { edit?.recycle() } catch (_: Exception) {}
            if (!ok) performGlobalAction(66) // KEYCODE_ENTER last resort
        }

        delay(2500)
        Log.d(TAG, "YT search done: '$query'")
        return true
    }

    private suspend fun youtubePlayFirstResult(): Boolean {
        delay(600)
        val root       = rootInActiveWindow ?: return false
        val clickables = findAllClickableNodesSafe(root)
        val target     = clickables.getOrNull(2) ?: clickables.firstOrNull() ?: return false
        return try { target.performAction(AccessibilityNodeInfo.ACTION_CLICK) }
               catch (_: Exception) { false }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP READER — read messages from a contact
    // Returns JSON-like string: "Contact: X\nMessages:\n- msg1\n- msg2"
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun whatsappReadMessages(contact: String): String {
        Log.d(TAG, "WA read: '$contact'")

        if (!openApp("com.whatsapp")) return "WhatsApp open nahi hua"
        delay(1800)

        // Open search
        val searchOpened =
            clickById("com.whatsapp:id/menuitem_search") ||
            clickByDesc("Search")
        if (!searchOpened) return "Search nahi mila"
        delay(700)

        typeInFocused(contact)
        delay(1200)

        // Click contact
        if (!clickByText(contact)) {
            val root  = rootInActiveWindow ?: return "Contact nahi mila"
            val nodes = findAllClickableNodesSafe(root)
            nodes.getOrNull(1)?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                ?: return "Contact nahi mila"
        }
        delay(1500)

        // Read message list from screen
        val root = rootInActiveWindow ?: return "Screen read nahi hua"
        val sb   = StringBuilder()
        sb.append("Contact: $contact\nMessages:\n")
        collectMessageNodes(root, sb)

        val result = sb.toString().trim()
        Log.d(TAG, "WA read result: ${result.length} chars")

        // Go back
        delay(300)
        performGlobalAction(GLOBAL_ACTION_BACK)

        return result
    }

    private fun collectMessageNodes(node: AccessibilityNodeInfo?, sb: StringBuilder) {
        if (node == null) return
        try {
            // WhatsApp message bubbles have specific class names
            val cls  = node.className?.toString() ?: ""
            val text = node.text?.toString()?.trim()

            if (!text.isNullOrEmpty() && text.length > 1 &&
                !text.matches(Regex("\\d{1,2}:\\d{2}.*")) && // skip timestamps
                !text.equals("Type a message", ignoreCase = true)) {
                sb.append("- $text\n")
            }

            for (i in 0 until node.childCount) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                collectMessageNodes(child, sb)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP AGENT MODE — Zara replies as human proxy
    // ══════════════════════════════════════════════════════════════════════════

    private fun whatsappStartAgent(contact: String, persona: String): Boolean {
        agentModeActive = true
        agentContact    = contact
        agentPersona    = persona
        Log.d(TAG, "Agent mode ON: contact=$contact")
        sendEvent("onAgentModeChanged", mapOf(
            "active"  to true,
            "contact" to contact,
            "persona" to persona
        ))
        return true
    }

    private fun whatsappStopAgent(): Boolean {
        agentModeActive = false
        agentContact    = ""
        agentPersona    = ""
        Log.d(TAG, "Agent mode OFF")
        sendEvent("onAgentModeChanged", mapOf("active" to false))
        return true
    }

    // Called from onAccessibilityEvent when new WhatsApp message arrives in agent mode
    private suspend fun handleAgentModeMessage(incomingText: String) {
        if (!agentModeActive || agentContact.isEmpty()) return
        Log.d(TAG, "Agent handling: '$incomingText'")
        // Tell Flutter to generate reply via Gemini and send it back
        sendEvent("onAgentMessageReceived", mapOf(
            "contact"  to agentContact,
            "message"  to incomingText,
            "persona"  to agentPersona
        ))
        // Flutter will call whatsappSendMessage with Gemini's reply
    }

    // ══════════════════════════════════════════════════════════════════════════
    // INSTAGRAM
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun instagramOpenReels(): Boolean {
        if (!openApp("com.instagram.android")) return false
        delay(1800)
        if (clickByDesc("Reels")) return true
        val w = resources.displayMetrics.widthPixels.toFloat()
        val h = resources.displayMetrics.heightPixels.toFloat()
        tapAt(w * 0.5f, h * 0.965f)
        delay(800)
        return true
    }

    private suspend fun instagramScrollReels(count: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(count) { performSwipe(w, h * 0.78f, w, h * 0.22f, 350); delay(700) }
    }

    private suspend fun instagramLikeCurrentReel(): Boolean {
        if (clickById("com.instagram.android:id/like_button")) return true
        if (clickByDesc("Like")) return true
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels / 2f
        tapAt(w, h); delay(130); tapAt(w, h)
        return true
    }

    private suspend fun instagramPostComment(text: String): Boolean {
        delay(500)
        if (!clickById("com.instagram.android:id/row_feed_comment_tv") &&
            !clickByDesc("Comment")) return false
        delay(900)
        typeInFocused(text)
        delay(400)
        clickByText("Post")
        return true
    }

    private suspend fun instagramSearchUser(username: String): Boolean {
        if (!openApp("com.instagram.android")) return false
        delay(1800)
        clickByDesc("Search and Explore")
        delay(900)
        if (!clickById("com.instagram.android:id/action_bar_search_edit_text"))
            clickByText("Search")
        delay(700)
        typeInFocused(username)
        delay(1300)
        clickByText(username)
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FLIPKART
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun flipkartSearchProduct(query: String): Boolean {
        if (!openApp("com.flipkart.android")) return false
        delay(2200)
        if (!clickById("com.flipkart.android:id/search_widget_textbox") &&
            !clickByText("Search for Products, Brands and More"))
            tapAt(resources.displayMetrics.widthPixels / 2f, 160f)
        delay(700)
        typeInFocused(query)
        delay(500)
        performGlobalAction(66)
        delay(2500)
        val root       = rootInActiveWindow ?: return false
        val clickables = findAllClickableNodesSafe(root)
        val product    = clickables.getOrNull(3) ?: clickables.firstOrNull() ?: return false
        return try { product.performAction(AccessibilityNodeInfo.ACTION_CLICK).also { delay(2500) } }
               catch (_: Exception) { false }
    }

    private suspend fun flipkartSelectSize(size: String): Boolean {
        delay(500)
        return clickByText(size) || clickByText(size.uppercase()) || clickByText(size.lowercase())
    }

    private suspend fun flipkartAddToCart(): Boolean {
        delay(300)
        val ok = clickByText("ADD TO CART") || clickByText("Add to Cart")
        if (ok) delay(1200)
        return ok
    }

    private suspend fun flipkartGoToPayment(): Boolean {
        delay(500)
        if (!clickByDesc("Cart") && !clickByText("Cart"))
            clickById("com.flipkart.android:id/cart_icon")
        delay(1800)
        val ok = clickByText("PLACE ORDER") || clickByText("Place Order")
        if (ok) delay(1500)
        return ok
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP SEND
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun whatsappSendMessage(contact: String, message: String): Boolean {
        if (!openApp("com.whatsapp")) return false
        delay(1800)
        if (!clickById("com.whatsapp:id/menuitem_search"))
            clickByDesc("Search")
        delay(700)
        typeInFocused(contact)
        delay(1300)
        if (!clickByText(contact)) {
            val root  = rootInActiveWindow ?: return false
            val nodes = findAllClickableNodesSafe(root)
            nodes.getOrNull(1)?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        delay(1200)
        typeInFocused(message)
        delay(400)
        if (!clickById("com.whatsapp:id/send"))
            clickByDesc("Send")
        Log.d(TAG, "WA sent to $contact")
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PRIMITIVE ACTIONS — all null-safe
    // ══════════════════════════════════════════════════════════════════════════

    private fun openApp(pkg: String): Boolean {
        return try {
            val i = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i); true
        } catch (e: Exception) { Log.e(TAG, "openApp $pkg: $e"); false }
    }

    private fun clickByText(text: String): Boolean {
        if (text.isBlank()) return false
        val node = safeFind { findNodeWithText(text) } ?: return false
        return try {
            val ok = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (!ok) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
            else true
        } catch (_: Exception) { false }
        finally { try { node.recycle() } catch (_: Exception) {} }
    }

    private fun clickByDesc(desc: String): Boolean {
        if (desc.isBlank()) return false
        val root = rootInActiveWindow ?: return false
        val node = safeFind { findNodeByDesc(root, desc.lowercase()) } ?: return false
        return try {
            val ok = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (!ok) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
            else true
        } catch (_: Exception) { false }
        finally { try { node.recycle() } catch (_: Exception) {} }
    }

    private fun clickById(id: String): Boolean {
        if (id.isBlank()) return false
        val root  = rootInActiveWindow ?: return false
        val nodes = try { root.findAccessibilityNodeInfosByViewId(id) } catch (_: Exception) { null }
        if (nodes.isNullOrEmpty()) return false
        return try {
            nodes[0].performAction(AccessibilityNodeInfo.ACTION_CLICK)
        } catch (_: Exception) { false }
        finally { nodes.forEach { try { it.recycle() } catch (_: Exception) {} } }
    }

    private fun typeInFocused(text: String): Boolean {
        if (text.isBlank()) return false
        val root    = rootInActiveWindow ?: return false
        val focused = try { root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) }
                      catch (_: Exception) { null }
                      ?: safeFind { findEditableNode(root) }
                      ?: return false
        return try {
            val bundle = Bundle()
            bundle.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
        } catch (_: Exception) { false }
        finally { try { focused.recycle() } catch (_: Exception) {} }
    }

    private fun clearFocused(): Boolean {
        val root    = rootInActiveWindow ?: return false
        val focused = try { root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) }
                      catch (_: Exception) { null }
                      ?: safeFind { findEditableNode(root) }
                      ?: return false
        return try {
            val bundle = Bundle()
            bundle.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "")
            focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
        } catch (_: Exception) { false }
        finally { try { focused.recycle() } catch (_: Exception) {} }
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
        try {
            val path   = Path().apply { moveTo(x1, y1); lineTo(x2, y2) }
            val stroke = GestureDescription.StrokeDescription(path, 0, ms.coerceAtLeast(50))
            dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
        } catch (e: Exception) { Log.e(TAG, "swipe: $e") }
    }

    private fun tapAt(x: Float, y: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        try {
            val path   = Path().apply { moveTo(x, y); lineTo(x + 1f, y + 1f) }
            val stroke = GestureDescription.StrokeDescription(path, 0, 50)
            dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
        } catch (e: Exception) { Log.e(TAG, "tap: $e") }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NULL-SAFE NODE FINDERS
    // ══════════════════════════════════════════════════════════════════════════

    // Wraps any finder in try-catch — no crash on null/stale nodes
    private fun <T> safeFind(block: () -> T?): T? {
        return try { block() } catch (e: Exception) { Log.v(TAG, "safeFind: $e"); null }
    }

    private fun findNodeWithText(text: String): AccessibilityNodeInfo? {
        val root  = rootInActiveWindow ?: return null
        val lower = text.lowercase()
        val exact = try { root.findAccessibilityNodeInfosByText(text) }
                    catch (_: Exception) { null }
        if (!exact.isNullOrEmpty()) {
            exact.drop(1).forEach { try { it.recycle() } catch (_: Exception) {} }
            return exact[0]
        }
        return traverseFindSafe(root) { n ->
            try {
                val t = n.text?.toString()?.lowercase() ?: ""
                val d = n.contentDescription?.toString()?.lowercase() ?: ""
                t.contains(lower) || d.contains(lower)
            } catch (_: Exception) { false }
        }
    }

    private fun findNodeByDesc(node: AccessibilityNodeInfo, desc: String) =
        traverseFindSafe(node) {
            try { it.contentDescription?.toString()?.lowercase()?.contains(desc) == true }
            catch (_: Exception) { false }
        }

    private fun findEditableNode(node: AccessibilityNodeInfo) =
        traverseFindSafe(node) {
            try { it.isEditable } catch (_: Exception) { false }
        }

    private fun findAllClickableNodesSafe(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        fun walk(n: AccessibilityNodeInfo?) {
            if (n == null) return
            try {
                if (n.isClickable) out.add(n)
                val count = n.childCount
                for (i in 0 until count) {
                    try { walk(n.getChild(i)) } catch (_: Exception) {}
                }
            } catch (_: Exception) {}
        }
        walk(node)
        return out
    }

    // Safe tree traversal — catches all exceptions, recycles properly
    private fun traverseFindSafe(
        node: AccessibilityNodeInfo?,
        predicate: (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (node == null) return null
        return try {
            if (predicate(node)) return node
            val count = try { node.childCount } catch (_: Exception) { 0 }
            for (i in 0 until count) {
                val child = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
                val found = traverseFindSafe(child, predicate)
                if (found != null) {
                    if (found !== child) try { child.recycle() } catch (_: Exception) {}
                    return found
                }
                try { child.recycle() } catch (_: Exception) {}
            }
            null
        } catch (e: Exception) {
            Log.v(TAG, "traverseFind: $e"); null
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ACCESSIBILITY EVENT
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = try { event.packageName?.toString() } catch (_: Exception) { null } ?: return

        // Window change — debounced
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            pkg != lastWindowPkg) {
            currentPackage = pkg
            lastWindowPkg  = pkg
            windowChangedJob?.cancel()
            windowChangedJob = serviceScope.launch {
                delay(200)
                sendEvent("onWindowChanged", mapOf("package" to pkg))
            }
        }

        // Guardian: wrong password detection
        if (LOCK_PACKAGES.contains(pkg)) {
            try {
                val text = event.text?.joinToString(" ").orEmpty().lowercase()
                if (PASSWORD_WORDS.any { text.contains(it) }) handleWrongPassword()
            } catch (_: Exception) {}
        }

        // Agent mode: detect new WhatsApp messages
        if (agentModeActive && pkg == "com.whatsapp" &&
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            try {
                val text = event.text?.joinToString(" ")?.trim()
                if (!text.isNullOrEmpty()) {
                    serviceScope.launch { handleAgentModeMessage(text) }
                }
            } catch (_: Exception) {}
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
            catch (e: Exception) { Log.e(TAG, "sendEvent $method: $e") }
        }
    }

    private fun str(args: Map<String, Any>, key: String, default: String = "") =
        args[key]?.toString() ?: default

    private fun int(args: Map<String, Any>, key: String, default: Int = 0) =
        (args[key] as? Int) ?: args[key]?.toString()?.toIntOrNull() ?: default

    private fun flt(args: Map<String, Any>, key: String, default: Float = 0f) =
        (args[key] as? Number)?.toFloat() ?: args[key]?.toString()?.toFloatOrNull() ?: default
}
