import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/cosmic_theme.dart';
import 'home_screen.dart';
import 'zodiac_screen.dart';
import 'archive_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ZodiacScreen(),
    ArchiveScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: CosmicTheme.goldAccent.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141724).withOpacity(0.85),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (idx) {
                  setState(() {
                    _currentIndex = idx;
                  });
                },
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: CosmicTheme.goldAccent.withOpacity(0.2),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.stars_outlined, color: CosmicTheme.textSecondary),
                    selectedIcon: Icon(Icons.stars_rounded, color: CosmicTheme.goldAccent),
                    label: 'Мой день',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined, color: CosmicTheme.textSecondary),
                    selectedIcon: Icon(Icons.auto_awesome, color: CosmicTheme.cyanAccent),
                    label: 'Знаки зодиака',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined, color: CosmicTheme.textSecondary),
                    selectedIcon: Icon(Icons.calendar_month_rounded, color: CosmicTheme.goldSoft),
                    label: 'Архив',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
