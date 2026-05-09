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
 * Android 8+ 의 백그라운드 서비스 제약에 대응하기 위해 startForegroundService 로
 * 시작되며 onStartCommand 진입 즉시 startForeground 를 호출해 무음 알림을 띄웁니다.
 *
 * View 는 SYSTEM_ALERT_WINDOW 권한을 사용해 WindowManager 에 직접 추가됩니다.
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
                // 기본 동작: 그냥 종료
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

        // 기존 오버레이 제거 (모드 전환 시)
        removeOverlay()

        val view = if (mode == "detail") buildDetailView(info) else buildBannerView(info)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val height = if (mode == "detail") dp(360) else dp(110)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            height,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(48)
        }

        try {
            windowManager?.addView(view, params)
            overlay = view
            Log.d(TAG, "overlay added mode=$mode name=${info.optString("name")}")
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
        val source = info.optString("source", "collected")
        val isCrm = source == "crm"

        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            background = roundedBg(0xFF1E1E2E.toInt(), 16f)
            setPadding(dp(16), dp(14), dp(12), dp(14))
            gravity = Gravity.CENTER_VERTICAL
        }

        val avatar = makeAvatar(name, isCrm, sizeDp = 40, fontDp = 16)
        card.addView(avatar)

        val texts = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            val lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            lp.leftMargin = dp(12)
            layoutParams = lp
        }

        val labelRow = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
        labelRow.addView(makeBadge("Mapae", 0xFF6366F1.toInt()))
        labelRow.addView(makeBadge(if (isCrm) "CRM" else "Contact",
            if (isCrm) 0xFF6366F1.toInt() else 0xFF10B981.toInt()).apply {
            (layoutParams as LinearLayout.LayoutParams).leftMargin = dp(6)
        })
        texts.addView(labelRow)

        texts.addView(TextView(ctx).apply {
            text = name
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
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
                setTextColor(0x99FFFFFF.toInt())
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                maxLines = 1
            })
        }
        card.addView(texts)

        // 닫기 버튼
        card.addView(ImageButton(ctx).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setBackgroundColor(Color.TRANSPARENT)
            setColorFilter(0x80FFFFFF.toInt())
            val lp = LinearLayout.LayoutParams(dp(36), dp(36))
            layoutParams = lp
            setOnClickListener { removeOverlay() }
        })

        // 외곽 wrapper (좌우 여백)
        val wrapper = FrameLayout(ctx).apply {
            setPadding(dp(16), 0, dp(16), 0)
            addView(card, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ))
        }
        return wrapper
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
        val source = info.optString("source", "collected")
        val isCrm = source == "crm"

        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedBg(0xFF1E1E2E.toInt(), 20f)
            setPadding(dp(20), dp(20), dp(20), dp(20))
            gravity = Gravity.CENTER_HORIZONTAL
        }

        // 상단 라벨
        val labelRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        labelRow.addView(makeBadge("Mapae", 0xFF6366F1.toInt()))
        labelRow.addView(makeBadge(if (isCrm) "CRM" else "Contact",
            if (isCrm) 0xFF6366F1.toInt() else 0xFF10B981.toInt()).apply {
            (layoutParams as LinearLayout.LayoutParams).leftMargin = dp(6)
        })
        card.addView(labelRow)

        card.addView(spacer(12))

        // 아바타
        card.addView(makeAvatar(name, isCrm, sizeDp = 64, fontDp = 26))

        card.addView(spacer(10))

        // 이름
        card.addView(TextView(ctx).apply {
            text = name
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        })

        // Company · Position · Department
        val sub = listOf(company, position, department).filter { it.isNotEmpty() }
            .joinToString(" · ")
        if (sub.isNotEmpty()) {
            card.addView(spacer(4))
            card.addView(TextView(ctx).apply {
                text = sub
                setTextColor(0xCCFFFFFF.toInt())
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                gravity = Gravity.CENTER_HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            })
        }

        if (email.isNotEmpty()) {
            card.addView(spacer(10))
            card.addView(makeKeyValue("이메일", email))
        }
        if (memo.isNotEmpty()) {
            card.addView(spacer(8))
            card.addView(makeKeyValue("메모", memo))
        }

        card.addView(spacer(14))

        // 닫기 버튼
        card.addView(TextView(ctx).apply {
            text = "닫기"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(dp(20), dp(8), dp(20), dp(8))
            background = roundedBg(0x33FFFFFF, 20f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener { removeOverlay() }
        })

        val wrapper = FrameLayout(ctx).apply {
            setPadding(dp(16), 0, dp(16), 0)
            addView(card, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ))
        }
        return wrapper
    }

    // ─────────── helpers ───────────

    private fun makeAvatar(name: String, isCrm: Boolean, sizeDp: Int, fontDp: Int): View {
        val initial = if (name.isNotEmpty()) name.substring(0, 1) else "?"
        val color = if (isCrm) 0xFF6366F1.toInt() else 0xFF10B981.toInt()
        val bgColor = (color and 0x00FFFFFF) or 0x33000000
        val tv = TextView(this).apply {
            text = initial
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, fontDp.toFloat())
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(bgColor)
            }
            val lp = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
            lp.gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = lp
        }
        return tv
    }

    private fun makeBadge(text: String, color: Int): TextView {
        return TextView(this).apply {
            this.text = text
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(dp(6), dp(2), dp(6), dp(2))
            background = roundedBg((color and 0x00FFFFFF) or 0x33000000, 4f)
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
            setTextColor(0x88FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            val lp = LinearLayout.LayoutParams(dp(60), LinearLayout.LayoutParams.WRAP_CONTENT)
            layoutParams = lp
        })
        row.addView(TextView(this).apply {
            text = value
            setTextColor(Color.WHITE)
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

    private fun roundedBg(color: Int, radiusDp: Float): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = dp(radiusDp.toInt()).toFloat()
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
