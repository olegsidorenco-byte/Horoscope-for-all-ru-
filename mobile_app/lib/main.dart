import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/theme/cosmic_theme.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Устанавливаем стиль системного статус-бара
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: CosmicTheme.backgroundDeep,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CosmicHoroscopeApp());
}

class CosmicHoroscopeApp extends StatelessWidget {
  const CosmicHoroscopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Астро Гороскоп',
      debugShowCheckedModeBanner: false,
      theme: CosmicTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
