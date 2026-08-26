import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/cosmic_theme.dart';

class CosmicBackground extends StatelessWidget {
  final Widget child;

  const CosmicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Градиент глубокого космоса
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF070913),
                Color(0xFF0F1426),
                Color(0xFF141A33),
                Color(0xFF0A0D1A),
              ],
              stops: [0.0, 0.4, 0.8, 1.0],
            ),
          ),
        ),
        // Неоновое свечение в верхнем углу
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CosmicTheme.purpleNeon.withOpacity(0.12),
            ),
          ),
        ),
        // Теплое свечение в левом нижнем углу
        Positioned(
          bottom: -80,
          left: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CosmicTheme.goldAccent.withOpacity(0.08),
            ),
          ),
        ),
        // Звездная россыпь
        CustomPaint(
          size: Size.infinite,
          painter: _StarryPainter(),
        ),
        // Основной контент
        SafeArea(child: child),
      ],
    );
  }
}

class _StarryPainter extends CustomPainter {
  final Random _rnd = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.4);

    for (int i = 0; i < 45; i++) {
      final x = _rnd.nextDouble() * size.width;
      final y = _rnd.nextDouble() * size.height;
      final radius = _rnd.nextDouble() * 1.5 + 0.5;
      final opacity = _rnd.nextDouble() * 0.5 + 0.2;
      
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
