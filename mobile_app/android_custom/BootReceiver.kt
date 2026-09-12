package com.cosmic.cosmic_horoscope

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.MY_PACKAGE_REPLACED" ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            try {
                // Проверяем, не отключил ли пользователь фоновую службу в настройках приложения
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean("flutter.cosmic_foreground_service_enabled", true)
                if (isEnabled) {
                    val serviceIntent = Intent(context, HoroscopeBackgroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                }
            } catch (_: Exception) {}
        }
    }
}
