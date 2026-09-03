import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
        if (location.currentTimeZone.offset == deviceOffsetMs) {
          return location;
        }
      }
    } catch (_) {}
    return tz.local;
  }

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final loc = _resolveLocalLocation();
      tz.setLocalLocation(loc);
    } catch (_) {}

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Создаем канал уведомлений с максимальным приоритетом и звуком
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Восстанавливаем расписание из сохраненных настроек
    final isEnabled = await StorageService.isNotificationsEnabled();
    if (isEnabled) {
      final hour = await StorageService.getNotificationHour();
      final minute = await StorageService.getNotificationMinute();
      await scheduleDailyNotification(hour: hour, minute: minute);
    }
  }

  static Future<bool> requestPermission() async {
    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Запланировать ежедневное утреннее уведомление
  static Future<void> scheduleDailyNotification({
    int hour = 8,
    int minute = 0,
  }) async {
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
      styleInformation: BigTextStyleInformation(
        'Новый день уже наступил — узнайте ключевые планетарные аспекты, часы деловой активности и персональный совет дня ✨',
        contentTitle: '🪐 <b>Астро Гороскоп на сегодня готов!</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
      ),
    );

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

  /// Отправить уведомление о публикации свежего гороскопа (если еще не отправляли сегодня)
  static Future<void> showNewForecastNotification(String date) async {
    final lastNotified = await StorageService.getLastNotifiedDate();
    if (lastNotified == date) return;

    await requestPermission();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        'Опубликован новый подробный астрологический прогноз дня! Узнайте ключевые часы активности, влияние планет и персональный совет ✨',
        contentTitle: '✨ <b>Свежий гороскоп на сегодня готов!</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
      ),
    );

    await _notificationsPlugin.show(
      202,
      '✨ Свежий гороскоп на сегодня готов!',
      'Новый астрологический прогноз уже доступен в приложении ✨',
      const NotificationDetails(android: androidDetails),
    );

    await StorageService.setLastNotifiedDate(date);
  }

  /// Отменить напоминания
  static Future<void> cancelDailyNotification() async {
    await _notificationsPlugin.cancel(101);
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
      styleInformation: BigTextStyleInformation(
        'Новый астрологический прогноз успешно рассчитан! Ключевые часы активности и планетарные влияния уже в приложении ✨',
        contentTitle: '🪐 <b>Астро Гороскоп обновлен!</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
      ),
    );

    await _notificationsPlugin.show(
      999,
      '🪐 Астро Гороскоп обновлен!',
      'Новый астрологический прогноз уже доступен ✨',
      const NotificationDetails(android: androidDetails),
    );
  }
}
