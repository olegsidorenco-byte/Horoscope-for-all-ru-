import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/horoscope_model.dart';
import '../../models/user_profile.dart';
import '../../services/horoscope_sync_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import '../widgets/greeting_header.dart';
import '../widgets/topic_card.dart';
import 'zodiac_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onReadStateChanged;
  const HomeScreen({super.key, this.onReadStateChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HoroscopeDay? _horoscope;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNewForecast = false;
  UserProfile _userProfile = UserProfile.defaultProfile();

  final List<Map<String, String>> _zodiacQuickList = const [
    {'id': 'aries', 'name': 'Овен', 'symbol': '♈'},
    {'id': 'taurus', 'name': 'Телец', 'symbol': '♉'},
    {'id': 'gemini', 'name': 'Близнецы', 'symbol': '♊'},
    {'id': 'cancer', 'name': 'Рак', 'symbol': '♋'},
    {'id': 'leo', 'name': 'Лев', 'symbol': '♌'},
    {'id': 'virgo', 'name': 'Дева', 'symbol': '♍'},
    {'id': 'libra', 'name': 'Весы', 'symbol': '♎'},
    {'id': 'scorpio', 'name': 'Скорпион', 'symbol': '♏'},
    {'id': 'sagittarius', 'name': 'Стрелец', 'symbol': '♐'},
    {'id': 'capricorn', 'name': 'Козерог', 'symbol': '♑'},
    {'id': 'aquarius', 'name': 'Водолей', 'symbol': '♒'},
    {'id': 'pisces', 'name': 'Рыбы', 'symbol': '♓'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLatestHoroscope();
  }

  Future<void> _fetchLatestHoroscope({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final h = await HoroscopeSyncService.fetchLatestHoroscope(forceRefresh: forceRefresh);
      final lastRead = await StorageService.getLastReadDate();
      final profile = await StorageService.loadProfile();

      final isUnread = h.date.isNotEmpty && lastRead != h.date;

      if (mounted) {
        setState(() {
          _horoscope = h;
          _isLoading = false;
          _isNewForecast = isUnread;
          _userProfile = profile;
        });
      }

      if (isUnread) {
        await NotificationService.showNewForecastNotification(h.date);
        widget.onReadStateChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead() async {
    if (_horoscope != null && _horoscope!.date.isNotEmpty) {
      await StorageService.setLastReadDate(_horoscope!.date);
      if (mounted) {
        setState(() {
          _isNewForecast = false;
        });
      }
      widget.onReadStateChanged?.call();
    }
  }

  void _openZodiacSign(String signId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ZodiacScreen(initialSignId: signId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.stars_rounded, color: CosmicTheme.goldAccent, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Астро Гороскоп',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_isNewForecast)
            GestureDetector(
              onTap: _markAsRead,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3D71), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3D71).withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 7),
                    SizedBox(width: 5),
                    Text(
                      'НОВОЕ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 800.ms),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: CosmicTheme.cyanAccent),
            tooltip: 'Настройки',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: CosmicBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _horoscope == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CosmicTheme.goldAccent.withOpacity(0.1),
              ),
              child: const CircularProgressIndicator(color: CosmicTheme.goldAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'Загрузка свежего прогноза дня...',
              style: TextStyle(color: CosmicTheme.goldSoft, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _horoscope == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: CosmicTheme.roseGlow, size: 54),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CosmicTheme.textPrimary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _fetchLatestHoroscope(forceRefresh: true),
                child: const Text('Обновить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_horoscope == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: CosmicTheme.goldAccent,
      backgroundColor: CosmicTheme.backgroundCard,
      onRefresh: () => _fetchLatestHoroscope(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          // Всплывающий баннер о новом прогнозе
          if (_isNewForecast)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE94057).withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'НЕПРОЧИТАННЫЙ ГОРОСКОП',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Свежий прогноз на ${_horoscope!.date} опубликован!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _markAsRead,
                    icon: const Icon(Icons.done_all_rounded, size: 14, color: Colors.black),
                    label: const Text(
                      'Прочитано',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),

          // Заголовок и приветствие
          GreetingHeader(
            greetingText: _horoscope!.greeting,
            dateStr: _horoscope!.date,
            isLoading: _isLoading,
            onRefresh: () => _fetchLatestHoroscope(forceRefresh: true),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

          // Персональный натальный баннер пользователя
          _buildPersonalProfileBanner(),

          // Быстрая панель перехода к знакам зодиака
          _buildZodiacQuickBar(),
          const SizedBox(height: 6),

          // Карточки тем
          ..._horoscope!.topics.asMap().entries.map((entry) {
            final idx = entry.key;
            final topic = entry.value;
            return TopicCard(
              topic: topic,
              index: idx,
            ).animate().fadeIn(delay: (60 * idx).ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
          }),
          const SizedBox(height: 80), // Отступ для красивой нижней панели навигации
        ],
      ),
    );
  }

  Widget _buildZodiacQuickBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CosmicTheme.backgroundCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '♈ Гороскоп по знакам зодиака',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: CosmicTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ZodiacScreen()),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Все 12',
                      style: TextStyle(color: CosmicTheme.goldSoft, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    Icon(Icons.chevron_right, color: CosmicTheme.goldSoft, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ряд 1: Первые 6 знаков (Овен - Дева)
          _buildZodiacRow(_zodiacQuickList.sublist(0, 6)),
          const SizedBox(height: 8),
          // Ряд 2: Следующие 6 знаков (Весы - Рыбы)
          _buildZodiacRow(_zodiacQuickList.sublist(6, 12)),
        ],
      ),
    );
  }

  Widget _buildZodiacRow(List<Map<String, String>> signs) {
    return Row(
      children: signs.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: GestureDetector(
              onTap: () => _openZodiacSign(item['id']!),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: CosmicTheme.backgroundDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['symbol']!,
                      style: const TextStyle(fontSize: 18, color: CosmicTheme.goldAccent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['name']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: CosmicTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonalProfileBanner() {
    if (!_userProfile.isRegistered) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CosmicTheme.backgroundCard.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: CosmicTheme.goldAccent, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Натальный профиль',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Заполните анкету (дата, время, место) для личного расчета',
                    style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen(initialProfile: _userProfile)),
                );
                if (res == true) {
                  final p = await StorageService.loadProfile();
                  if (mounted) setState(() => _userProfile = p);
                }
              },
              child: const Text(
                'Анкета',
                style: TextStyle(color: CosmicTheme.goldAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2356).withOpacity(0.8),
            CosmicTheme.backgroundCard.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CosmicTheme.goldAccent.withOpacity(0.15),
              border: Border.all(color: CosmicTheme.goldAccent, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text(
              _userProfile.zodiacSymbol,
              style: const TextStyle(fontSize: 19, color: CosmicTheme.goldAccent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ Гороскоп для: ${_userProfile.name}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_userProfile.zodiacSign} • ${_userProfile.birthPlace} → ${_userProfile.currentCity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: CosmicTheme.goldSoft, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen(initialProfile: _userProfile)),
              );
              if (res == true) {
                final p = await StorageService.loadProfile();
                if (mounted) setState(() => _userProfile = p);
              }
            },
          ),
        ],
      ),
    );
  }
}

