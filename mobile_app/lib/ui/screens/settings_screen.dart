import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/web_push/web_push_service.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/background_sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/update_service.dart';
import '../../models/user_profile.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import '../widgets/privacy_policy_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cachedDays = 0;
  bool _notificationsEnabled = true;
  bool _backgroundServiceActive = true;
  bool _isCheckingUpdate = false;
  int _notifHour = 6;
  int _notifMinute = 45;
  UserProfile _profile = UserProfile.defaultProfile();
  String _currentLanguageCode = 'en';

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
    final bgEnabled = await BackgroundSyncService.isServiceEnabled();
    final lang = await StorageService.getLanguageCode();

    if (mounted) {
      setState(() {
        _cachedDays = count;
        _notificationsEnabled = notifEnabled;
        _backgroundServiceActive = bgEnabled;
        _notifHour = hour;
        _notifMinute = minute;
        _profile = profile;
        _currentLanguageCode = lang;
      });
    }
  }

  Future<void> _toggleBackgroundService(bool value) async {
    setState(() {
      _backgroundServiceActive = value;
    });
    await BackgroundSyncService.toggleService(value);
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? l10n.backgroundServiceSubtitle : l10n.cancel,
          ),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await StorageService.setNotificationsEnabled(value);

    if (value) {
      if (!kIsWeb) {
        await NotificationService.requestPermission();
        await NotificationService.scheduleDailyNotification(
          hour: _notifHour,
          minute: _notifMinute,
        );
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await WebPushService.subscribe(user.uid);
        }
      }
    } else {
      if (!kIsWeb) {
        await NotificationService.cancelDailyNotification();
        await BackgroundSyncService.rescheduleAlarms();
      }
    }

    final updated = _profile.copyWith(
      notificationsEnabled: value,
      timezone: NotificationService.getDetectedTimezoneName(),
      utcOffsetMinutes: NotificationService.getUtcOffsetMinutes(),
    );
    await AuthService.syncCurrentProfile(updated);
    if (mounted) {
      setState(() => _profile = updated);
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
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      final tzName = NotificationService.getDetectedTimezoneName();
      final utcOffsetStr = NotificationService.getFormattedUtcOffset();

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
      } else {
        await BackgroundSyncService.rescheduleAlarms();
      }

      final updated = _profile.copyWith(
        deliveryTime: formattedTime,
        timezone: tzName,
        utcOffsetMinutes: NotificationService.getUtcOffsetMinutes(),
      );
      await AuthService.syncCurrentProfile(updated);
      if (mounted) {
        setState(() => _profile = updated);
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.reminderTimeSetSnackbar(formattedTime, tzName, utcOffsetStr),
            ),
            backgroundColor: CosmicTheme.backgroundCard,
          ),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    if (!kIsWeb) {
      await NotificationService.sendInstantTestNotification();
      await NotificationService.updateBadge(1);
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await WebPushService.sendTest(user.uid);
      }
    }
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.testNotifSent),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    await StorageService.clearAllCache();
    await _loadSettings();
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cacheCleared),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
    }
  }

  Future<void> _checkAppUpdatesManually() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    final l10n = AppLocalizations.of(context);
    try {
      final update = await UpdateService.checkForUpdate(force: true, lang: l10n.langCode);
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);

      if (update != null) {
        await UpdateService.showUpdateDialog(context, update, isManual: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.latestVersionInstalled),
            backgroundColor: CosmicTheme.backgroundCard,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.updateCheckFailed),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeStr =
        '${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: CosmicBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Карточка версии приложения и проверка обновлений
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CosmicTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: CosmicTheme.goldAccent.withOpacity(0.1),
                              child: const Icon(Icons.stars, color: CosmicTheme.goldAccent, size: 36),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.appTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CosmicTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.checkForUpdatesSubtitle(UpdateService.currentVersion),
                                style: const TextStyle(color: CosmicTheme.goldSoft, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCheckingUpdate ? null : _checkAppUpdatesManually,
                        icon: _isCheckingUpdate
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: CosmicTheme.goldAccent),
                              )
                            : const Icon(Icons.system_update_alt_rounded, size: 18, color: CosmicTheme.goldAccent),
                        label: Text(
                          _isCheckingUpdate ? l10n.checkingForUpdates : l10n.checkForUpdatesTitle,
                          style: const TextStyle(
                            color: CosmicTheme.goldAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CosmicTheme.goldAccent.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Блок выбора языка приложения и гороскопов
              _buildLanguageSection(l10n),
              const SizedBox(height: 20),

              // Блок Личного Профиля пользователя
              _buildProfileSection(l10n),
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
                        Expanded(
                          child: Text(
                            l10n.morningRemindersTitle,
                            style: const TextStyle(
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
                    Text(
                      l10n.morningRemindersDesc,
                      style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CosmicTheme.backgroundDeep,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CosmicTheme.cyanAccent.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.public_rounded, color: CosmicTheme.cyanAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.detectedTimezoneLabel(
                                NotificationService.getDetectedTimezoneName(),
                                NotificationService.getFormattedUtcOffset(),
                              ),
                              style: const TextStyle(
                                color: CosmicTheme.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, color: CosmicTheme.goldSoft, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.reminderTimeLabel,
                                    style: const TextStyle(color: CosmicTheme.textPrimary, fontSize: 14),
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
                        label: Text(l10n.testNotifButton),
                      ),
                      if (!kIsWeb) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161C2C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.battery_charging_full_rounded, color: Colors.amberAccent, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.batteryAdviceTitle,
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.batteryAdviceDesc,
                                style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 11.5, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync_rounded, color: CosmicTheme.cyanAccent),
                        const SizedBox(width: 10),
                        Text(
                          l10n.cloudDeliveryTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CosmicTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.cloudDeliveryDesc,
                      style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.45),
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
                              l10n.offlineStorageCount(_cachedDays),
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
                      label: Text(l10n.clearCacheButton),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutProjectTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CosmicTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.aboutProjectDesc,
                      style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.5),
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

  Future<void> _showLogoutDialog() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(l10n.logoutConfirmTitle, style: const TextStyle(color: Colors.white)),
          content: Text(
            l10n.logoutConfirmMessage,
            style: const TextStyle(color: CosmicTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CosmicTheme.goldAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.logoutButton, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await AuthService.logout();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E2235),
            content: Text(l10n.logoutButton),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.redAccent, width: 1.2),
          ),
          title: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.deleteAccountConfirmTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            l10n.deleteAccountConfirmDesc,
            style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.deleteAccountButton, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await AuthService.deleteAccount();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1E2235),
            content: Text(
              '🗑️ Account deleted.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Widget _buildLanguageSection(AppLocalizations l10n) {
    final currentLang = AppLocalizations.supportedLanguages.firstWhere(
      (item) => item['code'] == _currentLanguageCode,
      orElse: () => AppLocalizations.supportedLanguages.first,
    );

    return Container(
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
              const Icon(Icons.language_rounded, color: CosmicTheme.cyanAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.languageSectionTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CosmicTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _showLanguageDialog(l10n),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: CosmicTheme.backgroundDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        currentLang['flag'] ?? '🌐',
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentLang['nativeName'] ?? 'Русский',
                            style: const TextStyle(
                              color: CosmicTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            currentLang['name'] ?? '',
                            style: const TextStyle(
                              color: CosmicTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Icon(Icons.arrow_forward_ios_rounded, color: CosmicTheme.goldAccent, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CosmicTheme.backgroundDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.translate_rounded, color: CosmicTheme.goldAccent),
                      const SizedBox(width: 10),
                      Text(
                        l10n.selectLanguageTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CosmicTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...AppLocalizations.supportedLanguages.map((lang) {
                  final isSelected = lang['code'] == _currentLanguageCode;
                  return InkWell(
                    onTap: () async {
                      final code = lang['code']!;
                      Navigator.pop(ctx);
                      await StorageService.setLanguageCode(code);
                      CosmicHoroscopeApp.localeNotifier.value = Locale(code);
                      final updated = _profile.copyWith(lang: code);
                      await AuthService.syncCurrentProfile(updated);
                      await BackgroundSyncService.rescheduleAlarms();
                      if (mounted) {
                        setState(() {
                          _currentLanguageCode = code;
                          _profile = updated;
                        });
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations(Locale(code)).languageChangedSnackbar,
                            ),
                            backgroundColor: CosmicTheme.backgroundCard,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CosmicTheme.goldAccent.withOpacity(0.15)
                            : CosmicTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? CosmicTheme.goldAccent : Colors.white10,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(lang['flag'] ?? '', style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['nativeName'] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? CosmicTheme.goldAccent : CosmicTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  lang['name'] ?? '',
                                  style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: CosmicTheme.goldAccent),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileSection(AppLocalizations l10n) {
    final isRegistered = _profile.isRegistered;
    final code = l10n.langCode;

    Widget authBadge() {
      IconData icon;
      Color color;
      String label;
      switch (_profile.authType) {
        case 'google':
          icon = Icons.g_mobiledata_rounded;
          color = const Color(0xFF4285F4);
          label = 'Google';
          break;
        case 'telegram':
          icon = Icons.send_rounded;
          color = const Color(0xFF29B6F6);
          label = 'Telegram';
          break;
        case 'phone':
          icon = Icons.phone_android_rounded;
          color = CosmicTheme.cyanAccent;
          label = 'Phone';
          break;
        case 'email':
        default:
          icon = Icons.alternate_email_rounded;
          color = CosmicTheme.goldAccent;
          label = 'Email';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

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
                  Text(
                    l10n.natalProfileTitle,
                    style: const TextStyle(
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
                    '${_profile.zodiacSymbol} ${_profile.localizedZodiacSign(code)}',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '👤 ${l10n.nameLabel}: ${_profile.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                authBadge(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '📧 ${_profile.primaryContact}',
              style: const TextStyle(color: CosmicTheme.goldSoft, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '📅 ${_profile.formattedBirthDate}, ${_profile.birthTime}',
              style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
            ),
            if (_profile.birthPlace.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📍 ${_profile.birthPlace}',
                style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
              ),
            ],
            if (_profile.currentCity.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '🏠 ${_profile.currentCity}',
                style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
              ),
            ],
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
                    label: Text(l10n.editProfileButton, style: const TextStyle(color: CosmicTheme.goldAccent)),
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
                    label: Text(l10n.tabSignIn, style: const TextStyle(color: CosmicTheme.cyanAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CosmicTheme.cyanAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showPrivacyPolicyDialog(context),
                    icon: const Icon(Icons.shield_outlined, size: 16, color: Colors.white70),
                    label: Text(l10n.privacyPolicyButton,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white70),
                    label: Text(l10n.logoutButton, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDeleteAccountDialog,
                icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                label: Text(
                  l10n.deleteAccountButton,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1.1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            Text(
              l10n.profileSectionTitle,
              style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
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
                label: Text(
                  l10n.tabSignIn,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CosmicTheme.goldAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => showPrivacyPolicyDialog(context),
                icon: const Icon(Icons.shield_outlined, size: 15, color: CosmicTheme.textSecondary),
                label: Text(
                  l10n.privacyPolicyButton,
                  style: const TextStyle(
                      color: CosmicTheme.textSecondary, fontSize: 12, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
