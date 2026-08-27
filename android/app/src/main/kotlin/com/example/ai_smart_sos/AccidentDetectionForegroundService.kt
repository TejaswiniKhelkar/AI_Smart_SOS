package com.example.ai_smart_sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Android Foreground Service that reads accelerometer and gyroscope data
 * directly from the native SensorManager, independent of Flutter's
 * sensors_plus platform channel.
 *
 * This ensures sensor data keeps flowing when:
 *   - The app is minimised (Activity paused/stopped)
 *   - The screen is locked
 *   - Android would otherwise throttle or kill the process
 *
 * The service ONLY reads and forwards raw (x, y, z) values to the Flutter
 * engine via a shared MethodChannel. All accident detection logic (impact
 * thresholds, gyroscope correlation, false-positive filtering, confidence
 * scoring) remains in the existing Dart code — nothing is duplicated.
 */
class AccidentDetectionForegroundService : Service(), SensorEventListener {

    companion object {
        private const val TAG = "AccidentFgService"

        // ── Notification channels ────────────────────────────────────────
        const val MONITOR_CHANNEL_ID = "accident_detection_channel"
        const val ALERT_CHANNEL_ID  = "accident_alert_channel"

        // ── Notification IDs ─────────────────────────────────────────────
        private const val MONITOR_NOTIFICATION_ID = 1001
        const val ALERT_NOTIFICATION_ID   = 1002

        /**
         * Shared MethodChannel reference set by [MainActivity.configureFlutterEngine].
         * Both the Activity and this Service live in the same process, so a
         * static reference is safe and avoids complex IPC.
         */
        @Volatile
        var methodChannel: MethodChannel? = null

        /** True while the service is actively running. */
        @Volatile
        var isRunning = false
            private set
    }

    // ── Sensor handles ───────────────────────────────────────────────────
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Handler on the main/UI looper for MethodChannel calls (required by
    // Flutter's platform channel contract).
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Throttling ───────────────────────────────────────────────────────
    // Match the 20 ms sampling period used by sensors_plus in the existing
    // Dart AccelerometerService / GyroscopeService.
    private var lastAccelForwardMs = 0L
    private var lastGyroForwardMs  = 0L
    private val minForwardIntervalMs = 20L

    // ═════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ═════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        acquireWakeLock()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Handle explicit actions sent via Intent
        when (intent?.action) {
            "SHOW_ACCIDENT_ALERT" -> {
                showAccidentAlert()
                return START_STICKY
            }
        }

        // Normal start — only start once
        if (!isRunning) {
            startForegroundWithNotification()
            startSensorListening()
            isRunning = true
            Log.d(TAG, "Service started (sensors active)")
        } else {
            Log.d(TAG, "Service already running — ignoring duplicate start")
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopSensorListening()
        releaseWakeLock()
        isRunning = false
        Log.d(TAG, "Service destroyed")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ═════════════════════════════════════════════════════════════════════
    // NOTIFICATION CHANNELS
    // ═════════════════════════════════════════════════════════════════════

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // Low-priority persistent "monitoring active" notification
            val monitorChannel = NotificationChannel(
                MONITOR_CHANNEL_ID,
                "Accident Detection",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Continuous accident monitoring using phone sensors"
                setShowBadge(false)
            }
            manager.createNotificationChannel(monitorChannel)

            // High-priority accident alert notification
            val alertChannel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "Accident Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Critical accident detection alerts"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(alertChannel)

            Log.d(TAG, "Notification channels created")
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // FOREGROUND NOTIFICATION
    // ═════════════════════════════════════════════════════════════════════

    private fun startForegroundWithNotification() {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, MONITOR_CHANNEL_ID)
            .setContentTitle("Accident Monitoring Active")
            .setContentText("Sensors are monitoring for potential accidents")
            .setSmallIcon(R.drawable.ic_sos_notification)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ requires a typed foreground service
            startForeground(
                MONITOR_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(MONITOR_NOTIFICATION_ID, notification)
        }

        Log.d(TAG, "Foreground notification shown")
    }

    // ═════════════════════════════════════════════════════════════════════
    // SENSOR MANAGEMENT
    // ═════════════════════════════════════════════════════════════════════

    private fun startSensorListening() {
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroscope     = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        accelerometer?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            Log.d(TAG, "Accelerometer listener registered (SENSOR_DELAY_GAME)")
        } ?: Log.w(TAG, "No accelerometer sensor available on this device")

        gyroscope?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            Log.d(TAG, "Gyroscope listener registered (SENSOR_DELAY_GAME)")
        } ?: Log.w(TAG, "No gyroscope sensor available on this device")
    }

    private fun stopSensorListening() {
        sensorManager?.unregisterListener(this)
        sensorManager = null
        accelerometer = null
        gyroscope = null
        Log.d(TAG, "Sensor listeners unregistered")
    }

    // ═════════════════════════════════════════════════════════════════════
    // SENSOR EVENT LISTENER
    // ═════════════════════════════════════════════════════════════════════

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()

        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                if (now - lastAccelForwardMs < minForwardIntervalMs) return
                lastAccelForwardMs = now

                val data = hashMapOf<String, Any>(
                    "x" to event.values[0].toDouble(),
                    "y" to event.values[1].toDouble(),
                    "z" to event.values[2].toDouble(),
                )
                mainHandler.post {
                    try {
                        methodChannel?.invokeMethod("onAccelerometerData", data)
                    } catch (e: Exception) {
                        // Flutter engine may be detached — safe to ignore
                    }
                }
            }

            Sensor.TYPE_GYROSCOPE -> {
                if (now - lastGyroForwardMs < minForwardIntervalMs) return
                lastGyroForwardMs = now

                val data = hashMapOf<String, Any>(
                    "x" to event.values[0].toDouble(),
                    "y" to event.values[1].toDouble(),
                    "z" to event.values[2].toDouble(),
                )
                mainHandler.post {
                    try {
                        methodChannel?.invokeMethod("onGyroscopeData", data)
                    } catch (e: Exception) {
                        // Flutter engine may be detached — safe to ignore
                    }
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        Log.d(TAG, "Sensor accuracy changed: ${sensor?.name} → $accuracy")
    }

    // ═════════════════════════════════════════════════════════════════════
    // WAKE LOCK
    // ═════════════════════════════════════════════════════════════════════

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ai_smart_sos:accident_detection",
        ).apply { acquire() }
        Log.d(TAG, "PARTIAL_WAKE_LOCK acquired")
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "WakeLock released")
            }
        }
        wakeLock = null
    }

    // ═════════════════════════════════════════════════════════════════════
    // ACCIDENT ALERT (full-screen notification for background wake-up)
    // ═════════════════════════════════════════════════════════════════════

    /**
     * Shows a high-priority notification with a full-screen intent that
     * brings the Activity to the foreground — even when the screen is
     * locked. This is the standard Android pattern used by alarm and
     * emergency apps.
     *
     * On Android 10+ (API 29), background activity starts are restricted.
     * The full-screen intent bypasses this restriction for high-priority
     * notifications (CATEGORY_ALARM / CATEGORY_CALL).
     */
    fun showAccidentAlert() {
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("accident_detected", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 1, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setContentTitle("⚠️ Accident Detected!")
            .setContentText("Tap to open SOS countdown")
            .setSmallIcon(R.drawable.ic_sos_notification)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(ALERT_NOTIFICATION_ID, notification)

        Log.d(TAG, "Accident alert notification posted (full-screen intent)")
    }

    /**
     * Dismisses the accident alert notification (called after the user
     * has interacted with the SOS countdown).
     */
    fun dismissAccidentAlert() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.cancel(ALERT_NOTIFICATION_ID)
        Log.d(TAG, "Accident alert notification dismissed")
    }
}
