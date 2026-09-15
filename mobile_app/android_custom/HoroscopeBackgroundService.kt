package com.cosmic.cosmic_horoscope

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Класс обратной совместимости.
 * Если старые системные компоненты или предыдущая версия приложения пытаются запустить
 * Foreground Service — служба немедленно очищает старые уведомления из шторки,
 * переключается на HoroscopeAlarmReceiver и останавливает себя (stopSelf).
 */
class HoroscopeBackgroundService : Service() {

    override fun onCreate() {
        super.onCreate()
        HoroscopeAlarmReceiver.cleanupLegacyForegroundService(this)
        HoroscopeAlarmReceiver.scheduleAlarm(this)
        stopSelf()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        HoroscopeAlarmReceiver.cleanupLegacyForegroundService(this)
        HoroscopeAlarmReceiver.scheduleAlarm(this)
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
