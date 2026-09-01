import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/horoscope_model.dart';
import '../../services/horoscope_sync_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import '../widgets/greeting_header.dart';
import '../widgets/topic_card.dart';
import 'archive_screen.dart';
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
            icon: const Icon(Icons.history_rounded, color: CosmicTheme.goldSoft, size: 26),
            tooltip: 'Архив по дням',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ArchiveScreen()),
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
          GreetingHeader(
            greetingText: _horoscope!.greeting,
            dateStr: _horoscope!.date,
            isLoading: _isLoading,
            onRefresh: () => _fetchLatestHoroscope(forceRefresh: true),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 4),
          ..._horoscope!.topics.asMap().entries.map((entry) {
            final idx = entry.key;
            final topic = entry.value;
            return TopicCard(
              topic: topic,
              index: idx,
            ).animate().fadeIn(delay: (60 * idx).ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
