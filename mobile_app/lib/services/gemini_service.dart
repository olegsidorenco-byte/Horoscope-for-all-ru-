import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../models/horoscope_model.dart';
import 'storage_service.dart';

class GeminiService {
  static const List<String> fallbackModels = [
    'gemini-3.7-flash',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro'
  ];

  static String buildPrompt(UserProfile profile, String targetDate) {
    final name = profile.name.trim().isNotEmpty ? profile.name.trim() : 'Уважаемый читатель';
    final birthDate = profile.birthDate.trim();
    final birthTime = profile.birthTime.trim().isNotEmpty ? profile.birthTime.trim() : '12:00 (условно)';
    final birthCity = profile.birthCity.trim().isNotEmpty ? profile.birthCity.trim() : 'Не указан';
    final isGeneral = profile.isGeneral || birthDate.isEmpty;

    String profileContext;
    if (isGeneral) {
      profileContext = 'Текущая дата составления прогноза: $targetDate.\n'
          'Тип прогноза: Общий детальный астрологический прогноз дня по реальным текущим транзитам планет.';
    } else {
      profileContext = 'Текущая дата составления прогноза: $targetDate.\n'
          'Имя пользователя: $name.\n'
          'Дата рождения: $birthDate.\n'
          'Время рождения: $birthTime.\n'
          'Город/местоположение: $birthCity.\n'
          'Рассчитайте натальное положение планет на дату рождения и текущие транзиты планет.';
    }

    return '''ВЫ — ведущий астролог-эксперт высшей категории с фундаментальными знаниями классической натальной и транзитной астрологии.

ДАННЫЕ ДЛЯ РАСЧЕТА:
$profileContext

СТРОЖАЙШИЕ ПРАВИЛА И СТИЛЬ:
1. Обращение: ИСКЛЮЧИТЕЛЬНО на уважительное «Вы» (Ваш, Вам). Категорически ЗАПРЕЩЕНО обращение на «ты».
2. Начало рассылки (Блок 1):
   - ОБЯЗАТЕЛЬНО начинается с теплого, душевного утреннего приветствия с несколькими гармоничными эмодзи в начале и в конце (например: ☀️🌸🌿 Доброе утро. Новый день уже начался — пусть он будет спокойным, тёплым и удачным. Берегите себя и хорошего всем настроения. 🌿🌸 или 🌅✨☕, 🌺🕊️🌾, 🌤️🌱🍀, ☀️🌻💛).
   - Формулировки приветствия и комбинации эмодзи должны быть разнообразными, теплыми и живыми, избегайте механических шаблонных повторений.
   - СРАЗУ следом за приветствием в этом же блоке добавьте в 2–3 емких предложениях обобщенный астрологический прогноз дня на $targetDate.
3. Практичность и профессионализм: Взвешенные, экспертные рекомендации с привязкой к планетарным аспектам и конкретным временным интервалам дня.
4. Разделяйте каждую смысловую тему специальным разделителем: ===TOPIC===

ОБЯЗАТЕЛЬНО ВКЛЮЧИТЕ ВСЕ 7 ТЕМАТИЧЕСКИХ БЛОКОВ (строго в указанном порядке, каждый блок отделяется строкой ===TOPIC===):

БЛОК 1 (Приветствие и общий фон дня):
Утреннее приветствие с эмодзи в начале и в конце + обобщенный астрологический прогноз на $targetDate в 2-3 емких предложениях.

===TOPIC===
🪐 Влияние планет на сегодня
(Ключевые планетарные аспекты, фоновое астрологическое влияние дня, активные дома).

===TOPIC===
💼 Работа, бизнес и финансы
(Стратегия действий, деловые переговоры, финансовые операции, благоприятные и рискованные часы).

===TOPIC===
❤️ Личные отношения и общение
(Эмоциональный фон, взаимодействие с близкими и партнерами, конструктивный диалог).

===TOPIC===
🌿 Здоровье и тонус
(Физическое состояние, психоэмоциональный баланс, рекомендации по нагрузкам и биоритмам).

===TOPIC===
💡 Добрый совет на сегодня
(Глубокий практичный совет мастера с привязкой к конкретному времени суток).

===TOPIC===
✨ Пожелание на сегодня
(Теплое, вдохновляющее, возвышающее напутствие и сердечное пожелание на сегодняшний день).

Сгенерируйте ПОЛНЫЙ текст со всеми 7 блоками от начала до конца, без пропусков.''';
  }

  static Future<HoroscopeDay> generateHoroscope({
    required UserProfile profile,
    required String targetDate,
    String? customApiKey,
    bool forceRefresh = false,
  }) async {
    // 1. Проверяем кэш, если не запрошено принудительное обновление
    if (!forceRefresh) {
      final cached = await StorageService.getCachedHoroscope(targetDate);
      if (cached != null) {
        return cached;
      }
    }

    // 2. Получаем API ключ
    String apiKey = customApiKey?.trim() ?? '';
    if (apiKey.isEmpty) {
      apiKey = await StorageService.loadApiKey();
    }

    if (apiKey.isEmpty) {
      throw Exception('Пожалуйста, укажите ключ Google Gemini API в Настройках приложения.');
    }

    final prompt = buildPrompt(profile, targetDate);
    String lastError = '';

    for (final model in fallbackModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );

        final headers = {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        };

        final body = jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 8192,
          }
        });

        final response = await http.post(url, headers: headers, body: body).timeout(
          const Duration(seconds: 40),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final rawText = parts[0]['text'] as String? ?? '';
              if (rawText.trim().isNotEmpty) {
                // Сохраняем в кэш
                await StorageService.cacheHoroscope(targetDate, rawText);
                return HoroscopeDay.fromRawText(targetDate, rawText);
              }
            }
          }
        }

        lastError = 'HTTP ${response.statusCode}: ${response.body}';
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw Exception('Не удалось сгенерировать прогноз: $lastError');
  }
}
