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

  HoroscopeDay({
    required this.date,
    required this.greeting,
    required this.topics,
    required this.rawText,
    this.updatedAt = '',
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
      rawText: json['raw_text'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'greeting': greeting,
    'topics': topics.map((t) => t.toJson()).toList(),
    'raw_text': rawText,
    'updated_at': updatedAt,
  };

  factory HoroscopeDay.fromRawText(String date, String raw) {
    String clean = raw
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // Поиск первого блока / приветствия
    String greeting = '';
    List<HoroscopeTopic> topics = [];

    final topicBlocks = clean.split('<b>');
    if (topicBlocks.isNotEmpty) {
      greeting = topicBlocks[0]
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
    }

    for (int i = 1; i < topicBlocks.length; i++) {
      final parts = topicBlocks[i].split('</b>');
      if (parts.length >= 2) {
        String title = parts[0].trim();
        String content = parts[1]
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim();

        String icon = '✨';
        if (title.contains('Влияние планет')) {
          icon = '🪐';
        } else if (title.contains('Работа') || title.contains('бизнес')) {
          icon = '💼';
        } else if (title.contains('Личные отношения') || title.contains('общение')) {
          icon = '❤️';
        } else if (title.contains('Здоровье') || title.contains('тонус')) {
          icon = '🌿';
        } else if (title.contains('Добрый совет')) {
          icon = '💡';
        } else if (title.contains('Пожелание')) {
          icon = '✨';
        }

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
