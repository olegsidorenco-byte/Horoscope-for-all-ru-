import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'cosmic_horoscope_daily';
  static const String channelName = 'Ежедневный Астро Гороскоп';
  static const String channelDescription =
      'Утренние напоминания о свежем астрологическом прогнозе дня';

  /// Определение правильной временной зоны на основе текущего смещения устройства
  static tz.Location _resolveLocalLocation() {
    try {
      final deviceOffsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      for (final location in tz.timeZoneDatabase.locations.values) {
        try {
          if (location.currentTimeZone.offset == deviceOffsetMs) {
            return location;
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      return tz.getLocation('Europe/Moscow');
    } catch (_) {
      return tz.local;
    }
  }

  /// Инициализация сервиса уведомлений, каналов и разрешений
  static Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      final loc = _resolveLocalLocation();
      tz.setLocalLocation(loc);
    } catch (_) {}

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
    } catch (_) {}

    // Создаем канал уведомлений с максимальным приоритетом, звуком и бейджем на иконке
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true, // Включает бейдж/точку на иконке приложения на рабочем столе
    );

    try {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (_) {}

    // Запрашиваем разрешения Android 13+ (уведомления и точные будильники)
    await requestPermission();

    // Синхронизируем состояние бейджа на иконке рабочего стола при старте
    try {
      final hasUnread = await StorageService.hasUnreadHoroscope();
      if (hasUnread) {
        await updateBadge(1);
      } else {
        await clearBadge();
      }
    } catch (_) {}

    // Восстанавливаем расписание из сохраненных настроек
    try {
      final isEnabled = await StorageService.isNotificationsEnabled();
      if (isEnabled) {
        final hour = await StorageService.getNotificationHour();
        final minute = await StorageService.getNotificationMinute();
        await scheduleDailyNotification(hour: hour, minute: minute);
      }
    } catch (_) {}
  }

  /// Запрос системных разрешений для Android 13/14+
  static Future<bool> requestPermission() async {
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        try {
          await androidImpl.requestExactAlarmsPermission();
        } catch (_) {}
        return granted ?? false;
      }
    } catch (_) {}
    return true;
  }

  /// Управление бейджем (счетчиком непрочитанных) на иконке рабочего стола
  static Future<void> updateBadge(int count) async {
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        if (count > 0) {
          FlutterAppBadger.updateBadgeCount(count);
        } else {
          FlutterAppBadger.removeBadge();
        }
      }
    } catch (_) {}
  }

  /// Очистка бейджа на иконке приложения
  static Future<void> clearBadge() async {
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        FlutterAppBadger.removeBadge();
      }
    } catch (_) {}
  }

  /// Снятие активных уведомлений из шторки и очистка бейджа на иконке
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancel(202);
      await _notificationsPlugin.cancel(999);
      await clearBadge();
    } catch (_) {}
  }

  /// Запланировать ежедневное утреннее уведомление
  static Future<void> scheduleDailyNotification({
    int hour = 8,
    int minute = 0,
  }) async {
    try {
      await _notificationsPlugin.cancel(101); // Отменяем предыдущее расписание

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        number: 1,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          'Новый день уже наступил — узнайте ключевые планетарные аспекты, часы деловой активности и персональный совет дня ✨',
          contentTitle: '🪐 <b>Астро Гороскоп на сегодня готов!</b>',
          htmlFormatContentTitle: true,
          htmlFormatBigText: true,
        ),
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          101,
          '🪐 Астро Гороскоп на сегодня готов!',
          'Узнайте ключевые аспекты дня, часы успеха и совет ✨',
          scheduledDate,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {
        await _notificationsPlugin.zonedSchedule(
          101,
          '🪐 Астро Гороскоп на сегодня готов!',
          'Узнайте ключевые аспекты дня, часы успеха и совет ✨',
          scheduledDate,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {}
  }

  /// Отправить уведомление о публикации свежего гороскопа (если еще не отправляли сегодня)
  static Future<void> showNewForecastNotification(String date) async {
    final lastNotified = await StorageService.getLastNotifiedDate();
    if (lastNotified == date) {
      // Даже если уведомление уже показывалось сегодня, синхронизируем бейдж 1
      await updateBadge(1);
      return;
    }

    await requestPermission();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      number: 1,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        'Опубликован новый подробный астрологический прогноз дня! Узнайте ключевые часы активности, влияние планет и персональный совет ✨',
        contentTitle: '✨ <b>Свежий гороскоп на сегодня готов!</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
      ),
    );

    try {
      await _notificationsPlugin.show(
        202,
        '✨ Свежий гороскоп на сегодня готов!',
        'Новый астрологический прогноз уже доступен в приложении ✨',
        const NotificationDetails(android: androidDetails),
      );
      await updateBadge(1);
      await StorageService.setLastNotifiedDate(date);
    } catch (_) {}
  }

  /// Отменить напоминания
  static Future<void> cancelDailyNotification() async {
    try {
      await _notificationsPlugin.cancel(101);
    } catch (_) {}
  }

  /// Мгновенное тестовое уведомление для проверки работы
  static Future<void> sendInstantTestNotification() async {
    await requestPermission();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      number: 1,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        'Новый астрологический прогноз успешно рассчитан! Ключевые часы активности и планетарные влияния уже в приложении ✨',
        contentTitle: '🪐 <b>Астро Гороскоп обновлен!</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
      ),
    );

    try {
      await _notificationsPlugin.show(
        999,
        '🪐 Астро Гороскоп обновлен!',
        'Новый астрологический прогноз уже доступен ✨',
        const NotificationDetails(android: androidDetails),
      );
      await updateBadge(1);
    } catch (_) {}
  }
}
