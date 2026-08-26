import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/horoscope_model.dart';

class StorageService {
  static const String _keyProfile = 'cosmic_user_profile';
  static const String _keyApiKey = 'cosmic_gemini_api_key';
  static const String _prefixHoroscope = 'cosmic_cache_horoscope_';

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

  // Сохранение и получение ключа Gemini API
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, key.trim());
  }

  static Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey) ?? '';
  }

  // Кэширование гороскопа по дате
  static Future<void> cacheHoroscope(String date, String rawText) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefixHoroscope$date', rawText);
  }

  static Future<HoroscopeDay?> getCachedHoroscope(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefixHoroscope$date');
    if (raw != null && raw.isNotEmpty) {
      return HoroscopeDay.fromRawText(date, raw);
    }
    return null;
  }
}
