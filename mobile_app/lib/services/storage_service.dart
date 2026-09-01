import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/horoscope_model.dart';

class StorageService {
  static const String _keyProfile = 'cosmic_user_profile';
  static const String _keyLatest = 'cosmic_cache_latest_json';
  static const String _keyArchiveIndex = 'cosmic_cache_archive_index';
  static const String _prefixDay = 'cosmic_day_json_';

  // Сохранение и получение профиля
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, profile.serialize());
  }

  static Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyProfile);
    if (data == null || data.isEmpty) {
      return UserProfile();
    }
    return UserProfile.deserialize(data);
  }

  // Кэширование последнего актуального прогноза
  static Future<void> cacheLatestHoroscope(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLatest, jsonEncode(data));
  }

  static Future<HoroscopeDay?> getLatestCachedHoroscope() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLatest);
    if (str != null && str.isNotEmpty) {
      try {
        return HoroscopeDay.fromJson(jsonDecode(str));
      } catch (_) {}
    }
    return null;
  }

  // Кэширование конкретного дня
  static Future<void> cacheDayHoroscope(String date, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefixDay$date', jsonEncode(data));
  }

  static Future<HoroscopeDay?> getCachedDayHoroscope(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('$_prefixDay$date');
    if (str != null && str.isNotEmpty) {
      try {
        return HoroscopeDay.fromJson(jsonDecode(str));
      } catch (_) {}
    }
    return null;
  }

  // Кэширование индекса архива
  static Future<void> cacheArchiveIndex(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyArchiveIndex, jsonStr);
  }

  static Future<String?> getCachedArchiveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyArchiveIndex);
  }

  // Очистка кэша
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cosmic_cache_') || k.startsWith('cosmic_day_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Количество сохраненных в памяти дней
  static Future<int> getCachedDaysCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().where((k) => k.startsWith('cosmic_day_')).length;
  }
}
