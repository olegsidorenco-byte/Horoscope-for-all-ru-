class HoroscopeTopic {
  final String title;
  final String content;
  final String icon;

  HoroscopeTopic({
    required this.title,
    required this.content,
    required this.icon,
  });
}

class HoroscopeDay {
  final String date;
  final String greeting;
  final List<HoroscopeTopic> topics;
  final String rawText;

  HoroscopeDay({
    required this.date,
    required this.greeting,
    required this.topics,
    required this.rawText,
  });

  factory HoroscopeDay.fromRawText(String date, String raw) {
    String clean = raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    List<String> rawTopics = [];
    if (clean.contains('===TOPIC===')) {
      rawTopics = clean
          .split('===TOPIC===')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      // Резервный парсинг по ключевым рубрикам
      final pattern = RegExp(
        r'\n+(?=(?:Влияние планет|Работа|Личные отношения|Здоровье|Добрый совет|Пожелание|Положительная аффирмация))',
        caseSensitive: false,
      );
      rawTopics = clean
          .split(pattern)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    String greeting = '';
    List<HoroscopeTopic> topics = [];

    if (rawTopics.isNotEmpty) {
      greeting = rawTopics[0];
      
      for (int i = 1; i < rawTopics.length; i++) {
        final text = rawTopics[i];
        final lines = text.split('\n');
        String firstLine = lines.first.trim();
        String body = lines.skip(1).join('\n').trim();

        String icon = '✨';
        String title = firstLine;

        if (firstLine.contains('Влияние планет')) {
          icon = '🪐';
          title = 'Влияние планет на сегодня';
        } else if (firstLine.contains('Работа') || firstLine.contains('бизнес')) {
          icon = '💼';
          title = 'Работа, бизнес и финансы';
        } else if (firstLine.contains('Личные отношения') || firstLine.contains('общение')) {
          icon = '❤️';
          title = 'Личные отношения и общение';
        } else if (firstLine.contains('Здоровье') || firstLine.contains('тонус')) {
          icon = '🌿';
          title = 'Здоровье и тонус';
        } else if (firstLine.contains('Добрый совет')) {
          icon = '💡';
          title = 'Добрый совет на сегодня';
        } else if (firstLine.contains('Пожелание') || firstLine.contains('аффирмация')) {
          icon = '✨';
          title = 'Пожелание на сегодня';
        }

        if (body.isEmpty) {
          body = text;
        }

        topics.add(HoroscopeTopic(
          title: title,
          content: body,
          icon: icon,
        ));
      }
    }

    if (greeting.isEmpty) {
      greeting = clean;
    }

    return HoroscopeDay(
      date: date,
      greeting: greeting,
      topics: topics,
      rawText: raw,
    );
  }
}
