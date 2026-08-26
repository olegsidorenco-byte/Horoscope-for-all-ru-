import 'package:flutter/material.dart';
import '../../models/horoscope_model.dart';
import '../theme/cosmic_theme.dart';

class TopicCard extends StatefulWidget {
  final HoroscopeTopic topic;
  final int index;

  const TopicCard({
    super.key,
    required this.topic,
    required this.index,
  });

  @override
  State<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard> {
  bool _isExpanded = true;

  Color _getTopicAccent(String icon) {
    switch (icon) {
      case '🪐':
        return CosmicTheme.purpleNeon;
      case '💼':
        return CosmicTheme.goldAccent;
      case '❤️':
        return CosmicTheme.roseGlow;
      case '🌿':
        return const Color(0xFF2EC4B6);
      case '💡':
        return CosmicTheme.cyanAccent;
      case '✨':
        return CosmicTheme.goldSoft;
      default:
        return CosmicTheme.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _getTopicAccent(widget.topic.icon);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CosmicTheme.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded ? accent.withOpacity(0.35) : Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.topic.icon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.topic.title,
                        style: const TextStyle(
                          color: CosmicTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: CosmicTheme.textSecondary,
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 14),
                  Text(
                    widget.topic.content,
                    style: const TextStyle(
                      color: CosmicTheme.textPrimary,
                      fontSize: 14.5,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
