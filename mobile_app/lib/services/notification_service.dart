import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:app_badge_plus/app_badge_plus.dart';
import 'background_sync_service.dart';
import 'storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _tzInitialized = false;

  static const String channelId = 'cosmic_horoscope_daily_v2';
  static const String channelName = 'Ежедневный Астро Гороскоп';
  static const String channelDescription =
      'Утренние напоминания о свежем астрологическом прогнозе дня';

  static const List<String> _priorityLocations = [
    'Europe/Chisinau',
    'Europe/Moscow',
    'Europe/Kyiv',
    'Europe/Minsk',
    'Europe/Berlin',
    'Europe/Paris',
    'Europe/London',
    'Europe/Lisbon',
    'UTC',
    'Asia/Tehran',
    'Asia/Dubai',
    'Asia/Tbilisi',
    'Asia/Yerevan',
    'Asia/Baku',
    'Asia/Kabul',
    'Asia/Tashkent',
    'Asia/Yekaterinburg',
    'Asia/Kolkata',
    'Asia/Kathmandu',
    'Asia/Almaty',
    'Asia/Omsk',
    'Asia/Novosibirsk',
    'Asia/Bangkok',
    'Asia/Irkutsk',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Asia/Seoul',
    'Australia/Adelaide',
    'Asia/Vladivostok',
    'Australia/Sydney',
    'Asia/Magadan',
    'Asia/Kamchatka',
    'Pacific/Auckland',
    'Pacific/Honolulu',
    'America/Anchorage',
    'America/Los_Angeles',
    'America/Denver',
    'America/Chicago',
    'America/New_York',
    'America/Sao_Paulo',
  ];

  static void _ensureTimeZonesInitialized() {
    if (!_tzInitialized) {
      try {
        tz.initializeTimeZones();
        _tzInitialized = true;
      } catch (_) {}
    }
  }

  /// Определение правильной временной зоны строго в соответствии с точным смещением (включая дробные зоны +5:30, +3:30, +5:45)
  static tz.Location _resolveLocalLocation() {
    _ensureTimeZonesInitialized();
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      final tzNameHint = now.timeZoneName.trim();

      // Если ОС вернула прямое IANA-имя в timeZoneName и его смещение совпадает
      if (tzNameHint.contains('/') && tz.timeZoneDatabase.locations.containsKey(tzNameHint)) {
        final directLoc = tz.getLocation(tzNameHint);
        if (directLoc.currentTimeZone.offset == offsetMs) {
          return directLoc;
        }
      }

      // Проверяем приоритетные часовые пояса с точным совпадением смещения в миллисекундах (учитывает летнее/зимнее время)
      for (final name in _priorityLocations) {
        try {
          if (tz.timeZoneDatabase.locations.containsKey(name)) {
            final loc = tz.getLocation(name);
            if (loc.currentTimeZone.offset == offsetMs) {
              return loc;
            }
          }
        } catch (_) {}
      }

      // Точный поиск среди всех локаций базы данных по смещению в миллисекундах
      for (final loc in tz.timeZoneDatabase.locations.values) {
        try {
          if (loc.currentTimeZone.offset == offsetMs) {
            return loc;
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      return tz.getLocation('UTC');
    } catch (_) {
      return tz.local;
    }
  }

  /// Возвращает определенное IANA-имя часового пояса устройства (напр. 'Asia/Vladivostok')
  static String getDetectedTimezoneName() {
    try {
      return _resolveLocalLocation().name;
    } catch (_) {
      return 'UTC';
    }
  }

  /// Возвращает текущее смещение часового пояса пользователя от UTC в минутах
  static int getUtcOffsetMinutes() {
    return DateTime.now().timeZoneOffset.inMinutes;
  }

  /// Человекочитаемая метка смещения от UTC (напр. 'UTC+03:00', 'UTC+05:30', 'UTC-04:00')
  static String getFormattedUtcOffset() {
    final totalMinutes = getUtcOffsetMinutes();
    final sign = totalMinutes >= 0 ? '+' : '-';
    final absMins = totalMinutes.abs();
    final h = (absMins ~/ 60).toString().padLeft(2, '0');
    final m = (absMins % 60).toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }

  /// Инициализация сервиса уведомлений, каналов и разрешений
  static Future<void> initialize() async {
    try {
      _ensureTimeZonesInitialized();
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

    // Создаем канал уведомлений с наивысшим приоритетом, звуком и бейджем на иконке
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
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
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (_) {}
  }

  /// Очистка бейджа на иконке приложения
  static Future<void> clearBadge() async {
    try {
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) {
        await AppBadgePlus.updateBadge(0);
      }
    } catch (_) {}
  }

  /// Снятие только активных всплывающих уведомлений из шторки без отмены ежедневного будильника 101
  static Future<void> dismissActiveAlerts() async {
    try {
      await _notificationsPlugin.cancel(202);
      await _notificationsPlugin.cancel(999);
      await clearBadge();
    } catch (_) {}
  }

  /// Полная отмена всех уведомлений и будильников
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancel(101);
      await _notificationsPlugin.cancel(102);
      await _notificationsPlugin.cancel(103);
      await _notificationsPlugin.cancel(202);
      await _notificationsPlugin.cancel(999);
      await clearBadge();
    } catch (_) {}
  }

  /// Запланировать ежедневное уведомление строго на выбранное пользователем время в его часовом поясе
  static Future<void> scheduleDailyNotification({
    int hour = 6,
    int minute = 45,
  }) async {
    try {
      _ensureTimeZonesInitialized();
      tz.setLocalLocation(_resolveLocalLocation());

      await _notificationsPlugin.cancel(101);
      await _notificationsPlugin.cancel(102);
      await _notificationsPlugin.cancel(103);

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
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        number: 1,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          'Новый день уже наступил — узнайте ключевые планетарные аспекты, часы деловой активности и персональный совет дня ✨',
          contentTitle: '🪐 <b>Астро Гороскоп на сегодня готов!</b>',
          htmlFormatContentTitle: true,
          htmlFormatBigText: true,
        ),
      );

      // Ежедневный будильник (101) строго в выбранное пользователем локальное время
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

      // Синхронизируем нативный системный AlarmManager (предзагрузка за 30 минут + точная проверка)
      await BackgroundSyncService.rescheduleAlarms();
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
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
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
      await _notificationsPlugin.cancel(102);
      await _notificationsPlugin.cancel(103);
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
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
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
