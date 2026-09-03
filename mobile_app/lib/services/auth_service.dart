import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'storage_service.dart';

class AuthService {
  static const String _keyAccountsList = 'cosmic_auth_accounts_registry_v1';
  static const String _keyCurrentSessionUserId = 'cosmic_auth_current_session_uid_v1';

  /// Хэширование пароля SHA-256 с солью для безопасного хранения
  static String hashPassword(String password) {
    const salt = 'cosmic_astrology_secure_salt_2026';
    final bytes = utf8.encode('$password::$salt');
    return sha256.convert(bytes).toString();
  }

  /// Нормализация контакта (почта или телефон)
  static String normalizeContact(String contact) {
    final trimmed = contact.trim();
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }
    // Очистка номера телефона от пробелов, скобок и дефисов
    final digits = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('8') && digits.length == 11) {
      return '+7${digits.substring(1)}';
    }
    if (!digits.startsWith('+') && digits.isNotEmpty) {
      return '+$digits';
    }
    return digits;
  }

  static bool isEmail(String contact) {
    final norm = normalizeContact(contact);
    return RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(norm);
  }

  static bool isPhone(String contact) {
    final norm = normalizeContact(contact);
    return RegExp(r'^\+\d{10,15}$').hasMatch(norm);
  }

  /// Проверяет, авторизован ли пользователь в данный момент
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_keyCurrentSessionUserId);
    if (uid == null || uid.isEmpty || uid == 'guest_user') return false;
    final profile = await StorageService.loadProfile();
    return profile.isRegistered;
  }

  /// Возвращает список всех зарегистрированных на устройстве аккаунтов
  static Future<List<Map<String, dynamic>>> _getAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyAccountsList);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Сохраняет обновленный список аккаунтов
  static Future<void> _saveAllAccounts(List<Map<String, dynamic>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccountsList, jsonEncode(accounts));
  }

  /// Регистрация нового аккаунта с жестким правилом «Один контакт = один аккаунт»
  static Future<UserProfile> register({
    required String contact,
    required String password,
    required String name,
    DateTime? birthDate,
    String? birthTime,
    bool? isTimeExact,
    String? birthPlace,
    String? currentCity,
    String? gender,
    String? telegramUsername,
  }) async {
    final normContact = normalizeContact(contact);
    if (normContact.isEmpty) {
      throw Exception('Укажите номер телефона или адрес электронной почты');
    }
    if (password.length < 6) {
      throw Exception('Пароль должен содержать не менее 6 символов');
    }
    if (name.trim().isEmpty) {
      throw Exception('Пожалуйста, введите ваше имя');
    }

    final accounts = await _getAllAccounts();

    // Проверка уникальности контакта: запрет дубликатов
    final contactExists = accounts.any((acc) {
      final accEmail = normalizeContact(acc['email'] ?? '');
      final accPhone = normalizeContact(acc['phone'] ?? '');
      return accEmail == normContact || accPhone == normContact;
    });

    if (contactExists) {
      throw Exception('Аккаунт с контактом "$normContact" уже зарегистрирован! Пожалуйста, выполните вход.');
    }

    final isMail = isEmail(normContact);
    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final pwdHash = hashPassword(password);

    final newProfile = UserProfile(
      id: userId,
      name: name.trim(),
      email: isMail ? normContact : '',
      phone: !isMail ? normContact : '',
      authType: isMail ? 'email' : 'phone',
      telegramUsername: telegramUsername?.trim() ?? '',
      passwordHash: pwdHash,
      birthDate: birthDate ?? DateTime(2000, 1, 1),
      birthTime: birthTime ?? '12:00',
      isTimeExact: isTimeExact ?? false,
      birthPlace: birthPlace ?? '',
      currentCity: currentCity ?? '',
      gender: gender ?? 'female',
      updatedAt: DateTime.now(),
    );

    // Добавляем в реестр аккаунтов
    final accountEntry = {
      'id': userId,
      'email': newProfile.email,
      'phone': newProfile.phone,
      'name': newProfile.name,
      'authType': newProfile.authType,
      'passwordHash': pwdHash,
      'telegramUsername': newProfile.telegramUsername,
      'profile': newProfile.toJson(),
    };
    accounts.add(accountEntry);
    await _saveAllAccounts(accounts);

    // Активируем сессию
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentSessionUserId, userId);
    await StorageService.saveProfile(newProfile);

    return newProfile;
  }

  /// Вход в существующий аккаунт по почте или телефону и паролю
  static Future<UserProfile> login({
    required String contact,
    required String password,
  }) async {
    final normContact = normalizeContact(contact);
    if (normContact.isEmpty) {
      throw Exception('Введите номер телефона или Email');
    }
    if (password.isEmpty) {
      throw Exception('Введите пароль');
    }

    final accounts = await _getAllAccounts();
    final pwdHash = hashPassword(password);

    // Поиск аккаунта по нормализованному контакту
    final acc = accounts.firstWhere(
      (a) {
        final accEmail = normalizeContact(a['email'] ?? '');
        final accPhone = normalizeContact(a['phone'] ?? '');
        return accEmail == normContact || accPhone == normContact;
      },
      orElse: () => {},
    );

    if (acc.isEmpty) {
      throw Exception('Аккаунт с контактом "$normContact" не найден. Проверьте данные или зарегистрируйтесь.');
    }

    if (acc['passwordHash'] != pwdHash) {
      throw Exception('Неверный пароль. Пожалуйста, попробуйте снова.');
    }

    final profileData = Map<String, dynamic>.from(acc['profile'] ?? {});
    final profile = UserProfile.fromJson(profileData);

    // Устанавливаем текущую сессию
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentSessionUserId, profile.id);
    await StorageService.saveProfile(profile);

    return profile;
  }

  /// Быстрая авторизация через Telegram
  static Future<UserProfile> loginWithTelegram({
    required String telegramUsername,
    String? phone,
    String? firstName,
  }) async {
    final cleanTg = telegramUsername.replaceAll('@', '').trim();
    if (cleanTg.isEmpty) {
      throw Exception('Укажите имя пользователя Telegram');
    }

    final accounts = await _getAllAccounts();
    final normPhone = phone != null ? normalizeContact(phone) : '';

    // Ищем существующий аккаунт по Telegram или телефону
    Map<String, dynamic>? existing;
    for (final a in accounts) {
      final aTg = (a['telegramUsername'] ?? '').toString().replaceAll('@', '').trim();
      final aPhone = normalizeContact(a['phone'] ?? '');
      if (aTg.toLowerCase() == cleanTg.toLowerCase() || (normPhone.isNotEmpty && aPhone == normPhone)) {
        existing = a;
        break;
      }
    }

    UserProfile profile;
    if (existing != null) {
      // Существующий аккаунт
      profile = UserProfile.fromJson(Map<String, dynamic>.from(existing['profile']));
      if (profile.telegramUsername.isEmpty) {
        profile = profile.copyWith(telegramUsername: cleanTg);
      }
    } else {
      // Создаем новый аккаунт Telegram
      final userId = 'usr_tg_${DateTime.now().millisecondsSinceEpoch}';
      profile = UserProfile(
        id: userId,
        name: (firstName != null && firstName.isNotEmpty) ? firstName : cleanTg,
        email: '',
        phone: normPhone,
        authType: 'telegram',
        telegramUsername: cleanTg,
        birthDate: DateTime(2000, 1, 1),
        birthTime: '12:00',
        isTimeExact: false,
        birthPlace: '',
        currentCity: '',
        gender: 'female',
      );

      accounts.add({
        'id': userId,
        'email': '',
        'phone': normPhone,
        'name': profile.name,
        'authType': 'telegram',
        'telegramUsername': cleanTg,
        'passwordHash': '',
        'profile': profile.toJson(),
      });
      await _saveAllAccounts(accounts);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentSessionUserId, profile.id);
    await StorageService.saveProfile(profile);

    return profile;
  }

  /// Обновление анкеты текущего авторизованного пользователя
  static Future<void> syncCurrentProfile(UserProfile updatedProfile) async {
    final accounts = await _getAllAccounts();
    for (int i = 0; i < accounts.length; i++) {
      if (accounts[i]['id'] == updatedProfile.id) {
        accounts[i]['profile'] = updatedProfile.toJson();
        accounts[i]['name'] = updatedProfile.name;
        if (updatedProfile.email.isNotEmpty) accounts[i]['email'] = updatedProfile.email;
        if (updatedProfile.phone.isNotEmpty) accounts[i]['phone'] = updatedProfile.phone;
        break;
      }
    }
    await _saveAllAccounts(accounts);
    await StorageService.saveProfile(updatedProfile);
  }

  /// Выход из аккаунта (Logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentSessionUserId);
    await StorageService.saveProfile(UserProfile.defaultProfile());
  }
}
