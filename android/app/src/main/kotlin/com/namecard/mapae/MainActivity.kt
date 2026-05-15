package com.namecard.mapae

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.namecard.mapae/permissions"
    private val readCallLogRequestCode = 8731
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isCallLogGranted" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_CALL_LOG
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                    "requestCallLog" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_CALL_LOG
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        if (pendingResult != null) {
                            result.error("ALREADY_REQUESTING", "A permission request is already in progress", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_CALL_LOG),
                            readCallLogRequestCode
                        )
                    }
                    "shouldShowCallLogRationale" -> {
                        val show = ActivityCompat.shouldShowRequestPermissionRationale(
                            this,
                            Manifest.permission.READ_CALL_LOG
                        )
                        result.success(show)
                    }
                    "testOverlay" -> {
                        val mode = call.argument<String>("mode") ?: "banner"
                        val number = call.argument<String>("number") ?: ""
                        val info = CallerCache.lookup(this, number)
                        if (info == null) {
                            result.error(
                                "NOT_FOUND",
                                "No card matched for $number — 캐시 확인 필요",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val svc = Intent(this, CallerOverlayService::class.java).apply {
                            action = CallerOverlayService.ACTION_SHOW
                            putExtra(CallerOverlayService.EXTRA_MODE, mode)
                            putExtra(CallerOverlayService.EXTRA_INFO, info.toString())
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(svc)
                        } else {
                            startService(svc)
                        }
                        result.success(true)
                    }
                    "stopOverlay" -> {
                        val svc = Intent(this, CallerOverlayService::class.java).apply {
                            action = CallerOverlayService.ACTION_STOP
                        }
                        try {
                            startService(svc)
                        } catch (_: Exception) {
                            stopService(Intent(this, CallerOverlayService::class.java))
                        }
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            val i = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                .setData(android.net.Uri.parse("package:$packageName"))
                            startActivity(i)
                            result.success(true)
                        } catch (_: Throwable) {
                            // 일부 OEM 에서는 위 인텐트가 막혀 있으므로 일반 설정 화면으로 fallback
                            try {
                                startActivity(Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                result.success(true)
                            } catch (e: Throwable) {
                                result.error("NO_SETTINGS", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == readCallLogRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            pendingResult = null
        }
    }

    // ── App foreground 추적 ──
    // Flutter WidgetsBindingObserver 는 이벤트 채널을 거쳐 비동기로 전달되어
    // 수신 broadcast 보다 늦게 도착할 수 있다. Activity 라이프사이클에서 직접
    // SharedPreferences 를 갱신하면 CallReceiver 가 즉시 최신 값을 읽는다.

    override fun onResume() {
        super.onResume()
        writeForegroundFlag(true)
    }

    override fun onPause() {
        super.onPause()
        writeForegroundFlag(false)
    }

    private fun writeForegroundFlag(isForeground: Boolean) {
        try {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putBoolean("flutter.caller_id_app_foreground", isForeground)
                .commit() // 동기 — 다음 broadcast 까지 반드시 반영되도록
        } catch (_: Throwable) {}
    }
}