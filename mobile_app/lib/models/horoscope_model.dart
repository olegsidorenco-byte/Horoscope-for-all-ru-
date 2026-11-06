class HoroscopeTopic {
  final String title;
  final String content;
  final String icon;

  HoroscopeTopic({
    required this.title,
    required this.content,
    required this.icon,
  });

  factory HoroscopeTopic.fromJson(Map<String, dynamic> json) => HoroscopeTopic(
    title: json['title'] ?? '',
    content: json['content'] ?? '',
    icon: json['icon'] ?? '✨',
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'icon': icon,
  };
}

class HoroscopeDay {
  final String date;
  final String greeting;
  final List<HoroscopeTopic> topics;
  final String rawText;
  final String updatedAt;
  final bool isPersonal;

  HoroscopeDay({
    required this.date,
    required this.greeting,
    required this.topics,
    required this.rawText,
    this.updatedAt = '',
    this.isPersonal = false,
  });

  factory HoroscopeDay.fromJson(Map<String, dynamic> json) {
    var rawTopics = json['topics'] as List? ?? [];
    List<HoroscopeTopic> parsedTopics = rawTopics
        .map((item) => HoroscopeTopic.fromJson(item as Map<String, dynamic>))
        .toList();

    return HoroscopeDay(
      date: json['date'] ?? '',
      greeting: json['greeting'] ?? '',
      topics: parsedTopics,
      rawText: json['raw_text'] ?? json['horoscope'] ?? '',
      updatedAt: json['updated_at'] ?? json['generated_at'] ?? '',
      isPersonal: json['is_personal'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'greeting': greeting,
    'topics': topics.map((t) => t.toJson()).toList(),
    'raw_text': rawText,
    'updated_at': updatedAt,
    'is_personal': isPersonal,
  };

  static String _stripTrailingSectionIcon(String text, List<String> trailingIconsOut) {
    final trimmed = text.trimRight();
    final match = RegExp(r'\s*(🪐|💼|❤️|🌿|💡|✨)\s*$', unicode: true).firstMatch(trimmed);
    if (match != null) {
      trailingIconsOut.add(match.group(1)!);
      return trimmed.substring(0, match.start).trim();
    }
    return text.trim();
  }

  static String _detectTopicIcon(String title, String? precedingIcon) {
    if (precedingIcon != null && precedingIcon.isNotEmpty) {
      return precedingIcon;
    }
    final t = title.toLowerCase();
    if (t.contains('влияние планет') || t.contains('planet') || t.contains('influencia')) {
      return '🪐';
    } else if (t.contains('работа') || t.contains('бизнес') || t.contains('work') ||
        t.contains('business') || t.contains('trabajo') || t.contains('arbeit') || t.contains('travail')) {
      return '💼';
    } else if (t.contains('личн') || t.contains('отношен') || t.contains('общение') ||
        t.contains('personal') || t.contains('relationship') || t.contains('relaciones') ||
        t.contains('beziehung') || t.contains('relations')) {
      return '❤️';
    } else if (t.contains('здоров') || t.contains('тонус') || t.contains('health') ||
        t.contains('salud') || t.contains('gesundheit') || t.contains('sant')) {
      return '🌿';
    } else if (t.contains('совет') || t.contains('advice') || t.contains('consejo') ||
        t.contains('rat') || t.contains('conseil')) {
      return '💡';
    } else if (t.contains('пожелан') || t.contains('wish') || t.contains('deseo') ||
        t.contains('wünsch') || t.contains('vœux')) {
      return '✨';
    }
    return '✨';
  }

  factory HoroscopeDay.fromRawText(
    String date,
    String raw, {
    bool isPersonal = false,
    String updatedAt = '',
  }) {
    String clean = raw
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // Поиск первого блока / приветствия
    String greeting = '';
    List<HoroscopeTopic> topics = [];

    final topicBlocks = clean.split('<b>');
    String? pendingIcon;
    if (topicBlocks.isNotEmpty) {
      final rawGreeting = topicBlocks[0]
          .replaceAll(RegExp(r'<[^>]*>'), '');
      final captured = <String>[];
      greeting = _stripTrailingSectionIcon(rawGreeting, captured);
      if (captured.isNotEmpty) {
        pendingIcon = captured.last;
      }
    }

    for (int i = 1; i < topicBlocks.length; i++) {
      final parts = topicBlocks[i].split('</b>');
      if (parts.length >= 2) {
        String title = parts[0].trim();
        final rawContent = parts.sublist(1).join('</b>').replaceAll(RegExp(r'<[^>]*>'), '');
        final captured = <String>[];
        String content = _stripTrailingSectionIcon(rawContent, captured);
        String icon = _detectTopicIcon(title, pendingIcon);
        pendingIcon = captured.isNotEmpty ? captured.last : null;

        topics.add(HoroscopeTopic(
          title: title,
          content: content,
          icon: icon,
        ));
      }
    }

    if (greeting.isEmpty) {
      greeting = clean.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }

    return HoroscopeDay(
      date: date,
      greeting: greeting,
      topics: topics,
      rawText: raw,
      updatedAt: updatedAt,
      isPersonal: isPersonal,
    );
  }
}

class ArchiveIndexItem {
  final String date;
  final String isoDate;
  final String file;
  final String preview;
  final String updatedAt;

  ArchiveIndexItem({
    required this.date,
    required this.isoDate,
    required this.file,
    required this.preview,
    required this.updatedAt,
  });

  factory ArchiveIndexItem.fromJson(Map<String, dynamic> json) => ArchiveIndexItem(
    date: json['date'] ?? '',
    isoDate: json['iso_date'] ?? '',
    file: json['file'] ?? '',
    preview: json['preview'] ?? '',
    updatedAt: json['updated_at'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'iso_date': isoDate,
    'file': file,
    'preview': preview,
    'updated_at': updatedAt,
  };
}
