package com.cosmic.cosmic_horoscope

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import org.json.JSONObject

/**
 * Бесшумный системный приемник AlarmManager для периодической проверки гороскопа в фоне.
 * Не создает постоянных служб и не выводит постоянных значков в шторку уведомлений.
 * Появляется в шторке ТОЛЬКО при наличии свежего прогноза дня!
 */
class HoroscopeAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_CHECK_HOROSCOPE = "com.cosmic.action.CHECK_HOROSCOPE"
        const val ALERTS_CHANNEL_ID = "cosmic_horoscope_daily_v2"
        const val ALERT_NOTIFICATION_ID = 202
        const val LEGACY_SERVICE_NOTIFICATION_ID = 888
        const val ALARM_REQUEST_CODE = 909
        const val INTERVAL_MILLIS = 15 * 60 * 1000L // 15 минут
        const val GITHUB_JSON_URL = "https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/data/latest_horoscope.json"

        /**
         * Инициализация и создание каналов уведомлений
         */
        fun createNotificationChannels(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                // Удаляем старые служебные каналы
                try {
                    nm.deleteNotificationChannel("cosmic_service_silent_v2")
                    nm.deleteNotificationChannel("cosmic_horoscope_service_v1")
                } catch (_: Exception) {}

                // Основной пользовательский канал для алертов о новом гороскопе дня
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

        /**
         * Полная очистка устаревшей Foreground-службы и ее значка из шторки
         */
        fun cleanupLegacyForegroundService(context: Context) {
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(LEGACY_SERVICE_NOTIFICATION_ID)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    nm.deleteNotificationChannel("cosmic_service_silent_v2")
                    nm.deleteNotificationChannel("cosmic_horoscope_service_v1")
                }
            } catch (_: Exception) {}

            try {
                val intent = Intent(context, HoroscopeBackgroundService::class.java)
                context.stopService(intent)
            } catch (_: Exception) {}
        }

        /**
         * Планирование следующей фоновой проверки через AlarmManager
         */
        fun scheduleAlarm(context: Context, delayMillis: Long = INTERVAL_MILLIS) {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean("flutter.cosmic_foreground_service_enabled", true)
                if (!isEnabled) return

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, HoroscopeAlarmReceiver::class.java).apply {
                    action = ACTION_CHECK_HOROSCOPE
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    ALARM_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )

                val triggerAtMillis = System.currentTimeMillis() + delayMillis

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                    } catch (_: SecurityException) {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                    }
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } catch (_: Exception) {}
        }

        /**
         * Отмена фонового планировщика
         */
        fun cancelAlarm(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, HoroscopeAlarmReceiver::class.java).apply {
                    action = ACTION_CHECK_HOROSCOPE
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    ALARM_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_NO_CREATE or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )
                if (pendingIntent != null) {
                    alarmManager.cancel(pendingIntent)
                    pendingIntent.cancel()
                }
            } catch (_: Exception) {}
        }

        /**
         * Проверка, запланирован ли будильник
         */
        fun isAlarmScheduled(context: Context): Boolean {
            return try {
                val intent = Intent(context, HoroscopeAlarmReceiver::class.java).apply {
                    action = ACTION_CHECK_HOROSCOPE
                }
                PendingIntent.getBroadcast(
                    context,
                    ALARM_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_NO_CREATE or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                ) != null
            } catch (_: Exception) {
                false
            }
        }

        /**
         * Мгновенный запуск фоновой проверки без ожидания таймера
         */
        fun triggerImmediateCheck(context: Context) {
            Executors.newSingleThreadExecutor().execute {
                performBackgroundSync(context)
            }
        }

        /**
         * Выполнение сетевой проверки и показ уведомления при наличии нового прогноза
         */
        fun performBackgroundSync(context: Context) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "CosmicHoroscope:AlarmSyncLock")
            try {
                wakeLock?.acquire(20000)
            } catch (_: Exception) {}

            try {
                createNotificationChannels(context)

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
                        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val lastNotified = flutterPrefs.getString("flutter.cosmic_last_notified_date", "")
                        val lastRead = flutterPrefs.getString("flutter.cosmic_last_read_date", "")

                        // Уведомление показывается ТОЛЬКО если прогноз новый и еще не был показан или прочитан
                        if (horoscopeDate != lastNotified && horoscopeDate != lastRead) {
                            showMorningAlert(context, horoscopeDate)
                            flutterPrefs.edit().putString("flutter.cosmic_last_notified_date", horoscopeDate).apply()
                        }
                    }
                }
                conn.disconnect()
            } catch (_: Exception) {
                // Сетевой сбой — повторится при следующем тике
            } finally {
                try {
                    if (wakeLock?.isHeld == true) {
                        wakeLock.release()
                    }
                } catch (_: Exception) {}
            }
        }

        private fun showMorningAlert(context: Context, dateStr: String) {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                1,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )

            val alertNotification = NotificationCompat.Builder(context, ALERTS_CHANNEL_ID)
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

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(ALERT_NOTIFICATION_ID, alertNotification)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        cleanupLegacyForegroundService(context)
        createNotificationChannels(context)

        // Планируем следующий цикл на 15 минут вперед
        scheduleAlarm(context, INTERVAL_MILLIS)

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("flutter.cosmic_foreground_service_enabled", true)
        if (!isEnabled) return

        val pendingResult = goAsync()
        Executors.newSingleThreadExecutor().execute {
            try {
                performBackgroundSync(context)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
