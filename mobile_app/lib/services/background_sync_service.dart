import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundSyncService {
  static const MethodChannel _channel = MethodChannel('com.cosmic/background_service');
  static const String _keyForegroundServiceEnabled = 'cosmic_foreground_service_enabled';

  /// Запуск нативного системного планировщика фонового мониторинга
  static Future<bool> startService() async {
    try {
      final res = await _channel.invokeMethod<bool>('startService');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyForegroundServiceEnabled, true);
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Остановка нативного планировщика
  static Future<bool> stopService() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopService');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyForegroundServiceEnabled, false);
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Проверка активности планировщика в системе
  static Future<bool> isServiceRunning() async {
    try {
      final res = await _channel.invokeMethod<bool>('isServiceRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Проверка, включен ли мониторинг в настройках пользователя
  static Future<bool> isServiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyForegroundServiceEnabled) ?? true; // По умолчанию включен!
  }

  /// Включение / выключение службы с сохранением
  static Future<void> toggleService(bool enable) async {
    if (enable) {
      await startService();
    } else {
      await stopService();
    }
  }

  /// Автоматическая инициализация при запуске приложения
  static Future<void> initService() async {
    final enabled = await isServiceEnabled();
    if (enabled) {
      await startService();
    }
  }

  /// Запуск немедленной фоновой проверки свежего прогноза
  static Future<bool> triggerImmediateCheck() async {
    try {
      final res = await _channel.invokeMethod<bool>('triggerSync');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Открытие системных настроек уведомлений
  static Future<bool> openNotificationSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openNotificationSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Открытие настроек оптимизации батареи приложения (выбор «Без ограничений»)
  static Future<bool> openBatterySettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openBatterySettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
