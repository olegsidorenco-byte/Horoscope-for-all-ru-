import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/horoscope_model.dart';

class StorageService {
  static const String _keyProfile = 'cosmic_user_profile';
  static const String _keyLatest = 'cosmic_cache_latest_json';
  static const String _keyLatestZodiac = 'cosmic_cache_latest_zodiac_json';
  static const String _keySelectedSign = 'cosmic_selected_zodiac_sign';
  static const String _keyArchiveIndex = 'cosmic_cache_archive_index';
  static const String _keyLastReadDate = 'cosmic_last_read_date';
  static const String _keyNotifEnabled = 'cosmic_notif_enabled';
  static const String _keyNotifHour = 'cosmic_notif_hour';
  static const String _keyNotifMinute = 'cosmic_notif_minute';
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

  // Кэширование последнего актуального персонального прогноза
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

  // Кэширование гороскопа по 12 знакам зодиака
  static Future<void> cacheZodiacJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLatestZodiac, jsonStr);
  }

  static Future<String?> getCachedZodiacJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLatestZodiac);
  }

  // Выбранный пользователем знак зодиака (например: 'aries', 'leo')
  static Future<String> getSelectedZodiacSign() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedSign) ?? 'aries';
  }

  static Future<void> setSelectedZodiacSign(String signId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedSign, signId);
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

  // Дата последнего прочитанного гороскопа
  static Future<String> getLastReadDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastReadDate) ?? '';
  }

  static Future<void> setLastReadDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastReadDate, date);
  }

  // Настройки уведомлений
  static Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifEnabled) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifEnabled, val);
  }

  static Future<int> getNotificationHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNotifHour) ?? 8;
  }

  static Future<int> getNotificationMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNotifMinute) ?? 0;
  }

  static Future<void> setNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotifHour, hour);
    await prefs.setInt(_keyNotifMinute, minute);
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
