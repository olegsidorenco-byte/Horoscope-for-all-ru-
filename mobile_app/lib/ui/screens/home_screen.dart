import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/horoscope_model.dart';
import '../../services/horoscope_sync_service.dart';
import '../../services/storage_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import '../widgets/greeting_header.dart';
import '../widgets/topic_card.dart';
import 'zodiac_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HoroscopeDay? _horoscope;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNewForecast = false;

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
      final todayStr = DateFormat('dd.MM.yyyy').format(DateTime.now());

      final isUnread = h.date == todayStr && lastRead != h.date;

      if (mounted) {
        setState(() {
          _horoscope = h;
          _isLoading = false;
          _isNewForecast = isUnread;
        });
      }

      if (h.date.isNotEmpty) {
        await StorageService.setLastReadDate(h.date);
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
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2EC4B6), Color(0xFF0F4C81)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2EC4B6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '✨ Новый астрологический прогноз дня готов!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _isNewForecast = false;
                      });
                    },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '♈ Гороскоп по знакам зодиака',
                style: TextStyle(
                  fontSize: 15,
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
                      style: TextStyle(color: CosmicTheme.goldSoft, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Icon(Icons.chevron_right, color: CosmicTheme.goldSoft, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 74,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _zodiacQuickList.length,
            itemBuilder: (context, idx) {
              final item = _zodiacQuickList[idx];
              return GestureDetector(
                onTap: () => _openZodiacSign(item['id']!),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 60,
                  decoration: BoxDecoration(
                    color: CosmicTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['symbol']!,
                        style: const TextStyle(fontSize: 22, color: CosmicTheme.goldAccent),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['name']!,
                        style: const TextStyle(fontSize: 10.5, color: CosmicTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
