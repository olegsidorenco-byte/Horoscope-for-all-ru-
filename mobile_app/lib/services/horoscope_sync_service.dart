import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/horoscope_model.dart';
import '../models/zodiac_model.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class HoroscopeSyncService {
  static const String repoBaseUrl =
      'https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/data';
  static const String apiBaseUrl =
      'https://cosmic-horoscope-api-688107707932.europe-west1.run.app';

  /// Возвращает (dd.MM.yyyy, yyyy_MM_dd) строго по локальным часам и часовому поясу пользователя
  static ({String dmy, String isoKey}) _userLocalDateParts([DateTime? customLocal]) {
    final now = customLocal ?? DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString().padLeft(4, '0');
    return (dmy: '$dd.$mm.$yyyy', isoKey: '${yyyy}_${mm}_$dd');
  }

  /// Загружает самый свежий опубликованный персональный прогноз дня для выбранного языка
  /// с учетом часового пояса пользователя и его натальных данных (дата и время рождения).
  static Future<HoroscopeDay> fetchLatestHoroscope({
    bool forceRefresh = false,
    String? langCode,
    String? targetDateOverride,
  }) async {
    final lang = langCode ?? await StorageService.getLanguageCode();
    final localDates = _userLocalDateParts();
    final targetDmy = targetDateOverride ?? localDates.dmy;

    // 1. Персональный натальный расчет для авторизованного в Firebase пользователя
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await StorageService.loadProfile();
      final natalSig = profile.natalConfigSignature;

      if (!forceRefresh) {
        final cachedPersonal = await StorageService.getCachedPersonalHoroscope(
          uid: user.uid,
          date: targetDmy,
          lang: lang,
          natalSignature: natalSig,
        );
        if (cachedPersonal != null) {
          return cachedPersonal;
        }
      }

      try {
        final token = await user.getIdToken();
        if (token != null) {
          final tzName = NotificationService.getDetectedTimezoneName();
          final utcOffset = NotificationService.getUtcOffsetMinutes();
          final deliveryTime = await StorageService.getFormattedDeliveryTime();
          final notifEnabled = await StorageService.isNotificationsEnabled();

          final url = Uri.parse('$apiBaseUrl/horoscope/personal');
          final response = await http
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'lang': lang,
                  'timezone': tzName,
                  'utc_offset_minutes': utcOffset,
                  'target_date': targetDmy,
                  'delivery_time': deliveryTime,
                  'notifications_enabled': notifEnabled,
                  'force_refresh': forceRefresh,
                }),
              )
              .timeout(const Duration(seconds: 25));

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
            final respDate = (data['date'] ?? targetDmy).toString();
            final rawHoroscope = (data['horoscope'] ?? '').toString();
            final rawTopics = data['topics'];

            HoroscopeDay parsedHoroscope;
            if (rawTopics is List && rawTopics.isNotEmpty) {
              parsedHoroscope = HoroscopeDay(
                date: respDate,
                greeting: (data['greeting'] ?? '').toString(),
                topics: rawTopics
                    .map((item) => HoroscopeTopic.fromJson(Map<String, dynamic>.from(item as Map)))
                    .toList(),
                rawText: rawHoroscope,
                updatedAt: (data['generated_at'] ?? DateTime.now().toIso8601String()).toString(),
                isPersonal: true,
              );
            } else {
              parsedHoroscope = HoroscopeDay.fromRawText(
                respDate,
                rawHoroscope,
                isPersonal: true,
                updatedAt: (data['generated_at'] ?? DateTime.now().toIso8601String()).toString(),
              );
            }

            await StorageService.cachePersonalHoroscope(
              uid: user.uid,
              date: respDate,
              lang: lang,
              natalSignature: natalSig,
              horoscope: parsedHoroscope,
            );
            await StorageService.cacheLatestHoroscope(parsedHoroscope.toJson(), lang);
            return parsedHoroscope;
          }
        }
      } catch (e) {
        // Оффлайн-фолбэк на персональный кэш текущего дня, если он был загружен ранее
        final fallbackPersonal = await StorageService.getCachedPersonalHoroscope(
          uid: user.uid,
          date: targetDmy,
          lang: lang,
          natalSignature: natalSig,
        );
        if (fallbackPersonal != null) {
          return fallbackPersonal;
        }
      }
    }

    // --- ПУБЛИЧНЫЙ КАНАЛ (ГОСТИ ИЛИ РЕЗЕРВ ПРИ СБОЕ API) С УЧЕТОМ ЧАСОВОГО ПОЯСА ---
    final langSuffix = (lang == 'ru') ? '' : '_$lang';
    final fileName = 'latest_horoscope$langSuffix.json';
    final assetPath = 'assets/data/$fileName';
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    try {
      final url = Uri.parse('$repoBaseUrl/$fileName?t=$cacheBuster');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        var decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        var horoscope = HoroscopeDay.fromJson(decoded);

        // Если часовой пояс пользователя находится в других сутках относительно latest_horoscope.json
        // (напр. Дальний Восток уже в завтрашнем дне или Америка еще во вчерашнем),
        // запрашиваем заранее сгенерированный файл строго под локальную дату пользователя!
        if (horoscope.date != localDates.dmy) {
          try {
            final exactUrl = Uri.parse(
              '$repoBaseUrl/archive/horoscope_${localDates.isoKey}$langSuffix.json?t=$cacheBuster',
            );
            final exactResp = await http.get(exactUrl).timeout(const Duration(seconds: 4));
            if (exactResp.statusCode == 200) {
              decoded = jsonDecode(utf8.decode(exactResp.bodyBytes)) as Map<String, dynamic>;
              horoscope = HoroscopeDay.fromJson(decoded);
            }
          } catch (_) {}
        }

        await StorageService.cacheLatestHoroscope(decoded, lang);
        await StorageService.cacheDayHoroscope(horoscope.date, decoded, lang);
        return horoscope;
      }
    } catch (_) {}

    // 2. Если сеть недоступна (оффлайн) или ошибка сервера, используем локальный кэш этого языка
    final cached = await StorageService.getLatestCachedHoroscope(lang);
    if (cached != null) {
      return cached;
    }

    // 3. Если кэша еще нет (первый запуск в оффлайн-режиме), берем встроенный локализованный asset
    try {
      String assetJsonStr;
      try {
        assetJsonStr = await rootBundle.loadString(assetPath);
      } catch (_) {
        assetJsonStr = await rootBundle.loadString('assets/data/latest_horoscope.json');
      }
      final decoded = jsonDecode(assetJsonStr) as Map<String, dynamic>;
      final horoscope = HoroscopeDay.fromJson(decoded);
      await StorageService.cacheLatestHoroscope(decoded, lang);
      return horoscope;
    } catch (e) {
      throw Exception('Не удалось загрузить прогноз дня. Проверьте соединение.');
    }
  }

  /// Загружает актуальный гороскоп по 12 знакам зодиака для выбранного языка с учетом даты в часовом поясе пользователя
  static Future<ZodiacDayData> fetchLatestZodiac({
    bool forceRefresh = false,
    String? langCode,
  }) async {
    final lang = langCode ?? await StorageService.getLanguageCode();
    final langSuffix = (lang == 'ru') ? '' : '_$lang';
    final fileName = 'latest_zodiac$langSuffix.json';
    final assetPath = 'assets/data/$fileName';
    final localDates = _userLocalDateParts();

    // 1. Запрос свежего гороскопа по знакам из сети
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$repoBaseUrl/$fileName?t=$cacheBuster');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        var decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        var zodiacData = ZodiacDayData.fromJson(decoded);

        // Если пользователь в другом часовом поясе (другие сутки относительно сервера), подгружаем файл под его дату
        if (zodiacData.date != localDates.dmy) {
          try {
            final exactUrl = Uri.parse(
              '$repoBaseUrl/archive/zodiac_${localDates.isoKey}$langSuffix.json?t=$cacheBuster',
            );
            final exactResp = await http.get(exactUrl).timeout(const Duration(seconds: 4));
            if (exactResp.statusCode == 200) {
              decoded = jsonDecode(utf8.decode(exactResp.bodyBytes)) as Map<String, dynamic>;
              zodiacData = ZodiacDayData.fromJson(decoded);
            }
          } catch (_) {}
        }

        await StorageService.cacheZodiacJson(jsonEncode(decoded), lang);
        return zodiacData;
      }
    } catch (_) {}

    // 2. Откат на кэш при оффлайне
    final cachedStr = await StorageService.getCachedZodiacJson(lang);
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        return ZodiacDayData.fromJson(jsonDecode(cachedStr));
      } catch (_) {}
    }

    // 3. Откат на встроенный asset
    try {
      String assetStr;
      try {
        assetStr = await rootBundle.loadString(assetPath);
      } catch (_) {
        assetStr = await rootBundle.loadString('assets/data/latest_zodiac.json');
      }
      final decoded = jsonDecode(assetStr);
      final zodiacData = ZodiacDayData.fromJson(decoded);
      await StorageService.cacheZodiacJson(jsonEncode(decoded), lang);
      return zodiacData;
    } catch (_) {}

    throw Exception('Не удалось загрузить гороскоп по знакам зодиака');
  }

  /// Загружает список доступных архивных дней
  static Future<List<ArchiveIndexItem>> fetchArchiveIndex() async {
    try {
      final url = Uri.parse('$repoBaseUrl/archive/index.json');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(response.bodyBytes));
        final items = list.map((item) => ArchiveIndexItem.fromJson(item)).toList();
        await StorageService.cacheArchiveIndex(response.body);
        return items;
      }
    } catch (_) {}

    final cachedStr = await StorageService.getCachedArchiveIndex();
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final List list = jsonDecode(cachedStr);
        return list.map((item) => ArchiveIndexItem.fromJson(item)).toList();
      } catch (_) {}
    }

    try {
      final assetStr = await rootBundle.loadString('assets/data/archive/index.json');
      final List list = jsonDecode(assetStr);
      return list.map((item) => ArchiveIndexItem.fromJson(item)).toList();
    } catch (_) {}

    return [];
  }

  /// Загружает конкретный архивный день по дате (с учетом выбранного языка)
  static Future<HoroscopeDay> fetchArchiveDay(
    String isoDate,
    String displayDate, {
    String? langCode,
  }) async {
    final lang = langCode ?? await StorageService.getLanguageCode();
    final cached = await StorageService.getCachedDayHoroscope(displayDate, lang);
    if (cached != null) {
      return cached;
    }

    final candidates = <String>[
      if (lang != 'ru') 'horoscope_${isoDate}_$lang.json',
      'horoscope_$isoDate.json',
    ];

    for (final candidate in candidates) {
      try {
        final url = Uri.parse('$repoBaseUrl/archive/$candidate');
        final response = await http.get(url).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final horoscope = HoroscopeDay.fromJson(decoded);
          await StorageService.cacheDayHoroscope(displayDate, decoded, lang);
          return horoscope;
        }
      } catch (_) {}
    }

    for (final candidate in candidates) {
      try {
        final assetStr = await rootBundle.loadString('assets/data/archive/$candidate');
        final decoded = jsonDecode(assetStr) as Map<String, dynamic>;
        final horoscope = HoroscopeDay.fromJson(decoded);
        await StorageService.cacheDayHoroscope(displayDate, decoded, lang);
        return horoscope;
      } catch (_) {}
    }

    throw Exception('Архивная запись за $displayDate не найдена');
  }
}
