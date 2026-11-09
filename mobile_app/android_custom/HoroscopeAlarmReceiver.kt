package com.cosmic.cosmic_horoscope

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.Executors
import org.json.JSONObject

/**
 * Часовопоясной системный планировщик AlarmManager для заблаговременной предзагрузки
 * и точной доставки гороскопа строго по локальному времени и дате пользователя.
 */
class HoroscopeAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_PREFETCH_HOROSCOPE = "com.cosmic.action.PREFETCH_HOROSCOPE"
        const val ACTION_CHECK_HOROSCOPE = "com.cosmic.action.CHECK_HOROSCOPE"
        const val EXTRA_TARGET_DATE_DMY = "extra_target_date_dmy"
        const val EXTRA_TARGET_DATE_ISO = "extra_target_date_iso"

        const val ALERTS_CHANNEL_ID = "cosmic_horoscope_daily_v2"
        const val ALERT_NOTIFICATION_ID = 202
        const val LEGACY_SERVICE_NOTIFICATION_ID = 888

        const val ALARM_PREFETCH_REQ_CODE = 908
        const val ALARM_REQUEST_CODE = 909
        const val PREFETCH_LEAD_MINUTES = 30

        const val REPO_BASE_URL =
            "https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/data"

        const val MODE_PREFETCH = "prefetch"
        const val MODE_DELIVER = "deliver"
        const val MODE_BOOT = "boot"
        const val MODE_MANUAL = "manual"

        private data class UserScheduleConfig(
            val serviceEnabled: Boolean,
            val notifEnabled: Boolean,
            val hour: Int,
            val minute: Int,
            val lang: String
        )

        private fun readUserSchedule(prefs: SharedPreferences): UserScheduleConfig {
            val serviceEnabled = prefs.getBoolean("flutter.cosmic_foreground_service_enabled", true)
            val notifEnabled = prefs.getBoolean("flutter.cosmic_notif_enabled", true)
            val rawAll = prefs.all
            val hour = (rawAll["flutter.cosmic_notif_hour"] as? Number)?.toInt()?.coerceIn(0, 23) ?: 6
            val minute = (rawAll["flutter.cosmic_notif_minute"] as? Number)?.toInt()?.coerceIn(0, 59) ?: 45
            val sysLang = Locale.getDefault().language.lowercase(Locale.ROOT)
            val fallbackLang = if (sysLang in setOf("ru", "en", "es", "de", "fr")) sysLang else "en"
            val lang = (prefs.getString("flutter.cosmic_selected_language", fallbackLang) ?: fallbackLang)
                .trim()
                .lowercase(Locale.ROOT)
                .ifEmpty { fallbackLang }
            return UserScheduleConfig(serviceEnabled, notifEnabled, hour, minute, lang)
        }

        private fun formatDates(cal: Calendar): Pair<String, String> {
            val dmyFmt = SimpleDateFormat("dd.MM.yyyy", Locale.US).apply {
                timeZone = cal.timeZone
            }
            val isoFmt = SimpleDateFormat("yyyy_MM_dd", Locale.US).apply {
                timeZone = cal.timeZone
            }
            return Pair(dmyFmt.format(cal.time), isoFmt.format(cal.time))
        }

        /**
         * Инициализация и создание каналов уведомлений
         */
        fun createNotificationChannels(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                try {
                    nm.deleteNotificationChannel("cosmic_service_silent_v2")
                    nm.deleteNotificationChannel("cosmic_horoscope_service_v1")
                } catch (_: Exception) {}

                val alertChannel = NotificationChannel(
                    ALERTS_CHANNEL_ID,
                    "Ежедневный Астро Гороскоп",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Оповещения о свежем астрологическом прогнозе в выбранное вами время"
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

        private fun setExactCompat(
            alarmManager: AlarmManager,
            triggerAtMillis: Long,
            pendingIntent: PendingIntent
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                } catch (_: SecurityException) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        }

        /**
         * Планирование заблаговременной предзагрузки (за 30 минут) и доставки строго
         * по выбранному пользователем локальному времени и часовому поясу смартфона.
         */
        fun scheduleAlarm(context: Context, @Suppress("UNUSED_PARAMETER") delayMillis: Long = 0L) {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val cfg = readUserSchedule(prefs)
                if (!cfg.serviceEnabled) {
                    cancelAlarm(context)
                    return
                }

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val nowCal = Calendar.getInstance()
                val nowMillis = nowCal.timeInMillis

                // Вычисляем ближайший слот доставки строго в локальном часовом поясе пользователя
                val nextDeliveryCal = (nowCal.clone() as Calendar).apply {
                    set(Calendar.HOUR_OF_DAY, cfg.hour)
                    set(Calendar.MINUTE, cfg.minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                if (nextDeliveryCal.timeInMillis <= nowMillis + 2000L) {
                    nextDeliveryCal.add(Calendar.DAY_OF_YEAR, 1)
                }

                val (targetDmy, targetIso) = formatDates(nextDeliveryCal)
                val immutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }

                // 1. Заблаговременная бесшумная предзагрузка за 30 минут до времени пользователя
                // (если пользователь выбрал 00:15, предзагрузка в 23:45 заранее скачает прогноз на завтрашнюю дату!)
                val prefetchCal = (nextDeliveryCal.clone() as Calendar).apply {
                    add(Calendar.MINUTE, -PREFETCH_LEAD_MINUTES)
                }
                if (prefetchCal.timeInMillis > nowMillis + 5000L) {
                    val prefetchIntent = Intent(context, HoroscopeAlarmReceiver::class.java).apply {
                        action = ACTION_PREFETCH_HOROSCOPE
                        putExtra(EXTRA_TARGET_DATE_DMY, targetDmy)
                        putExtra(EXTRA_TARGET_DATE_ISO, targetIso)
                    }
                    val prefetchPi = PendingIntent.getBroadcast(
                        context,
                        ALARM_PREFETCH_REQ_CODE,
                        prefetchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag
                    )
                    setExactCompat(alarmManager, prefetchCal.timeInMillis, prefetchPi)
                }

                // 2. Основной будильник доставки точно в выбранное пользователем локальное время
                val deliverIntent = Intent(context, HoroscopeAlarmReceiver::class.java).apply {
                    action = ACTION_CHECK_HOROSCOPE
                    putExtra(EXTRA_TARGET_DATE_DMY, targetDmy)
                    putExtra(EXTRA_TARGET_DATE_ISO, targetIso)
                }
                val deliverPi = PendingIntent.getBroadcast(
                    context,
                    ALARM_REQUEST_CODE,
                    deliverIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag
                )
                setExactCompat(alarmManager, nextDeliveryCal.timeInMillis, deliverPi)
            } catch (_: Exception) {}
        }

        /**
         * Отмена фонового планировщика (предзагрузки и доставки)
         */
        fun cancelAlarm(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val immutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }

                val actions = listOf(
                    Pair(ACTION_PREFETCH_HOROSCOPE, ALARM_PREFETCH_REQ_CODE),
                    Pair(ACTION_CHECK_HOROSCOPE, ALARM_REQUEST_CODE)
                )
                for ((act, code) in actions) {
                    val intent = Intent(context, HoroscopeAlarmReceiver::class.java).apply {
                        action = act
                    }
                    val pi = PendingIntent.getBroadcast(
                        context,
                        code,
                        intent,
                        PendingIntent.FLAG_NO_CREATE or immutableFlag
                    )
                    if (pi != null) {
                        alarmManager.cancel(pi)
                        pi.cancel()
                    }
                }
            } catch (_: Exception) {}
        }

        /**
         * Проверка, запланирован ли системный будильник доставки
         */
        fun isAlarmScheduled(context: Context): Boolean {
            return try {
                val intent = Intent(context, HoroscopeAlarmReceiver::class.java).apply {
                    action = ACTION_CHECK_HOROSCOPE
                }
                val immutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
                PendingIntent.getBroadcast(
                    context,
                    ALARM_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_NO_CREATE or immutableFlag
                ) != null
            } catch (_: Exception) {
                false
            }
        }

        /**
         * Мгновенный запуск фоновой проверки (по кнопке «Проверить сейчас» или при старте)
         */
        fun triggerImmediateCheck(context: Context, silentOnly: Boolean = false) {
            Executors.newSingleThreadExecutor().execute {
                performBackgroundSync(
                    context,
                    mode = if (silentOnly) MODE_PREFETCH else MODE_MANUAL
                )
            }
        }

        /**
         * Проверка после перезагрузки / смены часового пояса:
         * если выбранное время сегодня уже наступило, но уведомление еще не доставлялось — доставляем.
         * Если время еще не наступило — только бесшумно предзагружаем кэш.
         */
        fun triggerBootOrTimezoneSync(context: Context) {
            Executors.newSingleThreadExecutor().execute {
                performBackgroundSync(context, mode = MODE_BOOT)
            }
        }

        private fun fetchJsonText(urlStr: String): String? {
            var conn: HttpURLConnection? = null
            return try {
                val url = URL(urlStr)
                conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 12000
                    readTimeout = 12000
                    requestMethod = "GET"
                    useCaches = false
                    setRequestProperty("Cache-Control", "no-cache")
                }
                if (conn.responseCode == 200) {
                    conn.inputStream.bufferedReader().use { it.readText() }
                } else {
                    null
                }
            } catch (_: Exception) {
                null
            } finally {
                try {
                    conn?.disconnect()
                } catch (_: Exception) {}
            }
        }

        /**
         * Загрузка прогноза строго под целевую локальную дату пользователя и показ уведомления только в разрешенный момент
         */
        fun performBackgroundSync(
            context: Context,
            mode: String = MODE_DELIVER,
            explicitTargetDmy: String? = null,
            explicitTargetIso: String? = null
        ) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "CosmicHoroscope:AlarmSyncLock")
            try {
                wakeLock?.acquire(20000)
            } catch (_: Exception) {}

            try {
                createNotificationChannels(context)
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val cfg = readUserSchedule(flutterPrefs)

                val nowCal = Calendar.getInstance()
                val (todayDmy, todayIso) = formatDates(nowCal)

                val targetDmy = explicitTargetDmy?.takeIf { it.isNotEmpty() } ?: todayDmy
                val targetIso = explicitTargetIso?.takeIf { it.isNotEmpty() } ?: todayIso

                val langSuffix = if (cfg.lang == "ru") "" else "_${cfg.lang}"
                val cacheBuster = System.currentTimeMillis()

                // 1. Сначала пробуем точный файл под локальную дату пользователя (поддерживает сдвиг суток на Восток и Запад)
                val exactArchiveUrl = "$REPO_BASE_URL/archive/horoscope_${targetIso}${langSuffix}.json?t=$cacheBuster"
                var matchedJsonStr: String? = fetchJsonText(exactArchiveUrl)
                var resolvedDate = targetDmy

                // 2. Фолбэк на latest_horoscope, если точный архивный файл еще не выложен или дата совпадает
                if (matchedJsonStr == null) {
                    val latestUrl = "$REPO_BASE_URL/latest_horoscope${langSuffix}.json?t=$cacheBuster"
                    val latestStr = fetchJsonText(latestUrl)
                    if (latestStr != null) {
                        val obj = JSONObject(latestStr)
                        val latestDate = obj.optString("date", "").trim()
                        if (latestDate == targetDmy || mode == MODE_MANUAL) {
                            matchedJsonStr = latestStr
                            if (latestDate.isNotEmpty()) {
                                resolvedDate = latestDate
                            }
                        }
                    }
                } else {
                    try {
                        val obj = JSONObject(matchedJsonStr)
                        val d = obj.optString("date", "").trim()
                        if (d.isNotEmpty()) resolvedDate = d
                    } catch (_: Exception) {}
                }

                val hasCorruptedCyrillic = cfg.lang != "ru" &&
                    matchedJsonStr != null &&
                    Regex("[а-яА-ЯёЁ]{3,}").containsMatchIn(matchedJsonStr)

                if (matchedJsonStr != null && resolvedDate.isNotEmpty() && !hasCorruptedCyrillic) {
                    // Бесшумно обновляем локальный кэш Flutter для мгновенного открытия оффлайн
                    val editor = flutterPrefs.edit()
                    editor.putString("flutter.cosmic_cache_latest_json_${cfg.lang}", matchedJsonStr)
                    if (cfg.lang == "ru") {
                        editor.putString("flutter.cosmic_cache_latest_json", matchedJsonStr)
                    }
                    editor.apply()

                    // Определяем, разрешено ли сейчас показывать звуковое уведомление пользователю
                    val shouldNotify = when (mode) {
                        MODE_PREFETCH -> false // Предзагрузка всегда бесшумна!
                        MODE_DELIVER -> cfg.notifEnabled && resolvedDate == todayDmy
                        MODE_BOOT -> {
                            val todaySlotCal = (nowCal.clone() as Calendar).apply {
                                set(Calendar.HOUR_OF_DAY, cfg.hour)
                                set(Calendar.MINUTE, cfg.minute)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }
                            cfg.notifEnabled &&
                                resolvedDate == todayDmy &&
                                nowCal.timeInMillis >= todaySlotCal.timeInMillis
                        }
                        MODE_MANUAL -> true
                        else -> false
                    }

                    if (shouldNotify) {
                        val lastNotified = flutterPrefs.getString("flutter.cosmic_last_notified_date", "")
                        val lastRead = flutterPrefs.getString("flutter.cosmic_last_read_date", "")
                        if (resolvedDate != lastNotified && resolvedDate != lastRead) {
                            showMorningAlert(context, resolvedDate, cfg.lang)
                            flutterPrefs.edit()
                                .putString("flutter.cosmic_last_notified_date", resolvedDate)
                                .apply()
                        }
                    }
                }
            } catch (_: Exception) {
            } finally {
                try {
                    if (wakeLock?.isHeld == true) {
                        wakeLock.release()
                    }
                } catch (_: Exception) {}
            }
        }

        private fun showMorningAlert(context: Context, dateStr: String, lang: String = "ru") {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                1,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )

            val (titleText, shortBody, bigBody) = when (lang) {
                "fr" -> Triple(
                    "✨ Votre horoscope du jour est prêt !",
                    "Le nouveau calcul astrologique ($dateStr) est disponible ✨",
                    "Votre horoscope détaillé du jour ($dateStr) est publié ! Découvrez les heures favorables, l'influence des planètes et votre conseil personnel ✨"
                )
                "en" -> Triple(
                    "✨ Your daily horoscope is ready!",
                    "Fresh astrological forecast ($dateStr) is now available ✨",
                    "Your detailed astrological forecast for today ($dateStr) is published! Discover your lucky hours, planetary influences, and personal advice ✨"
                )
                "es" -> Triple(
                    "✨ ¡Su horóscopo de hoy está listo!",
                    "El nuevo pronóstico astrológico ($dateStr) ya está disponible ✨",
                    "¡Se ha publicado el pronóstico astrológico detallado del día ($dateStr)! Descubra sus horas favorables, la influencia planetaria y el consejo personal ✨"
                )
                "de" -> Triple(
                    "✨ Ihr Tageshoroskop ist bereit!",
                    "Die neue astrologische Prognose ($dateStr) ist verfügbar ✨",
                    "Ihr ausführliches Tageshoroskop ($dateStr) ist veröffentlicht! Entdecken Sie Ihre Glücksstunden, Planeteneinflüsse und Ihren persönlichen Rat ✨"
                )
                else -> Triple(
                    "✨ Свежий гороскоп на сегодня готов!",
                    "Новый астрологический прогноз ($dateStr) уже доступен в приложении ✨",
                    "Опубликован подробный астрологический прогноз дня ($dateStr)! Узнайте ключевые часы активности, влияние планет и персональный совет ✨"
                )
            }

            val alertNotification = NotificationCompat.Builder(context, ALERTS_CHANNEL_ID)
                .setContentTitle(titleText)
                .setContentText(shortBody)
                .setStyle(NotificationCompat.BigTextStyle().bigText(bigBody))
                .setSmallIcon(R.mipmap.ic_launcher)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .build()

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // Убираем дублирующее уведомление 101 из шторки (не затрагивая будущий AlarmManager 101)
            try {
                nm.cancel(101)
            } catch (_: Exception) {}
            nm.notify(ALERT_NOTIFICATION_ID, alertNotification)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        cleanupLegacyForegroundService(context)
        createNotificationChannels(context)

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cfg = readUserSchedule(prefs)
        if (!cfg.serviceEnabled) return

        val action = intent?.action ?: ACTION_CHECK_HOROSCOPE
        val targetDmy = intent?.getStringExtra(EXTRA_TARGET_DATE_DMY)
        val targetIso = intent?.getStringExtra(EXTRA_TARGET_DATE_ISO)
        val syncMode = if (action == ACTION_PREFETCH_HOROSCOPE) MODE_PREFETCH else MODE_DELIVER

        // Перепланируем следующую пару будильников (предзагрузка + доставка) по локальному поясу
        scheduleAlarm(context)

        val pendingResult = goAsync()
        Executors.newSingleThreadExecutor().execute {
            try {
                performBackgroundSync(
                    context,
                    mode = syncMode,
                    explicitTargetDmy = targetDmy,
                    explicitTargetIso = targetIso
                )
            } finally {
                pendingResult.finish()
            }
        }
    }
}
