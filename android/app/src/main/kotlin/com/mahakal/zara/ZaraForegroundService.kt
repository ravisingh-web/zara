package com.mahakal.zara

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.*
import android.util.Log
import android.view.*
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class ZaraForegroundService : Service() {

    companion object {
        const val TAG     = "ZARA_FG"
        const val NOTIF_ID = 1002
        const val NOTIF_CH = "zara_foreground"
        var instance: ZaraForegroundService? = null
            private set
        var methodChannel: MethodChannel? = null

        fun start(context: Context) {
            val i = Intent(context, ZaraForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                context.startForegroundService(i) else context.startService(i)
        }
        fun stop(context: Context) = context.stopService(Intent(context, ZaraForegroundService::class.java))
    }

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var orbView: View? = null

    override fun onCreate() { super.onCreate(); instance = this; createNotifChannel() }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            startForeground(NOTIF_ID, buildNotif())
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed: ${e.message}")
            // Still continue — don't crash the app
        }
        handler.post { methodChannel?.invokeMethod("onForegroundStarted", mapOf("alive" to true)) }
        Log.d(TAG, "Zara alive in background")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        hideOrb()
        instance = null
        Log.d(TAG, "ZaraForegroundService stopped")
    }

    fun showOrb(state: String = "idle") {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(this)) return
        handler.post {
            try {
                if (orbView != null) { (orbView as? ZaraOrbView)?.setState(state); return@post }
                val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                windowManager = wm
                val p = WindowManager.LayoutParams(
                    120, 120,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                    PixelFormat.TRANSLUCENT
                ).apply { gravity = Gravity.TOP or Gravity.END; x = 16; y = 200 }
                val orb = ZaraOrbView(this@ZaraForegroundService, state)
                wm.addView(orb, p)
                orbView = orb
            } catch (e: Exception) { Log.e(TAG, "showOrb: ${e.message}") }
        }
    }

    fun hideOrb() {
        handler.post {
            try { orbView?.let { windowManager?.removeView(it) }; orbView = null }
            catch (e: Exception) { Log.e(TAG, "hideOrb: ${e.message}") }
        }
    }

    fun updateOrbState(state: String) { handler.post { (orbView as? ZaraOrbView)?.setState(state) } }

    private fun createNotifChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val ch = NotificationChannel(NOTIF_CH, "Z.A.R.A. Background", NotificationManager.IMPORTANCE_LOW)
            .apply { setShowBadge(false) }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
    }

    private fun buildNotif(): Notification {
        val pi = PendingIntent.getActivity(this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, NOTIF_CH)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Z.A.R.A.").setContentText("Active")
            .setPriority(NotificationCompat.PRIORITY_LOW).setOngoing(true)
            .setContentIntent(pi).build()
    }
}

class ZaraOrbView(context: Context, private var state: String = "idle") : View(context) {
    private val paint       = Paint(Paint.ANTI_ALIAS_FLAG)
    private val animHandler = Handler(Looper.getMainLooper())
    private var pulse       = 0f
    private var growing     = true

    init {
        animHandler.post(object : Runnable {
            override fun run() {
                pulse += if (growing) 2f else -2f
                if (pulse > 18f) growing = false
                if (pulse < 0f) { growing = true; pulse = 0f }
                invalidate()
                animHandler.postDelayed(this, 32)
            }
        })
    }

    fun setState(s: String) { state = s; invalidate() }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f; val cy = height / 2f; val r = minOf(cx, cy) * 0.68f
        val color = when (state) {
            "listening" -> Color.argb(220, 0, 255, 100)
            "speaking"  -> Color.argb(220, 180, 0, 255)
            "thinking"  -> Color.argb(220, 255, 180, 0)
            else        -> Color.argb(220, 0, 220, 255)
        }
        // Pulse ring
        paint.style = Paint.Style.STROKE; paint.strokeWidth = 3f
        paint.color = Color.argb(140, 0, 220, 255)
        canvas.drawCircle(cx, cy, r + pulse, paint)
        // Orb fill
        paint.style  = Paint.Style.FILL
        paint.shader = RadialGradient(cx, cy, r,
            intArrayOf(Color.WHITE, color, Color.TRANSPARENT),
            floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP)
        canvas.drawCircle(cx, cy, r, paint)
        paint.shader = null
        paint.color  = Color.argb(160, 255, 255, 255)
        canvas.drawCircle(cx, cy, r * 0.2f, paint)
    }

    override fun onDetachedFromWindow() { super.onDetachedFromWindow(); animHandler.removeCallbacksAndMessages(null) }
}
