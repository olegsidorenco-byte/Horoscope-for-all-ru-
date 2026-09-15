package com.cosmic.cosmic_horoscope

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.cosmic/background_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // При запуске приложения сразу очищаем любые старые служебные уведомления из шторки
        HoroscopeAlarmReceiver.cleanupLegacyForegroundService(this)
        HoroscopeAlarmReceiver.createNotificationChannels(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    try {
                        HoroscopeAlarmReceiver.scheduleAlarm(this, 1000L)
                        HoroscopeAlarmReceiver.triggerImmediateCheck(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopService" -> {
                    try {
                        HoroscopeAlarmReceiver.cancelAlarm(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "isServiceRunning" -> {
                    try {
                        val isScheduled = HoroscopeAlarmReceiver.isAlarmScheduled(this)
                        result.success(isScheduled)
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "triggerSync" -> {
                    try {
                        HoroscopeAlarmReceiver.triggerImmediateCheck(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SYNC_FAILED", e.message, null)
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_NOTIF_FAILED", e.message, null)
                    }
                }
                "openBatterySettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Резервный переход в свойства приложения
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("OPEN_BATTERY_FAILED", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
