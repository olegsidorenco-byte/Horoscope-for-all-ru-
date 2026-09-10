import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../theme/cosmic_theme.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile? initialProfile;

  const ProfileScreen({Key? key, this.initialProfile}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _telegramController;
  late TextEditingController _birthPlaceController;
  late TextEditingController _currentCityController;
  late TextEditingController _focusController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isTimeExact;
  late String _selectedGender;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile ?? UserProfile.defaultProfile();

    _nameController = TextEditingController(text: p.name);
    _emailController = TextEditingController(text: p.email);
    _telegramController = TextEditingController(text: p.telegramUsername);
    _birthPlaceController = TextEditingController(text: p.birthPlace);
    _currentCityController = TextEditingController(text: p.currentCity);
    _focusController = TextEditingController(text: p.focus);

    _selectedDate = p.birthDate; // по умолчанию 01.01.2000
    
    // Парсим время по умолчанию 12:00
    int hour = 12;
    int minute = 0;
    try {
      final parts = p.birthTime.split(":");
      if (parts.length == 2) {
        hour = int.tryParse(parts[0]) ?? 12;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    } catch (_) {}
    _selectedTime = TimeOfDay(hour: hour, minute: minute);

    _isTimeExact = p.isTimeExact;
    _selectedGender = p.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _telegramController.dispose();
    _birthPlaceController.dispose();
    _currentCityController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  UserProfile _buildCurrentProfile() {
    final p = widget.initialProfile ?? UserProfile.defaultProfile();
    final timeStr = "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";
    return UserProfile(
      id: p.id.isNotEmpty && p.id != 'default_user' && p.id != 'guest_user'
          ? p.id
          : "usr_${DateTime.now().millisecondsSinceEpoch}",
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : p.email,
      phone: p.phone,
      authType: p.authType,
      telegramUsername: _telegramController.text.replaceAll('@', '').trim(),
      passwordHash: p.passwordHash,
      birthDate: _selectedDate,
      birthTime: timeStr,
      isTimeExact: _isTimeExact,
      birthPlace: _birthPlaceController.text.trim(),
      currentCity: _currentCityController.text.trim(),
      gender: _selectedGender,
      focus: _focusController.text.trim().isNotEmpty
          ? _focusController.text.trim()
          : (p.focus.isNotEmpty ? p.focus : "бизнес, деловые переговоры, финансы и здоровье"),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Выйти из аккаунта?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Данные вашей анкеты останутся надежно сохранены в учетной записи. Вы сможете войти в нее снова в любой момент.',
          style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
      helpText: 'Выберите дату рождения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CosmicTheme.goldAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E2235),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Выберите время рождения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CosmicTheme.goldAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E2235),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final profile = _buildCurrentProfile();
    await AuthService.syncCurrentProfile(profile);

    // Автоматически синхронизируем выбранный знак зодиака под дату рождения
    await StorageService.setSelectedZodiacSign(profile.zodiacSign.toLowerCase());

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Натальный профиль ${profile.name} успешно сохранен!'),
          backgroundColor: CosmicTheme.goldAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewProfile = _buildCurrentProfile();

    return Scaffold(
      backgroundColor: CosmicTheme.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Натальный профиль',
          style: TextStyle(
            color: CosmicTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Карточка привязки аккаунта
                if (widget.initialProfile != null && widget.initialProfile!.isRegistered)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2235),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CosmicTheme.cyanAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: CosmicTheme.cyanAccent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'АККАУНТ ПРИВЯЗАН',
                                style: TextStyle(
                                  color: CosmicTheme.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                widget.initialProfile!.primaryContact,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                          tooltip: 'Выйти из аккаунта',
                          onPressed: _confirmLogout,
                        ),
                      ],
                    ),
                  ),

                // Карточка рассчитанного знака зодиака по текущей дате
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A2356), Color(0xFF161926)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CosmicTheme.goldAccent.withOpacity(0.15),
                          border: Border.all(color: CosmicTheme.goldAccent),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          previewProfile.zodiacSymbol,
                          style: const TextStyle(fontSize: 28, color: CosmicTheme.goldAccent),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              previewProfile.zodiacSign,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Стихия: ${previewProfile.element} • ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: CosmicTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Имя
                const Text(
                  'Имя / Псевдоним',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Как к вам обращаться в прогнозе',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.person_rounded, color: CosmicTheme.goldAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E2235),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Пожалуйста, введите ваше имя';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. Email
                const Text(
                  'Адрес эл. почты (Email)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'user@example.com',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.email_rounded, color: CosmicTheme.goldAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E2235),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Пожалуйста, укажите email для регистрации';
                    if (!val.contains('@') || !val.contains('.')) return 'Введите корректный email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2.1 Telegram @username
                const Text(
                  'Ваш Telegram (для доставки в бот)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Укажите ваш логин Telegram для синхронизации и персональной доставки',
                  style: TextStyle(fontSize: 11.5, color: CosmicTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _telegramController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'например: oleg_sidorenco',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.send_rounded, color: Color(0xFF2AABEE)),
                    filled: true,
                    fillColor: const Color(0xFF1E2235),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Дата и Время рождения
                Row(
                  children: [
                    // Дата рождения
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Дата рождения',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2235),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, color: CosmicTheme.goldAccent, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(_selectedDate),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Время рождения
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Время рождения',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickTime,
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2235),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_filled_rounded, color: CosmicTheme.goldAccent, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Чекбокс приблизительного времени
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: CosmicTheme.goldAccent,
                  checkColor: Colors.black,
                  value: !_isTimeExact,
                  onChanged: (val) {
                    setState(() {
                      _isTimeExact = !(val ?? false);
                      if (!_isTimeExact) {
                        _selectedTime = const TimeOfDay(hour: 12, minute: 0);
                      }
                    });
                  },
                  title: const Text(
                    'Не знаю точное время (расчет на полдень 12:00)',
                    style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Место рождения
                const Text(
                  'Место рождения (Город)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Необходимо для вычисления координат Асцендента и натальных домов',
                  style: TextStyle(fontSize: 11.5, color: CosmicTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _birthPlaceController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Например: Лондон, Великобритания',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.location_city_rounded, color: CosmicTheme.goldAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E2235),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Пожалуйста, укажите город рождения';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. Место пребывания
                const Text(
                  'Место текущего пребывания (Город проживания)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Необходимо для расчета локальных транзитов планет по вашему текущему часовому поясу',
                  style: TextStyle(fontSize: 11.5, color: CosmicTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _currentCityController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Например: Берлин, Германия',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.explore_rounded, color: CosmicTheme.goldAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E2235),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Пожалуйста, укажите где вы находитесь сейчас';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 6. Пол
                const Text(
                  'Пол (для правильной грамматики прогноза)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = "female"),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selectedGender == "female"
                                ? CosmicTheme.goldAccent.withOpacity(0.2)
                                : const Color(0xFF1E2235),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedGender == "female"
                                  ? CosmicTheme.goldAccent
                                  : Colors.white12,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '👩 Женский',
                            style: TextStyle(
                              color: _selectedGender == "female" ? CosmicTheme.goldAccent : Colors.white70,
                              fontWeight: _selectedGender == "female" ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = "male"),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selectedGender == "male"
                                ? CosmicTheme.goldAccent.withOpacity(0.2)
                                : const Color(0xFF1E2235),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedGender == "male"
                                  ? CosmicTheme.goldAccent
                                  : Colors.white12,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '👨 Мужской',
                            style: TextStyle(
                              color: _selectedGender == "male" ? CosmicTheme.goldAccent : Colors.white70,
                              fontWeight: _selectedGender == "male" ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 7. Приоритетные сферы внимания (фокус натального расчета)
                const Text(
                  'Приоритетные сферы внимания (фокус расчета)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Персональный акцент в деловой стратегии, переговорах и часах активности',
                  style: TextStyle(fontSize: 11.5, color: CosmicTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '💼 Бизнес и финансы',
                    '🤝 Переговоры и сделки',
                    '📈 Карьера и статус',
                    '❤️ Отношения и семья',
                    '🌿 Здоровье и тонус',
                    '🧘 Духовный рост',
                  ].map((preset) {
                    final cleanName = preset.substring(preset.indexOf(' ') + 1).toLowerCase();
                    final isSelected = _focusController.text.toLowerCase().contains(cleanName);
                    return ChoiceChip(
                      label: Text(preset),
                      selected: isSelected,
                      selectedColor: CosmicTheme.goldAccent.withOpacity(0.25),
                      backgroundColor: const Color(0xFF1E2235),
                      side: BorderSide(
                        color: isSelected ? CosmicTheme.goldAccent : Colors.white12,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? CosmicTheme.goldAccent : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          final current = _focusController.text.trim();
                          if (selected) {
                            if (current.isEmpty) {
                              _focusController.text = cleanName;
                            } else if (!current.toLowerCase().contains(cleanName)) {
                              _focusController.text = "$current, $cleanName";
                            }
                          } else {
                            final parts = current
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty && !s.toLowerCase().contains(cleanName))
                                .toList();
                            _focusController.text = parts.join(', ');
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _focusController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Например: бизнес, деловые переговоры, финансы и здоровье',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.stars_rounded, color: CosmicTheme.goldAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E2235),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Блок Telegram-бота
                _buildTelegramBotCard(),

                const SizedBox(height: 24),

                // Кнопка сохранения
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CosmicTheme.goldAccent,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.black, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Сохранить натальный профиль',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramBotCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B2A44).withOpacity(0.95),
            const Color(0xFF131722).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2AABEE).withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2AABEE).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2AABEE).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF2AABEE),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Персональный Telegram-бот',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '100% надежная утренняя доставка в 06:30',
                      style: TextStyle(
                        color: Color(0xFF2AABEE),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Если на смартфоне блокируются уведомления из-за спящего режима или ограничений батареи, подключите Telegram-бота. Сообщения приходят точно в 06:30 утра со звуком и всплывающим окном.',
            style: TextStyle(
              color: CosmicTheme.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F141F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Как подключить за 1 минуту:',
                  style: TextStyle(
                    color: CosmicTheme.goldAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructionStep('1', 'Скопируйте имя бота: @Horoscope_SiDoReCo_bot'),
                _buildInstructionStep('2', 'Откройте Telegram, найдите бота и нажмите «Запустить» (/start)'),
                _buildInstructionStep('3', 'Укажите ваш логин Telegram в поле выше и нажмите «Сохранить»'),
                _buildInstructionStep('4', 'В боте можно быстро менять время рождения командой /set_time'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: '@Horoscope_SiDoReCo_bot'));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Имя бота @Horoscope_SiDoReCo_bot скопировано в буфер!'),
                    backgroundColor: Color(0xFF2AABEE),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2AABEE)),
              label: const Text(
                'Скопировать @Horoscope_SiDoReCo_bot',
                style: TextStyle(
                  color: Color(0xFF2AABEE),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2AABEE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFF2AABEE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
