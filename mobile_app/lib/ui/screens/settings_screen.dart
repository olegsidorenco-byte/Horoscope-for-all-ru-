import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cachedDays = 0;
  bool _notificationsEnabled = true;
  int _notifHour = 8;
  int _notifMinute = 0;
  UserProfile _profile = UserProfile.defaultProfile();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final count = await StorageService.getCachedDaysCount();
    final notifEnabled = await StorageService.isNotificationsEnabled();
    final hour = await StorageService.getNotificationHour();
    final minute = await StorageService.getNotificationMinute();
    final profile = await StorageService.loadProfile();

    if (mounted) {
      setState(() {
        _cachedDays = count;
        _notificationsEnabled = notifEnabled;
        _notifHour = hour;
        _notifMinute = minute;
        _profile = profile;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await StorageService.setNotificationsEnabled(value);

    if (value) {
      await NotificationService.requestPermission();
      await NotificationService.scheduleDailyNotification(
        hour: _notifHour,
        minute: _notifMinute,
      );
    } else {
      await NotificationService.cancelDailyNotification();
    }
  }

  Future<void> _pickNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHour, minute: _notifMinute),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CosmicTheme.goldAccent,
              onPrimary: Color(0xFF0F111A),
              surface: CosmicTheme.backgroundCard,
              onSurface: CosmicTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _notifHour = picked.hour;
        _notifMinute = picked.minute;
      });

      await StorageService.setNotificationTime(picked.hour, picked.minute);
      if (_notificationsEnabled) {
        await NotificationService.scheduleDailyNotification(
          hour: picked.hour,
          minute: picked.minute,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⏰ Время утреннего напоминания установлено на ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
            ),
            backgroundColor: CosmicTheme.backgroundCard,
          ),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.sendInstantTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Тестовое уведомление отправлено в шторку Android!'),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    await StorageService.clearAllCache();
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Локальный кэш успешно очищен'),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки и система'),
      ),
      body: CosmicBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Карточка логотипа
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CosmicTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: CosmicTheme.goldAccent.withOpacity(0.1),
                          child: const Icon(Icons.stars, color: CosmicTheme.goldAccent, size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Астро Гороскоп',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CosmicTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Версия 1.0.8 (Release)',
                            style: TextStyle(color: CosmicTheme.goldSoft, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Блок Личного Профиля пользователя
              _buildProfileSection(),
              const SizedBox(height: 20),

              // Блок утренних уведомлений
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CosmicTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: CosmicTheme.goldAccent),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Утренние напоминания',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CosmicTheme.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          activeColor: CosmicTheme.goldAccent,
                          onChanged: _toggleNotifications,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ежедневное напоминание о готовности свежего астрологического прогноза дня в шторку смартфона.',
                      style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    if (_notificationsEnabled) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickNotificationTime,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: CosmicTheme.backgroundDeep,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.access_time_rounded, color: CosmicTheme.goldSoft, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Время напоминания',
                                    style: TextStyle(color: CosmicTheme.textPrimary, fontSize: 14),
                                  ),
                                ],
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: CosmicTheme.goldAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _testNotification,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Проверить уведомление сейчас'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Карточка синхронизации и кэша
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CosmicTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_sync_rounded, color: CosmicTheme.cyanAccent),
                        SizedBox(width: 10),
                        Text(
                          'Облачная доставка прогнозов',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CosmicTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Прогнозы рассчитываются автономной астрологической системой и публикуются каждое утро. Приложение работает автономно без API-ключей.',
                      style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CosmicTheme.backgroundDeep,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storage_rounded, color: CosmicTheme.goldSoft, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Сохранено в офлайн-памяти: $_cachedDays дн.',
                              style: const TextStyle(color: CosmicTheme.textPrimary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _clearCache,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Очистить кэш'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CosmicTheme.textSecondary,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // О системе
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CosmicTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'О проекте',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CosmicTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '🌌 Автономный астрологический комплекс\nРасчет планетарных транзитов, аспектов и домов на базе фундаментальной классической астрологии и современных нейросетевых моделей искусственного интеллекта.',
                      style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final isRegistered = _profile.isRegistered;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CosmicTheme.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRegistered ? CosmicTheme.goldAccent.withOpacity(0.35) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isRegistered ? Icons.account_circle : Icons.person_add_alt_1_rounded,
                    color: CosmicTheme.goldAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Мой натальный профиль',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CosmicTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (isRegistered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CosmicTheme.goldAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_profile.zodiacSymbol} ${_profile.zodiacSign}',
                    style: const TextStyle(
                      color: CosmicTheme.goldAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isRegistered) ...[
            Text(
              '👤 Имя: ${_profile.name}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '📱/📧 Контакт: ${_profile.primaryContact}',
              style: const TextStyle(color: CosmicTheme.goldSoft, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '📅 Дата и время: ${_profile.formattedBirthDate}, ${_profile.birthTime}',
              style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '📍 Рождение: ${_profile.birthPlace.isNotEmpty ? _profile.birthPlace : "Не указано"}',
              style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '🏠 Проживание: ${_profile.currentCity.isNotEmpty ? _profile.currentCity : "Не указано"}',
              style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(initialProfile: _profile),
                        ),
                      );
                      if (updated == true) {
                        _loadSettings();
                      }
                    },
                    icon: const Icon(Icons.edit, size: 16, color: CosmicTheme.goldAccent),
                    label: const Text('Анкета', style: TextStyle(color: CosmicTheme.goldAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CosmicTheme.goldAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                      );
                      _loadSettings();
                    },
                    icon: const Icon(Icons.switch_account_outlined, size: 16, color: CosmicTheme.cyanAccent),
                    label: const Text('Сменить', style: TextStyle(color: CosmicTheme.cyanAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CosmicTheme.cyanAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Авторизуйтесь по номеру телефона, почте или через Telegram, чтобы закрепить за собой персональную натальную анкету.',
              style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(isRegistrationInitial: true),
                    ),
                  );
                  _loadSettings();
                },
                icon: const Icon(Icons.lock_person_rounded, size: 18, color: Colors.black),
                label: const Text(
                  'Войти или Зарегистрироваться',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CosmicTheme.goldAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
