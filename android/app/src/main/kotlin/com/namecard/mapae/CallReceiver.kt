package com.namecard.mapae

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.telephony.TelephonyManager
import android.util.Log

/**
 * 시스템 PHONE_STATE 브로드캐스트를 받아 Caller ID 오버레이를 띄우는 receiver.
 * AndroidManifest 에 정적으로 등록되어 있어 앱이 종료된 상태에서도 호출됩니다.
 *
 * 백그라운드 신뢰성 확보를 위해:
 *   • goAsync() 로 broadcast 예산(10s) 까지 실행을 연장한다.
 *   • PARTIAL_WAKE_LOCK(8s) 을 잡아 Doze 중에도 CPU 가 깨어 있도록 한다.
 *   • 모든 I/O / FGS 시작 작업은 worker thread 에서 수행한다.
 */
class CallReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "CallReceiver"
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY_ENABLED = "flutter.caller_id_enabled"
        private const val KEY_LAST_NUMBER = "flutter.caller_id_last_number"
        private const val KEY_APP_FOREGROUND = "flutter.caller_id_app_foreground"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        Log.d(TAG, "onReceive state=$state number=${number?.take(4)}***")

        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Mapae:CallReceiver")
        wl.setReferenceCounted(false)
        wl.acquire(8_000L) // 10s broadcast 예산 아래

        val pending = goAsync()
        Thread {
            try {
                handle(context, state, number)
            } catch (t: Throwable) {
                Log.e(TAG, "handle failed: $t")
            } finally {
                if (wl.isHeld) try { wl.release() } catch (_: Throwable) {}
                pending.finish()
            }
        }.start()
    }

    private fun handle(context: Context, state: String?, number: String?) {
        // 사용자가 기능을 꺼두었다면 무시.
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            Log.d(TAG, "Caller ID disabled — skipping")
            return
        }

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // 동일한 RINGING 이 여러 번 broadcast 될 수 있으므로 마지막 번호와 다를 때만 처리.
                val last = prefs.getString(KEY_LAST_NUMBER, null)
                if (number != null && number == last) return
                prefs.edit().putString(KEY_LAST_NUMBER, number).apply()

                if (number == null) return
                val info = CallerCache.lookup(context, number)
                if (info == null) {
                    Log.d(TAG, "no card matched")
                    return
                }

                // 시스템 전화 UI 가 heads-up(상단 작은 띠) 인지, full-screen 인지에 따라
                // 우리 띠 위치를 바꾼다.
                //   - Mapae 앱 포그라운드 + 잠금 해제 + 화면 켜짐 → heads-up 으로 추정 → 하단 띠
                //   - 그 외(백그라운드/잠금화면/화면 꺼짐)            → full-screen 으로 추정 → 상단 띠
                //
                // foreground 판정은 두 신호를 합산:
                //   (1) MainActivity.onResume/onPause 가 동기 commit() 한 SharedPreferences 플래그
                //   (2) ActivityManager.runningAppProcesses 의 importance — 실시간 신호.
                // (2) 가 IMPORTANCE_FOREGROUND 가 아니면 실제로 포그라운드가 아니므로 무조건 false 로 본다.
                val appForegroundFlag = prefs.getBoolean(KEY_APP_FOREGROUND, false)
                val appForegroundLive = isOwnAppForeground(context)
                val appForeground = appForegroundFlag && appForegroundLive
                val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isFullscreen = !appForeground || km.isKeyguardLocked || !pm.isInteractive
                val mode = if (isFullscreen) "banner_top" else "banner"
                Log.d(
                    TAG,
                    "matched: ${info.optString("name")} mode=$mode fgFlag=$appForegroundFlag fgLive=$appForegroundLive locked=${km.isKeyguardLocked} interactive=${pm.isInteractive}"
                )
                startService(context, mode, info.toString())
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // 발신은 RINGING 없이 OFFHOOK 으로 시작 — 그 경우는 표시하지 않음.
                val last = prefs.getString(KEY_LAST_NUMBER, null) ?: return
                val info = CallerCache.lookup(context, last) ?: return
                startService(context, "detail", info.toString())
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                prefs.edit().remove(KEY_LAST_NUMBER).apply()
                val stop = Intent(context, CallerOverlayService::class.java)
                stop.action = CallerOverlayService.ACTION_STOP
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(stop)
                    } else {
                        context.startService(stop)
                    }
                } catch (_: Exception) {
                    context.stopService(Intent(context, CallerOverlayService::class.java))
                }
            }
        }
    }

    /**
     * 우리 앱이 현재 포그라운드(사용자에게 보이는 활동) 인지 실시간으로 확인.
     *
     * `getRunningAppProcesses()` 는 Android 5+ 부터 자신의 패키지 process 만
     * 반환하므로 외부 권한 없이도 우리 process 의 importance 를 안정적으로 확인할 수 있다.
     */
    private fun isOwnAppForeground(context: Context): Boolean {
        return try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val procs = am.runningAppProcesses ?: return false
            val ours = procs.firstOrNull { it.processName == context.packageName }
                ?: return false
            ours.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        } catch (_: Throwable) {
            false
        }
    }

    private fun startService(context: Context, mode: String, infoJson: String) {
        val svc = Intent(context, CallerOverlayService::class.java).apply {
            action = CallerOverlayService.ACTION_SHOW
            putExtra(CallerOverlayService.EXTRA_MODE, mode)
            putExtra(CallerOverlayService.EXTRA_INFO, infoJson)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(svc)
            } else {
                context.startService(svc)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startService failed: $e")
        }
    }
}
