package com.namecard.mapae

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

/**
 * 수신/통화 중 명함 정보를 화면 위에 띄우는 네이티브 오버레이 서비스.
 *
 * 디자인:
 *   • 흰색 배경 + 검정 굵은 아웃라인(3dp) + 그림자
 *   • 텍스트는 검정, 강조(라벨/아바타/닫기)는 검정 배경 + 흰색 텍스트
 *
 * 위치:
 *   • banner (수신 중)  — 화면 맨 아래 (응답/거절 버튼 바로 위)
 *   • detail (통화 중)  — 화면 맨 위 (상태 표시줄 바로 아래)
 */
class CallerOverlayService : Service() {

    companion object {
        private const val TAG = "CallerOverlay"
        const val ACTION_SHOW = "com.namecard.mapae.SHOW"
        const val ACTION_STOP = "com.namecard.mapae.STOP"
        const val EXTRA_MODE = "mode"
        const val EXTRA_INFO = "info"

        private const val NOTI_ID = 7821
        private const val CHANNEL_ID = "caller_id_overlay"

        // 색상 팔레트 (흑백)
        private const val COLOR_BG = 0xFFFFFFFF.toInt()      // 카드 배경 (흰색)
        private const val COLOR_FG = 0xFF000000.toInt()      // 텍스트 / 아웃라인 (검정)
        private const val COLOR_FG_DIM = 0xFF555555.toInt()  // 부가 텍스트 (회색)
        private const val COLOR_FG_FAINT = 0xFF888888.toInt()// 라벨/키 (옅은 회색)
        private const val COLOR_INVERT = 0xFFFFFFFF.toInt()  // 반전 텍스트 (흰색)
    }

    private var windowManager: WindowManager? = null
    private var overlay: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundCompat()

        when (intent?.action) {
            ACTION_SHOW -> {
                val mode = intent.getStringExtra(EXTRA_MODE) ?: "banner"
                val infoJson = intent.getStringExtra(EXTRA_INFO)
                if (infoJson != null) {
                    showOverlay(mode, infoJson)
                }
            }
            ACTION_STOP -> {
                removeOverlay()
                stopSelf()
            }
            else -> {
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    // ─────────── Foreground notification ───────────

    private fun startForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "Caller ID",
                    NotificationManager.IMPORTANCE_MIN
                ).apply {
                    description = "수신 전화 명함 표시"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                }
                nm.createNotificationChannel(ch)
            }
        }
        val noti: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Mapae")
                .setContentText("수신 전화 정보 표시 중")
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Mapae")
                .setContentText("수신 전화 정보 표시 중")
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .setOngoing(true)
                .build()
        }
        startForeground(NOTI_ID, noti)
    }

    // ─────────── Overlay rendering ───────────

    private fun showOverlay(mode: String, infoJson: String) {
        val info = try {
            JSONObject(infoJson)
        } catch (e: Exception) {
            Log.e(TAG, "parse info fail: $e")
            return
        }

        removeOverlay()

        val view = if (mode == "detail") buildDetailView(info) else buildBannerView(info)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // 모드별 위치/크기
        //   banner (수신 중)  : 화면 맨 아래 (응답/거절 버튼 바로 위 빈 공간)
        //   detail (통화 중)  : 화면 맨 위 (상태 표시줄 바로 아래)
        val isDetail = mode == "detail"
        val height = if (isDetail) dp(320) else dp(96)
        val verticalGravity = if (isDetail) Gravity.TOP else Gravity.BOTTOM
        val yOffset = dp(24)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            height,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = verticalGravity or Gravity.CENTER_HORIZONTAL
            y = yOffset
        }

        try {
            windowManager?.addView(view, params)
            overlay = view
            Log.d(TAG, "overlay added mode=$mode gravity=${if (isDetail) "TOP" else "BOTTOM"} y=$yOffset name=${info.optString("name")}")
        } catch (e: Exception) {
            Log.e(TAG, "addView failed: $e")
        }
    }

    private fun removeOverlay() {
        val v = overlay ?: return
        try {
            windowManager?.removeView(v)
        } catch (_: Exception) {}
        overlay = null
    }

    // ─────────── 작은 띠 (수신 중) ───────────

    private fun buildBannerView(info: JSONObject): View {
        val ctx = this
        val name = info.optString("name", "")
        val company = info.optString("company", "")
        val position = info.optString("position", "")

        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            background = roundedBg(COLOR_BG, 14f, COLOR_FG, 3)
            elevation = dp(6).toFloat()
            setPadding(dp(14), dp(12), dp(8), dp(12))
            gravity = Gravity.CENTER_VERTICAL
        }

        // 검정 원형 아바타 (흰색 이니셜)
        card.addView(makeAvatar(name, sizeDp = 38, fontDp = 16, invert = true))

        val texts = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            val lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            lp.leftMargin = dp(12)
            layoutParams = lp
        }

        // Mapae 라벨 (검정 배경)
        val labelRow = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
        labelRow.addView(makeBadge("Mapae", invert = true))
        texts.addView(labelRow)

        texts.addView(spacer(2))

        texts.addView(TextView(ctx).apply {
            text = name
            setTextColor(COLOR_FG)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        })

        val sub = listOf(company, position).filter { it.isNotEmpty() }.joinToString(" · ")
        if (sub.isNotEmpty()) {
            texts.addView(TextView(ctx).apply {
                text = sub
                setTextColor(COLOR_FG_DIM)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                maxLines = 1
            })
        }
        card.addView(texts)

        // 닫기 버튼
        card.addView(ImageButton(ctx).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setBackgroundColor(Color.TRANSPARENT)
            setColorFilter(COLOR_FG)
            val lp = LinearLayout.LayoutParams(dp(36), dp(36))
            layoutParams = lp
            setOnClickListener { removeOverlay() }
        })

        return wrapWithMargin(card)
    }

    // ─────────── 자세한 카드 (통화 중) ───────────

    private fun buildDetailView(info: JSONObject): View {
        val ctx = this
        val name = info.optString("name", "")
        val company = info.optString("company", "")
        val position = info.optString("position", "")
        val department = info.optString("department", "")
        val email = info.optString("email", "")
        val memo = info.optString("memo", "")

        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedBg(COLOR_BG, 18f, COLOR_FG, 3)
            elevation = dp(8).toFloat()
            setPadding(dp(20), dp(20), dp(20), dp(20))
            gravity = Gravity.CENTER_HORIZONTAL
        }

        // 상단 Mapae 라벨
        val labelRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        labelRow.addView(makeBadge("Mapae", invert = true))
        card.addView(labelRow)

        card.addView(spacer(12))

        // 검정 원형 아바타 (흰색 이니셜)
        card.addView(makeAvatar(name, sizeDp = 60, fontDp = 24, invert = true))

        card.addView(spacer(10))

        // 이름
        card.addView(TextView(ctx).apply {
            text = name
            setTextColor(COLOR_FG)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        })

        val sub = listOf(company, position, department).filter { it.isNotEmpty() }
            .joinToString(" · ")
        if (sub.isNotEmpty()) {
            card.addView(spacer(4))
            card.addView(TextView(ctx).apply {
                text = sub
                setTextColor(COLOR_FG_DIM)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                gravity = Gravity.CENTER_HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            })
        }

        if (email.isNotEmpty()) {
            card.addView(spacer(12))
            card.addView(makeKeyValue("이메일", email))
        }
        if (memo.isNotEmpty()) {
            card.addView(spacer(8))
            card.addView(makeKeyValue("메모", memo))
        }

        card.addView(spacer(14))

        // 닫기 버튼 (검정 배경 + 흰색 텍스트)
        card.addView(TextView(ctx).apply {
            text = "닫기"
            setTextColor(COLOR_INVERT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(dp(28), dp(10), dp(28), dp(10))
            background = roundedBg(COLOR_FG, 22f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener { removeOverlay() }
        })

        return wrapWithMargin(card)
    }

    // ─────────── helpers ───────────

    /** 좌우 여백 wrapper */
    private fun wrapWithMargin(card: View): View {
        return FrameLayout(this).apply {
            setPadding(dp(16), 0, dp(16), 0)
            addView(card, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ))
        }
    }

    /**
     * 원형 아바타 — invert=true 면 검정 배경+흰색 이니셜(강조), false 면 반대.
     */
    private fun makeAvatar(name: String, sizeDp: Int, fontDp: Int, invert: Boolean): View {
        val initial = if (name.isNotEmpty()) name.substring(0, 1) else "?"
        val bg = if (invert) COLOR_FG else COLOR_BG
        val fg = if (invert) COLOR_INVERT else COLOR_FG
        return TextView(this).apply {
            text = initial
            setTextColor(fg)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, fontDp.toFloat())
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(bg)
                if (!invert) setStroke(dp(2), COLOR_FG)
            }
            val lp = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
            lp.gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = lp
        }
    }

    /**
     * 작은 라벨. invert=true 면 검정 배경+흰색 텍스트, false 면 흰색 배경+검정 텍스트+얇은 테두리.
     */
    private fun makeBadge(text: String, invert: Boolean): TextView {
        val bg = if (invert) COLOR_FG else COLOR_BG
        val fg = if (invert) COLOR_INVERT else COLOR_FG
        return TextView(this).apply {
            this.text = text
            setTextColor(fg)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(dp(8), dp(3), dp(8), dp(3))
            background = roundedBg(bg, 6f, COLOR_FG, if (invert) 0 else 1)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun makeKeyValue(key: String, value: String): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        row.addView(TextView(this).apply {
            text = key
            setTextColor(COLOR_FG_FAINT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            val lp = LinearLayout.LayoutParams(dp(60), LinearLayout.LayoutParams.WRAP_CONTENT)
            layoutParams = lp
        })
        row.addView(TextView(this).apply {
            text = value
            setTextColor(COLOR_FG)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            maxLines = 2
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        })
        return row
    }

    private fun spacer(dpHeight: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(dpHeight))
    }

    /**
     * 둥근 사각형 배경 + 옵션 stroke.
     */
    private fun roundedBg(
        color: Int,
        radiusDp: Float,
        strokeColor: Int? = null,
        strokeDp: Int = 0,
    ): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = dp(radiusDp.toInt()).toFloat()
            if (strokeColor != null && strokeDp > 0) {
                setStroke(dp(strokeDp), strokeColor)
            }
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}