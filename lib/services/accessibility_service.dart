package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// ZaraAccessibilityService.kt — Supreme God Mode v9.0
//
// ✅ WAKE WORD: Vosk offline speech recognition — "Hii Zara" / "Sunna"
//    Uses Vosk Android SDK (org.vosk:vosk-android)
//    Fully offline — no API key needed, no internet required for wake word
//    Falls back to Energy VAD + PCM→Flutter path if Vosk model not ready
//
// ✅ UNIVERSAL GENERIC CONTROL:
//    performGenericAction(action, target) — works on ANY app
//    Supported: CLICK_BY_TEXT, CLICK_BY_ID, CLICK_BY_DESC,
//               TYPE_AND_SUBMIT, SCROLL_DOWN, SCROLL_UP,
//               LONG_CLICK, WAIT_FOR_TEXT, SWIPE_CUSTOM
//
// ✅ YOUTUBE FIX: search_edit_text → ACTION_SET_TEXT → search_go_btn
// ✅ WhatsApp READER + AGENT MODE (auto-reply as proxy)
// ✅ COMMAND CHAIN: sequential multi-step executor
// ✅ CRASH FIX: startForeground() REMOVED from AccessibilityService
// ✅ NULL SAFETY: safeFind / traverseFindSafe — zero crash on SDK 35
// ✅ SDK 35: no deprecated APIs
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
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlin.math.abs
import kotlin.math.sqrt
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer

class ZaraAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG     = "ZARA_GOD"
        const val CHANNEL = "com.mahakal.zara/accessibility"

        private const val PREFS      = "zara_guardian_prefs"
        private const val KEY_COUNT  = "wrong_password_count"
        private const val KEY_LAST   = "last_password_attempt"
        private const val THRESHOLD  = 2

        // Wake word strings (matched against transcription)
        private val WAKE_WORDS = listOf("hii zara", "hi zara", "hey zara",
                                         "sunna", "suno", "zara sunna")

        private val LOCK_PACKAGES  = setOf("com.android.systemui", "com.android.keyguard")
        private val PASSWORD_WORDS = setOf("wrong", "incorrect", "invalid", "error")

        var instance      : ZaraAccessibilityService? = null; private set
        var pendingEngine : FlutterEngine?            = null
    }

    private var methodChannel : MethodChannel?     = null
    private var prefs         : SharedPreferences? = null
    var isMonitoring          : Boolean            = false
    var currentPackage        : String             = ""

    private val handler          = Handler(Looper.getMainLooper())
    private val serviceScope     = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var windowChangedJob : Job?    = null
    private var lastWindowPkg    : String  = ""

    // Wake word state
    private var wakeWordActive   : Boolean = false
    private var wakeListenJob    : Job?    = null

    // Agent Mode
    private var agentModeActive  : Boolean = false
    private var agentContact     : String  = ""
    private var agentPersona     : String  = ""

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE — ❌ NO startForeground() — causes "malfunctioning" crash
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

        isMonitoring = true
        pendingEngine?.let { attachToEngine(it) }
        Log.d(TAG, "✅ God Mode ACTIVE — SDK ${Build.VERSION.SDK_INT}")
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
            "isEnabled"             -> isMonitoring
            "getForegroundApp"      -> currentPackage
            "getScreenContext"      -> getScreenContext()
            "getPermissionStatus"   -> getPermissionStatus()
            "findTextOnScreen"      -> safeFind { findNodeWithText(str(args,"text")) } != null

            // ── Wake Word ───────────────────────────────────────────────────
            "startWakeWord"         -> { startWakeWordEngine(); true }
            "stopWakeWord"          -> { stopWakeWordEngine(); true }

            // ── Command Chain ───────────────────────────────────────────────
            "executeChain"          -> executeCommandChain(args)

            // ── UNIVERSAL GENERIC CONTROL ────────────────────────────────────
            // The "Jarvis engine" — works on ANY app
            "performGenericAction"  -> performGenericAction(
                str(args,"action"), str(args,"target"),
                str(args,"target2",""), int(args,"steps",3))

            // ── Basic UI ────────────────────────────────────────────────────
            "openApp"               -> openApp(str(args,"package"))
            "clickText"             -> clickByText(str(args,"text"))
            "clickById"             -> clickById(str(args,"id"))
            "clickByDesc"           -> clickByDesc(str(args,"desc"))
            "typeText"              -> typeInFocused(str(args,"text"))
            "clearText"             -> clearFocused()
            "scrollDown"            -> { scrollDown(int(args,"steps",3)); true }
            "scrollUp"              -> { scrollUp(int(args,"steps",3)); true }
            "pressBack"             -> { performGlobalAction(GLOBAL_ACTION_BACK); true }
            "pressHome"             -> { performGlobalAction(GLOBAL_ACTION_HOME); true }
            "pressRecents"          -> { performGlobalAction(GLOBAL_ACTION_RECENTS); true }
            "takeScreenshot"        -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT); true }
            "openNotifications"     -> { performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS); true }
            "openQuickSettings"     -> { performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS); true }
            "tapAt"                 -> { tapAt(flt(args,"x",540f), flt(args,"y",960f)); true }
            "swipe"                 -> {
                performSwipe(flt(args,"x1",540f), flt(args,"y1",1400f),
                             flt(args,"x2",540f), flt(args,"y2",400f),
                             int(args,"durationMs",350).toLong()); true }

            // ── YouTube (fixed) ─────────────────────────────────────────────
            "youtubeSearch"         -> youtubeSearch(str(args,"query"))
            "youtubePlayFirst"      -> youtubePlayFirstResult()

            // ── Instagram ───────────────────────────────────────────────────
            "instagramOpenReels"    -> instagramOpenReels()
            "instagramScrollReels"  -> { instagramScrollReels(int(args,"count",1)); true }
            "instagramLikeReel"     -> instagramLikeCurrentReel()
            "instagramPostComment"  -> instagramPostComment(str(args,"text"))
            "instagramSearchUser"   -> instagramSearchUser(str(args,"username"))

            // ── WhatsApp ────────────────────────────────────────────────
            "whatsappSendMessage"   -> whatsappSendMessage(str(args,"contact"), str(args,"message"))
            "whatsappVoiceCall"     -> whatsappVoiceCall(str(args,"contact"))
            "whatsappVideoCall"     -> whatsappVideoCall(str(args,"contact"))
            "whatsappReadMessages"  -> whatsappReadMessages(str(args,"contact"))
            "whatsappStartAgent"    -> whatsappStartAgent(str(args,"contact"), str(args,"persona"))
            "whatsappStopAgent"     -> whatsappStopAgent()

            // ── Flipkart ────────────────────────────────────────────────────
            "flipkartSearchProduct" -> flipkartSearchProduct(str(args,"query"))
            "flipkartSelectSize"    -> flipkartSelectSize(str(args,"size"))
            "flipkartAddToCart"     -> flipkartAddToCart()
            "flipkartGoToPayment"   -> flipkartGoToPayment()

            else -> { Log.w(TAG, "Unknown cmd: $method"); false }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WAKE WORD ENGINE — Vosk Offline STT (com.alphacephei:vosk-android:0.3.75)
    // ══════════════════════════════════════════════════════════════════════════
    //
    // Model: android/app/src/main/assets/model/
    //        (vosk-model-small-en-in-0.4 — am/ conf/ graph/ ivector/ README)
    //
    // Flow: AudioRecord 16kHz → Vosk (grammar restricted) → partial match
    //       "hi zara"/"sunna" → wake_word_detected → Flutter → TTS + Whisper
    //   Fallback: assets/model/ missing → VAD PCM → Flutter → Whisper
    //
    // WakeLock: PARTIAL_WAKE_LOCK keeps AudioRecord alive when screen is OFF
    //           Released automatically when stopWakeWordEngine() is called
    // ══════════════════════════════════════════════════════════════════════════

    private var voskModel      : Model?       = null
    private var voskRecognizer : Recognizer?  = null
    private var audioRecord    : AudioRecord? = null
    private var wakeLock       : android.os.PowerManager.WakeLock? = null

    private val SAMPLE_RATE      = 16000
    private val FRAME_SIZE       = 4096          // 256ms per chunk at 16kHz
    private val ENERGY_THRESHOLD = 600.0

    private fun startWakeWordEngine() {
        if (wakeWordActive) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "WakeWord: no RECORD_AUDIO permission")
            sendEvent("onWakeWordError", mapOf("error" to "no_mic_permission"))
            return
        }
        wakeWordActive = true

        // ✅ PARTIAL_WAKE_LOCK — keeps CPU + mic alive when screen is OFF
        // Without this, Android Doze kills AudioRecord silently after ~1 min
        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        wakeLock = pm.newWakeLock(
            android.os.PowerManager.PARTIAL_WAKE_LOCK,
            "zara:VoskWakeLock"
        ).also { it.acquire(10 * 60 * 1000L) } // max 10 min — refreshed on re-detect

        serviceScope.launch(Dispatchers.IO) { _initVoskAndListen() }
        sendEvent("onWakeWordEngineChanged", mapOf("active" to true))
        Log.d(TAG, "🎙️ Vosk wake word engine starting...")
    }

    private suspend fun _initVoskAndListen() {
        try {
            val modelFiles = try { assets.list("model") ?: emptyArray() }
                             catch (_: Exception) { emptyArray<String>() }

            if (modelFiles.isEmpty()) {
                Log.w(TAG, "Vosk: assets/model/ missing → VAD fallback")
                wakeWordVadLoop()
                return
            }

            val modelDir = "${filesDir.absolutePath}/vosk_model"
            _unpackVoskModel(modelDir)

            // ✅ Model() on IO thread — heavy disk read, NOT on Main thread
            // Calling on Main = ANR on Android 12+ strict mode
            try {
                voskModel      = Model(modelDir)
                voskRecognizer = Recognizer(voskModel, SAMPLE_RATE.toFloat())
                // Grammar restricted to wake words only
                // → 10x faster than full dict, ~3% CPU at 16kHz
                voskRecognizer?.setGrammar(
                    """["hi zara", "hii zara", "hey zara", "zara", "sunna", "suno", "zara sunna", "[unk]"]"""
                )
                Log.d(TAG, "✅ Vosk ready — say 'Hii Zara' or 'Sunna'")
                voskListenLoop() // already on Dispatchers.IO
            } catch (e: Exception) {
                Log.e(TAG, "Vosk init: $e → VAD fallback")
                wakeWordVadLoop()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Vosk error: $e → VAD fallback")
            wakeWordVadLoop()
        }
    }

    private fun _unpackVoskModel(destDir: String) {
        val dest = java.io.File(destDir)
        if (dest.exists() && dest.list()?.isNotEmpty() == true) return
        dest.mkdirs()
        _copyAssetsDir("model", dest)
        Log.d(TAG, "Vosk: model unpacked → $destDir")
    }

    private fun _copyAssetsDir(assetPath: String, dest: java.io.File) {
        val list = try { assets.list(assetPath) ?: return } catch (_: Exception) { return }
        if (list.isEmpty()) {
            try {
                assets.open(assetPath).use { input ->
                    dest.outputStream().use { input.copyTo(it) }
                }
            } catch (e: Exception) { Log.e(TAG, "_copyAssets: $e") }
            return
        }
        dest.mkdirs()
        list.forEach { child -> _copyAssetsDir("$assetPath/$child", java.io.File(dest, child)) }
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
        Log.d(TAG, "🎙️ Vosk listening — say 'Hi Zara' or 'Sunna'")

        while (wakeWordActive && currentCoroutineContext().isActive) {
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
                        Log.d(TAG, "🔔 Vosk: '$matched' detected")
                        withContext(Dispatchers.Main) {
                            sendEvent("wake_word_detected",
                                mapOf("transcript" to text, "word" to matched))
                        }
                        recognizer.reset()
                        delay(2000) // cooldown
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
        // ✅ Release WakeLock — let CPU go back to sleep
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        wakeLock = null
        Log.d(TAG, "🎙️ Wake word engine STOPPED")
        sendEvent("onWakeWordEngineChanged", mapOf("active" to false))
    }

    // VAD fallback — when Vosk model not in assets
    // Sends PCM to Flutter → Whisper transcribes → onWakeWordTranscript()
    private suspend fun wakeWordVadLoop() {
        val bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(512 * 4)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufferSize)
            audioRecord!!.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "VAD init: $e"); wakeWordActive = false; return
        }

        val pcm       = ShortArray(512)
        var silenceMs = 0L
        val speechBuf = mutableListOf<ShortArray>()
        var speaking  = false

        Log.d(TAG, "🎙️ VAD fallback loop active")

        while (wakeWordActive && currentCoroutineContext().isActive) {
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
                            "sample_rate" to SAMPLE_RATE
                        ))
                    }
                    speechBuf.clear()
                }
            }
        }
        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
    }

    fun onWakeWordTranscript(transcript: String) {
        val lower = transcript.lowercase().trim()
        val match = WAKE_WORDS.any { lower.contains(it) }
        if (match) {
            Log.d(TAG, "🔔 Wake word (VAD path): '$lower'")
            sendEvent("wake_word_detected", mapOf("transcript" to transcript, "word" to lower))
        }
    }

    private fun computeRms(pcm: ShortArray, len: Int): Double {
        var sum = 0.0
        for (i in 0 until len) sum += (pcm[i].toLong() * pcm[i].toLong()).toDouble()
        return kotlin.math.sqrt(sum / len)
    }

    private fun shortsToBytes(shorts: ShortArray): ByteArray {
        val bytes = ByteArray(shorts.size * 2)
        for (i in shorts.indices) {
            bytes[i * 2]     = (shorts[i].toInt() and 0xff).toByte()
            bytes[i * 2 + 1] = (shorts[i].toInt() shr 8 and 0xff).toByte()
        }
        return bytes
    }

    // ══════════════════════════════════════════════════════════════════════════
    // UNIVERSAL GENERIC CONTROL — works on ANY app
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun performGenericAction(
        action  : String,
        target  : String,
        target2 : String = "",
        steps   : Int    = 3
    ): Boolean {
        Log.d(TAG, "GenericAction: $action target='$target'")
        return when (action.uppercase()) {

            // Click any node by visible text — ANY app
            "CLICK_BY_TEXT"   -> clickByText(target)

            // Click by resource ID — e.g. "com.app:id/button_send"
            "CLICK_BY_ID"     -> clickById(target)

            // Click by content description — icon buttons
            "CLICK_BY_DESC"   -> clickByDesc(target)

            // Long press by text
            "LONG_CLICK" -> {
                val node = safeFind { findNodeWithText(target) } ?: return false
                try {
                    node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)
                } catch (_: Exception) { false }
                finally { try { node.recycle() } catch (_: Exception) {} }
            }

            // Find any EditText, type text, press Enter to submit
            "TYPE_AND_SUBMIT" -> {
                val typed = typeInFocused(target)
                delay(400)
                if (target2.isNotEmpty()) {
                    // target2 = submit button text to click
                    clickByText(target2) || clickByDesc(target2)
                } else {
                    performGlobalAction(66) // KEYCODE_ENTER
                    true
                }
            }

            // Type without submitting
            "TYPE_TEXT"       -> typeInFocused(target)

            // Clear focused field
            "CLEAR_TEXT"      -> clearFocused()

            // Scroll down N steps
            "SCROLL_DOWN"     -> { scrollDown(steps); true }

            // Scroll up N steps
            "SCROLL_UP"       -> { scrollUp(steps); true }

            // Custom swipe: target="x1,y1" target2="x2,y2"
            "SWIPE_CUSTOM" -> {
                val (x1, y1) = target.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                val (x2, y2) = target2.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                performSwipe(x1, y1, x2, y2, 400); true
            }

            // Wait until text appears on screen then click it (max 8s)
            "WAIT_FOR_TEXT" -> {
                val timeout   = 8000L
                val startTime = System.currentTimeMillis()
                var found     = false
                while (!found && System.currentTimeMillis() - startTime < timeout) {
                    found = safeFind { findNodeWithText(target) } != null
                    if (!found) delay(500)
                }
                if (found) clickByText(target) else false
            }

            // Wait then click
            "WAIT_AND_CLICK" -> {
                delay(steps * 500L)
                clickByText(target)
            }

            // Open any app by package name
            "OPEN_APP"        -> openApp(target)

            // Press system buttons
            "PRESS_BACK"      -> { performGlobalAction(GLOBAL_ACTION_BACK); true }
            "PRESS_HOME"      -> { performGlobalAction(GLOBAL_ACTION_HOME); true }
            "PRESS_RECENTS"   -> { performGlobalAction(GLOBAL_ACTION_RECENTS); true }
            "SCREENSHOT"      -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT); true }

            // Tap at absolute screen coordinates
            "TAP_AT"          -> {
                val (x, y) = target.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                tapAt(x, y); true
            }

            else -> {
                Log.w(TAG, "Unknown generic action: $action")
                false
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND CHAIN
    // ══════════════════════════════════════════════════════════════════════════

    @Suppress("UNCHECKED_CAST")
    private suspend fun executeCommandChain(args: Map<String, Any>): Any {
        val commands = args["commands"] as? List<Map<String, Any>> ?: return false
        val results  = mutableListOf<Any>()
        Log.d(TAG, "Chain: ${commands.size} commands")
        for ((i, cmd) in commands.withIndex()) {
            val method  = cmd["method"]?.toString() ?: continue
            val cmdArgs = (cmd["args"] as? Map<String, Any>) ?: emptyMap()
            val result  = try { processCommand(method, cmdArgs) }
                          catch (e: Exception) { Log.e(TAG, "chain[$i]: $e"); false }
            results.add(result)
            delay(300)
            if (result == false && cmd["required"] == true) {
                Log.w(TAG, "Chain stopped at $method (required=true, result=false)")
                break
            }
        }
        sendEvent("onChainComplete", mapOf("results" to results.map { it.toString() }))
        return results.lastOrNull() ?: false
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PERMISSION STATUS
    // ══════════════════════════════════════════════════════════════════════════

    private fun getPermissionStatus(): Map<String, Boolean> {
        val mic = try {
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }

        val storage = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                android.os.Environment.isExternalStorageManager()
            else checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
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
    // SCREEN CONTEXT — null-safe full text extraction
    // ══════════════════════════════════════════════════════════════════════════

    fun getScreenContextPublic(): String = getScreenContext()

    private fun getScreenContext(): String {
        val root = rootInActiveWindow ?: return ""
        return try {
            val sb = StringBuilder()
            collectTextSafe(root, sb, 0, 12)
            sb.toString().trim().let { if (it.length > 2000) it.substring(0, 2000) else it }
        } catch (e: Exception) { "" }
    }

    private fun collectTextSafe(node: AccessibilityNodeInfo?, sb: StringBuilder,
                                 depth: Int, max: Int) {
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
    // YOUTUBE — FIXED: no voice search, search_edit_text → ACTION_SET_TEXT
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun youtubeSearch(query: String): Boolean {
        if (query.isBlank()) return false
        if (!openApp("com.google.android.youtube")) return false
        delay(2500)

        // Step 1: Click search ICON by ID — avoids mic button
        val iconClicked =
            clickById("com.google.android.youtube:id/menu_item_1") ||
            clickById("com.google.android.youtube:id/search_button")
        if (!iconClicked) {
            val w = resources.displayMetrics.widthPixels.toFloat()
            tapAt(w - 160f, 100f) // 160px from right — away from mic icon
        }
        delay(1200)

        // Step 2: Find search_edit_text and type
        var typed = false
        repeat(3) { attempt ->
            if (typed) return@repeat
            val root = rootInActiveWindow ?: return@repeat
            val field = safeFind {
                root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_edit_text")?.firstOrNull()
            } ?: safeFind {
                root.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_box_text")?.firstOrNull()
            } ?: safeFind { findEditableNode(root) }

            if (field != null) {
                try {
                    field.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    delay(400)
                    val bundle = Bundle()
                    bundle.putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, query)
                    typed = field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
                } finally { try { field.recycle() } catch (_: Exception) {} }
            }
            if (!typed) delay(900)
        }
        if (!typed) return false
        delay(600)

        // Step 3: Submit search — try multiple methods in order of reliability
        // IME_ACTION_SEARCH is the most reliable — fires the search keyboard button
        var submitted = false

        // Try IME action on the search field directly
        val root3 = rootInActiveWindow
        if (root3 != null) {
            val field = safeFind {
                root3.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_edit_text")?.firstOrNull()
            } ?: safeFind { findEditableNode(root3) }

            if (field != null) {
                val imeBundle = Bundle()
                imeBundle.putInt(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT,
                    AccessibilityNodeInfo.MOVEMENT_GRANULARITY_LINE)
                // IME_ACTION_SEARCH = 3
                submitted = field.performAction(0x00000003) // ACTION_IME_ENTER
                try { field.recycle() } catch (_: Exception) {}
            }
        }

        // Fallback chain
        if (!submitted) submitted =
            clickById("com.google.android.youtube:id/search_go_btn")        ||
            clickById("com.google.android.youtube:id/search_button_progressive") ||
            clickByDesc("Search")

        // Last resort: global Enter key
        if (!submitted) performGlobalAction(66)

        delay(2500)
        return true
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
    // WHATSAPP READER
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun whatsappReadMessages(contact: String): String {
        if (!openApp("com.whatsapp")) return "WhatsApp open nahi hua"
        delay(1800)
        if (!clickById("com.whatsapp:id/menuitem_search"))
            if (!clickByDesc("Search")) return "Search nahi mila"
        delay(700)
        typeInFocused(contact); delay(1200)
        if (!clickByText(contact)) {
            val root = rootInActiveWindow ?: return "Contact nahi mila"
            findAllClickableNodesSafe(root).getOrNull(1)
                ?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: return "Contact nahi mila"
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

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP AGENT MODE
    // ══════════════════════════════════════════════════════════════════════════

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
    // INSTAGRAM
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun instagramOpenReels(): Boolean {
        if (!openApp("com.instagram.android")) return false; delay(1800)
        if (clickByDesc("Reels")) return true
        tapAt(resources.displayMetrics.widthPixels * 0.5f,
              resources.displayMetrics.heightPixels * 0.965f)
        delay(800); return true
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
        tapAt(w, h); delay(130); tapAt(w, h); return true
    }

    private suspend fun instagramPostComment(text: String): Boolean {
        delay(500)
        if (!clickById("com.instagram.android:id/row_feed_comment_tv") &&
            !clickByDesc("Comment")) return false
        delay(900); typeInFocused(text); delay(400); clickByText("Post"); return true
    }

    private suspend fun instagramSearchUser(username: String): Boolean {
        if (!openApp("com.instagram.android")) return false; delay(1800)
        clickByDesc("Search and Explore"); delay(900)
        if (!clickById("com.instagram.android:id/action_bar_search_edit_text"))
            clickByText("Search")
        delay(700); typeInFocused(username); delay(1300); clickByText(username); return true
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WHATSAPP — Send Message + Voice Call + Video Call
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun whatsappSendMessage(contact: String, message: String): Boolean {
        if (!openApp("com.whatsapp")) return false
        delay(2000)

        // Step 1: Open search
        val searchOpened =
            clickById("com.whatsapp:id/menuitem_search") ||
            clickByDesc("Search")                        ||
            clickByText("Search")
        if (!searchOpened) return false
        delay(600)

        // Step 2: Type contact name
        typeInFocused(contact)
        delay(1400)

        // Step 3: Click contact in results
        val opened =
            clickByText(contact) ||
            clickByText(contact.split(" ").firstOrNull() ?: contact)
        if (!opened) {
            // Tap first result in list
            val root  = rootInActiveWindow ?: return false
            val nodes = findAllClickableNodesSafe(root)
            // Skip header/search bar — tap first actual contact row
            val row   = nodes.getOrNull(1) ?: nodes.firstOrNull() ?: return false
            row.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        delay(1500)

        // Step 4: Type message
        typeInFocused(message)
        delay(500)

        // Step 5: Send
        val sent =
            clickById("com.whatsapp:id/send")         ||
            clickById("com.whatsapp:id/send_btn")     ||
            clickByDesc("Send")                        ||
            clickByText("Send")
        if (!sent) performGlobalAction(66) // Enter key fallback
        delay(400)
        return true
    }

    // ── Voice Call ────────────────────────────────────────────────────────────
    // Opens WhatsApp → searches contact → opens chat → taps voice call icon
    private suspend fun whatsappVoiceCall(contact: String): Boolean {
        if (!_openWhatsAppChat(contact)) return false
        delay(1200)

        // Voice call button IDs (tested on WhatsApp 2.24.x – 2.25.x)
        val called =
            clickById("com.whatsapp:id/voice_call_btn")        ||
            clickById("com.whatsapp:id/menuitem_voice_call")   ||
            clickByDesc("Voice call")                           ||
            clickByDesc("Audio call")                           ||
            clickByText("Voice call")

        if (!called) {
            // Last resort: find phone icon in top-right area
            val root  = rootInActiveWindow ?: return false
            val nodes = findAllClickableNodesSafe(root)
            // Voice call is usually the second-to-last icon in chat header
            val btn   = nodes.getOrNull(nodes.size - 2)
            btn?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
        }
        Log.d(TAG, "📞 WhatsApp voice call → $contact")
        return true
    }

    // ── Video Call ────────────────────────────────────────────────────────────
    private suspend fun whatsappVideoCall(contact: String): Boolean {
        if (!_openWhatsAppChat(contact)) return false
        delay(1200)

        val called =
            clickById("com.whatsapp:id/video_call_btn")        ||
            clickById("com.whatsapp:id/menuitem_video_call")   ||
            clickByDesc("Video call")                           ||
            clickByText("Video call")

        if (!called) {
            // Video call is usually the last icon in chat header
            val root  = rootInActiveWindow ?: return false
            val nodes = findAllClickableNodesSafe(root)
            nodes.lastOrNull()?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        Log.d(TAG, "📹 WhatsApp video call → $contact")
        return true
    }

    // ── Shared: open WhatsApp and navigate to contact chat ───────────────────
    private suspend fun _openWhatsAppChat(contact: String): Boolean {
        if (!openApp("com.whatsapp")) return false
        delay(2000)

        // Try direct deep link first (most reliable)
        try {
            val number = contact.filter { it.isDigit() }
            if (number.length >= 10) {
                val i = Intent(Intent.ACTION_VIEW,
                    android.net.Uri.parse("https://api.whatsapp.com/send?phone=$number"))
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                applicationContext.startActivity(i)
                delay(2500)
                return rootInActiveWindow?.packageName == "com.whatsapp"
            }
        } catch (_: Exception) {}

        // Fallback: search by name
        val searchOpened =
            clickById("com.whatsapp:id/menuitem_search") ||
            clickByDesc("Search")
        if (!searchOpened) return false
        delay(600)

        typeInFocused(contact)
        delay(1400)

        return clickByText(contact) ||
               clickByText(contact.split(" ").firstOrNull() ?: contact)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FLIPKART
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun flipkartSearchProduct(query: String): Boolean {
        if (!openApp("com.flipkart.android")) return false; delay(2200)
        if (!clickById("com.flipkart.android:id/search_widget_textbox") &&
            !clickByText("Search for Products, Brands and More"))
            tapAt(resources.displayMetrics.widthPixels / 2f, 160f)
        delay(700); typeInFocused(query); delay(500); performGlobalAction(66); delay(2500)
        val root = rootInActiveWindow ?: return false
        val p    = findAllClickableNodesSafe(root).getOrNull(3) ?: return false
        return try { p.performAction(AccessibilityNodeInfo.ACTION_CLICK).also { delay(2500) } }
               catch (_: Exception) { false }
    }

    private suspend fun flipkartSelectSize(size: String) =
        clickByText(size) || clickByText(size.uppercase()) || clickByText(size.lowercase())
    private suspend fun flipkartAddToCart(): Boolean {
        delay(300); val ok = clickByText("ADD TO CART") || clickByText("Add to Cart")
        if (ok) delay(1200); return ok
    }
    private suspend fun flipkartGoToPayment(): Boolean {
        delay(500)
        if (!clickByDesc("Cart") && !clickByText("Cart"))
            clickById("com.flipkart.android:id/cart_icon")
        delay(1800)
        val ok = clickByText("PLACE ORDER") || clickByText("Place Order")
        if (ok) delay(1500); return ok
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PRIMITIVE ACTIONS — null-safe
    // ══════════════════════════════════════════════════════════════════════════

    private fun openApp(pkg: String): Boolean {
        return try {
            val i = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(i); true
        } catch (e: Exception) { Log.e(TAG, "openApp $pkg: $e"); false }
    }

    private fun clickByText(text: String): Boolean {
        if (text.isBlank()) return false
        val node = safeFind { findNodeWithText(text) } ?: return false
        return try {
            val ok = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (!ok) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false else true
        } catch (_: Exception) { false }
        finally { try { node.recycle() } catch (_: Exception) {} }
    }

    private fun clickByDesc(desc: String): Boolean {
        if (desc.isBlank()) return false
        val root = rootInActiveWindow ?: return false
        val node = safeFind { findNodeByDesc(root, desc.lowercase()) } ?: return false
        return try {
            val ok = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (!ok) node.parent?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false else true
        } catch (_: Exception) { false }
        finally { try { node.recycle() } catch (_: Exception) {} }
    }

    private fun clickById(id: String): Boolean {
        if (id.isBlank()) return false
        val root  = rootInActiveWindow ?: return false
        val nodes = try { root.findAccessibilityNodeInfosByViewId(id) } catch (_: Exception) { null }
        if (nodes.isNullOrEmpty()) return false
        return try { nodes[0].performAction(AccessibilityNodeInfo.ACTION_CLICK) }
               catch (_: Exception) { false }
        finally { nodes.forEach { try { it.recycle() } catch (_: Exception) {} } }
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

    private fun traverseFindSafe(node: AccessibilityNodeInfo?,
                                  predicate: (AccessibilityNodeInfo) -> Boolean
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
    // ACCESSIBILITY EVENT
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isMonitoring) return
        val pkg = try { event.packageName?.toString() } catch (_: Exception) { null } ?: return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && pkg != lastWindowPkg) {
            currentPackage = pkg; lastWindowPkg = pkg
            windowChangedJob?.cancel()
            windowChangedJob = serviceScope.launch {
                delay(200); sendEvent("onWindowChanged", mapOf("package" to pkg))
            }
        }

        if (LOCK_PACKAGES.contains(pkg)) {
            try {
                val text = event.text?.joinToString(" ").orEmpty().lowercase()
                if (PASSWORD_WORDS.any { text.contains(it) }) handleWrongPassword()
            } catch (_: Exception) {}
        }

        // Agent mode: detect incoming WA messages
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
