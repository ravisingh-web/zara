package com.mahakal.zara

// ══════════════════════════════════════════════════════════════════════════════
// ZaraForegroundService.kt — v5.0
//
// OVERLAY ORB — always visible on top of every app:
// ✅ System-level WindowManager overlay (TYPE_APPLICATION_OVERLAY)
// ✅ Draggable — user can reposition anywhere on screen
// ✅ State-reactive: idle / listening / thinking / speaking
// ✅ Per-state color + animation (matches Flutter ZaraFloatingOrb exactly)
// ✅ Audio-reactive pulse — amplitude value sent from Flutter via channel
// ✅ Double-tap to show/hide (collapse to small dot when not needed)
// ✅ Stays alive across ALL apps — foreground service keeps it persistent
// ✅ SDK 35 ready — foregroundServiceType=specialUse declared in manifest
// ══════════════════════════════════════════════════════════════════════════════

import android.animation.ValueAnimator
import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.*
import android.util.Log
import android.view.*
import android.view.animation.AccelerateDecelerateInterpolator
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*

class ZaraForegroundService : Service() {

    companion object {
        const val TAG      = "ZARA_FG"
        const val NOTIF_ID = 1002
        const val NOTIF_CH = "zara_foreground"

        var instance: ZaraForegroundService? = null
            private set
        var methodChannel: MethodChannel? = null

        fun start(context: Context) {
            val i = Intent(context, ZaraForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                context.startForegroundService(i)
            else
                context.startService(i)
        }

        fun stop(context: Context) =
            context.stopService(Intent(context, ZaraForegroundService::class.java))

        const val ORB_SIZE = 90   // px — orb canvas size
        const val DOT_SIZE = 24   // px — collapsed dot size
    }

    private val handler       = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var orbView: ZaraOrbView? = null
    private var orbParams: WindowManager.LayoutParams? = null

    // ── Orb state ──────────────────────────────────────────────────────────────
    private var currentState  = "idle"
    private var isCollapsed   = false   // double-tap collapses to small dot
    private var amplitude     = 0f      // 0.0–1.0, sent from Flutter

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotifChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            startForeground(NOTIF_ID, buildNotif())
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed: ${e.message}")
        }
        handler.post {
            methodChannel?.invokeMethod("onForegroundStarted", mapOf("alive" to true))
        }
        // Auto-show orb when service starts
        handler.postDelayed({ showOrb("idle") }, 500)
        Log.d(TAG, "ZaraForegroundService started ✅")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        hideOrb()
        instance = null
        Log.d(TAG, "ZaraForegroundService stopped")
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ORB SHOW / HIDE / UPDATE
    // ══════════════════════════════════════════════════════════════════════════

    fun showOrb(state: String = "idle") {
        // Overlay permission required for Android 6+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(this)) {
            Log.w(TAG, "showOrb: SYSTEM_ALERT_WINDOW permission not granted")
            return
        }

        handler.post {
            try {
                val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                windowManager = wm

                if (orbView != null) {
                    // Already showing — just update state
                    orbView?.setState(state)
                    return@post
                }

                // ── Window layout params ─────────────────────────────────────
                val screenW = resources.displayMetrics.widthPixels
                val screenH = resources.displayMetrics.heightPixels

                val p = WindowManager.LayoutParams(
                    ORB_SIZE, ORB_SIZE,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.START
                    // Default position: right side, 30% down
                    x = screenW - ORB_SIZE - dpToPx(16)
                    y = (screenH * 0.30).toInt()
                }
                orbParams = p

                val orb = ZaraOrbView(this@ZaraForegroundService, state) { newState ->
                    // Callback when orb is double-tapped — toggle collapse
                    isCollapsed = !isCollapsed
                    orbView?.setCollapsed(isCollapsed)
                    methodChannel?.invokeMethod(
                        "onOrbTapped", mapOf("collapsed" to isCollapsed))
                }

                // ── Drag-to-reposition ────────────────────────────────────────
                orb.setOnTouchListener(DragTouchListener(p, wm, orb))

                wm.addView(orb, p)
                orbView = orb
                currentState = state
                Log.d(TAG, "Orb shown: $state")
            } catch (e: Exception) {
                Log.e(TAG, "showOrb error: ${e.message}")
            }
        }
    }

    fun hideOrb() {
        handler.post {
            try {
                orbView?.let { windowManager?.removeView(it) }
                orbView    = null
                orbParams  = null
                amplitude  = 0f
            } catch (e: Exception) {
                Log.e(TAG, "hideOrb: ${e.message}")
            }
        }
    }

    fun updateOrbState(state: String) {
        currentState = state
        handler.post { orbView?.setState(state) }
    }

    // Called from Flutter with current audio amplitude (0.0–1.0)
    fun updateOrbAmplitude(amp: Float) {
        amplitude = amp.coerceIn(0f, 1f)
        handler.post { orbView?.setAmplitude(amplitude) }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DRAG TOUCH LISTENER — reposition orb anywhere on screen
    // ══════════════════════════════════════════════════════════════════════════

    private inner class DragTouchListener(
        private val params: WindowManager.LayoutParams,
        private val wm:     WindowManager,
        private val view:   View,
    ) : View.OnTouchListener {

        private var startX      = 0f
        private var startY      = 0f
        private var startParamX = 0
        private var startParamY = 0
        private var isDragging  = false
        private var downTime    = 0L
        private var tapCount    = 0
        private val handler     = Handler(Looper.getMainLooper())

        override fun onTouch(v: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX      = event.rawX
                    startY      = event.rawY
                    startParamX = params.x
                    startParamY = params.y
                    isDragging  = false
                    downTime    = System.currentTimeMillis()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - startX
                    val dy = event.rawY - startY
                    if (!isDragging && (abs(dx) > 8 || abs(dy) > 8)) {
                        isDragging = true
                    }
                    if (isDragging) {
                        val screenW = resources.displayMetrics.widthPixels
                        val screenH = resources.displayMetrics.heightPixels
                        params.x = (startParamX + dx.toInt())
                            .coerceIn(0, screenW - ORB_SIZE)
                        params.y = (startParamY + dy.toInt())
                            .coerceIn(0, screenH - ORB_SIZE)
                        try { wm.updateViewLayout(view, params) } catch (_: Exception) {}
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        // Tap — handle single vs double tap
                        tapCount++
                        if (tapCount == 1) {
                            handler.postDelayed({
                                if (tapCount == 1) {
                                    // Single tap — tell Flutter
                                    methodChannel?.invokeMethod(
                                        "onOrbTapped", mapOf("collapsed" to isCollapsed))
                                }
                                tapCount = 0
                            }, 280)
                        } else if (tapCount >= 2) {
                            // Double tap — collapse/expand
                            tapCount    = 0
                            isCollapsed = !isCollapsed
                            orbView?.setCollapsed(isCollapsed)
                        }
                    }
                    isDragging = false
                }
            }
            return true
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NOTIFICATION
    // ══════════════════════════════════════════════════════════════════════════

    private fun createNotifChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val ch = NotificationChannel(
            NOTIF_CH, "Z.A.R.A. Background", NotificationManager.IMPORTANCE_LOW
        ).apply { setShowBadge(false) }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(ch)
    }

    private fun buildNotif(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, NOTIF_CH)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Z.A.R.A.")
            .setContentText("Active — tap to open")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    private fun dpToPx(dp: Int): Int =
        (dp * resources.displayMetrics.density).toInt()
}

// ══════════════════════════════════════════════════════════════════════════════
// ZaraOrbView — Custom View
//
// States:
//   idle      → cyan breathing glow
//   listening → green pulse rings
//   thinking  → amber rotating arc
//   speaking  → purple/cyan expanding rings + amplitude wave
//
// Collapsed → shrinks to a small glowing dot
// ══════════════════════════════════════════════════════════════════════════════

class ZaraOrbView(
    context: Context,
    private var state: String = "idle",
    private val onDoubleTap: (String) -> Unit = {},
) : View(context) {

    // ── Paint objects (allocated once, never in onDraw) ────────────────────────
    private val orbPaint   = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ringPaint  = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style       = Paint.Style.STROKE
        strokeWidth = 2.5f
    }
    private val glowPaint  = Paint(Paint.ANTI_ALIAS_FLAG)
    private val dotPaint   = Paint(Paint.ANTI_ALIAS_FLAG)
    private val arcPaint   = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style       = Paint.Style.STROKE
        strokeWidth = 3f
        strokeCap   = Paint.Cap.ROUND
    }

    // ── Animation state ────────────────────────────────────────────────────────
    private var pulse       = 0f       // 0–1, breathing
    private var ringScale   = 1f       // 1–2.5, expanding rings
    private var arcAngle    = 0f       // 0–360, rotating arc (thinking)
    private var amplitude   = 0f      // 0–1, audio level
    private var collapsed   = false

    // ── Animators ──────────────────────────────────────────────────────────────
    private val breathAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration           = 2800
        repeatMode         = ValueAnimator.REVERSE
        repeatCount        = ValueAnimator.INFINITE
        interpolator       = AccelerateDecelerateInterpolator()
        addUpdateListener  { pulse = it.animatedValue as Float; invalidate() }
    }

    private val ringAnimator = ValueAnimator.ofFloat(1f, 2.5f).apply {
        duration    = 900
        repeatCount = ValueAnimator.INFINITE
        addUpdateListener { ringScale = it.animatedValue as Float; invalidate() }
    }

    private val arcAnimator = ValueAnimator.ofFloat(0f, 360f).apply {
        duration    = 1200
        repeatCount = ValueAnimator.INFINITE
        addUpdateListener { arcAngle = it.animatedValue as Float; invalidate() }
    }

    // ── State colors ───────────────────────────────────────────────────────────
    private val colorIdle      = Color.argb(220, 0,   220, 255)   // cyan
    private val colorListening = Color.argb(220, 0,   255, 120)   // green
    private val colorThinking  = Color.argb(220, 255, 180, 0  )   // amber
    private val colorSpeaking  = Color.argb(220, 180, 0,   255)   // purple

    init {
        breathAnimator.start()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // STATE MANAGEMENT
    // ══════════════════════════════════════════════════════════════════════════

    fun setState(s: String) {
        if (state == s) return
        state = s
        // Start/stop animators based on state
        when (s) {
            "listening" -> {
                if (!ringAnimator.isRunning) ringAnimator.start()
                arcAnimator.cancel()
            }
            "thinking"  -> {
                if (!arcAnimator.isRunning) arcAnimator.start()
                ringAnimator.cancel()
            }
            "speaking"  -> {
                if (!ringAnimator.isRunning) ringAnimator.start()
                arcAnimator.cancel()
            }
            else -> {
                ringAnimator.cancel()
                arcAnimator.cancel()
                ringScale = 1f
            }
        }
        invalidate()
    }

    fun setAmplitude(amp: Float) {
        amplitude = amp
        if (state == "speaking" || state == "listening") invalidate()
    }

    fun setCollapsed(c: Boolean) {
        collapsed = c
        invalidate()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DRAW
    // ══════════════════════════════════════════════════════════════════════════

    override fun onDraw(canvas: Canvas) {
        val cx = width  / 2f
        val cy = height / 2f

        if (collapsed) {
            drawCollapsedDot(canvas, cx, cy)
            return
        }

        drawOrb(canvas, cx, cy)
    }

    // ── Collapsed: small glowing dot ───────────────────────────────────────────
    private fun drawCollapsedDot(canvas: Canvas, cx: Float, cy: Float) {
        val r     = 10f + pulse * 3f
        val color = stateColor()

        // Glow
        glowPaint.shader = RadialGradient(
            cx, cy, r * 3f,
            intArrayOf(Color.argb(100, Color.red(color), Color.green(color), Color.blue(color)),
                       Color.TRANSPARENT),
            null, Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, r * 3f, glowPaint)

        // Dot
        dotPaint.color = color
        canvas.drawCircle(cx, cy, r, dotPaint)
    }

    // ── Full orb ───────────────────────────────────────────────────────────────
    private fun drawOrb(canvas: Canvas, cx: Float, cy: Float) {
        val baseR = minOf(cx, cy) * 0.62f
        val r     = baseR + (amplitude * baseR * 0.18f)   // audio-reactive size
        val color = stateColor()

        // ── Outer glow ────────────────────────────────────────────────────────
        val glowR = r * (1.6f + pulse * 0.5f)
        glowPaint.shader = RadialGradient(
            cx, cy, glowR,
            intArrayOf(
                Color.argb((40 + (pulse * 60).toInt()),
                    Color.red(color), Color.green(color), Color.blue(color)),
                Color.TRANSPARENT
            ),
            null, Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, glowR, glowPaint)

        // ── Expanding rings (listening / speaking) ────────────────────────────
        if (state == "listening" || state == "speaking") {
            val alpha1 = ((1f - (ringScale - 1f) / 1.5f) * 200).toInt().coerceIn(0, 200)
            val alpha2 = ((1f - (ringScale - 1f) / 1.5f) * 130).toInt().coerceIn(0, 200)

            // Ring 1
            ringPaint.color = Color.argb(alpha1,
                Color.red(color), Color.green(color), Color.blue(color))
            canvas.drawCircle(cx, cy, r * ringScale, ringPaint)

            // Ring 2 — delayed
            val rs2 = ((ringScale - 0.4f).coerceIn(1f, 2.5f))
            ringPaint.color = Color.argb(alpha2,
                Color.red(color), Color.green(color), Color.blue(color))
            canvas.drawCircle(cx, cy, r * rs2, ringPaint)

            // Ring 3 — more delayed
            val rs3 = ((ringScale - 0.8f).coerceIn(1f, 2.5f))
            ringPaint.color = Color.argb((alpha2 * 0.6f).toInt().coerceIn(0, 200),
                Color.red(color), Color.green(color), Color.blue(color))
            canvas.drawCircle(cx, cy, r * rs3, ringPaint)
        }

        // ── Breathing pulse ring (idle) ───────────────────────────────────────
        if (state == "idle") {
            ringPaint.color = Color.argb((30 + pulse * 80).toInt().coerceIn(0, 200),
                Color.red(color), Color.green(color), Color.blue(color))
            ringPaint.strokeWidth = 1.5f
            canvas.drawCircle(cx, cy, r * (1.15f + pulse * 0.25f), ringPaint)
            ringPaint.strokeWidth = 2.5f
        }

        // ── Thinking: rotating arc ─────────────────────────────────────────────
        if (state == "thinking") {
            arcPaint.color = color
            val oval = RectF(cx - r * 1.25f, cy - r * 1.25f,
                             cx + r * 1.25f, cy + r * 1.25f)
            canvas.drawArc(oval, arcAngle, 220f, false, arcPaint)
            // Second arc, opposite direction
            arcPaint.color = Color.argb(120,
                Color.red(color), Color.green(color), Color.blue(color))
            canvas.drawArc(oval, arcAngle + 180f, 100f, false, arcPaint)
        }

        // ── Orb fill: radial gradient ──────────────────────────────────────────
        orbPaint.shader = RadialGradient(
            cx - r * 0.3f, cy - r * 0.35f, r,
            intArrayOf(
                Color.argb(255, 255, 255, 255),
                color,
                Color.argb(200, 8, 8, 20)
            ),
            floatArrayOf(0f, 0.52f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, r, orbPaint)

        // ── Inner highlight ────────────────────────────────────────────────────
        orbPaint.shader = null
        orbPaint.color  = Color.argb((160 + (pulse * 40).toInt()), 255, 255, 255)
        canvas.drawCircle(cx - r * 0.22f, cy - r * 0.22f, r * 0.18f, orbPaint)

        // ── Audio wave bars (speaking only) ───────────────────────────────────
        if (state == "speaking" && amplitude > 0.05f) {
            drawWaveBars(canvas, cx, cy, r)
        }

        // ── Mic dot (listening) ───────────────────────────────────────────────
        if (state == "listening") {
            orbPaint.color = Color.argb(230, 255, 255, 255)
            canvas.drawCircle(cx, cy, r * 0.18f, orbPaint)
            orbPaint.color = Color.argb(200, 0, 200, 80)
            canvas.drawCircle(cx, cy, r * 0.10f, orbPaint)
        }
    }

    // ── 3-bar audio wave ───────────────────────────────────────────────────────
    private fun drawWaveBars(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        val barW    = r * 0.12f
        val maxBarH = r * 0.55f
        val gap     = r * 0.16f
        val t       = System.currentTimeMillis() / 120.0

        val heights = floatArrayOf(
            maxBarH * (0.4f + amplitude * 0.6f * abs(sin(t).toFloat())),
            maxBarH * (0.55f + amplitude * 0.45f * abs(sin(t + 1.0).toFloat())),
            maxBarH * (0.35f + amplitude * 0.65f * abs(sin(t + 2.0).toFloat())),
        )

        val totalW = barW * 3 + gap * 2
        var bx     = cx - totalW / 2f

        val wavePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(220, 255, 255, 255)
        }

        for (h in heights) {
            val rect = RectF(bx, cy - h / 2f, bx + barW, cy + h / 2f)
            canvas.drawRoundRect(rect, barW / 2f, barW / 2f, wavePaint)
            bx += barW + gap
        }
    }

    // ── State color ────────────────────────────────────────────────────────────
    private fun stateColor() = when (state) {
        "listening" -> colorListening
        "thinking"  -> colorThinking
        "speaking"  -> colorSpeaking
        else        -> colorIdle
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CLEANUP
    // ══════════════════════════════════════════════════════════════════════════

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        breathAnimator.cancel()
        ringAnimator.cancel()
        arcAnimator.cancel()
    }
}
