import 'package:flutter/material.dart';
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
        border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: CosmicTheme.goldAccent.withOpacity(0.12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CosmicTheme.goldAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CosmicTheme.goldAccent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: CosmicTheme.goldAccent, size: 16),
                    const SizedBox(width: 6),
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
