import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile currentProfile;
  final Function(UserProfile) onSaved;

  const ProfileScreen({
    super.key,
    required this.currentProfile,
    required this.onSaved,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  DateTime? _selectedBirthDate;
  TimeOfDay? _selectedBirthTime;
  bool _isGeneral = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentProfile.name);
    _cityController = TextEditingController(text: widget.currentProfile.birthCity);
    _isGeneral = widget.currentProfile.isGeneral;

    if (widget.currentProfile.birthDate.isNotEmpty) {
      try {
        _selectedBirthDate = DateFormat('dd.MM.yyyy').parse(widget.currentProfile.birthDate);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedBirthDate ?? DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: now,
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
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedBirthTime ?? const TimeOfDay(hour: 12, minute: 0),
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
        _selectedBirthTime = picked;
      });
    }
  }

  Future<void> _save() async {
    final birthDateStr = _selectedBirthDate != null
        ? DateFormat('dd.MM.yyyy').format(_selectedBirthDate!)
        : '';
    final birthTimeStr = _selectedBirthTime != null
        ? '${_selectedBirthTime!.hour.toString().padLeft(2, '0')}:${_selectedBirthTime!.minute.toString().padLeft(2, '0')}'
        : '';

    final updated = UserProfile(
      name: _nameController.text.trim(),
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      birthCity: _cityController.text.trim(),
      isGeneral: _isGeneral,
    );

    await StorageService.saveProfile(updated);
    widget.onSaved(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Натальные данные сохранены!'),
          backgroundColor: CosmicTheme.backgroundCard,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Натальный профиль'),
      ),
      body: CosmicBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CosmicTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: CosmicTheme.goldAccent, size: 28),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Укажите данные рождения для точного расчета натальной карты и планетарных транзитов.',
                        style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Режим общего прогноза
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: CosmicTheme.goldAccent,
                title: const Text(
                  'Общий астрологический прогноз',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Прогноз по текущему положению планет без натальной привязки',
                  style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 12),
                ),
                value: _isGeneral,
                onChanged: (val) {
                  setState(() {
                    _isGeneral = val;
                  });
                },
              ),
              if (!_isGeneral) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ваше имя',
                    prefixIcon: Icon(Icons.person_outline, color: CosmicTheme.goldSoft),
                  ),
                ),
                const SizedBox(height: 16),
                // Выбор даты рождения
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: CosmicTheme.backgroundCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined, color: CosmicTheme.goldSoft),
                        const SizedBox(width: 12),
                        Text(
                          _selectedBirthDate != null
                              ? DateFormat('dd.MM.yyyy').format(_selectedBirthDate!)
                              : 'Дата рождения (дд.мм.гггг)',
                          style: TextStyle(
                            color: _selectedBirthDate != null ? CosmicTheme.textPrimary : CosmicTheme.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Выбор времени рождения
                InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: CosmicTheme.backgroundCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_outlined, color: CosmicTheme.goldSoft),
                        const SizedBox(width: 12),
                        Text(
                          _selectedBirthTime != null
                              ? '${_selectedBirthTime!.hour.toString().padLeft(2, '0')}:${_selectedBirthTime!.minute.toString().padLeft(2, '0')}'
                              : 'Время рождения (чч:мм, если известно)',
                          style: TextStyle(
                            color: _selectedBirthTime != null ? CosmicTheme.textPrimary : CosmicTheme.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Город рождения',
                    prefixIcon: Icon(Icons.location_city_outlined, color: CosmicTheme.goldSoft),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Сохранить профиль'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
