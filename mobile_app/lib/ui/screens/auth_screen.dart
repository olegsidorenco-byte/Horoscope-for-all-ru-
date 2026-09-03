import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import 'profile_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isRegistrationInitial;
  const AuthScreen({Key? key, this.isRegistrationInitial = false}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _regFormKey = GlobalKey<FormState>();

  // Контроллеры входа
  final _loginContactController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;

  // Контроллеры регистрации
  final _regNameController = TextEditingController();
  final _regContactController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  bool _regObscurePassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isRegistrationInitial ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginContactController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regContactController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await AuthService.login(
        contact: _loginContactController.text,
        password: _loginPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E2235),
            content: Text(
              '✨ Добро пожаловать, ${profile.name.isNotEmpty ? profile.name : "пользователь"}!',
              style: const TextStyle(color: CosmicTheme.goldAccent, fontWeight: FontWeight.bold),
            ),
          ),
        );
        Navigator.pop(context, profile);
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

  Future<void> _handleRegister() async {
    if (!_regFormKey.currentState!.validate()) return;

    if (_regPasswordController.text != _regConfirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Пароли не совпадают. Пожалуйста, проверьте ввод.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await AuthService.register(
        contact: _regContactController.text,
        password: _regPasswordController.text,
        name: _regNameController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1E2235),
            content: Text(
              '🎉 Аккаунт успешно создан! Заполните натальную анкету для персонального расчета.',
              style: TextStyle(color: CosmicTheme.goldAccent),
            ),
          ),
        );

        // Переходим к заполнению анкеты
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(initialProfile: profile),
          ),
        );
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

  void _showTelegramLoginDialog() {
    final tgController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: CosmicTheme.cyanAccent, width: 1.2),
          ),
          title: Row(
            children: const [
              Icon(Icons.send_rounded, color: Color(0xFF29B6F6), size: 24),
              SizedBox(width: 10),
              Text(
                'Вход через Telegram',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Укажите ваш логин в Telegram или номер телефона для привязки аккаунта к боту:',
                style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '@username или номер телефона',
                  prefixIcon: const Icon(Icons.alternate_email, color: CosmicTheme.cyanAccent),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ваше имя',
                  prefixIcon: const Icon(Icons.person_outline, color: CosmicTheme.goldAccent),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF29B6F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final tgVal = tgController.text.trim();
                final nameVal = nameController.text.trim();
                if (tgVal.isEmpty) return;

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                try {
                  final p = await AuthService.loginWithTelegram(
                    telegramUsername: tgVal,
                    name: nameVal.isNotEmpty ? nameVal : tgVal,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1E2235),
                        content: Text('✨ Авторизация через Telegram успешна (@${p.telegramUsername})!'),
                      ),
                    );
                    Navigator.pop(context, p);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _errorMessage = e.toString().replaceAll('Exception: ', '');
                      _isLoading = false;
                    });
                  }
                }
              },
              child: const Text('Подтвердить', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Личный профиль'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CosmicTheme.goldAccent,
          indicatorWeight: 3,
          labelColor: CosmicTheme.goldAccent,
          unselectedLabelColor: CosmicTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Вход', icon: Icon(Icons.login_rounded, size: 20)),
            Tab(text: 'Регистрация', icon: Icon(Icons.person_add_alt_1_rounded, size: 20)),
          ],
        ),
      ),
      body: CosmicBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.18),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginTab(),
                    _buildRegisterTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [CosmicTheme.goldAccent, CosmicTheme.cyanAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CosmicTheme.goldAccent.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_person_rounded, size: 38, color: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Вход в аккаунт',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Один телефон или почта — один аккаунт',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: CosmicTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Поле Контакт
            TextFormField(
              controller: _loginContactController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email или номер телефона',
                hintText: 'example@mail.ru или +79991234567',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.contact_mail_outlined, color: CosmicTheme.goldAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Введите телефон или email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Поле Пароль
            TextFormField(
              controller: _loginPasswordController,
              obscureText: _loginObscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Пароль',
                prefixIcon: const Icon(Icons.key_outlined, color: CosmicTheme.cyanAccent),
                suffixIcon: IconButton(
                  icon: Icon(
                    _loginObscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white60,
                  ),
                  onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
                ),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Введите пароль';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Кнопка Войти
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: CosmicTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Text(
                      'Войти в аккаунт',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 20),

            // Разделитель
            Row(
              children: const [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ИЛИ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white12)),
              ],
            ),
            const SizedBox(height: 18),

            // Быстрый вход через Telegram
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showTelegramLoginDialog,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF29B6F6), size: 20),
              label: const Text(
                'Войти через Telegram',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF29B6F6), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _regFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            const Text(
              'Регистрация профиля',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Один телефон или почта закрепляется за одним аккаунтом',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: CosmicTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // Имя
            TextFormField(
              controller: _regNameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Ваше имя',
                prefixIcon: const Icon(Icons.person_outline, color: CosmicTheme.goldAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите ваше имя' : null,
            ),
            const SizedBox(height: 14),

            // Контакт
            TextFormField(
              controller: _regContactController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Телефон или Email (уникальный контакт)',
                hintText: '+79991234567 или user@mail.ru',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.contact_phone_outlined, color: CosmicTheme.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Укажите телефон или email';
                if (!AuthService.isEmail(v) && !AuthService.isPhone(v)) {
                  return 'Укажите корректный email или номер телефона (+7...)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Пароль
            TextFormField(
              controller: _regPasswordController,
              obscureText: _regObscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Придумайте пароль (от 6 символов)',
                prefixIcon: const Icon(Icons.lock_outline, color: CosmicTheme.goldAccent),
                suffixIcon: IconButton(
                  icon: Icon(
                    _regObscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white60,
                  ),
                  onPressed: () => setState(() => _regObscurePassword = !_regObscurePassword),
                ),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v == null || v.length < 6) return 'Пароль должен содержать не менее 6 символов';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Подтверждение пароля
            TextFormField(
              controller: _regConfirmPasswordController,
              obscureText: _regObscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Повторите пароль',
                prefixIcon: const Icon(Icons.lock_clock_outlined, color: CosmicTheme.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v != _regPasswordController.text) return 'Пароли не совпадают';
                return null;
              },
            ),
            const SizedBox(height: 22),

            // Кнопка Создать аккаунт
            ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: CosmicTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Text(
                      'Создать аккаунт и перейти к анкете →',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 16),

            // Быстрый вход через Telegram
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showTelegramLoginDialog,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF29B6F6), size: 20),
              label: const Text(
                'Быстрая регистрация через Telegram',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF29B6F6), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
