import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/horoscope_model.dart';
import '../models/zodiac_model.dart';
import 'storage_service.dart';

class HoroscopeSyncService {
  static const String repoBaseUrl =
      'https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/data';

  /// Загружает самый свежий опубликованный персональный прогноз дня для выбранного языка
  static Future<HoroscopeDay> fetchLatestHoroscope({
    bool forceRefresh = false,
    String? langCode,
  }) async {
    final lang = langCode ?? await StorageService.getLanguageCode();
    final fileName = (lang == 'ru') ? 'latest_horoscope.json' : 'latest_horoscope_$lang.json';
    final assetPath = (lang == 'ru') ? 'assets/data/latest_horoscope.json' : 'assets/data/latest_horoscope_$lang.json';

    // 1. Пробуем запросить свежие данные из сети с тайм-аутом 4 сек и анти-кэш параметром
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$repoBaseUrl/$fileName?t=$cacheBuster');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final horoscope = HoroscopeDay.fromJson(decoded);
        
        await StorageService.cacheLatestHoroscope(decoded, lang);
        await StorageService.cacheDayHoroscope(horoscope.date, decoded);
        
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
        // Fallback на базовый asset, если отдельный языковой asset не найден
        assetJsonStr = await rootBundle.loadString('assets/data/latest_horoscope.json');
      }
      final decoded = jsonDecode(assetJsonStr);
      final horoscope = HoroscopeDay.fromJson(decoded);
      await StorageService.cacheLatestHoroscope(decoded, lang);
      return horoscope;
    } catch (e) {
      throw Exception('Не удалось загрузить прогноз дня. Проверьте соединение.');
    }
  }

  /// Загружает актуальный гороскоп по 12 знакам зодиака для выбранного языка
  static Future<ZodiacDayData> fetchLatestZodiac({
    bool forceRefresh = false,
    String? langCode,
  }) async {
    final lang = langCode ?? await StorageService.getLanguageCode();
    final fileName = (lang == 'ru') ? 'latest_zodiac.json' : 'latest_zodiac_$lang.json';
    final assetPath = (lang == 'ru') ? 'assets/data/latest_zodiac.json' : 'assets/data/latest_zodiac_$lang.json';

    // 1. Запрос свежего гороскопа по знакам из сети
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$repoBaseUrl/$fileName?t=$cacheBuster');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final zodiacData = ZodiacDayData.fromJson(decoded);
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

  /// Загружает конкретный архивный день по дате
  static Future<HoroscopeDay> fetchArchiveDay(String isoDate, String displayDate) async {
    final cached = await StorageService.getCachedDayHoroscope(displayDate);
    if (cached != null) {
      return cached;
    }

    try {
      final url = Uri.parse('$repoBaseUrl/archive/horoscope_$isoDate.json');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final horoscope = HoroscopeDay.fromJson(decoded);
        await StorageService.cacheDayHoroscope(displayDate, decoded);
        return horoscope;
      }
    } catch (_) {}

    try {
      final assetStr = await rootBundle.loadString('assets/data/archive/horoscope_$isoDate.json');
      final decoded = jsonDecode(assetStr);
      final horoscope = HoroscopeDay.fromJson(decoded);
      await StorageService.cacheDayHoroscope(displayDate, decoded);
      return horoscope;
    } catch (_) {}

    throw Exception('Архивная запись за $displayDate не найдена');
  }
}
