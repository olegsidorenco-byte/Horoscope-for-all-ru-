"""
Сервис взаимодействия с Google AI (Gemini / Imagen).
Включает:
- Автопоиск моделей (Auto-Discovery)
- Отказоустойчивое переключение (Auto-Fallback)
- Персональный расчет натальной карты и транзитов
- Генерацию космической картины дня
"""

import json
import re
import time
from datetime import datetime
import requests


# Резервный список моделей на случай сбоя автопоиска
DEFAULT_MODELS_PRIORITY = [
    "gemini-3.7-flash",
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
    "gemini-1.5-pro",
    "gemini-2.5-pro"
]


def discover_models(api_key: str) -> list:
    """
    Опрашивает Google AI API и находит актуальные модели Gemini.
    Сортирует их по приоритету новизны (3.7 -> 2.5 -> 2.0 -> 1.5, Flash предпочтительнее).
    """
    url = "https://generativelanguage.googleapis.com/v1beta/models"
    headers = {"x-goog-api-key": api_key}

    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json()
            models = data.get("models", [])
            
            valid_models = []
            for m in models:
                name = m.get("name", "").replace("models/", "")
                methods = m.get("supportedGenerationMethods", [])
                
                # Фильтруем только модели, поддерживающие генерацию текста
                if "generateContent" not in methods:
                    continue
                
                # Исключаем устаревшие, экспериментальные без версий и специализированные модели
                lower_name = name.lower()
                if any(x in lower_name for x in ["embedding", "aqa", "bison", "tts", "imagen", "vision"]):
                    continue
                if "gemini" in lower_name:
                    valid_models.append(name)
            
            if valid_models:
                # Функция оценки приоритета модели
                def model_score(m_name: str):
                    score = 0
                    m_lower = m_name.lower()
                    if "3.7" in m_lower:
                        score += 500
                    elif "3.5" in m_lower or "3.1" in m_lower:
                        score += 400
                    elif "2.5" in m_lower:
                        score += 300
                    elif "2.0" in m_lower:
                        score += 200
                    elif "1.5" in m_lower:
                        score += 100
                    
                    if "flash" in m_lower:
                        score += 50
                    if "pro" in m_lower:
                        score += 30
                    if "exp" in m_lower or "preview" in m_lower:
                        score -= 20
                    return score

                valid_models.sort(key=model_score, reverse=True)
                return valid_models
    except Exception as e:
        print(f"⚠️ Ошибка при автопоиске моделей ({e}). Используем стандартный приоритетный список.")

    return DEFAULT_MODELS_PRIORITY


def build_horoscope_prompt(user_profile: dict, target_date: str) -> str:
    """
    Формирует структурированный промпт для ИИ с расчетом натальной карты.
    """
    name = user_profile.get("name", "Уважаемый читатель")
    birth_date = user_profile.get("birth_date", "").strip()
    birth_time = user_profile.get("birth_time", "").strip()
    birth_city = user_profile.get("birth_city", "").strip()
    is_general = user_profile.get("is_general", False) or not birth_date

    if is_general:
        profile_context = (
            f"Текущая дата составления прогноза: {target_date}.\n"
            "Тип прогноза: Общий детальный астрологический прогноз дня по реальным текущим транзитам планет."
        )
    else:
        profile_context = (
            f"Текущая дата составления прогноза: {target_date}.\n"
            f"Имя пользователя: {name}.\n"
            f"Дата рождения: {birth_date}.\n"
            f"Время рождения: {birth_time if birth_time else '12:00 (условно)'}.\n"
            f"Город/местоположение: {birth_city if birth_city else 'Не указан'}.\n"
            "Рассчитайте точное натальное положение планет на дату рождения и реальные транзиты планет на сегодняшнюю дату."
        )

    prompt = f"""ВЫ — ведущий астролог-эксперт высшей категории со стажем практической работы 60 лет. Вы обладаете глубокими фундаментальными знаниями классической натальной и транзитной астрологии.

ДАННЫЕ ДЛЯ РАСЧЕТА:
{profile_context}

СТРОЖАЙШИЕ ПРАВИЛА И СТИЛЬ:
1. Обращение: ИСКЛЮЧИТЕЛЬНО на уважительное «Вы» (Ваш, Вам). Категорически ЗАПРЕЩЕНО обращение на «ты».
2. Без пустых приветствий: КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНЫ клише («Приветствую тебя...», «Здравствуй...», «В этот прекрасный день...»). Текст начинается СРАЗУ с индивидуального натального расчета.
3. Практичность и точность: Никаких детских наивных советов («попей чай», «погуляй»). Только взвешенные, профессиональные рекомендации с привязкой к планетарным аспектам и КОНКРЕТНЫМ часовым интервалам дня (например: «в период с 11:00 до 14:30», «после 17:00»).
4. Форматирование:
   - Заголовки рубрик выделять ТОЛЬКО тегом <b>Заголовок</b>.
   - Разделение между смысловыми блоками и рубриками — двойной перенос строки (\\n\\n).
   - КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНЫ символы Markdown (*, **, #, ##, -) и теги <br>, <p>, <h1>.
   - Внутри текста разрешено использовать курсив <i>...</i> и жирный шрифт <b>...</b>.

ЭТАЛОННАЯ СТРУКТУРА ПРОГНОЗА (строго в указанном порядке):
1. Вводный абзац (БЕЗ какого-либо заголовка): расчет натального положения ключевых планет для даты рождения и главный транзит текущего дня ({target_date}).
2. <b>Влияние планет на сегодня</b> 🪐
(Детальный разбор ключевых планетарных аспектов, фоновое астрологическое влияние дня, активные дома).
3. <b>Работа, бизнес и финансы</b> 💼
(Стратегия действий, деловые переговоры, финансовые операции, благоприятные и рискованные часы).
4. <b>Личные отношения и общение</b> ❤️
(Эмоциональный фон, взаимодействие с близкими и партнерами, конструктивный диалог).
5. <b>Здоровье и тонус</b> 🌿
(Физическое состояние, психоэмоциональный баланс, рекомендации по нагрузкам и биоритмам).
6. <b>Добрый совет на сегодня</b> 💡
(Глубокий практичный совет мастера с привязкой к конкретному времени суток).
7. <b>Положительная аффирмация дня</b> ✨
(Емкая, возвышающая, вдохновляющая формулировка для настройки сознания).

Составьте подробный, глубокий, стилистически безупречный текст."""

    return prompt


def generate_horoscope_text(api_key: str, user_profile: dict) -> str:
    """
    Генерирует текст гороскопа с автопоиском моделей и автопереключением (Fallback).
    Делает до 2 попыток на каждую модель при временных сбоях.
    """
    models = discover_models(api_key)
    target_date = datetime.now().strftime("%d.%m.%Y")
    prompt = build_horoscope_prompt(user_profile, target_date)

    headers = {
        "x-goog-api-key": api_key,
        "Content-Type": "application/json"
    }

    payload = {
        "contents": [
            {
                "parts": [{"text": prompt}]
            }
        ],
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 3000
        }
    }

    last_error = ""

    for model in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        
        for attempt in range(1, 3):
            try:
                print(f"🤖 Запрос к модели {model} (попытка {attempt}/2)...")
                response = requests.post(url, headers=headers, json=payload, timeout=45)
                
                if response.status_code == 200:
                    result = response.json()
                    candidates = result.get("candidates", [])
                    if candidates:
                        content = candidates[0].get("content", {})
                        parts = content.get("parts", [])
                        if parts:
                            text = parts[0].get("text", "").strip()
                            # Очищаем от возможных случайных markdown-символов в заголовках
                            cleaned_text = clean_markdown_formatting(text)
                            print(f"✅ Текст успешно сгенерирован моделью {model}!")
                            return cleaned_text
                
                # Если ошибка 429 (лимит) или 5xx (сервер) — делаем паузу
                status = response.status_code
                error_msg = response.text[:200]
                last_error = f"HTTP {status}: {error_msg}"
                print(f"⚠️ Ошибка от {model}: {last_error}")
                
                if status in [429, 500, 503, 504]:
                    time.sleep(2)
                else:
                    # Другие ошибки (например 404 для неподдерживаемой модели) — переходим к следующей модели сразу
                    break

            except Exception as e:
                last_error = str(e)
                print(f"⚠️ Исключение при запросе к {model} (попытка {attempt}): {e}")
                time.sleep(2)

    raise RuntimeError(f"Не удалось сгенерировать гороскоп ни одной из моделей. Последняя ошибка: {last_error}")


def clean_markdown_formatting(text: str) -> str:
    """
    Убирает случайные символы Markdown (#, **, *) и заменяет их на чистый HTML <b>...</b>
    """
    # Заменяем заголовки Markdown ### Заголовок на <b>Заголовок</b>
    text = re.sub(r"^#{1,6}\s*(.+)$", r"<b>\1</b>", text, flags=re.MULTILINE)
    # Заменяем **текст** на <b>текст</b>
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    # Заменяем *текст* на <i>текст</i>
    text = re.sub(r"(?<!\*)\*([^*]+?)\*(?!\*)", r"<i>\1</i>", text)
    # Убираем теги <p>, </p>, <br>, <br/>
    text = re.sub(r"<\/?(p|br\s*\/?)>", "\n", text, flags=re.IGNORECASE)
    # Убираем множественные переносы строк (более 2)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def generate_cosmic_image(api_key: str, horoscope_text: str) -> bytes | None:
    """
    Генерирует космическую картину дня через новейшие модели Google AI Image.
    Поддерживает gemini-3.1-flash-image, gemini-2.5-flash-image и imagen-3.
    Возвращает байты изображения или None в случае сбоя для отката на локальную обложку.
    """
    try:
        # Шаг 1: Формируем емкий англоязычный промпт на основе текста
        english_prompt = extract_image_prompt(api_key, horoscope_text)
        print(f"🎨 Сформирован промпт для космической картины: {english_prompt[:100]}...")

        # Список моделей генерации изображений по приоритету
        image_models = [
            "gemini-3.1-flash-image",
            "gemini-2.5-flash-image",
            "gemini-3-pro-image",
            "imagen-3.0-generate-002"
        ]

        headers = {
            "x-goog-api-key": api_key,
            "Content-Type": "application/json"
        }

        full_prompt = (
            f"Generate a majestic, photorealistic astrological artwork: {english_prompt}. "
            "Mystical celestial space, glowing planets and stars, sacred zodiac constellations, ethereal atmospheric lighting, 8k masterpiece."
        )

        for model in image_models:
            print(f"🌌 Запрос к модели генерации изображений {model}...")
            
            # Для новейших моделей Gemini Image
            if "gemini" in model:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
                payload = {
                    "contents": [{"parts": [{"text": full_prompt}]}]
                }
                try:
                    response = requests.post(url, headers=headers, json=payload, timeout=60)
                    if response.status_code == 200:
                        import base64
                        data = response.json()
                        candidates = data.get("candidates", [])
                        if candidates:
                            parts = candidates[0].get("content", {}).get("parts", [])
                            for part in parts:
                                if "inlineData" in part and "data" in part["inlineData"]:
                                    print(f"✅ Космическая картина успешно сгенерирована моделью {model}!")
                                    return base64.b64decode(part["inlineData"]["data"])
                    print(f"⚠️ Модель {model} вернула статус HTTP {response.status_code}")
                except Exception as err:
                    print(f"⚠️ Ошибка при запросе к {model}: {err}")
            
            # Для Imagen 3 API
            elif "imagen" in model:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:predict"
                payload = {
                    "instances": [{"prompt": full_prompt}],
                    "parameters": {"sampleCount": 1, "aspectRatio": "1:1"}
                }
                try:
                    response = requests.post(url, headers=headers, json=payload, timeout=60)
                    if response.status_code == 200:
                        import base64
                        predictions = response.json().get("predictions", [])
                        if predictions:
                            b64_img = predictions[0].get("bytesBase64Encoded", "")
                            if b64_img:
                                print(f"✅ Космическая картина успешно сгенерирована через {model}!")
                                return base64.b64decode(b64_img)
                except Exception:
                    pass

        print("ℹ️ Онлайн-генераторы недоступны. Переключаемся на резервную обложку.")
        return None

    except Exception as e:
        print(f"ℹ️ Онлайн-генерация картины недоступна ({e}). Будет использована локальная обложка.")
        return None


def extract_image_prompt(api_key: str, horoscope_text: str) -> str:
    """
    Извлекает визуальные космические образы из текста для промпта генерации.
    """
    default_prompt = "Sacred astrological cosmic alignment, glowing golden planets, ethereal nebula, deep starry space, mystical zodiac wheel, cinematic lighting"
    
    try:
        url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        headers = {"x-goog-api-key": api_key, "Content-Type": "application/json"}
        prompt_request = {
            "contents": [{
                "parts": [{"text": (
                    "Based on this astrological forecast, create a single short visual prompt (in English, 1-2 sentences) "
                    "for an AI image generator depicting the cosmic and planetary energy of this day. "
                    "Only output the prompt text, no quotes, no explanations:\n\n" + horoscope_text[:1500]
                )}]
            }],
            "generationConfig": {"temperature": 0.5, "maxOutputTokens": 100}
        }
        res = requests.post(url, headers=headers, json=prompt_request, timeout=15)
        if res.status_code == 200:
            data = res.json()
            candidates = data.get("candidates", [])
            if candidates:
                out = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
                if out:
                    return out
    except Exception:
        pass

    return default_prompt
