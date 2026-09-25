import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'ui/theme/cosmic_theme.dart';
import 'ui/screens/main_nav_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase init error: $e");
  }
  
  // Устанавливаем стиль системного статус-бара
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: CosmicTheme.backgroundDeep,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Загружаем сохраненный язык интерфейса
  try {
    final langCode = await StorageService.getLanguageCode();
    CosmicHoroscopeApp.localeNotifier.value = Locale(langCode);
  } catch (_) {}

  // Инициализация сервиса утренних напоминаний, бейджей и разрешений Android 13/14+
  try {
    await NotificationService.initialize();
  } catch (_) {}

  // Запуск службы фонового мониторинга для гарантированной доставки утреннего прогноза
  try {
    await BackgroundSyncService.initService();
  } catch (_) {}

  runApp(const CosmicHoroscopeApp());
}

class CosmicHoroscopeApp extends StatelessWidget {
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

  const CosmicHoroscopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          title: 'Астро Гороскоп',
          debugShowCheckedModeBanner: false,
          theme: CosmicTheme.darkTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: currentLocale,
          home: const MainNavScreen(),
        );
      },
    );
  }
}
