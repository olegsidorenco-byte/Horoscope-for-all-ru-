import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'horoscope_sync_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class AuthService {
  static const String _keyCurrentSessionUserId = 'cosmic_auth_current_session_uid_v1';
  static const String _apiBaseUrl = HoroscopeSyncService.apiBaseUrl;

  /// Нормализация контакта (Email)
  static String normalizeContact(String contact) {
    final trimmed = contact.trim();
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }
    return trimmed;
  }

  static bool isEmail(String contact) {
    final norm = normalizeContact(contact);
    return RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,10}$').hasMatch(norm);
  }

  /// Проверяет, авторизован ли пользователь в данный момент в Firebase
  static Future<bool> isLoggedIn() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_keyCurrentSessionUserId);
    if (uid == null || uid.isEmpty || uid == 'guest_user') return false;
    final profile = await StorageService.loadProfile();
    return profile.isRegistered;
  }

  /// Регистрация нового аккаунта через Firebase Auth (Email + пароль)
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
    if (!isEmail(normContact)) {
      throw Exception('Укажите корректный адрес электронной почты');
    }
    if (password.length < 6) {
      throw Exception('Пароль должен содержать не менее 6 символов');
    }
    if (name.trim().isEmpty) {
      throw Exception('Пожалуйста, введите ваше имя');
    }

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normContact,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Не удалось создать пользователя в Firebase');

      final lang = await StorageService.getLanguageCode();
      final deliveryTime = await StorageService.getFormattedDeliveryTime();
      final notifEnabled = await StorageService.isNotificationsEnabled();
      final tzName = NotificationService.getDetectedTimezoneName();
      final utcOffset = NotificationService.getUtcOffsetMinutes();

      final newProfile = UserProfile(
        id: user.uid,
        name: name.trim(),
        email: normContact,
        phone: '',
        authType: 'email',
        telegramUsername: telegramUsername?.trim() ?? '',
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(newProfile.toJson(), SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentSessionUserId, user.uid);
      await StorageService.saveProfile(newProfile);
      await StorageService.setSelectedZodiacSign(newProfile.zodiacSignId);

      return newProfile;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('Слишком слабый пароль.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Аккаунт с такой почтой уже существует.');
      }
      throw Exception(e.message ?? 'Ошибка регистрации');
    }
  }

  /// Вход в существующий аккаунт по Email и паролю через Firebase Auth
  static Future<UserProfile> login({
    required String contact,
    required String password,
  }) async {
    final normContact = normalizeContact(contact);
    if (!isEmail(normContact)) {
      throw Exception('Введите корректный адрес электронной почты');
    }
    if (password.isEmpty) {
      throw Exception('Введите пароль');
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normContact,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Не удалось войти');

      return await _syncSignedInUser(user, authType: 'email');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Неверный логин или пароль.');
      }
      throw Exception(e.message ?? 'Ошибка авторизации');
    }
  }

  /// Реальный вход через Google (Firebase Federated OAuth — Web Popup / Mobile Browser Flow)
  static Future<UserProfile> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');

      final UserCredential userCredential = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Не удалось завершить вход через Google');
      }

      return await _syncSignedInUser(user, authType: 'google');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        throw Exception('Вход через Google отменён пользователем.');
      }
      throw Exception(e.message ?? 'Ошибка входа через Google');
    }
  }

  static Future<UserProfile> _syncSignedInUser(User user, {required String authType}) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    UserProfile profile;
    if (doc.exists && doc.data() != null) {
      profile = UserProfile.fromJson({...doc.data()!, 'id': user.uid});
    } else {
      final email = (user.email ?? '').trim().toLowerCase();
      final displayName = (user.displayName ?? '').trim();
      profile = UserProfile(
        id: user.uid,
        name: displayName.isNotEmpty
            ? displayName
            : (email.contains('@') ? email.split('@')[0] : 'Пользователь'),
        email: email,
        phone: '',
        authType: authType,
        birthDate: DateTime(2000, 1, 1),
        birthTime: '12:00',
        isTimeExact: false,
        birthPlace: '',
        currentCity: '',
      );
    }

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
        if (!kIsWeb && profile.notificationsEnabled) {
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentSessionUserId, user.uid);
    await StorageService.saveProfile(profile);
    await StorageService.setSelectedZodiacSign(profile.zodiacSignId);

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

  /// Псевдоним для совместимости с интерфейсом сброса пароля
  static Future<void> sendPasswordResetEmail(String email) => sendPasswordReset(email);

  /// Полное удаление аккаунта и персональных данных (Firestore + Firebase Auth через Admin SDK)
  static Future<void> deleteAccount() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      throw Exception('Пользователь не авторизован в облачном аккаунте');
    }

    final token = await fbUser.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить токен авторизации для удаления');
    }

    final res = await http
        .delete(
          Uri.parse('$_apiBaseUrl/user/account'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Не удалось удалить аккаунт на сервере (${res.statusCode})');
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
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
