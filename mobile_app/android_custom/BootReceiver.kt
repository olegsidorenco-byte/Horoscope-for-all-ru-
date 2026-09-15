package com.cosmic.cosmic_horoscope

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.MY_PACKAGE_REPLACED" ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            try {
                // Проверяем, не отключил ли пользователь фоновый мониторинг в настройках
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean("flutter.cosmic_foreground_service_enabled", true)
                
                // Очищаем старые служебные уведомления 888 из шторки
                HoroscopeAlarmReceiver.cleanupLegacyForegroundService(context)
                HoroscopeAlarmReceiver.createNotificationChannels(context)

                if (isEnabled) {
                    // Планируем AlarmManager через 10 секунд после загрузки системы
                    HoroscopeAlarmReceiver.scheduleAlarm(context, 10000L)
                    // Запускаем быструю проверку на случай, если за время сна вышел новый гороскоп
                    HoroscopeAlarmReceiver.triggerImmediateCheck(context)
                }
            } catch (_: Exception) {}
        }
    }
}
