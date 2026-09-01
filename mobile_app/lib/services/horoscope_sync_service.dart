import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/horoscope_model.dart';
import '../models/zodiac_model.dart';
import 'storage_service.dart';

class HoroscopeSyncService {
  static const String repoBaseUrl =
      'https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/data';

  /// Загружает самый свежий опубликованный персональный прогноз дня
  static Future<HoroscopeDay> fetchLatestHoroscope({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await StorageService.getLatestCachedHoroscope();
      if (cached != null) {
        return cached;
      }
    }

    try {
      final url = Uri.parse('$repoBaseUrl/latest_horoscope.json');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final horoscope = HoroscopeDay.fromJson(decoded);
        
        await StorageService.cacheLatestHoroscope(decoded);
        await StorageService.cacheDayHoroscope(horoscope.date, decoded);
        
        return horoscope;
      }
    } catch (_) {}

    final cached = await StorageService.getLatestCachedHoroscope();
    if (cached != null) {
      return cached;
    }

    try {
      final assetJsonStr = await rootBundle.loadString('assets/data/latest_horoscope.json');
      final decoded = jsonDecode(assetJsonStr);
      final horoscope = HoroscopeDay.fromJson(decoded);
      await StorageService.cacheLatestHoroscope(decoded);
      return horoscope;
    } catch (e) {
      throw Exception('Не удалось загрузить прогноз дня. Проверьте соединение.');
    }
  }

  /// Загружает актуальный гороскоп по 12 знакам зодиака
  static Future<ZodiacDayData> fetchLatestZodiac({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedStr = await StorageService.getCachedZodiacJson();
      if (cachedStr != null && cachedStr.isNotEmpty) {
        try {
          return ZodiacDayData.fromJson(jsonDecode(cachedStr));
        } catch (_) {}
      }
    }

    try {
      final url = Uri.parse('$repoBaseUrl/latest_zodiac.json');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final zodiacData = ZodiacDayData.fromJson(decoded);
        await StorageService.cacheZodiacJson(jsonEncode(decoded));
        return zodiacData;
      }
    } catch (_) {}

    final cachedStr = await StorageService.getCachedZodiacJson();
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        return ZodiacDayData.fromJson(jsonDecode(cachedStr));
      } catch (_) {}
    }

    try {
      final assetStr = await rootBundle.loadString('assets/data/latest_zodiac.json');
      final decoded = jsonDecode(assetStr);
      final zodiacData = ZodiacDayData.fromJson(decoded);
      await StorageService.cacheZodiacJson(jsonEncode(decoded));
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
