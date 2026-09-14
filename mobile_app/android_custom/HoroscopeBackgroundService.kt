package com.cosmic.cosmic_horoscope

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import org.json.JSONObject

class HoroscopeBackgroundService : Service() {

    companion object {
        var isRunning = false
        const val SERVICE_CHANNEL_ID = "cosmic_service_silent_v2"
        const val ALERTS_CHANNEL_ID = "cosmic_horoscope_daily_v2"
        const val SERVICE_NOTIFICATION_ID = 888
        const val ALERT_NOTIFICATION_ID = 202
        const val GITHUB_JSON_URL = "https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/data/latest_horoscope.json"
    }

    private var scheduler: ScheduledExecutorService? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannels()
        startForegroundServiceInternal()
        startPeriodicSync()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        startForegroundServiceInternal()
        if (scheduler == null || scheduler!!.isShutdown) {
            startPeriodicSync()
        }
        return START_STICKY
    }

    private fun startForegroundServiceInternal() {
        try {
            val notification = buildServiceNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(SERVICE_NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(SERVICE_NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        isRunning = false
        try {
            scheduler?.shutdownNow()
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Удаляем старый канал v1 с IMPORTANCE_LOW, чтобы он не оставался в системе
            try {
                nm.deleteNotificationChannel("cosmic_horoscope_service_v1")
            } catch (_: Exception) {}

            // 1. Абсолютно тихий, минимизированный канал фоновой службы (IMPORTANCE_MIN)
            val serviceChannel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Фоновый мониторинг (служба)",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Техническая служба для работы в фоне"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            nm.createNotificationChannel(serviceChannel)

            // 2. Громкий канал всплывающих алертов дня
            val alertChannel = NotificationChannel(
                ALERTS_CHANNEL_ID,
                "Ежедневный Астро Гороскоп",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Утренние оповещения о новом гороскопе дня"
                enableVibration(true)
                setShowBadge(true)
            }
            nm.createNotificationChannel(alertChannel)
        }
    }

    private fun buildServiceNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // Интент для перехода в системные настройки отключения значка службы в 1 клик
        val hideSettingsIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(android.provider.Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra(android.provider.Settings.EXTRA_CHANNEL_ID, SERVICE_CHANNEL_ID)
            }
        } else {
            Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
            }
        }
        val hidePendingIntent = PendingIntent.getActivity(
            this,
            2,
            hideSettingsIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setContentTitle("🪐 Астро Гороскоп (в фоне)")
            .setContentText("Работает в фоне. Нажмите «Скрыть», чтобы убрать из шторки.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(false) // Разрешает смахнуть уведомление из шторки вбок!
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Скрыть из шторки", hidePendingIntent)
            .build()
    }

    private fun startPeriodicSync() {
        try {
            scheduler?.shutdownNow()
        } catch (_: Exception) {}

        scheduler = Executors.newSingleThreadScheduledExecutor()
        // Проверяем через 15 секунд после старта службы, затем каждые 15 минут
        scheduler?.scheduleWithFixedDelay({
            checkAndNotifyHoroscope()
        }, 15, 15 * 60, TimeUnit.SECONDS)
    }

    private fun checkAndNotifyHoroscope() {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "CosmicHoroscope:BackgroundSyncLock")
        try {
            wakeLock?.acquire(15000)
        } catch (_: Exception) {}

        try {
            val url = URL(GITHUB_JSON_URL)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 12000
            conn.readTimeout = 12000
            conn.requestMethod = "GET"
            conn.useCaches = false
            conn.setRequestProperty("Cache-Control", "no-cache")

            if (conn.responseCode == 200) {
                val jsonStr = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(jsonStr)
                val horoscopeDate = json.optString("date", "").trim()

                if (horoscopeDate.isNotEmpty()) {
                    val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val lastNotified = flutterPrefs.getString("flutter.cosmic_last_notified_date", "")
                    val lastRead = flutterPrefs.getString("flutter.cosmic_last_read_date", "")

                    if (horoscopeDate != lastNotified && horoscopeDate != lastRead) {
                        showMorningAlert(horoscopeDate)
                        flutterPrefs.edit().putString("flutter.cosmic_last_notified_date", horoscopeDate).apply()
                    }
                }
            }
            conn.disconnect()
        } catch (_: Exception) {
            // Ошибка сети — повторится при следующем таймере
        } finally {
            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock.release()
                }
            } catch (_: Exception) {}
        }
    }

    private fun showMorningAlert(dateStr: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val alertNotification = NotificationCompat.Builder(this, ALERTS_CHANNEL_ID)
            .setContentTitle("✨ Свежий гороскоп на сегодня готов!")
            .setContentText("Новый астрологический прогноз ($dateStr) уже доступен в приложении ✨")
            .setStyle(NotificationCompat.BigTextStyle().bigText(
                "Опубликован новый подробный астрологический прогноз дня ($dateStr)! Узнайте ключевые часы активности, влияние планет и персональный совет ✨"
            ))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(ALERT_NOTIFICATION_ID, alertNotification)
    }
}
