import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_profile.dart';
import '../../models/horoscope_model.dart';
import '../../services/gemini_service.dart';
import '../../services/storage_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import '../widgets/greeting_header.dart';
import '../widgets/topic_card.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile _profile = UserProfile();
  HoroscopeDay? _horoscope;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadProfileAndFetch();
  }

  Future<void> _loadProfileAndFetch() async {
    final prof = await StorageService.loadProfile();
    setState(() {
      _profile = prof;
    });
    _fetchHoroscope(forceRefresh: false);
  }

  String get _formattedTargetDate => DateFormat('dd.MM.yyyy').format(_selectedDate);

  Future<void> _fetchHoroscope({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final h = await GeminiService.generateHoroscope(
        profile: _profile,
        targetDate: _formattedTargetDate,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _horoscope = h;
          _isLoading = false;
        });
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

  void _changeDate(int offsetDays) {
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: offsetDays));
    });
    _fetchHoroscope(forceRefresh: false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(_selectedDate, now);
    final isYesterday = DateUtils.isSameDay(_selectedDate, now.subtract(const Duration(days: 1)));
    final isTomorrow = DateUtils.isSameDay(_selectedDate, now.add(const Duration(days: 1)));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nightlight_round, color: CosmicTheme.goldAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              _profile.name.isNotEmpty ? 'Гороскоп: ${_profile.name}' : 'Астро Гороскоп',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: CosmicTheme.goldSoft),
            tooltip: 'Натальный профиль',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    currentProfile: _profile,
                    onSaved: (p) {
                      setState(() {
                        _profile = p;
                      });
                      _fetchHoroscope(forceRefresh: true);
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: CosmicTheme.cyanAccent),
            tooltip: 'Настройки',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _fetchHoroscope());
            },
          ),
        ],
      ),
      body: CosmicBackground(
        child: Column(
          children: [
            // Переключатель дат
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: CosmicTheme.backgroundCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DateTab(
                      label: 'Вчера',
                      isSelected: isYesterday,
                      onTap: () => _changeDate(-1),
                    ),
                  ),
                  Expanded(
                    child: _DateTab(
                      label: 'Сегодня',
                      isSelected: isToday,
                      onTap: () => _changeDate(0),
                    ),
                  ),
                  Expanded(
                    child: _DateTab(
                      label: 'Завтра',
                      isSelected: isTomorrow,
                      onTap: () => _changeDate(1),
                    ),
                  ),
                ],
              ),
            ),
            // Основной контент
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
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
              'Расчет натальной карты и планетарных аспектов...',
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
              const Icon(Icons.error_outline_rounded, color: CosmicTheme.roseGlow, size: 54),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CosmicTheme.textPrimary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _fetchHoroscope(forceRefresh: true),
                child: const Text('Повторить расчет'),
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
      onRefresh: () => _fetchHoroscope(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          GreetingHeader(
            greetingText: _horoscope!.greeting,
            dateStr: _formattedTargetDate,
            isLoading: _isLoading,
            onRefresh: () => _fetchHoroscope(forceRefresh: true),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 4),
          ..._horoscope!.topics.asMap().entries.map((entry) {
            final idx = entry.key;
            final topic = entry.value;
            return TopicCard(
              topic: topic,
              index: idx,
            ).animate().fadeIn(delay: (80 * idx).ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DateTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? CosmicTheme.goldAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0A0D18) : CosmicTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
