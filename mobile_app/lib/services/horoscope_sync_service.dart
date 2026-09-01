import 'dart:convert';
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

    try {
      final url = Uri.parse('$repoBaseUrl/latest_horoscope.json');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final horoscope = HoroscopeDay.fromJson(decoded);
        
        // Сохраняем в локальный кэш
        await StorageService.cacheLatestHoroscope(decoded);
        await StorageService.cacheDayHoroscope(horoscope.date, decoded);
        
        return horoscope;
      } else {
        throw Exception('Сервер вернул статус ${response.statusCode}');
      }
    } catch (e) {
      // При ошибке сети пытаемся взять из кэша
      final cached = await StorageService.getLatestCachedHoroscope();
      if (cached != null) {
        return cached;
      }
      throw Exception('Не удалось загрузить прогноз дня: $e');
    }
  }

  /// Загружает список доступных архивных дней
  static Future<List<ArchiveIndexItem>> fetchArchiveIndex() async {
    try {
      final url = Uri.parse('$repoBaseUrl/archive/index.json');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(response.bodyBytes));
        final items = list.map((item) => ArchiveIndexItem.fromJson(item)).toList();
        await StorageService.cacheArchiveIndex(response.body);
        return items;
      }
    } catch (_) {}

    // Фолбэк на сохраненный кэш архива
    final cachedStr = await StorageService.getCachedArchiveIndex();
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final List list = jsonDecode(cachedStr);
        return list.map((item) => ArchiveIndexItem.fromJson(item)).toList();
      } catch (_) {}
    }

    return [];
  }

  /// Загружает конкретный архивный день по дате
  static Future<HoroscopeDay> fetchArchiveDay(String isoDate, String displayDate) async {
    // 1. Проверяем локальный кэш
    final cached = await StorageService.getCachedDayHoroscope(displayDate);
    if (cached != null) {
      return cached;
    }

    try {
      final url = Uri.parse('$repoBaseUrl/archive/horoscope_$isoDate.json');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final horoscope = HoroscopeDay.fromJson(decoded);
        await StorageService.cacheDayHoroscope(displayDate, decoded);
        return horoscope;
      }
    } catch (e) {
      throw Exception('Не удалось загрузить архивный прогноз за $displayDate');
    }

    throw Exception('Архивная запись за $displayDate не найдена');
  }
}
