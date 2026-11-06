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
  static const String _keyLanguage = 'cosmic_selected_language';
  static const String _prefixDay = 'cosmic_day_json_';
  static const String _prefixPersonal = 'cosmic_personal_horoscope_';

  // Выбранный язык приложения (ru, en, es, de, fr)
  static Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  static Future<void> setLanguageCode(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, langCode);
  }

  // Сохранение и получение профиля
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
  }

  static Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyProfile);
    if (data == null || data.isEmpty) {
      return UserProfile.defaultProfile();
    }
    try {
      return UserProfile.fromJson(jsonDecode(data));
    } catch (_) {
      return UserProfile.defaultProfile();
    }
  }

  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfile);
  }

  // Кэширование последнего актуального персонального прогноза (с учетом языка)
  static Future<void> cacheLatestHoroscope(Map<String, dynamic> data, [String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final lang = langCode ?? await getLanguageCode();
    await prefs.setString('${_keyLatest}_$lang', jsonEncode(data));
    // Сохраняем и в дефолтный ключ для обратной совместимости
    if (lang == 'ru') {
      await prefs.setString(_keyLatest, jsonEncode(data));
    }
  }

  static Future<HoroscopeDay?> getLatestCachedHoroscope([String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final lang = langCode ?? await getLanguageCode();
    var str = prefs.getString('${_keyLatest}_$lang');
    if ((str == null || str.isEmpty) && lang == 'ru') {
      str = prefs.getString(_keyLatest);
    }
    if (str != null && str.isNotEmpty) {
      try {
        return HoroscopeDay.fromJson(jsonDecode(str));
      } catch (_) {}
    }
    return null;
  }

  // Кэширование гороскопа по 12 знакам зодиака (с учетом языка)
  static Future<void> cacheZodiacJson(String jsonStr, [String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final lang = langCode ?? await getLanguageCode();
    await prefs.setString('${_keyLatestZodiac}_$lang', jsonStr);
    if (lang == 'ru') {
      await prefs.setString(_keyLatestZodiac, jsonStr);
    }
  }

  static Future<String?> getCachedZodiacJson([String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final lang = langCode ?? await getLanguageCode();
    var str = prefs.getString('${_keyLatestZodiac}_$lang');
    if ((str == null || str.isEmpty) && lang == 'ru') {
      str = prefs.getString(_keyLatestZodiac);
    }
    return str;
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

  // Кэширование персонального натального прогноза API (с привязкой к UID, дате, языку и натальной сигнатуре)
  static Future<void> cachePersonalHoroscope({
    required String uid,
    required String date,
    required String lang,
    required String natalSignature,
    required HoroscopeDay horoscope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final safeDate = date.replaceAll('.', '_');
    final key = '$_prefixPersonal${uid}_${safeDate}_$lang';
    final payload = {
      'natal_signature': natalSignature,
      'horoscope': horoscope.toJson(),
    };
    await prefs.setString(key, jsonEncode(payload));
  }

  static Future<HoroscopeDay?> getCachedPersonalHoroscope({
    required String uid,
    required String date,
    required String lang,
    required String natalSignature,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final safeDate = date.replaceAll('.', '_');
    final key = '$_prefixPersonal${uid}_${safeDate}_$lang';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['natal_signature'] != natalSignature) {
        return null;
      }
      final hJson = Map<String, dynamic>.from(decoded['horoscope'] as Map);
      hJson['is_personal'] = true;
      return HoroscopeDay.fromJson(hJson);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPersonalHoroscopeCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefixPersonal)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Кэширование конкретного дня
  static Future<void> cacheDayHoroscope(String date, Map<String, dynamic> data, [String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = (langCode != null && langCode.isNotEmpty && langCode != 'ru') ? '_$langCode' : '';
    await prefs.setString('$_prefixDay$date$suffix', jsonEncode(data));
  }

  static Future<HoroscopeDay?> getCachedDayHoroscope(String date, [String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = (langCode != null && langCode.isNotEmpty && langCode != 'ru') ? '_$langCode' : '';
    final str = prefs.getString('$_prefixDay$date$suffix');
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

  // Проверка наличия свежего непрочитанного гороскопа
  static Future<bool> hasUnreadHoroscope() async {
    final cached = await getLatestCachedHoroscope();
    if (cached == null || cached.date.isEmpty) return false;
    final lastRead = await getLastReadDate();
    return lastRead != cached.date;
  }

  // Дата отправки утреннего системного уведомления
  static const String _keyLastNotifiedDate = 'cosmic_last_notified_date';

  static Future<String> getLastNotifiedDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastNotifiedDate) ?? '';
  }

  static Future<void> setLastNotifiedDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastNotifiedDate, date);
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
    return prefs.getInt(_keyNotifHour) ?? 6;
  }

  static Future<int> getNotificationMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNotifMinute) ?? 45;
  }

  static Future<void> setNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotifHour, hour);
    await prefs.setInt(_keyNotifMinute, minute);
  }

  static Future<String> getFormattedDeliveryTime() async {
    final h = await getNotificationHour();
    final m = await getNotificationMinute();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // Очистка кэша
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) =>
            k.startsWith('cosmic_cache_') ||
            k.startsWith('cosmic_day_') ||
            k.startsWith(_prefixPersonal))
        .toList();
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
