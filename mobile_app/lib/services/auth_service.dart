import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class AuthService {
  static const String _keyAccountsList = 'cosmic_auth_accounts_registry_v1';
  static const String _keyCurrentSessionUserId = 'cosmic_auth_current_session_uid_v1';
  static const String _apiBaseUrl =
      'https://cosmic-horoscope-api-688107707932.europe-west1.run.app';

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

    final isMail = isEmail(normContact);
    // Для Firebase Auth мы требуем email. Если ввели телефон, делаем фиктивный email для совместимости,
    // либо можно использовать FirebaseAuth.instance.verifyPhoneNumber, но это сложнее.
    // Пока что конвертируем телефон в почту:
    final authEmail = isMail ? normContact : '$normContact@phone.cosmic-horoscope.app';

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Не удалось создать пользователя в Firebase");

      final lang = await StorageService.getLanguageCode();
      final deliveryTime = await StorageService.getFormattedDeliveryTime();
      final notifEnabled = await StorageService.isNotificationsEnabled();
      final tzName = NotificationService.getDetectedTimezoneName();
      final utcOffset = NotificationService.getUtcOffsetMinutes();

      final newProfile = UserProfile(
        id: user.uid,
        name: name.trim(),
        email: isMail ? normContact : '',
        phone: !isMail ? normContact : '',
        authType: isMail ? 'email' : 'phone',
        telegramUsername: telegramUsername?.trim() ?? '',
        passwordHash: '', // Больше не храним хеши
        birthDate: birthDate ?? DateTime(2000, 1, 1),
        birthTime: birthTime ?? '12:00',
        isTimeExact: isTimeExact ?? false,
        birthPlace: birthPlace ?? '',
        currentCity: currentCity ?? '',
        gender: gender ?? 'female',
        timezone: tzName,
        utcOffsetMinutes: utcOffset,
        deliveryTime: deliveryTime,
        notificationsEnabled: notifEnabled,
        lang: lang,
        updatedAt: DateTime.now(),
      );

      // Сохраняем в Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(newProfile.toJson(), SetOptions(merge: true));

      // Активируем локальную сессию для оффлайна
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentSessionUserId, user.uid);
      await StorageService.saveProfile(newProfile);
      await StorageService.setSelectedZodiacSign(newProfile.zodiacSignId);

      return newProfile;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('Слишком слабый пароль.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Аккаунт с таким контактом уже существует.');
      }
      throw Exception(e.message ?? 'Ошибка регистрации');
    }
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

    final isMail = isEmail(normContact);
    final authEmail = isMail ? normContact : '$normContact@phone.cosmic-horoscope.app';

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Не удалось войти");

      // Пытаемся загрузить профиль из Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      UserProfile profile;
      if (doc.exists && doc.data() != null) {
        profile = UserProfile.fromJson({...doc.data()!, 'id': user.uid});
      } else {
        // Если профиля в базе почему-то нет (например удален вручную)
        profile = UserProfile(
          id: user.uid,
          name: "Пользователь",
          email: isMail ? normContact : '',
          phone: !isMail ? normContact : '',
          authType: isMail ? 'email' : 'phone',
          birthDate: DateTime(2000, 1, 1),
          birthTime: "12:00",
          isTimeExact: false,
          birthPlace: "",
          currentCity: "",
        );
      }

      // Актуализируем часовой пояс смартфона и синхронизируем выбранное время доставки
      final tzName = NotificationService.getDetectedTimezoneName();
      final utcOffset = NotificationService.getUtcOffsetMinutes();
      final lang = await StorageService.getLanguageCode();
      profile = profile.copyWith(
        timezone: tzName,
        utcOffsetMinutes: utcOffset,
        lang: profile.lang.isNotEmpty ? profile.lang : lang,
      );

      if (profile.deliveryTime.contains(':')) {
        final parts = profile.deliveryTime.split(':');
        final h = int.tryParse(parts[0]);
        final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          await StorageService.setNotificationTime(h, m);
          if (profile.notificationsEnabled) {
            await NotificationService.scheduleDailyNotification(hour: h, minute: m);
          }
        }
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(profile.toJson(), SetOptions(merge: true));
      } catch (_) {}

      // Устанавливаем текущую локальную сессию
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentSessionUserId, user.uid);
      await StorageService.saveProfile(profile);
      await StorageService.setSelectedZodiacSign(profile.zodiacSignId);

      return profile;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Неверный логин или пароль.');
      }
      throw Exception(e.message ?? 'Ошибка авторизации');
    }
  }

  /// Быстрая авторизация через Telegram
  static Future<UserProfile> loginWithTelegram({
    required String telegramUsername,
    String? phone,
    String? name,
    String? firstName,
  }) async {
    final cleanTg = telegramUsername.replaceAll('@', '').trim();
    if (cleanTg.isEmpty) {
      throw Exception('Укажите имя пользователя Telegram');
    }

    final accounts = await _getAllAccounts();
    final normPhone = phone != null ? normalizeContact(phone) : '';
    final finalName = (name != null && name.isNotEmpty)
        ? name
        : ((firstName != null && firstName.isNotEmpty) ? firstName : cleanTg);

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
        name: finalName,
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

  /// Опциональный быстрый вход через аккаунт Google
  static Future<UserProfile> loginWithGoogle({
    required String email,
    required String name,
    String? googleId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !isEmail(cleanEmail)) {
      throw Exception('Некорректный адрес Google аккаунта');
    }

    final accounts = await _getAllAccounts();
    Map<String, dynamic>? existing;
    for (final a in accounts) {
      final aEmail = normalizeContact(a['email'] ?? '');
      if (aEmail == cleanEmail) {
        existing = a;
        break;
      }
    }

    UserProfile profile;
    if (existing != null) {
      profile = UserProfile.fromJson(Map<String, dynamic>.from(existing['profile']));
      if (profile.authType != 'google') {
        profile = profile.copyWith(authType: 'google');
      }
    } else {
      final userId = 'usr_g_${googleId ?? DateTime.now().millisecondsSinceEpoch}';
      final finalName = name.trim().isNotEmpty ? name.trim() : cleanEmail.split('@')[0];
      profile = UserProfile(
        id: userId,
        name: finalName,
        email: cleanEmail,
        phone: '',
        authType: 'google',
        passwordHash: '',
        birthDate: DateTime(2000, 1, 1),
        birthTime: '12:00',
        isTimeExact: false,
        birthPlace: '',
        currentCity: '',
        gender: 'female',
        updatedAt: DateTime.now(),
      );

      accounts.add({
        'id': userId,
        'email': cleanEmail,
        'phone': '',
        'name': profile.name,
        'authType': 'google',
        'passwordHash': '',
        'telegramUsername': '',
        'profile': profile.toJson(),
      });
      await _saveAllAccounts(accounts);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentSessionUserId, profile.id);
    await StorageService.saveProfile(profile);

    return profile;
  }

  /// Отправка ссылки для сброса пароля через Firebase Auth
  static Future<void> sendPasswordReset(String email) async {
    final cleanEmail = normalizeContact(email);
    if (!isEmail(cleanEmail)) {
      throw Exception('Укажите корректный адрес электронной почты');
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Аккаунт с почтой "$cleanEmail" не найден');
      } else if (e.code == 'invalid-email') {
        throw Exception('Некорректный адрес электронной почты');
      }
      throw Exception(e.message ?? 'Не удалось отправить письмо для сброса пароля');
    }
  }

  /// Восстановление / сброс пароля по электронной почте (совместимость с оффлайн-реестром + Firebase)
  static Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!isEmail(cleanEmail)) {
      throw Exception('Укажите корректный адрес электронной почты');
    }

    final accounts = await _getAllAccounts();
    int matchIdx = -1;
    for (int i = 0; i < accounts.length; i++) {
      final aEmail = normalizeContact(accounts[i]['email'] ?? '');
      if (aEmail == cleanEmail) {
        matchIdx = i;
        break;
      }
    }

    if (matchIdx != -1 && newPassword.length >= 6) {
      final newHash = hashPassword(newPassword);
      accounts[matchIdx]['passwordHash'] = newHash;
      if (accounts[matchIdx]['profile'] != null) {
        final pMap = Map<String, dynamic>.from(accounts[matchIdx]['profile']);
        pMap['passwordHash'] = newHash;
        accounts[matchIdx]['profile'] = pMap;
      }
      await _saveAllAccounts(accounts);
      return;
    }

    await sendPasswordReset(cleanEmail);
  }

  /// Полное удаление аккаунта и персональных данных в облаке и на устройстве (Google Play Policy)
  static Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_keyCurrentSessionUserId);

    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      try {
        final token = await fbUser.getIdToken();
        if (token != null) {
          await http
              .delete(
                Uri.parse('$_apiBaseUrl/user/account'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 10));
        }
      } catch (_) {}

      try {
        await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).delete();
      } catch (_) {}

      try {
        await fbUser.delete();
      } catch (_) {}

      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }

    if (uid != null && uid.isNotEmpty) {
      final accounts = await _getAllAccounts();
      accounts.removeWhere((acc) => acc['id'] == uid);
      await _saveAllAccounts(accounts);
    }
    await prefs.remove(_keyCurrentSessionUserId);
    await StorageService.clearProfile();
    await StorageService.clearAllCache();
  }

  /// Обновление анкеты и настроек времени/часового пояса текущего пользователя (локально и в Firestore)
  static Future<void> syncCurrentProfile(UserProfile updatedProfile) async {
    final tzName = NotificationService.getDetectedTimezoneName();
    final utcOffset = NotificationService.getUtcOffsetMinutes();
    final deliveryTime = await StorageService.getFormattedDeliveryTime();
    final notifEnabled = await StorageService.isNotificationsEnabled();
    final lang = await StorageService.getLanguageCode();

    final enriched = updatedProfile.copyWith(
      timezone: updatedProfile.timezone.isNotEmpty ? updatedProfile.timezone : tzName,
      utcOffsetMinutes: updatedProfile.utcOffsetMinutes ?? utcOffset,
      deliveryTime: deliveryTime,
      notificationsEnabled: notifEnabled,
      lang: lang,
      updatedAt: DateTime.now(),
    );

    final accounts = await _getAllAccounts();
    for (int i = 0; i < accounts.length; i++) {
      if (accounts[i]['id'] == enriched.id) {
        accounts[i]['profile'] = enriched.toJson();
        accounts[i]['name'] = enriched.name;
        if (enriched.email.isNotEmpty) accounts[i]['email'] = enriched.email;
        if (enriched.phone.isNotEmpty) accounts[i]['phone'] = enriched.phone;
        break;
      }
    }
    await _saveAllAccounts(accounts);
    await StorageService.saveProfile(enriched);

    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null && fbUser.uid == enriched.id) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(fbUser.uid)
            .set(enriched.toJson(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Выход из аккаунта (Logout) с очисткой облачной сессии и персонального кэша
  static Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentSessionUserId);
    await StorageService.clearPersonalHoroscopeCache();
    await StorageService.saveProfile(UserProfile.defaultProfile());
  }
}
