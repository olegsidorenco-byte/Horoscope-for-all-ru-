import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/cosmic_theme.dart';

class GreetingHeader extends StatelessWidget {
  final String greetingText;
  final String dateStr;
  final VoidCallback onRefresh;
  final bool isLoading;

  const GreetingHeader({
    super.key,
    required this.greetingText,
    required this.dateStr,
    required this.onRefresh,
    required this.isLoading,
  });

  bool get _isToday {
    final todayStr = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return dateStr.trim() == todayStr.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CosmicTheme.backgroundElevated,
            CosmicTheme.backgroundCard.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isToday ? CosmicTheme.goldAccent.withOpacity(0.4) : Colors.white12,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isToday ? CosmicTheme.goldAccent.withOpacity(0.15) : Colors.black26,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: CosmicTheme.goldAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: CosmicTheme.goldAccent, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: CosmicTheme.goldSoft,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Бейдж новизны
                  if (_isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2EC4B6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2EC4B6).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2EC4B6),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'СВЕЖИЙ',
                            style: TextStyle(
                              color: Color(0xFF2EC4B6),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scaleXY(begin: 1.0, end: 1.05, duration: 1500.ms)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'АРХИВ',
                        style: TextStyle(
                          color: CosmicTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: CosmicTheme.goldAccent),
                      )
                    : const Icon(Icons.refresh_rounded, color: CosmicTheme.cyanAccent),
                tooltip: 'Обновить прогноз',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            greetingText,
            style: const TextStyle(
              color: CosmicTheme.textPrimary,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
