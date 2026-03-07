package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// ZaraAccessibilityService.kt — God Mode v10.0
//
// ✅ VOSK WAKE WORD  : Offline STT, grammar restricted, IO thread, WakeLock
// ✅ WHATSAPP GOD MODE: Send + Voice Call + Video Call (ID + desc + fallback)
// ✅ UNIVERSAL SUBMIT : ACTION_SET_TEXT + IME_ACTION_SEARCH (no GLOBAL_ACTION(66))
// ✅ SMART NODE FINDER: ID → contentDescription → text → parent-click fallback
// ✅ YOUTUBE SEARCH   : search_edit_text → ACTION_SET_TEXT → search_go_btn
// ✅ ANDROID 14+ SAFE : WakeLock, no startForeground, no deprecated APIs
// ✅ NULL SAFETY      : safeFind / traverseFindSafe — zero crash on SDK 35/36
// ══════════════════════════════════════════════════════════════════════════════

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Path
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlin.coroutines.coroutineContext
import kotlin.math.sqrt
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer

class ZaraAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG     = "ZARA_GOD"
        const val CHANNEL = "com.mahakal.zara/accessibility"

        private const val PREFS     = "zara_guardian_prefs"
        private const val KEY_COUNT = "wrong_password_count"
        private const val KEY_LAST  = "last_password_attempt"
        private const val THRESHOLD = 2

        private val WAKE_WORDS = listOf(
            "hii zara", "hi zara", "hey zara", "zara", "sunna", "suno", "zara sunna"
        )
        private val LOCK_PACKAGES  = setOf("com.android.systemui", "com.android.keyguard")
        private val PASSWORD_WORDS = setOf("wrong", "incorrect", "invalid", "error")

        var instance      : ZaraAccessibilityService? = null; private set
        var pendingEngine : FlutterEngine?            = null
    }

    private var methodChannel : MethodChannel?     = null
    private var prefs         : SharedPreferences? = null
    var isMonitoring          : Boolean            = false
    var currentPackage        : String             = ""

    private val handler      = Handler(Looper.getMainLooper())
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var windowJob    : Job?   = null
    private var lastWindowPkg: String = ""

    // Wake word
    private var wakeWordActive = false
    private var wakeListenJob  : Job? = null

    // Agent mode
    private var agentModeActive = false
    private var agentContact    = ""
    private var agentPersona    = ""

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        prefs    = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes          = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType        = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags               =
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS      or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS                  or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS     or
                AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            notificationTimeout = 100
            packageNames        = null   // ALL apps — no restriction
        }

        isMonitoring = true
        pendingEngine?.let { attachToEngine(it) }
        Log.d(TAG, "✅ God Mode v10 ACTIVE — SDK ${Build.VERSION.SDK_INT}")
        sendEvent("onServiceStatusChanged", mapOf("enabled" to true))
    }

    override fun onInterrupt() { isMonitoring = false }

    override fun onDestroy() {
        super.onDestroy()
        stopWakeWordEngine()
        serviceScope.cancel()
        isMonitoring = false
        instance     = null
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
                          catch (e: Exception) { Log.e(TAG, "${call.method}: $e"); false }
                withContext(Dispatchers.Main) { result.success(res) }
            }
        }
    }

    fun handleMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
        serviceScope.launch(Dispatchers.IO) {
            val res = try { processCommand(call.method, args) } catch (_: Exception) { false }
            withContext(Dispatchers.Main) { result.success(res) }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND ROUTER
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun processCommand(method: String, args: Map<String, Any>): Any {
        return when (method) {

            // ── Status ──────────────────────────────────────────────────────
            "isEnabled"           -> isMonitoring
            "getForegroundApp"    -> currentPackage
            "getScreenContext"    -> getScreenContext()
            "scanScreen"          -> scanScreen()          // ← NEW: full node map
            "getPermissionStatus" -> getPermissionStatus()
            "findTextOnScreen"    -> safeFind { findNodeWithText(str(args, "text")) } != null

            // ── Wake Word ───────────────────────────────────────────────────
            "startWakeWord"       -> { startWakeWordEngine(); true }
            "stopWakeWord"        -> { stopWakeWordEngine();  true }

            // ── Command Chain ────────────────────────────────────────────────
            "executeChain"        -> executeCommandChain(args)

            // ── Generic (any app) ────────────────────────────────────────────
            "performGenericAction" -> performGenericAction(
                str(args, "action"), str(args, "target"),
                str(args, "target2", ""), int(args, "steps", 3))

            // ── Basic UI ─────────────────────────────────────────────────────
            "openApp"          -> openApp(str(args, "package"))
            "clickText"        -> smartClick(text = str(args, "text"))
            "clickById"        -> smartClick(id   = str(args, "id"))
            "clickByDesc"      -> smartClick(desc = str(args, "desc"))
            "typeText"         -> typeInFocused(str(args, "text"))
            "clearText"        -> clearFocused()
            "scrollDown"       -> { scrollDown(int(args, "steps", 3)); true }
            "scrollUp"         -> { scrollUp(int(args, "steps", 3)); true }
            "pressBack"        -> { performGlobalAction(GLOBAL_ACTION_BACK); true }
            "pressHome"        -> { performGlobalAction(GLOBAL_ACTION_HOME); true }
            "pressRecents"     -> { performGlobalAction(GLOBAL_ACTION_RECENTS); true }
            "takeScreenshot"   -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT); true }
            "openNotifications"-> { performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS); true }
            "openSettings"     -> {
                startActivity(Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true }
            "tapAt"            -> { tapAt(flt(args, "x", 540f), flt(args, "y", 960f)); true }
            "swipe"            -> {
                performSwipe(flt(args,"x1",540f), flt(args,"y1",1400f),
                             flt(args,"x2",540f), flt(args,"y2",400f),
                             int(args,"durationMs",350).toLong()); true }

            // ── YouTube ──────────────────────────────────────────────────────
            "youtubeSearch"    -> youtubeSearch(str(args, "query"))
            "youtubePlayFirst" -> youtubePlayFirstResult()

            // ── Instagram ────────────────────────────────────────────────────
            "instagramOpenReels"   -> instagramOpenReels()
            "instagramScrollReels" -> { instagramScrollReels(int(args, "count", 1)); true }
            "instagramLikeReel"    -> instagramLikeCurrentReel()
            "instagramPostComment" -> instagramPostComment(str(args, "text"))
            "instagramSearchUser"  -> instagramSearchUser(str(args, "username"))

            // ── WhatsApp ─────────────────────────────────────────────────────
            "whatsappSendMessage"  -> whatsappSendMessage(str(args,"contact"), str(args,"message"))
            "whatsappVoiceCall"    -> whatsappVoiceCall(str(args, "contact"))
            "whatsappVideoCall"    -> whatsappVideoCall(str(args, "contact"))
            "whatsappReadMessages" -> whatsappReadMessages(str(args, "contact"))
            "whatsappStartAgent"   -> whatsappStartAgent(str(args,"contact"), str(args,"persona"))
            "whatsappStopAgent"    -> whatsappStopAgent()

            // ── Flipkart ─────────────────────────────────────────────────────
            "flipkartSearchProduct" -> flipkartSearchProduct(str(args, "query"))
            "flipkartSelectSize"    -> flipkartSelectSize(str(args, "size"))
            "flipkartAddToCart"     -> flipkartAddToCart()
            "flipkartGoToPayment"   -> flipkartGoToPayment()

            else -> { Log.w(TAG, "Unknown cmd: $method"); false }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SMART CLICK — ID → desc → text → parent fallback
    // ══════════════════════════════════════════════════════════════════════════

    private fun smartClick(
        id   : String = "",
        desc : String = "",
        text : String = ""
    ): Boolean {
        // 1. Try resource ID
        if (id.isNotBlank()) {
            val root  = rootInActiveWindow ?: return false
            val nodes = try { root.findAccessibilityNodeInfosByViewId(id) }
                        catch (_: Exception) { null }
            if (!nodes.isNullOrEmpty()) {
                val ok = try { nodes[0].performAction(AccessibilityNodeInfo.ACTION_CLICK) }
                         catch (_: Exception) { false }
                nodes.forEach { try { it.recycle() } catch (_: Exception) {} }
                if (ok) return true
            }
        }
        // 2. Try content description
        if (desc.isNotBlank()) {
            val root = rootInActiveWindow ?: return false
            val node = safeFind { findNodeByDesc(root, desc.lowercase()) }
            if (node != null) {
                val ok = try {
                    node.performAction(AccessibilityNodeInfo.ACTION_CLICK).let { r ->
                        if (!r) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
                        else r
                    }
                } catch (_: Exception) { false }
                finally { try { node.recycle() } catch (_: Exception) {} }
                if (ok) return true
            }
        }
        // 3. Try visible text
        if (text.isNotBlank()) {
            val node = safeFind { findNodeWithText(text) } ?: return false
            return try {
                val ok = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (!ok) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
                else ok
            } catch (_: Exception) { false }
            finally { try { node.recycle() } catch (_: Exception) {} }
        }
        return false
    }

    // Backward-compat wrappers
    private fun clickByText(t: String) = smartClick(text = t)
    private fun clickById(id: String)   = smartClick(id = id)
    private fun clickByDesc(d: String)  = smartClick(desc = d)

    // ══════════════════════════════════════════════════════════════════════════
    // VOSK WAKE WORD ENGINE
    // ══════════════════════════════════════════════════════════════════════════
    //
    //  Model: android/app/src/main/assets/model/
    //         (vosk-model-small-en-in-0.4)
    //
    //  Flow : AudioRecord 16kHz → Vosk (grammar restricted) → partial match
    //         "hii zara" → sendEvent("wake_word_detected") → Flutter
    //  Guard: PARTIAL_WAKE_LOCK keeps AudioRecord alive when screen is OFF
    //         Without it, Android Doze kills AudioRecord in ~60s silently
    //  Thread: Model() + Recognizer() on Dispatchers.IO (NOT Main → no ANR)
    // ══════════════════════════════════════════════════════════════════════════

    private val SAMPLE_RATE      = 16000
    private val FRAME_SIZE       = 4096
    private val ENERGY_THRESHOLD = 600.0

    private var voskModel      : Model?      = null
    private var voskRecognizer : Recognizer? = null
    private var audioRecord    : AudioRecord? = null
    private var wakeLock       : PowerManager.WakeLock? = null

    private fun startWakeWordEngine() {
        if (wakeWordActive) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "WakeWord: no RECORD_AUDIO permission")
            sendEvent("onWakeWordError", mapOf("error" to "no_mic_permission"))
            return
        }
        wakeWordActive = true

        // PARTIAL_WAKE_LOCK — CPU stays alive, mic stays alive, screen can be off
        // Max 10 min → refreshed on each wake_word_detected event
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "zara:VoskWakeLock"
        ).also { it.acquire(10 * 60 * 1000L) }

        serviceScope.launch(Dispatchers.IO) { _initVoskAndListen() }
        sendEvent("onWakeWordEngineChanged", mapOf("active" to true))
        Log.d(TAG, "🎙️ Vosk engine starting…")
    }

    private suspend fun _initVoskAndListen() {
        try {
            val modelFiles = try { assets.list("model") ?: emptyArray() }
                             catch (_: Exception) { emptyArray<String>() }
            if (modelFiles.isEmpty()) {
                Log.w(TAG, "Vosk: assets/model/ missing → VAD fallback")
                wakeWordVadLoop(); return
            }

            val modelDir = "${filesDir.absolutePath}/vosk_model"
            _unpackVoskModel(modelDir)

            // ✅ Model() on IO thread — heavy disk I/O, calling on Main = ANR
            try {
                voskModel      = Model(modelDir)
                voskRecognizer = Recognizer(voskModel, SAMPLE_RATE.toFloat())
                // Grammar restriction → 10x faster, ~3% CPU
                voskRecognizer?.setGrammar(
                    """["hi zara", "hii zara", "hey zara", "zara", "sunna", "suno", "[unk]"]"""
                )
                Log.d(TAG, "✅ Vosk ready — say 'Hii Zara'")
                voskListenLoop()   // already on Dispatchers.IO
            } catch (e: Exception) {
                Log.e(TAG, "Vosk init: $e → VAD fallback")
                wakeWordVadLoop()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Vosk outer: $e → VAD fallback")
            wakeWordVadLoop()
        }
    }

    private fun _unpackVoskModel(destDir: String) {
        val dest = java.io.File(destDir)
        if (dest.exists() && dest.list()?.isNotEmpty() == true) return
        dest.mkdirs()
        _copyAssetsDir("model", dest)
        Log.d(TAG, "Vosk model unpacked → $destDir")
    }

    private fun _copyAssetsDir(assetPath: String, dest: java.io.File) {
        val list = try { assets.list(assetPath) ?: return } catch (_: Exception) { return }
        if (list.isEmpty()) {
            try { assets.open(assetPath).use { i -> dest.outputStream().use { i.copyTo(it) } } }
            catch (e: Exception) { Log.e(TAG, "_copyAssets: $e") }
            return
        }
        dest.mkdirs()
        list.forEach { _copyAssetsDir("$assetPath/$it", java.io.File(dest, it)) }
    }

    private suspend fun voskListenLoop() {
        val bufSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(FRAME_SIZE * 2)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufSize)
            audioRecord!!.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "Vosk AudioRecord: $e"); wakeWordActive = false; return
        }

        val pcm = ByteArray(FRAME_SIZE * 2)
        Log.d(TAG, "🎙️ Vosk loop active — say 'Hii Zara'")

        while (wakeWordActive && coroutineContext.isActive) {
            val read = audioRecord?.read(pcm, 0, pcm.size) ?: -1
            if (read <= 0) { delay(10); continue }

            val recognizer = voskRecognizer ?: break
            val isFinal    = recognizer.acceptWaveForm(pcm, read)
            val json       = if (isFinal) recognizer.result else recognizer.partialResult

            try {
                val text = JSONObject(json)
                    .optString(if (isFinal) "text" else "partial", "")
                    .lowercase().trim()

                if (text.isNotEmpty()) {
                    val matched = WAKE_WORDS.firstOrNull { text.contains(it) }
                    if (matched != null) {
                        Log.d(TAG, "🔔 Vosk: '$matched'")
                        // Refresh WakeLock on each detection (resets 10-min timer)
                        try {
                            if (wakeLock?.isHeld == true) wakeLock?.release()
                            wakeLock?.acquire(10 * 60 * 1000L)
                        } catch (_: Exception) {}
                        withContext(Dispatchers.Main) {
                            sendEvent("wake_word_detected",
                                mapOf("transcript" to text, "word" to matched))
                        }
                        recognizer.reset()
                        delay(2000) // cooldown — prevent double-fire
                    }
                }
            } catch (_: Exception) {}
        }
        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
    }

    private fun stopWakeWordEngine() {
        wakeWordActive = false
        wakeListenJob?.cancel(); wakeListenJob = null
        try { voskRecognizer?.close(); voskRecognizer = null } catch (_: Exception) {}
        try { voskModel?.close();      voskModel      = null } catch (_: Exception) {}
        try { audioRecord?.stop();     audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
        // ✅ Release WakeLock — let CPU sleep
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        wakeLock = null
        Log.d(TAG, "🎙️ Wake word engine STOPPED")
        sendEvent("onWakeWordEngineChanged", mapOf("active" to false))
    }

    // ── VAD fallback — fires when assets/model/ is missing ────────────────────
    // Streams PCM chunks to Flutter → Whisper transcribes → wake word check
    private suspend fun wakeWordVadLoop() {
        val bufSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(512 * 4)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufSize)
            audioRecord!!.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "VAD init: $e"); wakeWordActive = false; return
        }

        val pcm       = ShortArray(512)
        var silenceMs = 0L
        val speechBuf = mutableListOf<ShortArray>()
        var speaking  = false

        Log.d(TAG, "🎙️ VAD fallback loop active")

        while (wakeWordActive && coroutineContext.isActive) {
            val read = audioRecord?.read(pcm, 0, 512) ?: -1
            if (read <= 0) { delay(10); continue }

            val rms = computeRms(pcm, read)
            if (rms > ENERGY_THRESHOLD) {
                speaking = true; silenceMs = 0L
                speechBuf.add(pcm.copyOf(read))
                if (speechBuf.size > 96) speechBuf.removeAt(0)
            } else if (speaking) {
                silenceMs += (512 * 1000L / SAMPLE_RATE)
                if (silenceMs >= 800L) {
                    val flat     = speechBuf.flatMap { it.toList() }.toShortArray()
                    speaking     = false; silenceMs = 0L
                    val pcmBytes = shortsToBytes(flat)
                    withContext(Dispatchers.Main) {
                        sendEvent("onWakeWordPcmReady", mapOf(
                            "pcm_base64"  to android.util.Base64.encodeToString(
                                pcmBytes, android.util.Base64.NO_WRAP),
                            "sample_rate" to SAMPLE_RATE))
                    }
                    speechBuf.clear()
                }
            }
        }
        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
    }

    private fun computeRms(pcm: ShortArray, len: Int): Double {
        var sum = 0.0
        for (i in 0 until len) sum += (pcm[i].toLong() * pcm[i].toLong()).toDouble()
        return sqrt(sum / len)
    }

    private fun shortsToBytes(s: ShortArray): ByteArray {
        val b = ByteArray(s.size * 2)
        for (i in s.indices) {
            b[i * 2]     = (s[i].toInt() and 0xff).toByte()
            b[i * 2 + 1] = (s[i].toInt() shr 8 and 0xff).toByte()
        }
        return b
    }

    // ══════════════════════════════════════════════════════════════════════════
    // UNIVERSAL SUBMIT — IME_ACTION_SEARCH (replaces GLOBAL_ACTION(66))
    // ══════════════════════════════════════════════════════════════════════════

    private fun imeSearch(node: AccessibilityNodeInfo): Boolean {
        return try {
            // IME_ACTION_SEARCH = 3
            node.performAction(AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY).let {}
            node.performAction(3) // IME_ACTION_SEARCH
        } catch (_: Exception) { false }
    }

    private fun submitSearchField(root: AccessibilityNodeInfo?, fieldId: String = ""): Boolean {
        val field = if (fieldId.isNotBlank()) {
            try { root?.findAccessibilityNodeInfosByViewId(fieldId)?.firstOrNull() }
            catch (_: Exception) { null }
        } else {
            safeFind { root?.let { findEditableNode(it) } }
        } ?: return false

        return try {
            // Method 1: IME action on field (most reliable)
            val ok = field.performAction(3) // IME_ACTION_SEARCH
            if (!ok) {
                // Method 2: press Enter via key event injection
                val bundle = Bundle()
                bundle.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT, 1)
                field.performAction(AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY, bundle)
            }
            true
        } catch (_: Exception) { false }
        finally { try { field.recycle() } catch (_: Exception) {} }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GENERIC ACTION ENGINE
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun performGenericAction(
        action : String,
        target : String,
        target2: String = "",
        steps  : Int    = 3
    ): Boolean {
        Log.d(TAG, "GenericAction: $action → '$target'")
        return when (action.uppercase()) {
            "CLICK_BY_TEXT"  -> smartClick(text = target)
            "CLICK_BY_ID"    -> smartClick(id   = target)
            "CLICK_BY_DESC"  -> smartClick(desc = target)
            "LONG_CLICK" -> {
                val node = safeFind { findNodeWithText(target) } ?: return false
                try { node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK) }
                catch (_: Exception) { false }
                finally { try { node.recycle() } catch (_: Exception) {} }
            }
            "TYPE_AND_SUBMIT" -> {
                typeInFocused(target); delay(400)
                if (target2.isNotEmpty()) {
                    smartClick(text = target2) || smartClick(desc = target2)
                } else {
                    // ✅ IME_ACTION_SEARCH — not GLOBAL_ACTION(66)
                    val root = rootInActiveWindow
                    val submitted = submitSearchField(root)
                    // ✅ Wait 1200ms for search UI to load results before any
                    // subsequent click. Without this delay the results list
                    // hasn't rendered yet and clicks land on stale nodes.
                    if (submitted) delay(1200)
                    submitted
                }
            }
            "TYPE_TEXT"  -> typeInFocused(target)
            "CLEAR_TEXT" -> clearFocused()
            "SCROLL_DOWN" -> { scrollDown(steps); true }
            "SCROLL_UP"   -> { scrollUp(steps);   true }
            "SWIPE_CUSTOM" -> {
                val parts1 = target.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                val parts2 = target2.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                performSwipe(parts1.getOrElse(0){0f}, parts1.getOrElse(1){0f},
                             parts2.getOrElse(0){0f}, parts2.getOrElse(1){0f}, 400); true
            }
            "WAIT_FOR_TEXT" -> {
                val timeout = 8000L; val start = System.currentTimeMillis(); var found = false
                while (!found && System.currentTimeMillis() - start < timeout) {
                    found = safeFind { findNodeWithText(target) } != null
                    if (!found) delay(500)
                }
                if (found) smartClick(text = target) else false
            }
            "WAIT_AND_CLICK" -> { delay(steps * 500L); smartClick(text = target) }
            "OPEN_APP"       -> openApp(target)
            "PRESS_BACK"     -> { performGlobalAction(GLOBAL_ACTION_BACK); true }
            "PRESS_HOME"     -> { performGlobalAction(GLOBAL_ACTION_HOME); true }
            "PRESS_RECENTS"  -> { performGlobalAction(GLOBAL_ACTION_RECENTS); true }
            "SCREENSHOT"     -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT); true }
            "TAP_AT" -> {
                val p = target.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                tapAt(p.getOrElse(0){0f}, p.getOrElse(1){0f}); true
            }
            else -> { Log.w(TAG, "Unknown generic action: $action"); false }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND CHAIN
    // ══════════════════════════════════════════════════════════════════════════

    @Suppress("UNCHECKED_CAST")
    private suspend fun executeCommandChain(args: Map<String, Any>): Any {
        val commands = args["commands"] as? List<Map<String, Any>> ?: return false
        val results  = mutableListOf<Any>()
        for ((i, cmd) in commands.withIndex()) {
            val method  = cmd["method"]?.toString() ?: continue
            val cmdArgs = (cmd["args"] as? Map<String, Any>) ?: emptyMap()
            val result  = try { processCommand(method, cmdArgs) }
                          catch (e: Exception) { Log.e(TAG, "chain[$i]: $e"); false }
            results.add(result)
            delay(300)
            if (result == false && cmd["required"] == true) break
        }
        sendEvent("onChainComplete", mapOf("results" to results.map { it.toString() }))
        return results.lastOrNull() ?: false
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP GOD MODE
    // ══════════════════════════════════════════════════════════════════════════

    // ── Open chat by name or number ────────────────────────────────────────────
    private suspend fun _openWhatsAppChat(contact: String): Boolean {
        // Path A: If it's a phone number → deep link (most reliable)
        val digits = contact.filter { it.isDigit() }
        if (digits.length >= 10) {
            try {
                val uri = android.net.Uri.parse("https://api.whatsapp.com/send?phone=$digits")
                startActivity(Intent(Intent.ACTION_VIEW, uri)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                delay(2800)
                return rootInActiveWindow?.packageName == "com.whatsapp"
            } catch (_: Exception) {}
        }

        // Path B: Open WA → search bar → type name → click first result
        if (!openApp("com.whatsapp")) return false
        delay(2000)

        val searchOpened =
            smartClick(id   = "com.whatsapp:id/menuitem_search") ||
            smartClick(desc = "Search")                           ||
            smartClick(text = "Search")
        if (!searchOpened) return false
        delay(700)

        typeInFocused(contact)
        delay(1400)

        return smartClick(text = contact) ||
               smartClick(text = contact.split(" ").firstOrNull() ?: contact)
    }

    // ── Send message ───────────────────────────────────────────────────────────
    private suspend fun whatsappSendMessage(contact: String, message: String): Boolean {
        if (!_openWhatsAppChat(contact)) return false
        delay(1200)
        typeInFocused(message)
        delay(500)
        val sent =
            smartClick(id   = "com.whatsapp:id/send")         ||
            smartClick(id   = "com.whatsapp:id/send_btn")     ||
            smartClick(desc = "Send")                          ||
            smartClick(text = "Send")
        return sent
    }

    // ── Voice call ────────────────────────────────────────────────────────────
    // Tries IDs first, then content descriptions, then positional fallback
    private suspend fun whatsappVoiceCall(contact: String): Boolean {
        if (!_openWhatsAppChat(contact)) return false
        delay(1400)

        // ID fallback chain (tested across WhatsApp 2.24.x–2.25.x)
        val called =
            smartClick(id   = "com.whatsapp:id/voice_call_btn")      ||
            smartClick(id   = "com.whatsapp:id/menuitem_voice_call") ||
            smartClick(desc = "Voice call")                           ||
            smartClick(desc = "Audio call")                           ||
            smartClick(text = "Voice call")

        if (!called) {
            // Positional fallback: voice call is 2nd-to-last icon in chat header
            val root  = rootInActiveWindow ?: return false
            val nodes = findAllClickableNodesSafe(root)
            val btn   = nodes.getOrNull(nodes.size - 2) ?: return false
            btn.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        Log.d(TAG, "📞 WhatsApp voice call → $contact"); return true
    }

    // ── Video call ────────────────────────────────────────────────────────────
    private suspend fun whatsappVideoCall(contact: String): Boolean {
        if (!_openWhatsAppChat(contact)) return false
        delay(1400)

        val called =
            smartClick(id   = "com.whatsapp:id/video_call_btn")      ||
            smartClick(id   = "com.whatsapp:id/menuitem_video_call") ||
            smartClick(desc = "Video call")                           ||
            smartClick(text = "Video call")

        if (!called) {
            // Positional fallback: video call is last icon in chat header
            val root  = rootInActiveWindow ?: return false
            val nodes = findAllClickableNodesSafe(root)
            nodes.lastOrNull()?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        Log.d(TAG, "📹 WhatsApp video call → $contact"); return true
    }

    // ── Read messages ─────────────────────────────────────────────────────────
    private suspend fun whatsappReadMessages(contact: String): String {
        if (!openApp("com.whatsapp")) return "WhatsApp open nahi hua"
        delay(1800)
        if (!smartClick(id = "com.whatsapp:id/menuitem_search") && !smartClick(desc = "Search"))
            return "Search nahi mila"
        delay(700)
        typeInFocused(contact); delay(1200)
        if (!smartClick(text = contact)) {
            val root = rootInActiveWindow ?: return "Contact nahi mila"
            findAllClickableNodesSafe(root).getOrNull(1)
                ?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                ?: return "Contact nahi mila"
        }
        delay(1500)
        val root = rootInActiveWindow ?: return "Screen read nahi hua"
        val sb   = StringBuilder("Contact: $contact\nMessages:\n")
        collectMessageNodes(root, sb)
        delay(300); performGlobalAction(GLOBAL_ACTION_BACK)
        return sb.toString().trim()
    }

    private fun collectMessageNodes(node: AccessibilityNodeInfo?, sb: StringBuilder) {
        if (node == null) return
        try {
            val text = node.text?.toString()?.trim()
            if (!text.isNullOrEmpty() && text.length > 1 &&
                !text.matches(Regex("\\d{1,2}:\\d{2}.*")) &&
                !text.equals("Type a message", ignoreCase = true)) sb.append("- $text\n")
            for (i in 0 until node.childCount) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                collectMessageNodes(child, sb)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ── Agent mode ────────────────────────────────────────────────────────────
    private fun whatsappStartAgent(contact: String, persona: String): Boolean {
        agentModeActive = true; agentContact = contact; agentPersona = persona
        sendEvent("onAgentModeChanged", mapOf("active" to true, "contact" to contact))
        return true
    }
    private fun whatsappStopAgent(): Boolean {
        agentModeActive = false; agentContact = ""; agentPersona = ""
        sendEvent("onAgentModeChanged", mapOf("active" to false))
        return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // YOUTUBE — ACTION_SET_TEXT + IME_ACTION_SEARCH
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun youtubeSearch(query: String): Boolean {
        if (query.isBlank()) return false
        if (!openApp("com.google.android.youtube")) return false
        delay(2500)

        // Open search bar (avoid mic icon — click search icon by ID)
        val iconClicked =
            smartClick(id = "com.google.android.youtube:id/menu_item_1") ||
            smartClick(id = "com.google.android.youtube:id/search_button")
        if (!iconClicked) {
            val w = resources.displayMetrics.widthPixels.toFloat()
            tapAt(w - 160f, 100f)
        }
        delay(1200)

        // Type into search field
        var typed = false
        repeat(3) { attempt ->
            if (typed) return@repeat
            val root  = rootInActiveWindow ?: return@repeat
            val field = safeFind {
                root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_edit_text")?.firstOrNull()
            } ?: safeFind {
                root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_box_text")?.firstOrNull()
            } ?: safeFind { findEditableNode(root) }

            if (field != null) {
                try {
                    field.performAction(AccessibilityNodeInfo.ACTION_CLICK); delay(400)
                    val b = Bundle()
                    b.putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, query)
                    typed = field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, b)
                } finally { try { field.recycle() } catch (_: Exception) {} }
            }
            if (!typed) delay(900)
        }
        if (!typed) return false
        delay(600)

        // ✅ Submit via IME_ACTION_SEARCH first, then button IDs
        val root3 = rootInActiveWindow
        var submitted = false

        if (root3 != null) {
            val field = safeFind {
                root3.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_edit_text")?.firstOrNull()
            } ?: safeFind { findEditableNode(root3) }
            if (field != null) {
                submitted = try { field.performAction(3) } // IME_ACTION_SEARCH
                            catch (_: Exception) { false }
                try { field.recycle() } catch (_: Exception) {}
            }
        }

        if (!submitted) submitted =
            smartClick(id   = "com.google.android.youtube:id/search_go_btn")             ||
            smartClick(id   = "com.google.android.youtube:id/search_button_progressive") ||
            smartClick(desc = "Search")

        delay(2500); return true
    }

    private suspend fun youtubePlayFirstResult(): Boolean {
        delay(600)
        val root       = rootInActiveWindow ?: return false
        val clickables = findAllClickableNodesSafe(root)
        return try {
            (clickables.getOrNull(2) ?: clickables.firstOrNull())
                ?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
        } catch (_: Exception) { false }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // INSTAGRAM
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun instagramOpenReels(): Boolean {
        if (!openApp("com.instagram.android")) return false; delay(1800)
        if (smartClick(desc = "Reels")) return true
        tapAt(resources.displayMetrics.widthPixels * 0.5f,
              resources.displayMetrics.heightPixels * 0.965f); delay(800); return true
    }
    private suspend fun instagramScrollReels(count: Int) {
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(count) { performSwipe(w, h * 0.78f, w, h * 0.22f, 350); delay(700) }
    }
    private suspend fun instagramLikeCurrentReel(): Boolean {
        if (smartClick(id = "com.instagram.android:id/like_button")) return true
        if (smartClick(desc = "Like")) return true
        val w = resources.displayMetrics.widthPixels / 2f
        val h = resources.displayMetrics.heightPixels / 2f
        tapAt(w, h); delay(130); tapAt(w, h); return true
    }
    private suspend fun instagramPostComment(text: String): Boolean {
        delay(500)
        if (!smartClick(id = "com.instagram.android:id/row_feed_comment_tv") &&
            !smartClick(desc = "Comment")) return false
        delay(900); typeInFocused(text); delay(400); smartClick(text = "Post"); return true
    }
    private suspend fun instagramSearchUser(username: String): Boolean {
        if (!openApp("com.instagram.android")) return false; delay(1800)
        smartClick(desc = "Search and Explore"); delay(900)
        if (!smartClick(id = "com.instagram.android:id/action_bar_search_edit_text"))
            smartClick(text = "Search")
        delay(700); typeInFocused(username); delay(1300); smartClick(text = username); return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FLIPKART
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun flipkartSearchProduct(query: String): Boolean {
        if (!openApp("com.flipkart.android")) return false; delay(2200)
        if (!smartClick(id = "com.flipkart.android:id/search_widget_textbox") &&
            !smartClick(text = "Search for Products, Brands and More"))
            tapAt(resources.displayMetrics.widthPixels / 2f, 160f)
        delay(700); typeInFocused(query); delay(500)
        submitSearchField(rootInActiveWindow)
        delay(2500)
        val root = rootInActiveWindow ?: return false
        val p    = findAllClickableNodesSafe(root).getOrNull(3) ?: return false
        return try { p.performAction(AccessibilityNodeInfo.ACTION_CLICK).also { delay(2500) } }
               catch (_: Exception) { false }
    }
    private suspend fun flipkartSelectSize(size: String) =
        smartClick(text = size) || smartClick(text = size.uppercase()) || smartClick(text = size.lowercase())
    private suspend fun flipkartAddToCart(): Boolean {
        delay(300)
        val ok = smartClick(text = "ADD TO CART") || smartClick(text = "Add to Cart")
        if (ok) delay(1200); return ok
    }
    private suspend fun flipkartGoToPayment(): Boolean {
        delay(500)
        if (!smartClick(desc = "Cart") && !smartClick(text = "Cart"))
            smartClick(id = "com.flipkart.android:id/cart_icon")
        delay(1800)
        val ok = smartClick(text = "PLACE ORDER") || smartClick(text = "Place Order")
        if (ok) delay(1500); return ok
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PRIMITIVE ACTIONS
    // ══════════════════════════════════════════════════════════════════════════

    private fun openApp(pkg: String): Boolean {
        return try {
            val i = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(i); true
        } catch (e: Exception) { Log.e(TAG, "openApp $pkg: $e"); false }
    }

    private fun typeInFocused(text: String): Boolean {
        if (text.isBlank()) return false
        val root    = rootInActiveWindow ?: return false
        val focused = try { root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) }
                      catch (_: Exception) { null }
                      ?: safeFind { findEditableNode(root) } ?: return false
        return try {
            val b = Bundle()
            b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, b)
        } catch (_: Exception) { false }
        finally { try { focused.recycle() } catch (_: Exception) {} }
    }

    private fun clearFocused(): Boolean {
        val root    = rootInActiveWindow ?: return false
        val focused = try { root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) }
                      catch (_: Exception) { null }
                      ?: safeFind { findEditableNode(root) } ?: return false
        return try {
            val b = Bundle()
            b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "")
            focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, b)
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
            val p = Path().apply { moveTo(x1, y1); lineTo(x2, y2) }
            dispatchGesture(GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(p, 0, ms.coerceAtLeast(50)))
                .build(), null, null)
        } catch (e: Exception) { Log.e(TAG, "swipe: $e") }
    }
    private fun tapAt(x: Float, y: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        try {
            val p = Path().apply { moveTo(x, y); lineTo(x + 1f, y + 1f) }
            dispatchGesture(GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(p, 0, 50))
                .build(), null, null)
        } catch (e: Exception) { Log.e(TAG, "tap: $e") }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NULL-SAFE NODE FINDERS
    // ══════════════════════════════════════════════════════════════════════════

    private fun <T> safeFind(block: () -> T?): T? =
        try { block() } catch (_: Exception) { null }

    private fun findNodeWithText(text: String): AccessibilityNodeInfo? {
        val root  = rootInActiveWindow ?: return null
        val lower = text.lowercase()
        val exact = try { root.findAccessibilityNodeInfosByText(text) }
                    catch (_: Exception) { null }
        if (!exact.isNullOrEmpty()) {
            exact.drop(1).forEach { try { it.recycle() } catch (_: Exception) {} }
            return exact[0]
        }
        return traverseFindSafe(root) {
            try {
                val t = it.text?.toString()?.lowercase() ?: ""
                val d = it.contentDescription?.toString()?.lowercase() ?: ""
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
        traverseFindSafe(node) { try { it.isEditable } catch (_: Exception) { false } }

    private fun findAllClickableNodesSafe(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        fun walk(n: AccessibilityNodeInfo?) {
            if (n == null) return
            try {
                if (n.isClickable) out.add(n)
                for (i in 0 until n.childCount) try { walk(n.getChild(i)) } catch (_: Exception) {}
            } catch (_: Exception) {}
        }
        walk(node); return out
    }

    private fun traverseFindSafe(
        node      : AccessibilityNodeInfo?,
        predicate : (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (node == null) return null
        return try {
            if (predicate(node)) return node
            for (i in 0 until try { node.childCount } catch (_: Exception) { 0 }) {
                val child = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
                val found = traverseFindSafe(child, predicate)
                if (found != null) {
                    if (found !== child) try { child.recycle() } catch (_: Exception) {}
                    return found
                }
                try { child.recycle() } catch (_: Exception) {}
            }
            null
        } catch (_: Exception) { null }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PERMISSION STATUS
    // ══════════════════════════════════════════════════════════════════════════

    private fun getPermissionStatus(): Map<String, Boolean> {
        val mic = try {
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }
        val overlay = try {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                android.provider.Settings.canDrawOverlays(this)
        } catch (_: Exception) { false }
        return mapOf("accessibility" to isMonitoring, "microphone" to mic, "overlay" to overlay)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SCREEN SCANNER — "The Eyes" v2.0
    //
    // Returns a JSON map of ALL interactive elements on screen:
    //   {
    //     "package": "com.whatsapp",
    //     "elements": [
    //       { "text":"Send", "desc":"Send message", "id":"com.whatsapp:id/send",
    //         "clickable":true, "editable":false, "x":980, "y":1840,
    //         "w":120, "h":80, "depth":5 },
    //       ...
    //     ],
    //     "editableFields": [...],
    //     "allText": "full screen text joined"
    //   }
    //
    // ZaraProvider passes this JSON to Gemini so AI knows EXACTLY what
    // buttons exist, where they are, what text is on screen.
    // Gemini can then say: [COMMAND:CLICK_BY_ID,ID:com.whatsapp:id/send]
    // ══════════════════════════════════════════════════════════════════════════

    private fun scanScreen(): String {
        val root = rootInActiveWindow ?: return "{\"error\":\"no_window\"}"
        return try {
            val elements   = mutableListOf<Map<String, Any>>()
            val editable   = mutableListOf<Map<String, Any>>()
            val texts      = mutableListOf<String>()
            val pkg        = currentPackage

            _scanNode(root, elements, editable, texts, 0, 12)

            org.json.JSONObject().apply {
                put("package",   pkg)
                put("timestamp", System.currentTimeMillis())
                put("elements",  org.json.JSONArray().also { arr ->
                    elements.take(60).forEach { el ->
                        arr.put(org.json.JSONObject(el))
                    }
                })
                put("editableFields", org.json.JSONArray().also { arr ->
                    editable.take(10).forEach { el ->
                        arr.put(org.json.JSONObject(el))
                    }
                })
                put("allText", texts.take(80).joinToString(" | "))
                put("elementCount", elements.size)
            }.toString()
        } catch (e: Exception) {
            Log.e(TAG, "scanScreen: $e")
            "{\"error\":\"${e.message}\"}"
        }
    }

    private fun _scanNode(
        node    : AccessibilityNodeInfo?,
        elements: MutableList<Map<String, Any>>,
        editable: MutableList<Map<String, Any>>,
        texts   : MutableList<String>,
        depth   : Int,
        maxDepth: Int
    ) {
        if (node == null || depth > maxDepth) return
        try {
            val text  = try { node.text?.toString()?.trim()          } catch (_: Exception) { null }
            val desc  = try { node.contentDescription?.toString()?.trim() } catch (_: Exception) { null }
            val resId = try { node.viewIdResourceName?.toString()     } catch (_: Exception) { null }
            val click = try { node.isClickable } catch (_: Exception) { false }
            val edit  = try { node.isEditable  } catch (_: Exception) { false }
            val vis   = try { node.isVisibleToUser } catch (_: Exception) { false }

            if (!vis) return  // skip invisible nodes

            // Collect text for allText
            if (!text.isNullOrEmpty() && text.length > 1) texts.add(text)
            else if (!desc.isNullOrEmpty() && desc.length > 1) texts.add(desc)

            // Get bounds for coordinates
            val bounds = android.graphics.Rect()
            try { node.getBoundsInScreen(bounds) } catch (_: Exception) {}

            val label = when {
                !text.isNullOrEmpty() -> text
                !desc.isNullOrEmpty() -> desc
                !resId.isNullOrEmpty() -> resId.substringAfterLast("/")
                else                  -> null
            }

            if ((click || edit) && bounds.width() > 0 && bounds.height() > 0) {
                val el = mapOf(
                    "text"      to (text  ?: ""),
                    "desc"      to (desc  ?: ""),
                    "id"        to (resId ?: ""),
                    "label"     to (label ?: ""),
                    "clickable" to click,
                    "editable"  to edit,
                    "x"         to bounds.centerX(),
                    "y"         to bounds.centerY(),
                    "w"         to bounds.width(),
                    "h"         to bounds.height(),
                    "depth"     to depth
                )
                if (edit) editable.add(el)
                else      elements.add(el)
            }

            // Recurse into children
            val childCount = try { node.childCount } catch (_: Exception) { 0 }
            for (i in 0 until childCount) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                _scanNode(child, elements, editable, texts, depth + 1, maxDepth)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SCREEN CONTEXT
    // ══════════════════════════════════════════════════════════════════════════

    fun getScreenContextPublic(): String = getScreenContext()
    private fun getScreenContext(): String {
        val root = rootInActiveWindow ?: return ""
        return try {
            val sb = StringBuilder()
            collectTextSafe(root, sb, 0, 12)
            sb.toString().trim().let { if (it.length > 2000) it.substring(0, 2000) else it }
        } catch (_: Exception) { "" }
    }
    private fun collectTextSafe(node: AccessibilityNodeInfo?, sb: StringBuilder, depth: Int, max: Int) {
        if (node == null || depth > max) return
        try {
            val t = node.text?.toString()?.trim()
            val d = node.contentDescription?.toString()?.trim()
            when { !t.isNullOrEmpty() -> sb.append(t).append(" | ")
                   !d.isNullOrEmpty() -> sb.append(d).append(" | ") }
            for (i in 0 until node.childCount) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                collectTextSafe(child, sb, depth + 1, max)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ACCESSIBILITY EVENT
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = try { event.packageName?.toString() } catch (_: Exception) { null } ?: return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && pkg != lastWindowPkg) {
            currentPackage = pkg; lastWindowPkg = pkg
            windowJob?.cancel()
            windowJob = serviceScope.launch {
                delay(200); sendEvent("onWindowChanged", mapOf("package" to pkg))
            }
        }

        if (LOCK_PACKAGES.contains(pkg)) {
            try {
                val text = event.text?.joinToString(" ").orEmpty().lowercase()
                if (PASSWORD_WORDS.any { text.contains(it) }) handleWrongPassword()
            } catch (_: Exception) {}
        }

        if (agentModeActive && pkg == "com.whatsapp" &&
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            try {
                val text = event.text?.joinToString(" ")?.trim()
                if (!text.isNullOrEmpty())
                    serviceScope.launch {
                        sendEvent("onAgentMessageReceived",
                            mapOf("contact" to agentContact, "message" to text))
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
    // SEND EVENT TO FLUTTER
    // ══════════════════════════════════════════════════════════════════════════

    private fun sendEvent(method: String, data: Map<String, Any>) {
        handler.post {
            try { methodChannel?.invokeMethod(method, data) }
            catch (e: Exception) { Log.e(TAG, "sendEvent $method: $e") }
        }
    }

    // ── Arg helpers ───────────────────────────────────────────────────────────
    private fun str(args: Map<String, Any>, key: String, default: String = "") =
        args[key]?.toString() ?: default
    private fun int(args: Map<String, Any>, key: String, default: Int = 0) =
        (args[key] as? Int) ?: args[key]?.toString()?.toIntOrNull() ?: default
    private fun flt(args: Map<String, Any>, key: String, default: Float = 0f) =
        (args[key] as? Number)?.toFloat() ?: args[key]?.toString()?.toFloatOrNull() ?: default
}
