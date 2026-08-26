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
  late TextEditingController _apiKeyController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await StorageService.loadApiKey();
    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    await StorageService.saveApiKey(_apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Ключ Google AI Gemini сохранен!'),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: CosmicBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        Icon(Icons.vpn_key_outlined, color: CosmicTheme.goldAccent),
                        SizedBox(width: 10),
                        Text(
                          'Google AI Studio Key',
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
                      'Для работы ИИ прогноза укажите персональный ключ Google AI Studio (Gemini). Он хранится исключительно на вашем телефоне в зашифрованном виде.',
                      style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        labelText: 'API Ключ (AIzaSy...)',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: CosmicTheme.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureKey = !_obscureKey;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveKey,
                      child: const Text('Сохранить ключ'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                      'О приложении',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CosmicTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '🌌 Астро Гороскоп v1.0.0\nАвтономный персональный расчет натальной карты и ежедневных планетарных транзитов на базе новейших моделей Google Gemini 3.7 / 2.5 Flash.',
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
