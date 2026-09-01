import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/horoscope_model.dart';
import 'storage_service.dart';

class HoroscopeSyncService {
  static const String repoBaseUrl =
      'https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/data';

  /// Загружает самый свежий опубликованный прогноз дня
  static Future<HoroscopeDay> fetchLatestHoroscope({bool forceRefresh = false}) async {
    // 1. Если не принудительное обновление, проверяем локальный кэш
    if (!forceRefresh) {
      final cached = await StorageService.getLatestCachedHoroscope();
      if (cached != null) {
        return cached;
      }
    }

    // 2. Пробуем загрузить из сети (GitHub Raw)
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

    // 3. Пробуем взять из кэша
    final cached = await StorageService.getLatestCachedHoroscope();
    if (cached != null) {
      return cached;
    }

    // 4. Если в кэше пусто и сеть недоступна / приватный репозиторий, загружаем встроенный ассет
    try {
      final assetJsonStr = await rootBundle.loadString('assets/data/latest_horoscope.json');
      final decoded = jsonDecode(assetJsonStr);
      final horoscope = HoroscopeDay.fromJson(decoded);
      await StorageService.cacheLatestHoroscope(decoded);
      return horoscope;
    } catch (e) {
      throw Exception('Не удалось загрузить прогноз дня. Проверьте интернет-соединение.');
    }
  }

  /// Загружает список доступных архивных дней
  static Future<List<ArchiveIndexItem>> fetchArchiveIndex() async {
    // 1. Сеть
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

    // 2. Кэш
    final cachedStr = await StorageService.getCachedArchiveIndex();
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final List list = jsonDecode(cachedStr);
        return list.map((item) => ArchiveIndexItem.fromJson(item)).toList();
      } catch (_) {}
    }

    // 3. Встроенный ассет
    try {
      final assetStr = await rootBundle.loadString('assets/data/archive/index.json');
      final List list = jsonDecode(assetStr);
      return list.map((item) => ArchiveIndexItem.fromJson(item)).toList();
    } catch (_) {}

    return [];
  }

  /// Загружает конкретный архивный день по дате
  static Future<HoroscopeDay> fetchArchiveDay(String isoDate, String displayDate) async {
    // 1. Локальный кэш
    final cached = await StorageService.getCachedDayHoroscope(displayDate);
    if (cached != null) {
      return cached;
    }

    // 2. Сеть
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

    // 3. Встроенный ассет
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
