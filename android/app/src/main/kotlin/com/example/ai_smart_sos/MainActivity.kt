package com.example.ai_smart_sos

import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main Flutter Activity extended with a MethodChannel for controlling
 * the [AccidentDetectionForegroundService].
 *
 * The channel handles:
 *   Flutter → Native: startService, stopService, isServiceRunning,
 *                      showAccidentAlert, dismissAccidentAlert
 *   Native → Flutter: onAccelerometerData(x,y,z), onGyroscopeData(x,y,z)
 *                      (sent by the foreground service via the shared
 *                       static [AccidentDetectionForegroundService.methodChannel])
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.example.ai_smart_sos/foreground_sensor"
    }

    private var uiChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        uiChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )

        // Share the channel with the foreground service so it can send
        // sensor data back to the Flutter engine.
        AccidentDetectionForegroundService.methodChannel = uiChannel

        uiChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startAccidentDetectionService()
                    result.success(true)
                }
                "stopService" -> {
                    stopAccidentDetectionService()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(AccidentDetectionForegroundService.isRunning)
                }
                "checkSensorHealth" -> {
                    if (!AccidentDetectionForegroundService.isRunning) {
                        result.success("inactive")
                        return@setMethodCallHandler
                    }
                    if (!AccidentDetectionForegroundService.hasAccelerometer || !AccidentDetectionForegroundService.hasGyroscope) {
                        result.success("unavailable")
                        return@setMethodCallHandler
                    }
                    val now = System.currentTimeMillis()
                    val accelActive = (now - AccidentDetectionForegroundService.lastAccelTimeMs) < 3000
                    val gyroActive = (now - AccidentDetectionForegroundService.lastGyroTimeMs) < 3000
                    
                    if (accelActive && gyroActive) {
                        result.success("active")
                    } else {
                        result.success("failed")
                    }
                }
                "showAccidentAlert" -> {
                    // Bring the app to foreground via high-priority notification
                    val intent = Intent(
                        this,
                        AccidentDetectionForegroundService::class.java,
                    ).apply { action = "SHOW_ACCIDENT_ALERT" }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "dismissAccidentAlert" -> {
                    val manager = getSystemService(
                        android.app.NotificationManager::class.java,
                    )
                    manager.cancel(
                        AccidentDetectionForegroundService.ALERT_NOTIFICATION_ID,
                    )
                    result.success(true)
                }
                "simulateTestAccident" -> {
                    val intent = Intent(
                        this,
                        AccidentDetectionForegroundService::class.java,
                    ).apply { action = "SIMULATE_TEST_ACCIDENT" }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        Log.d(TAG, "MethodChannel configured: $CHANNEL")
    }

    override fun onResume() {
        super.onResume()
        if (intent?.getBooleanExtra("accident_detected", false) == true) {
            intent?.removeExtra("accident_detected")
            uiChannel?.invokeMethod("onAccidentAlertFromIntent", null)
            Log.d(TAG, "Notified Flutter of accident_detected intent")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    // ── Service helpers ──────────────────────────────────────────────────

    private fun startAccidentDetectionService() {
        val intent = Intent(this, AccidentDetectionForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d(TAG, "Foreground service start requested")
    }

    private fun stopAccidentDetectionService() {
        val intent = Intent(this, AccidentDetectionForegroundService::class.java)
        stopService(intent)
        Log.d(TAG, "Foreground service stop requested")
    }

    override fun onDestroy() {
        // Clear the static channel reference so the service doesn't try
        // to invoke methods on a detached engine.
        AccidentDetectionForegroundService.methodChannel = null
        super.onDestroy()
    }
}
