import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/cosmic_theme.dart';
import '../../services/storage_service.dart';
import 'home_screen.dart';
import 'zodiac_screen.dart';
import 'archive_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUnreadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUnreadStatus();
    }
  }

  Future<void> _checkUnreadStatus() async {
    final unread = await StorageService.hasUnreadHoroscope();
    if (mounted && unread != _hasUnread) {
      setState(() {
        _hasUnread = unread;
      });
    }
  }

  void _onTabChanged(int idx) {
    setState(() {
      _currentIndex = idx;
    });
    _checkUnreadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onReadStateChanged: _checkUnreadStatus),
      const ZodiacScreen(),
      const ArchiveScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
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
                onDestinationSelected: _onTabChanged,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: CosmicTheme.goldAccent.withOpacity(0.2),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: _hasUnread,
                      label: const Text(
                        'NEW',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFFFF3D71),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      child: const Icon(Icons.stars_outlined, color: CosmicTheme.textSecondary),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: _hasUnread,
                      label: const Text(
                        'NEW',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFFFF3D71),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      child: const Icon(Icons.stars_rounded, color: CosmicTheme.goldAccent),
                    ),
                    label: 'Мой день',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined, color: CosmicTheme.textSecondary),
                    selectedIcon: Icon(Icons.auto_awesome, color: CosmicTheme.cyanAccent),
                    label: 'Знаки зодиака',
                  ),
                  const NavigationDestination(
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
