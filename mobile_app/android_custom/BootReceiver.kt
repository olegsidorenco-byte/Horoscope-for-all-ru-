package com.cosmic.cosmic_horoscope

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == "android.intent.action.MY_PACKAGE_REPLACED" ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {

            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean("flutter.cosmic_foreground_service_enabled", true)

                HoroscopeAlarmReceiver.cleanupLegacyForegroundService(context)
                HoroscopeAlarmReceiver.createNotificationChannels(context)

                if (isEnabled) {
                    // Пересчитываем расписание предзагрузки и доставки под актуальный часовой пояс устройства
                    HoroscopeAlarmReceiver.scheduleAlarm(context)
                    // Безопасно проверяем кэш (уведомит только если выбранное время сегодня уже наступило)
                    HoroscopeAlarmReceiver.triggerBootOrTimezoneSync(context)
                }
            } catch (_: Exception) {}
        }
    }
}
