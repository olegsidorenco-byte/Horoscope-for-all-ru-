import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cachedDays = 0;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    final count = await StorageService.getCachedDaysCount();
    if (mounted) {
      setState(() {
        _cachedDays = count;
      });
    }
  }

  Future<void> _clearCache() async {
    await StorageService.clearAllCache();
    await _loadCacheInfo();
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
                            'Версия 1.0.0 (Release)',
                            style: TextStyle(color: CosmicTheme.goldSoft, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Карточка синхронизации
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
                      'Прогнозы рассчитываются автономной астрологической системой и автоматически публикуются каждое утро. Приложение работает напрямую из коробки без необходимости настройки API-ключей.',
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
                      '🌌 Автономный астрологический комплекс\nРасчет планетарных транзитов, аспектов и домов на базе фундаментальной классической астрологии и ИИ моделей Google Gemini.',
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
}
