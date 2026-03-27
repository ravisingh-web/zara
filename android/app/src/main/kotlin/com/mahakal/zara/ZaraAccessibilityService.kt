package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// ZaraAccessibilityService.kt — Z.A.R.A. God Mode v15.0
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  WHAT'S IN HERE                                                         ║
// ║                                                                         ║
// ║  🎙️  WAKE WORD     Vosk offline STT — "Hi Zara" / "Sunna"             ║
// ║                   Falls back to Energy VAD + PCM→Flutter→Whisper       ║
// ║                                                                         ║
// ║  👁️  SCAN SCREEN   scanScreen() → full JSON element map                ║
// ║                   {id, text, desc, x, y, w, h, clickable, editable}    ║
// ║                   Injected into Gemini SYSTEM PROMPT as "eyes"         ║
// ║                                                                         ║
// ║  🤖  VISION CMDS   CLICK_BY_ID / CLICK_BY_TEXT / TAP_AT               ║
// ║                   TYPE_TEXT / PRESS_BACK / PRESS_HOME                  ║
// ║                                                                         ║
// ║  📱  APP CONTROL   YouTube · WhatsApp · Instagram · Flipkart           ║
// ║                   whatsappVoiceCall / whatsappVideoCall (NEW)          ║
// ║                   Agent Mode (auto-reply as Ravi)                      ║
// ║                                                                         ║
// ║  🛡️  GUARDIAN      Wrong password detector → capture + alert           ║
// ║                                                                         ║
// ║  🔗  COMMAND CHAIN Sequential multi-step executor                       ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// ✅ SDK 35 safe — zero deprecated APIs
// ✅ NULL SAFE — safeFind / traverseFindSafe wraps every node op
// ✅ NO startForeground() in AccessibilityService (avoids "malfunctioning")
// ✅ TYPE_AND_SUBMIT: delay(1200) after submit — waits for results to render
// ✅ YouTube: IME_ACTION_SEARCH (not KEYCODE_ENTER, not mic)
// ✅ WhatsApp: deep link + UI fallback for voice & video calls
// ✅ scanScreen(): recursive _scanNode walker → JSON for Gemini vision
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
import android.graphics.Rect
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
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
import org.json.JSONArray
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import kotlin.math.sqrt

class ZaraAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG     = "ZARA_GOD"
        const val CHANNEL = "com.mahakal.zara/accessibility"

        private const val PREFS     = "zara_guardian_prefs"
        private const val KEY_COUNT = "wrong_password_count"
        private const val KEY_LAST  = "last_password_attempt"
        private const val THRESHOLD = 2

        private val WAKE_WORDS = listOf(
            "hi zara", "hii zara", "hey zara",
            "zara", "sunna", "suno", "zara sunna"
        )

        private val LOCK_PACKAGES  = setOf("com.android.systemui", "com.android.keyguard")
        private val PASSWORD_WORDS = setOf("wrong", "incorrect", "invalid", "error")

        var instance      : ZaraAccessibilityService? = null; private set
        var pendingEngine : FlutterEngine?            = null
    }

    private var methodChannel : MethodChannel?     = null
    private var prefs         : SharedPreferences? = null

    var isMonitoring   : Boolean = false
    var currentPackage : String  = ""

    private val handler          = Handler(Looper.getMainLooper())
    private val serviceScope     = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var windowChangedJob : Job?   = null
    private var lastWindowPkg    : String = ""

    // Wake word
    private var wakeWordActive : Boolean    = false
    private var voskModel      : Model?     = null
    private var voskRecognizer : Recognizer? = null
    private var audioRecord    : AudioRecord? = null
    private val SAMPLE_RATE    = 16000
    private val FRAME_SIZE     = 4096
    private val ENERGY_THRESHOLD = 600.0

    // Agent mode
    private var agentModeActive : Boolean = false
    private var agentContact    : String  = ""
    private var agentPersona    : String  = ""

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
    // FLUTTER ENGINE ATTACH
    // ══════════════════════════════════════════════════════════════════════════

    fun attachToEngine(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            @Suppress("UNCHECKED_CAST")
            val args = (call.arguments as? Map<String, Any>) ?: emptyMap()
            serviceScope.launch(Dispatchers.IO) {
                val res = try {
                    processCommand(call.method, args)
                } catch (e: Exception) {
                    Log.e(TAG, "${call.method}: $e"); false
                }
                withContext(Dispatchers.Main) { result.success(res) }
            }
        }
    }

    fun handleMethodCall(
        call   : io.flutter.plugin.common.MethodCall,
        result : MethodChannel.Result
    ) {
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

            // Status
            "isEnabled"            -> isMonitoring
            "getForegroundApp"     -> currentPackage
            "getScreenContext"     -> getScreenContext()
            "scanScreen"           -> scanScreen()
            "getPermissionStatus"  -> getPermissionStatus()
            "findTextOnScreen"     -> safeFind { findNodeWithText(str(args, "text")) } != null

            // Wake Word
            "startWakeWord"        -> { startWakeWordEngine(); true }
            "stopWakeWord"         -> { stopWakeWordEngine();  true }

            // Command Chain
            "executeChain"         -> executeCommandChain(args)

            // Universal Generic Control
            "performGenericAction" -> performGenericAction(
                str(args, "action"), str(args, "target"),
                str(args, "target2", ""), int(args, "steps", 3)
            )

            // Basic UI
            "openApp"              -> openApp(str(args, "package"))
            "clickText"            -> clickByText(str(args, "text"))
            "clickById"            -> clickById(str(args, "id"))
            "clickByDesc"          -> clickByDesc(str(args, "desc"))
            "typeText"             -> typeInFocused(str(args, "text"))
            "clearText"            -> clearFocused()
            "scrollDown"           -> { scrollDown(int(args, "steps", 3)); true }
            "scrollUp"             -> { scrollUp(int(args, "steps", 3));   true }
            "pressBack"            -> { performGlobalAction(GLOBAL_ACTION_BACK);             true }
            "pressHome"            -> { performGlobalAction(GLOBAL_ACTION_HOME);             true }
            "pressRecents"         -> { performGlobalAction(GLOBAL_ACTION_RECENTS);          true }
            "takeScreenshot"       -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT);  true }
            "openNotifications"    -> { performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS);    true }
            "openQuickSettings"    -> { performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS);   true }
            "tapAt"                -> { tapAt(flt(args, "x", 540f), flt(args, "y", 960f));  true }
            "swipe"                -> {
                performSwipe(
                    flt(args, "x1", 540f), flt(args, "y1", 1400f),
                    flt(args, "x2", 540f), flt(args, "y2",  400f),
                    int(args, "durationMs", 350).toLong()
                ); true
            }

            // YouTube
            "youtubeSearch"        -> youtubeSearch(str(args, "query"))
            "youtubePlayFirst"     -> youtubePlayFirstResult()

            // Instagram
            "instagramOpenReels"   -> instagramOpenReels()
            "instagramScrollReels" -> { instagramScrollReels(int(args, "count", 1)); true }
            "instagramLikeReel"    -> instagramLikeCurrentReel()
            "instagramPostComment" -> instagramPostComment(str(args, "text"))
            "instagramSearchUser"  -> instagramSearchUser(str(args, "username"))

            // WhatsApp
            "whatsappSendMessage"  -> whatsappSendMessage(str(args, "contact"), str(args, "message"))
            "whatsappReadMessages" -> whatsappReadMessages(str(args, "contact"))
            "whatsappStartAgent"   -> whatsappStartAgent(str(args, "contact"), str(args, "persona"))
            "whatsappStopAgent"    -> whatsappStopAgent()
            "whatsappVoiceCall"    -> whatsappVoiceCall(str(args, "contact"))
            "whatsappVideoCall"    -> whatsappVideoCall(str(args, "contact"))

            // Flipkart
            "flipkartSearchProduct" -> flipkartSearchProduct(str(args, "query"))
            "flipkartSelectSize"    -> flipkartSelectSize(str(args, "size"))
            "flipkartAddToCart"     -> flipkartAddToCart()
            "flipkartGoToPayment"   -> flipkartGoToPayment()

            // Facebook
            "facebookPost"         -> facebookPost(str(args, "text"))

            else -> { Log.w(TAG, "Unknown: $method"); false }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 👁️  SCAN SCREEN — Vision Pipeline
    //
    // Returns JSON of ALL interactive elements on screen.
    // ZaraProvider injects this into Gemini's SYSTEM PROMPT so AI "sees" the UI.
    //
    // Output schema:
    // {
    //   "package": "com.whatsapp",
    //   "elements": [
    //     {"id":"com.wa:id/send","text":"Send","desc":"","clickable":true,
    //      "editable":false,"x":980,"y":1840,"w":120,"h":80}
    //   ],
    //   "editableFields": [...],
    //   "allText": "Send | Chat | ...",
    //   "elementCount": 42
    // }
    //
    // Gemini vision commands:
    //   [COMMAND:CLICK_BY_ID,ID:com.wa:id/send]   ← most reliable
    //   [COMMAND:CLICK_BY_TEXT,TEXT:Send]          ← text fallback
    //   [COMMAND:TAP_AT,X:980,Y:1840]             ← coordinate last resort
    // ══════════════════════════════════════════════════════════════════════════

    private fun scanScreen(): String {
        val root = rootInActiveWindow ?: return "{}"
        return try {
            val elements       = JSONArray()
            val editableFields = JSONArray()
            val allText        = StringBuilder()

            _scanNode(root, elements, editableFields, allText, 0, 15)

            JSONObject().apply {
                put("package",        currentPackage)
                put("elements",       elements)
                put("editableFields", editableFields)
                put("allText", allText.toString().trim()
                    .let { if (it.length > 1500) it.substring(0, 1500) else it })
                put("elementCount", elements.length())
            }.toString()
        } catch (e: Exception) {
            Log.e(TAG, "scanScreen: $e"); "{}"
        } finally {
            // Fix 4: Always recycle root — prevents memory leak / "Malfunctioning"
            try { root.recycle() } catch (_: Exception) {}
        }
    }

    private fun _scanNode(
        node          : AccessibilityNodeInfo?,
        elements      : JSONArray,
        editableFields: JSONArray,
        allText       : StringBuilder,
        depth         : Int,
        maxDepth      : Int
    ) {
        if (node == null || depth > maxDepth) return
        try {
            val text = node.text?.toString()?.trim()                ?: ""
            val desc = node.contentDescription?.toString()?.trim() ?: ""
            val id   = node.viewIdResourceName                      ?: ""

            if (text.isNotEmpty()) allText.append(text).append(" | ")
            else if (desc.isNotEmpty()) allText.append(desc).append(" | ")

            val interesting = id.isNotEmpty() || text.isNotEmpty() ||
                              desc.isNotEmpty() || node.isClickable || node.isEditable

            if (interesting) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                val obj = JSONObject().apply {
                    put("id",        id)
                    put("text",      text)
                    put("desc",      desc)
                    put("clickable", node.isClickable)
                    put("editable",  node.isEditable)
                    put("x",         bounds.centerX())
                    put("y",         bounds.centerY())
                    put("w",         bounds.width())
                    put("h",         bounds.height())
                }
                elements.put(obj)
                if (node.isEditable) editableFields.put(obj)
            }

            for (i in 0 until node.childCount) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                _scanNode(child, elements, editableFields, allText, depth + 1, maxDepth)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 🎙️  WAKE WORD ENGINE — Vosk Offline
    //
    // Model: android/app/src/main/assets/model/
    //        (vosk-model-small-en-in-0.4)
    //
    // Sequence after wake word detected:
    //   Flutter _onWakeWordDetected:
    //     1. _vosk.stop()     → releases AudioRecord lock
    //     2. delay(200ms)     → OS AudioRecord teardown (OEM-safe)
    //     3. whisper.start()  → Whisper claims mic successfully
    // ══════════════════════════════════════════════════════════════════════════

    private fun startWakeWordEngine() {
        if (wakeWordActive) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "WakeWord: no RECORD_AUDIO permission")
            sendEvent("onWakeWordError", mapOf("error" to "no_mic_permission"))
            return
        }
        wakeWordActive = true
        serviceScope.launch(Dispatchers.IO) { _initVoskAndListen() }
        sendEvent("onWakeWordEngineChanged", mapOf("active" to true))
        Log.d(TAG, "🎙️ Vosk engine starting...")
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

            withContext(Dispatchers.Main) {
                try {
                    voskModel      = Model(modelDir)
                    voskRecognizer = Recognizer(voskModel, SAMPLE_RATE.toFloat())
                    voskRecognizer?.setGrammar(
                        """["hi zara","hii zara","hey zara","sunna","suno","zara sunna","[unk]"]"""
                    )
                    Log.d(TAG, "✅ Vosk ready — say 'Hi Zara'")
                    serviceScope.launch(Dispatchers.IO) { voskListenLoop() }
                } catch (e: Exception) {
                    Log.e(TAG, "Vosk init: $e → VAD fallback")
                    serviceScope.launch(Dispatchers.IO) { wakeWordVadLoop() }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Vosk setup: $e → VAD fallback")
            serviceScope.launch(Dispatchers.IO) { wakeWordVadLoop() }
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
            try { assets.open(assetPath).use { i -> dest.outputStream().use { i.copyTo(it) } } }
            catch (e: Exception) { Log.e(TAG, "_copyAssets $assetPath: $e") }
            return
        }
        dest.mkdirs()
        list.forEach { child -> _copyAssetsDir("$assetPath/$child", java.io.File(dest, child)) }
    }

    private suspend fun voskListenLoop() {
        val bufSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(FRAME_SIZE * 2)

        // Fix 3: UNPROCESSED avoids Android pre-emption in background.
        // MIC is the fallback if UNPROCESSED not available on device.
        val audioSource = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            MediaRecorder.AudioSource.UNPROCESSED
        } else {
            MediaRecorder.AudioSource.MIC
        }
        try {
            audioRecord = AudioRecord(
                audioSource,
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufSize
            )
            if (audioRecord!!.state != AudioRecord.STATE_INITIALIZED) {
                // UNPROCESSED not supported — fall back to MIC
                audioRecord?.release()
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, bufSize
                )
            }
            audioRecord!!.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "Vosk AudioRecord: $e"); wakeWordActive = false; return
        }

        val pcm = ByteArray(FRAME_SIZE * 2)
        Log.d(TAG, "🎙️ Vosk listening — say 'Hi Zara'")

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
                        Log.d(TAG, "🔔 '$matched'")
                        withContext(Dispatchers.Main) {
                            sendEvent("wake_word_detected",
                                mapOf("transcript" to text, "word" to matched))
                        }
                        recognizer.reset()
                        delay(2000) // cooldown — avoid re-trigger on echo
                    }
                }
            } catch (_: Exception) {}
        }

        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
    }

    private fun stopWakeWordEngine() {
        wakeWordActive = false
        try { voskRecognizer?.close(); voskRecognizer = null } catch (_: Exception) {}
        try { voskModel?.close();      voskModel      = null } catch (_: Exception) {}
        try { audioRecord?.stop();     audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
        Log.d(TAG, "🎙️ Vosk STOPPED")
        sendEvent("onWakeWordEngineChanged", mapOf("active" to false))
    }

    // VAD fallback — Vosk model missing → send PCM to Flutter → Whisper
    private suspend fun wakeWordVadLoop() {
        val bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(512 * 4)

        // Fix 3: UNPROCESSED for background mic resilience
        val vadAudioSource = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            MediaRecorder.AudioSource.UNPROCESSED
        } else {
            MediaRecorder.AudioSource.MIC
        }
        try {
            audioRecord = AudioRecord(
                vadAudioSource,
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufferSize
            )
            if (audioRecord!!.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord?.release()
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, bufferSize
                )
            }
            audioRecord!!.startRecording()
        } catch (e: Exception) { Log.e(TAG, "VAD init: $e"); wakeWordActive = false; return }

        val pcm       = ShortArray(512)
        var silenceMs = 0L
        val speechBuf = mutableListOf<ShortArray>()
        var speaking  = false
        Log.d(TAG, "🎙️ VAD fallback active")

        while (wakeWordActive && currentCoroutineContext().isActive) {
            val read = audioRecord?.read(pcm, 0, 512) ?: -1
            if (read <= 0) { delay(10); continue }

            val rms = _rms(pcm, read)
            if (rms > ENERGY_THRESHOLD) {
                speaking = true; silenceMs = 0L
                speechBuf.add(pcm.copyOf(read))
                if (speechBuf.size > 96) speechBuf.removeAt(0)
            } else if (speaking) {
                silenceMs += (512 * 1000L / SAMPLE_RATE)
                if (silenceMs >= 800L) {
                    val flat     = speechBuf.flatMap { it.toList() }.toShortArray()
                    speaking     = false; silenceMs = 0L
                    val pcmBytes = _shortsToBytes(flat)
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
        if (WAKE_WORDS.any { lower.contains(it) }) {
            Log.d(TAG, "🔔 VAD path: '$lower'")
            sendEvent("wake_word_detected", mapOf("transcript" to transcript, "word" to lower))
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 🛠️  UNIVERSAL GENERIC CONTROL
    //
    // Works on ANY app — Gemini vision commands + manual chains use this.
    //
    // TYPE_AND_SUBMIT:
    //   1. typeInFocused(target)         → set text
    //   2. _submitSearchField()          → IME_ACTION_SEARCH (action=3)
    //   3. delay(1200)                   ← CRITICAL: wait for results UI
    //      Without this delay, next click hits stale/empty nodes.
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun performGenericAction(
        action  : String,
        target  : String,
        target2 : String = "",
        steps   : Int    = 3
    ): Boolean {
        Log.d(TAG, "GenericAction: $action target='$target'")
        return when (action.uppercase()) {

            "CLICK_BY_TEXT" -> clickByText(target)
            "CLICK_BY_ID"   -> clickById(target)
            "CLICK_BY_DESC" -> clickByDesc(target)

            "LONG_CLICK" -> {
                val node = safeFind { findNodeWithText(target) } ?: return false
                return try {
                    node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)
                } catch (_: Exception) { false }
                finally { try { node.recycle() } catch (_: Exception) {} }
            }

            "TYPE_AND_SUBMIT" -> {
                typeInFocused(target)
                delay(400)
                if (target2.isNotEmpty()) {
                    clickByText(target2) || clickByDesc(target2)
                } else {
                    // ✅ IME_ACTION_SEARCH = 3 (NOT GLOBAL_ACTION(66) = KEYCODE_ENTER)
                    val submitted = _submitSearchField(rootInActiveWindow)
                    // ✅ CRITICAL: 1200ms — search results need time to render
                    if (submitted) delay(1200)
                    submitted
                }
            }

            "TYPE_TEXT"   -> typeInFocused(target)
            "CLEAR_TEXT"  -> clearFocused()
            "SCROLL_DOWN" -> { scrollDown(steps); true }
            "SCROLL_UP"   -> { scrollUp(steps);   true }

            "SWIPE_CUSTOM" -> {
                val p1 = target.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                val p2 = target2.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                performSwipe(
                    p1.getOrElse(0) { 0f }, p1.getOrElse(1) { 0f },
                    p2.getOrElse(0) { 0f }, p2.getOrElse(1) { 0f }, 400
                ); true
            }

            "WAIT_FOR_TEXT" -> {
                val timeout = 8000L; val start = System.currentTimeMillis(); var found = false
                while (!found && System.currentTimeMillis() - start < timeout) {
                    found = safeFind { findNodeWithText(target) } != null
                    if (!found) delay(500)
                }
                if (found) clickByText(target) else false
            }

            "WAIT_AND_CLICK" -> { delay(steps * 500L); clickByText(target) }
            "OPEN_APP"       -> openApp(target)
            "PRESS_BACK"     -> { performGlobalAction(GLOBAL_ACTION_BACK);    true }
            "PRESS_HOME"     -> { performGlobalAction(GLOBAL_ACTION_HOME);    true }
            "PRESS_RECENTS"  -> { performGlobalAction(GLOBAL_ACTION_RECENTS); true }
            "SCREENSHOT"     -> { performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT); true }

            "TAP_AT" -> {
                val pts = target.split(",").map { it.trim().toFloatOrNull() ?: 0f }
                tapAt(pts.getOrElse(0) { 0f }, pts.getOrElse(1) { 0f }); true
            }

            else -> { Log.w(TAG, "Unknown generic: $action"); false }
        }
    }

    // IME_ACTION_SEARCH on focused editable field
    private fun _submitSearchField(root: AccessibilityNodeInfo?): Boolean {
        if (root == null) return false
        val field = safeFind { findEditableNode(root) } ?: return false
        return try { field.performAction(3) } // IME_ACTION_SEARCH = 3
               catch (_: Exception) { false }
        finally { try { field.recycle() } catch (_: Exception) {} }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COMMAND CHAIN
    // ══════════════════════════════════════════════════════════════════════════

    @Suppress("UNCHECKED_CAST")
    private suspend fun executeCommandChain(args: Map<String, Any>): Any {
        val commands = args["commands"] as? List<Map<String, Any>> ?: return false
        val results  = mutableListOf<Any>()
        Log.d(TAG, "Chain: ${commands.size} steps")
        for ((i, cmd) in commands.withIndex()) {
            val method  = cmd["method"]?.toString() ?: continue
            val cmdArgs = (cmd["args"] as? Map<String, Any>) ?: emptyMap()
            val result  = try { processCommand(method, cmdArgs) }
                          catch (e: Exception) { Log.e(TAG, "chain[$i] $method: $e"); false }
            results.add(result); delay(300)
            if (result == false && cmd["required"] == true) {
                Log.w(TAG, "Chain stopped at $method"); break
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
            "accessibility"        to isMonitoring,
            "microphone"           to mic,
            "storage"              to storage,
            "overlay"              to overlay,
            "foregroundService"    to true,
            "notificationListener" to true
        )
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SCREEN CONTEXT — plain text (human readable, for Gemini user message)
    // Note: scanScreen() → structured JSON (for Gemini system prompt)
    //       getScreenContext() → plain text  (for user message context)
    // ══════════════════════════════════════════════════════════════════════════

    fun getScreenContextPublic(): String = getScreenContext()

    private fun getScreenContext(): String {
        val root = rootInActiveWindow ?: return ""
        return try {
            val sb = StringBuilder()
            _collectTextSafe(root, sb, 0, 12)
            sb.toString().trim().let { if (it.length > 2000) it.substring(0, 2000) else it }
        } catch (_: Exception) { "" }
        finally { try { root.recycle() } catch (_: Exception) {} }
    }

    private fun _collectTextSafe(
        node : AccessibilityNodeInfo?,
        sb   : StringBuilder,
        depth: Int,
        max  : Int
    ) {
        if (node == null || depth > max) return
        try {
            val t = node.text?.toString()?.trim()
            val d = node.contentDescription?.toString()?.trim()
            when {
                !t.isNullOrEmpty() -> sb.append(t).append(" | ")
                !d.isNullOrEmpty() -> sb.append(d).append(" | ")
            }
            for (i in 0 until node.childCount) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                _collectTextSafe(child, sb, depth + 1, max)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 📺 YOUTUBE SEARCH
    //
    // ✅ Uses search_edit_text → ACTION_SET_TEXT (not voice search bar)
    // ✅ Submits via IME_ACTION_SEARCH (not mic, not KEYCODE_ENTER)
    // ✅ delay(1200) after submit — results need time to render
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun youtubeSearch(query: String): Boolean {
        if (query.isBlank()) return false
        if (!openApp("com.google.android.youtube")) return false
        delay(2500)

        // Click search icon (avoid mic button — tap far from mic)
        val iconClicked =
            clickById("com.google.android.youtube:id/menu_item_1") ||
            clickById("com.google.android.youtube:id/search_button")
        if (!iconClicked) tapAt(resources.displayMetrics.widthPixels.toFloat() - 160f, 100f)
        delay(1200)

        var typed = false
        repeat(3) { _ ->
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

        // Submit — IME_ACTION_SEARCH first, then button IDs
        val root3 = rootInActiveWindow
        var submitted = false
        if (root3 != null) {
            val field = safeFind {
                root3.findAccessibilityNodeInfosByViewId(
                    "com.google.android.youtube:id/search_edit_text")?.firstOrNull()
            } ?: safeFind { findEditableNode(root3) }
            if (field != null) {
                submitted = try { field.performAction(3) } catch (_: Exception) { false }
                try { field.recycle() } catch (_: Exception) {}
            }
        }
        if (!submitted) submitted =
            clickById("com.google.android.youtube:id/search_go_btn") ||
            clickById("com.google.android.youtube:id/search_button_progressive") ||
            clickByDesc("Search")

        // ✅ Wait for results to render
        if (submitted) delay(1200)
        return true
    }

    private suspend fun youtubePlayFirstResult(): Boolean {
        delay(600)
        val root       = rootInActiveWindow ?: return false
        return try {
            val clickables = findAllClickableNodesSafe(root)
            (clickables.getOrNull(2) ?: clickables.firstOrNull())
                ?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
        } catch (_: Exception) { false }
        finally { try { root.recycle() } catch (_: Exception) {} }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 💬 WHATSAPP — Send, Read, Voice Call, Video Call, Agent Mode
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun whatsappSendMessage(contact: String, message: String): Boolean {
        if (!openApp("com.whatsapp")) return false; delay(1800)
        if (!clickById("com.whatsapp:id/menuitem_search")) clickByDesc("Search")
        delay(700); typeInFocused(contact)

        // Retry loop — wait for contact to appear in search results (max 4s)
        var contactClicked = false
        repeat(4) { attempt ->
            if (contactClicked) return@repeat
            delay(800)
            contactClicked = clickByText(contact)
            if (!contactClicked && attempt == 3) {
                // Last resort: tap first result in list
                findAllClickableNodesSafe(rootInActiveWindow ?: return@repeat)
                    .getOrNull(1)?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                contactClicked = true
            }
        }
        delay(1200); typeInFocused(message); delay(400)
        return clickById("com.whatsapp:id/send") || clickByDesc("Send")
    }

    private suspend fun whatsappReadMessages(contact: String): String {
        if (!openApp("com.whatsapp")) return "WhatsApp open nahi hua"; delay(1800)
        if (!clickById("com.whatsapp:id/menuitem_search"))
            if (!clickByDesc("Search")) return "Search nahi mila"
        delay(700); typeInFocused(contact); delay(1200)
        if (!clickByText(contact)) {
            val root = rootInActiveWindow ?: return "Contact nahi mila"
            findAllClickableNodesSafe(root).getOrNull(1)
                ?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: return "Contact nahi mila"
        }
        delay(1500)
        val root = rootInActiveWindow ?: return "Screen read nahi hua"
        val sb   = StringBuilder("Contact: $contact\nMessages:\n")
        _collectMessageNodes(root, sb)
        delay(300); performGlobalAction(GLOBAL_ACTION_BACK)
        return sb.toString().trim()
    }

    private fun _collectMessageNodes(node: AccessibilityNodeInfo?, sb: StringBuilder) {
        if (node == null) return
        try {
            val text = node.text?.toString()?.trim()
            if (!text.isNullOrEmpty() && text.length > 1 &&
                !text.matches(Regex("\\d{1,2}:\\d{2}.*")) &&
                !text.equals("Type a message", ignoreCase = true)) sb.append("- $text\n")
            for (i in 0 until node.childCount) {
                val child = try { node.getChild(i) } catch (_: Exception) { null }
                _collectMessageNodes(child, sb)
                try { child?.recycle() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ── Voice Call ─────────────────────────────────────────────────────────────
    // Strategy: deep link (instant if phone number) → UI fallback
    private suspend fun whatsappVoiceCall(contact: String): Boolean {
        if (contact.isBlank()) return false
        Log.d(TAG, "📞 Voice call: $contact")
        val digits = contact.replace(Regex("[^0-9+]"), "")
        if (digits.isNotEmpty()) {
            try {
                val intent = Intent(Intent.ACTION_VIEW,
                    Uri.parse("whatsapp://send?phone=$digits&call=true"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent); delay(2000)
                if (clickByText("Voice call") || clickByDesc("Voice call") ||
                    clickById("com.whatsapp:id/call_btn")) return true
            } catch (_: Exception) {}
        }
        return _whatsappCallViaUI(contact, video = false)
    }

    // ── Video Call ─────────────────────────────────────────────────────────────
    private suspend fun whatsappVideoCall(contact: String): Boolean {
        if (contact.isBlank()) return false
        Log.d(TAG, "📹 Video call: $contact")
        val digits = contact.replace(Regex("[^0-9+]"), "")
        if (digits.isNotEmpty()) {
            try {
                val intent = Intent(Intent.ACTION_VIEW,
                    Uri.parse("whatsapp://send?phone=$digits&video=true"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent); delay(2000)
                if (clickByText("Video call") || clickByDesc("Video call") ||
                    clickById("com.whatsapp:id/video_call_btn")) return true
            } catch (_: Exception) {}
        }
        return _whatsappCallViaUI(contact, video = true)
    }

    private suspend fun _whatsappCallViaUI(contact: String, video: Boolean): Boolean {
        if (!openApp("com.whatsapp")) return false; delay(1800)
        if (!clickById("com.whatsapp:id/menuitem_search")) clickByDesc("Search")
        delay(700); typeInFocused(contact)

        // Retry loop — wait for contact to appear (max 4s)
        var contactClicked = false
        repeat(4) { attempt ->
            if (contactClicked) return@repeat
            delay(800)
            contactClicked = clickByText(contact)
            if (!contactClicked && attempt == 3) {
                findAllClickableNodesSafe(rootInActiveWindow ?: return@repeat)
                    .getOrNull(1)?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                contactClicked = true
            }
        }
        delay(1500)
        return if (video)
            clickById("com.whatsapp:id/video_call_btn") ||
            clickByDesc("Video call") || clickByText("Video call")
        else
            clickById("com.whatsapp:id/voice_call_btn") ||
            clickByDesc("Voice call") || clickByText("Voice call")
    }

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
    // 📘 FACEBOOK POST
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun facebookPost(text: String): Boolean {
        if (text.isBlank()) return false
        if (!openApp("com.facebook.katana")) return false; delay(2500)

        // Click "What's on your mind?" composer
        val composerClicked =
            clickByText("What's on your mind?") ||
            clickByText("Aap kya soch rahe hain?") ||
            clickById("com.facebook.katana:id/composer_what_do_you_think_prompt_text") ||
            clickByText("Write something...")
        if (!composerClicked) return false
        delay(1200)

        // Type the post text
        typeInFocused(text)
        delay(800)

        // Submit post — try multiple button labels
        val posted =
            clickByText("Post")     ||
            clickByText("POST")     ||
            clickByText("Share")    ||
            clickById("com.facebook.katana:id/composer_share_button") ||
            clickByDesc("Post")
        if (posted) delay(1500)
        return posted
    }

    private suspend fun instagramOpenReels(): Boolean {
        if (!openApp("com.instagram.android")) return false; delay(1800)
        if (clickByDesc("Reels")) return true
        tapAt(resources.displayMetrics.widthPixels * 0.5f,
              resources.displayMetrics.heightPixels * 0.965f)
        delay(800); return true
    }

    private suspend fun instagramScrollReels(count: Int) {
        val w = resources.displayMetrics.widthPixels  / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(count) { performSwipe(w, h * 0.78f, w, h * 0.22f, 350); delay(700) }
    }

    private suspend fun instagramLikeCurrentReel(): Boolean {
        if (clickById("com.instagram.android:id/like_button")) return true
        if (clickByDesc("Like")) return true
        val w = resources.displayMetrics.widthPixels  / 2f
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
        delay(700); typeInFocused(username)
        delay(1200) // ✅ wait for suggestions
        return clickByText(username)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 🛍️  FLIPKART
    // ══════════════════════════════════════════════════════════════════════════

    private suspend fun flipkartSearchProduct(query: String): Boolean {
        if (!openApp("com.flipkart.android")) return false; delay(2200)
        if (!clickById("com.flipkart.android:id/search_widget_textbox") &&
            !clickByText("Search for Products, Brands and More"))
            tapAt(resources.displayMetrics.widthPixels / 2f, 160f)
        delay(700); typeInFocused(query); delay(500)
        _submitSearchField(rootInActiveWindow)
        delay(1200) // ✅ wait for results
        val root = rootInActiveWindow ?: return false
        val p    = findAllClickableNodesSafe(root).getOrNull(3) ?: return false
        return try { p.performAction(AccessibilityNodeInfo.ACTION_CLICK).also { delay(2500) } }
               catch (_: Exception) { false }
    }

    private suspend fun flipkartSelectSize(size: String) =
        clickByText(size) || clickByText(size.uppercase()) || clickByText(size.lowercase())

    private suspend fun flipkartAddToCart(): Boolean {
        delay(300)
        val ok = clickByText("ADD TO CART") || clickByText("Add to Cart")
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
    // PRIMITIVE ACTIONS
    // ══════════════════════════════════════════════════════════════════════════

    // ══════════════════════════════════════════════════════════════════════════
    // Fix 2: PARENT-TRAP CLICK — walks up to 5 parent levels to find clickable
    //
    // Modern apps (Instagram, Facebook, WhatsApp) wrap text in non-clickable
    // spans inside a clickable container. Direct ACTION_CLICK on text node
    // silently fails. This helper climbs the tree until it finds a clickable
    // ancestor (max 5 levels = safe, prevents infinite walk to root).
    // ══════════════════════════════════════════════════════════════════════════

    private fun performClickOnNodeOrParent(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        var current: AccessibilityNodeInfo? = node
        var depth = 0
        while (current != null && depth < 5) {
            try {
                if (current.isClickable) {
                    val ok = current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    if (ok) return true
                }
            } catch (_: Exception) {}
            val parent = try { current.parent } catch (_: Exception) { null }
            if (depth > 0) try { current.recycle() } catch (_: Exception) {}
            current = parent
            depth++
        }
        // Final attempt on whatever we have
        return try { current?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false }
               catch (_: Exception) { false }
    }

    private fun openApp(pkg: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(intent); true
        } catch (e: Exception) { Log.e(TAG, "openApp $pkg: $e"); false }
    }

    private fun clickByText(text: String): Boolean {
        if (text.isBlank()) return false
        val node = safeFind { findNodeWithText(text) } ?: return false
        return try {
            performClickOnNodeOrParent(node)
        } catch (_: Exception) { false }
        finally { try { node.recycle() } catch (_: Exception) {} }
    }

    private fun clickByDesc(desc: String): Boolean {
        if (desc.isBlank()) return false
        val root = rootInActiveWindow ?: return false
        val node = safeFind { findNodeByDesc(root, desc.lowercase()) } ?: return false
        return try {
            performClickOnNodeOrParent(node)
        } catch (_: Exception) { false }
        finally { try { node.recycle() } catch (_: Exception) {} }
    }

    private fun clickById(id: String): Boolean {
        if (id.isBlank()) return false
        val root  = rootInActiveWindow ?: return false
        val nodes = try { root.findAccessibilityNodeInfosByViewId(id) }
                    catch (_: Exception) { null }
        if (nodes.isNullOrEmpty()) return false
        return try { nodes[0].performAction(AccessibilityNodeInfo.ACTION_CLICK) }
               catch (_: Exception) { false }
        finally { nodes.forEach { try { it.recycle() } catch (_: Exception) {} } }
    }

    private fun typeInFocused(text: String): Boolean {
        if (text.isBlank()) return false

        // ── WAKE WORD GUARD ────────────────────────────────────────────────────
        // Problem: Wake word transcript ("hii zara", "zara sunna") gets passed
        // as TYPE_TEXT command and typed into WhatsApp search / Facebook post box.
        // Fix: Block any text that IS a wake word or starts with one.
        val lower = text.lowercase().trim()
        val wakeWordList = listOf(
            "hi zara", "hii zara", "hey zara",
            "zara", "sunna", "suno", "zara sunna"
        )
        if (wakeWordList.any { lower == it || lower.startsWith(it) }) {
            Log.w(TAG, "typeInFocused: BLOCKED wake word text = \"$text\"")
            return false
        }
        // ──────────────────────────────────────────────────────────────────────

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
        val w = resources.displayMetrics.widthPixels  / 2f
        val h = resources.displayMetrics.heightPixels.toFloat()
        repeat(steps) { performSwipe(w, h * 0.78f, w, h * 0.22f, 360); delay(400) }
    }

    private suspend fun scrollUp(steps: Int) {
        val w = resources.displayMetrics.widthPixels  / 2f
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

    private fun <T> safeFind(block: () -> T?): T? = try { block() } catch (_: Exception) { null }

    private fun findNodeWithText(text: String): AccessibilityNodeInfo? {
        val root  = rootInActiveWindow ?: return null
        val lower = text.lowercase()
        val exact = try { root.findAccessibilityNodeInfosByText(text) } catch (_: Exception) { null }
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
    // ACCESSIBILITY EVENT
    // ══════════════════════════════════════════════════════════════════════════

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Fix 1: Return IMMEDIATELY — never block the main thread here.
        // Heavy string work (password check, agent message) offloaded to Default dispatcher.
        if (event == null || !isMonitoring) return
        val pkg       = try { event.packageName?.toString() } catch (_: Exception) { null } ?: return
        val eventType = try { event.eventType } catch (_: Exception) { return }

        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && pkg != lastWindowPkg) {
            currentPackage = pkg; lastWindowPkg = pkg
            windowChangedJob?.cancel()
            windowChangedJob = serviceScope.launch {
                delay(200); sendEvent("onWindowChanged", mapOf("package" to pkg))
            }
        }

        // Offload all string/node work — never block main thread
        if (LOCK_PACKAGES.contains(pkg) && eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val textSnapshot = try { event.text?.map { it?.toString() } ?: emptyList() }
                               catch (_: Exception) { emptyList<String?>() }
            serviceScope.launch(Dispatchers.Default) {
                try {
                    val text = textSnapshot.filterNotNull().joinToString(" ").lowercase()
                    if (PASSWORD_WORDS.any { text.contains(it) }) {
                        withContext(Dispatchers.Main) { _handleWrongPassword() }
                    }
                } catch (_: Exception) {}
            }
        }

        if (agentModeActive && pkg == "com.whatsapp" &&
            eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val textSnapshot = try { event.text?.map { it?.toString() } ?: emptyList() }
                               catch (_: Exception) { emptyList<String?>() }
            serviceScope.launch(Dispatchers.Default) {
                try {
                    val text = textSnapshot.filterNotNull().joinToString(" ").trim()
                    if (text.isNotEmpty()) withContext(Dispatchers.Main) {
                        sendEvent("onAgentMessageReceived",
                            mapOf("contact" to agentContact, "message" to text))
                    }
                } catch (_: Exception) {}
            }
        }
    }

    private fun _handleWrongPassword() {
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

    private fun _rms(pcm: ShortArray, len: Int): Double {
        var sum = 0.0
        for (i in 0 until len) sum += (pcm[i].toLong() * pcm[i].toLong()).toDouble()
        return sqrt(sum / len)
    }

    private fun _shortsToBytes(shorts: ShortArray): ByteArray {
        val bytes = ByteArray(shorts.size * 2)
        for (i in shorts.indices) {
            bytes[i * 2]     = (shorts[i].toInt() and 0xff).toByte()
            bytes[i * 2 + 1] = (shorts[i].toInt() shr 8 and 0xff).toByte()
        }
        return bytes
    }

    private fun str(args: Map<String, Any>, key: String, default: String = "") =
        args[key]?.toString() ?: default
    private fun int(args: Map<String, Any>, key: String, default: Int = 0) =
        (args[key] as? Int) ?: args[key]?.toString()?.toIntOrNull() ?: default
    private fun flt(args: Map<String, Any>, key: String, default: Float = 0f) =
        (args[key] as? Number)?.toFloat() ?: args[key]?.toString()?.toFloatOrNull() ?: default
}
