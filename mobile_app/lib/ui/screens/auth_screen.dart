import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';
import '../widgets/privacy_policy_dialog.dart';
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E2235),
            content: Text(
              '${l10n.authSuccess} ${profile.name.isNotEmpty ? profile.name : ""}',
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
    final l10n = AppLocalizations.of(context);
    if (!_regFormKey.currentState!.validate()) return;

    if (_regPasswordController.text != _regConfirmPasswordController.text) {
      setState(() {
        _errorMessage = l10n.passwordsDoNotMatch;
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
          SnackBar(
            backgroundColor: const Color(0xFF1E2235),
            content: Text(
              l10n.authSuccess,
              style: const TextStyle(color: CosmicTheme.goldAccent),
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

  Future<void> _showForgotPasswordDialog() async {
    final l10n = AppLocalizations.of(context);
    final emailCtrl = TextEditingController(text: _loginContactController.text.trim());
    String? localError;
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2235),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: CosmicTheme.goldAccent, width: 1.2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.lock_reset_rounded, color: CosmicTheme.goldAccent, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.resetPasswordTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resetPasswordDesc,
                      style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    if (localError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined, color: CosmicTheme.goldAccent),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(ctx),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CosmicTheme.goldAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty || !AuthService.isEmail(email)) {
                            setDialogState(() => localError = l10n.emailFormatError);
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                            localError = null;
                          });

                          try {
                            await AuthService.sendPasswordResetEmail(email);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF1E2235),
                                  content: Text(
                                    l10n.resetPasswordSent,
                                    style: const TextStyle(color: CosmicTheme.goldAccent),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSending = false;
                              localError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          l10n.sendResetLink,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showGoogleLoginDialog() async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2235),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF4285F4), width: 1.2),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.signInGoogle,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (localError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        hintText: 'user@gmail.com',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF4285F4)),
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
                        labelText: l10n.nameLabel,
                        prefixIcon: const Icon(Icons.person_outline, color: CosmicTheme.goldAccent),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F1F1F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final name = nameController.text.trim();

                    if (email.isEmpty || !AuthService.isEmail(email)) {
                      setDialogState(() => localError = l10n.emailFormatError);
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      final profile = await AuthService.loginWithGoogle(
                        email: email,
                        name: name.isNotEmpty ? name : email.split('@')[0],
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E2235),
                            content: Text('${l10n.authSuccess} (${profile.email})'),
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
                  },
                  child: Text(l10n.tabSignIn, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showTelegramLoginDialog() async {
    final l10n = AppLocalizations.of(context);
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
            children: [
              const Icon(Icons.send_rounded, color: Color(0xFF29B6F6), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.signInTelegram,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.telegramDesc,
                style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.telegramLabel,
                  hintText: l10n.telegramHint,
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
                  labelText: l10n.nameLabel,
                  hintText: l10n.nameHint,
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
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white60)),
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
                        content: Text('${l10n.authSuccess} (@${p.telegramUsername})'),
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
              child: Text(l10n.selectButton, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.authScreenTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: CosmicTheme.goldAccent),
            tooltip: l10n.privacyPolicyButton,
            onPressed: () => showPrivacyPolicyDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CosmicTheme.goldAccent,
          indicatorWeight: 3,
          labelColor: CosmicTheme.goldAccent,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(text: l10n.tabSignIn, icon: const Icon(Icons.login_rounded, size: 20)),
            Tab(text: l10n.tabSignUp, icon: const Icon(Icons.person_add_rounded, size: 20)),
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
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
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
                    _buildLoginTab(l10n),
                    _buildRegisterTab(l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [CosmicTheme.goldAccent, CosmicTheme.cyanAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CosmicTheme.goldAccent.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.mail_lock_rounded, size: 36, color: Colors.black),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.tabSignIn,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),

            // Поле Email / Контакт
            TextFormField(
              controller: _loginContactController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.emailLabel,
                hintText: l10n.emailHint,
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.alternate_email, color: CosmicTheme.goldAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.emailValidator;
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Поле Пароль
            TextFormField(
              controller: _loginPasswordController,
              obscureText: _loginObscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                prefixIcon: const Icon(Icons.lock_outline, color: CosmicTheme.cyanAccent),
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
                if (v == null || v.isEmpty) return l10n.passwordTooShort;
                return null;
              },
            ),
            const SizedBox(height: 6),

            // Кнопка Забыли пароль?
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: Text(
                  l10n.forgotPasswordButton,
                  style: const TextStyle(color: CosmicTheme.goldSoft, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Кнопка Войти
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: CosmicTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : Text(
                      l10n.tabSignIn,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 18),

            // Разделитель
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(l10n.orOtherMethods,
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Expanded(child: Divider(color: Colors.white12)),
              ],
            ),
            const SizedBox(height: 16),

            // Опциональный вход через Google
            ElevatedButton(
              onPressed: _isLoading ? null : _showGoogleLoginDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                    ),
                    child: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.signInGoogle,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Быстрый вход через Telegram
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showTelegramLoginDialog,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF29B6F6), size: 19),
              label: Text(
                l10n.signInTelegram,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF29B6F6), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 18),

            // Ссылка на Политику конфиденциальности
            Center(
              child: TextButton.icon(
                onPressed: () => showPrivacyPolicyDialog(context),
                icon: const Icon(Icons.shield_outlined, color: CosmicTheme.textSecondary, size: 16),
                label: Text(
                  l10n.privacyPolicyButton,
                  style: const TextStyle(
                    color: CosmicTheme.textSecondary,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _regFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            Text(
              l10n.tabSignUp,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),

            // Имя
            TextFormField(
              controller: _regNameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                hintText: l10n.nameHint,
                prefixIcon: const Icon(Icons.person_outline, color: CosmicTheme.goldAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.nameValidator : null,
            ),
            const SizedBox(height: 14),

            // Контакт / Email
            TextFormField(
              controller: _regContactController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.emailLabel,
                hintText: l10n.emailHint,
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.email_outlined, color: CosmicTheme.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.emailValidator;
                if (!AuthService.isEmail(v)) {
                  return l10n.emailFormatError;
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
                labelText: l10n.passwordLabel,
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
                if (v == null || v.length < 6) return l10n.passwordTooShort;
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
                labelText: l10n.confirmPasswordLabel,
                prefixIcon: const Icon(Icons.check_circle_outline, color: CosmicTheme.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF191D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) {
                if (v != _regPasswordController.text) return l10n.passwordsDoNotMatch;
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Кнопка Создать аккаунт
            ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: CosmicTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : Text(
                      l10n.tabSignUp,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 18),

            // Разделитель
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(l10n.orOtherMethods,
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Expanded(child: Divider(color: Colors.white12)),
              ],
            ),
            const SizedBox(height: 16),

            // Регистрация через Google
            ElevatedButton(
              onPressed: _isLoading ? null : _showGoogleLoginDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                    ),
                    child: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.signInGoogle,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Быстрая регистрация через Telegram
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showTelegramLoginDialog,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF29B6F6), size: 19),
              label: Text(
                l10n.signInTelegram,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF29B6F6), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
