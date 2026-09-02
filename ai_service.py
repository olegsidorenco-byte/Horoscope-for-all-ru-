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


def get_astronomical_context(target_date_str: str) -> dict:
    """
    Рассчитывает астрономический контекст для заданной даты:
    - День недели и планетарный управитель дня (Халдейский ряд)
    - Приблизительный лунный день и фаза Луны (алгоритм Conway)
    - Знак зодиака транзитной Луны и Солнца
    """
    try:
        dt = datetime.strptime(target_date_str, "%d.%m.%Y")
    except Exception:
        dt = datetime.now()

    weekdays_data = [
        {"name": "Понедельник", "ruler": "Луна", "ruler_symbol": "🌙", "focus": "Эмоциональная сфера, интуиция, семейные вопросы, внутреннее равновесие"},
        {"name": "Вторник", "ruler": "Марс", "ruler_symbol": "♂️", "focus": "Энергия действий, смелость, преодоление препятствий, спорт, инициатива"},
        {"name": "Среда", "ruler": "Меркурий", "ruler_symbol": "☿️", "focus": "Интеллект, переговоры, коммерция, документы, поездки, коммуникации"},
        {"name": "Четверг", "ruler": "Юпитер", "ruler_symbol": "♃", "focus": "Масштаб, расширение горизонтов, стратегические планы, юриспруденция, авторитет"},
        {"name": "Пятница", "ruler": "Венера", "ruler_symbol": "♀️", "focus": "Гармония, партнерские союзы, финансовые сделки, эстетика, творчество"},
        {"name": "Суббота", "ruler": "Сатурн", "ruler_symbol": "♄", "focus": "Структурирование, дисциплина, подведение итогов, избавление от лишнего"},
        {"name": "Воскресенье", "ruler": "Солнце", "ruler_symbol": "☀️", "focus": "Творческая витальность, лидерство, раскрытие потенциала, вдохновение"}
    ]
    day_info = weekdays_data[dt.weekday()]

    year = dt.year
    month = dt.month
    day = dt.day

    if month < 3:
        year -= 1
        month += 12
    a = year // 100
    b = a // 4
    c = 2 - a + b
    e = int(365.25 * (year + 4716))
    f = int(30.6001 * (month + 1))
    jd = c + day + e + f - 1524.5
    days_since_new_moon = (jd - 2451549.5) % 29.53058867
    lunar_day = int(days_since_new_moon) + 1

    if days_since_new_moon < 1.84:
        lunar_phase = "Новолуние"
    elif days_since_new_moon < 7.38:
        lunar_phase = "Растущая Луна (1-я четверть)"
    elif days_since_new_moon < 14.77:
        lunar_phase = "Растущая Луна (2-я четверть)"
    elif days_since_new_moon < 16.61:
        lunar_phase = "Полнолуние"
    elif days_since_new_moon < 22.15:
        lunar_phase = "Убывающая Луна (3-я четверть)"
    else:
        lunar_phase = "Убывающая Луна (4-я четверть)"

    zodiac_signs = [
        "Овен", "Телец", "Близнецы", "Рак", "Лев", "Дева",
        "Весы", "Скорпион", "Стрелец", "Козерог", "Водолей", "Рыбы"
    ]
    moon_longitude = ((jd - 2451545.0) * 13.176396 + 218.316) % 360
    moon_sign_idx = int(moon_longitude // 30) % 12
    moon_sign = zodiac_signs[moon_sign_idx]

    sun_sign = "Дева"
    if (month == 8 and day >= 23) or (month == 9 and day <= 22):
        sun_sign = "Дева"
    elif (month == 9 and day >= 23) or (month == 10 and day <= 22):
        sun_sign = "Весы"

    return {
        "weekday": day_info["name"],
        "ruler": day_info["ruler"],
        "ruler_symbol": day_info["ruler_symbol"],
        "focus": day_info["focus"],
        "lunar_day": lunar_day,
        "lunar_phase": lunar_phase,
        "moon_sign": moon_sign,
        "sun_sign": sun_sign
    }


def build_horoscope_prompt(user_profile: dict, target_date: str) -> str:
    """
    Формирует структурированный промпт для ИИ с приветствием, обобщенным гороскопом
    и разбивкой по темам на сегодня с реальным астрономическим паспортом дня.
    """
    name = user_profile.get("name", "Уважаемый читатель")
    birth_date = user_profile.get("birth_date", "").strip()
    birth_time = user_profile.get("birth_time", "").strip()
    birth_city = user_profile.get("birth_city", "").strip()
    is_general = user_profile.get("is_general", False) or not birth_date

    astro = get_astronomical_context(target_date)

    if is_general:
        profile_context = (
            f"Текущая календарная дата: {target_date} ({astro['weekday']}).\n"
            f"Планетарный управитель дня: {astro['ruler']} {astro['ruler_symbol']} (фокус дня: {astro['focus']}).\n"
            f"Лунная динамика: {astro['lunar_day']}-й лунный день, фаза: {astro['lunar_phase']}, транзитная Луна в знаке {astro['moon_sign']}.\n"
            f"Положение Солнца: {astro['sun_sign']}.\n"
            "Тип прогноза: Точный классический астрологический прогноз дня по реальным астрономическим транзитам."
        )
    else:
        profile_context = (
            f"Текущая календарная дата: {target_date} ({astro['weekday']}).\n"
            f"Планетарный управитель дня: {astro['ruler']} {astro['ruler_symbol']} (фокус: {astro['focus']}).\n"
            f"Лунная динамика: {astro['lunar_day']}-й лунный день, фаза: {astro['lunar_phase']}, Луна в знаке {astro['moon_sign']}.\n"
            f"Положение Солнца: {astro['sun_sign']}.\n"
            f"Имя пользователя: {name}.\n"
            f"Дата рождения: {birth_date}.\n"
            f"Время рождения: {birth_time if birth_time else '12:00 (условно)'}.\n"
            f"Город/местоположение: {birth_city if birth_city else 'Не указан'}.\n"
            "Рассчитайте точные аспекты транзитных планет к натальной карте пользователя."
        )

    prompt = f"""ВЫ — Магистр классической натально-транзитной астрологии и эфемерист высшей категории.
Ваша цель — составить абсолютно УНИКАЛЬНЫЙ, ТОЧНЫЙ и ЖИВОЙ астрологический прогноз на {target_date}.

АСТРОНОМИЧЕСКИЙ ПАСПОРТ ДНЯ:
{profile_context}

КАТЕГОРИЧЕСКИЕ ТРЕБОВАНИЯ К НЕПОВТОРИМОСТИ И ТОЧНОСТИ:
1. НИКАКИХ ШАБЛОНОВ И ПОВТОРЕНИЙ: Не используйте заученные фразы из прошлых дней. Прогноз должен дышать энергией именно {astro['weekday']}а под управлением {astro['ruler']}а!
2. ВРЕМЕННЫЕ ИНТЕРВАЛЫ: Рассчитайте точные часы для активности и отдыха ИСКЛЮЧИТЕЛЬНО на основе сегодняшних аспектов Луны и управителя дня. КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО использовать одинаковые шаблонные часы каждый день!
3. ОБЪЕМ: строго от 1600 до 2500 символов (строго помещается в 1 сообщение Telegram). Концентрированная суть, экспертная глубина.
4. ОБРАЩЕНИЕ: ИСКЛЮЧИТЕЛЬНО на уважительное «Вы» (Ваш, Вам). Категорически ЗАПРЕЩЕНО «ты».
5. ФОРМАТИРОВАНИЕ:
   - Заголовки рубрик выделять ТОЛЬКО тегом <b>...</b>.
   - КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНЫ символы Markdown (*, **, #, ##, -) и теги <br>, <p>, <h1>.
   - Разделение между смысловыми блоками — двойной перенос строки (\\n\\n).

ЭТАЛОННАЯ СТРУКТУРА ЕДИНОГО СООБЩЕНИЯ:

1. Вводная часть (без заголовка):
Теплое, душевное утреннее приветствие с гармоничными эмодзи (уникальная комбинация) + обобщенный астрономический фон дня ({astro['weekday']}, {astro['lunar_day']}-й лунный день, влияние {astro['ruler']}а) в 2-3 емких предложениях.

2. 🪐 <b>Влияние планет на сегодня</b>
(1–2 емких предложения: ключевой транзит дня, положение Луны в знаке {astro['moon_sign']}, аспект управителя дня).

3. 💼 <b>Работа, бизнес и финансы</b>
(2–3 емких предложения: деловая стратегия, благоприятные часы активности, финансовая осторожность).

4. ❤️ <b>Личные отношения и общение</b>
(1–2 емких предложения: эмоциональный климат, взаимопонимание, нюансы общения).

5. 🌿 <b>Здоровье и тонус</b>
(1–2 емких предложения: самочувствие, биоритмы, распределение физических сил).

6. 💡 <b>Добрый совет на сегодня</b>
(1 точный практический совет с указанием рассчитанных благоприятных часов дня).

7. ✨ <b>Пожелание на сегодня</b>
(1 емкое, возвышающее напутствие на этот день).

Сгенерируйте гармоничный, емкий и астрологически точный текст."""

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
            "maxOutputTokens": 8192
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


def split_into_topic_messages(raw_text: str) -> list[str]:
    """
    Разбивает полный сгенерированный текст прогноза на отдельные сообщения по темам.
    Поддерживает как явный разделитель ===TOPIC===, так и интеллектуальный парсинг по рубрикам.
    """
    text = clean_markdown_formatting(raw_text)
    
    # 1. Проверяем наличие явного разделителя ===TOPIC===
    if "===TOPIC===" in text:
        parts = [p.strip() for p in text.split("===TOPIC===") if p.strip()]
        if len(parts) >= 2:
            return parts

    # 2. Если разделителя нет, парсим по заголовкам рубрик (с ключевыми фразами)
    keyword_pattern = re.compile(
        r"\n+(?=[^\n<]{0,25}<b>\s*(?:Влияние планет|Работа|Личные отношения|Здоровье|Добрый совет|Пожелание|Положительная аффирмация|Общий прогноз))",
        re.IGNORECASE
    )
    splits = [s.strip() for s in keyword_pattern.split(text) if s.strip()]
    if len(splits) >= 2:
        return splits

    # 3. Резервный парсинг по любым тегам <b> в начале блоков
    generic_header_pattern = re.compile(r"\n\n+(?=[^\n<]{0,15}<b>)", re.IGNORECASE)
    splits = [s.strip() for s in generic_header_pattern.split(text) if s.strip()]
    if len(splits) >= 2:
        return splits

    # 4. Резервный вариант: разделение по двойным переносам строк
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    if len(paragraphs) > 1:
        return paragraphs

    # 5. Если ничего не подошло, возвращаем исходный текст одним сообщением
    return [text]


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


def build_zodiac_prompt(target_date: str = None) -> str:
    """
    Формирует структурированный промпт для генерации компактного гороскопа по 12 знакам зодиака
    с учетом реального астрономического фона дня.
    """
    if not target_date:
        target_date = datetime.now().strftime("%d.%m.%Y")
    
    astro = get_astronomical_context(target_date)

    return f"""Ты — Магистр классической астрологии и эфемерист.
Твоя задача — составить точный, живой и абсолютно УНИКАЛЬНЫЙ гороскоп на {target_date} ({astro['weekday']}) ДЛЯ ВСЕХ 12 ЗНАКОВ ЗОДИАКА.

АСТРОНОМИЧЕСКИЙ ФОН ДНЯ:
• День недели: {astro['weekday']} (Планетарный управитель: {astro['ruler']} {astro['ruler_symbol']})
• Лунный цикл: {astro['lunar_day']}-й лунный день, фаза: {astro['lunar_phase']}
• Транзитная Луна: в знаке {astro['moon_sign']}
• Положение Солнца: {astro['sun_sign']}

ТРЕБОВАНИЯ К НЕПОВТОРИМОСТИ И ТОЧНОСТИ:
1. Никаких шаблонных повторов! Рассчитайте уникальные для сегодняшнего дня часы удачи для каждого знака исходя из взаимодействия стихии знака с Луной в знаке {astro['moon_sign']} и влияния {astro['ruler']}а.
2. В самом начале напиши заголовок:
✨ <b>ГОРОСКОП ПО ЗНАКАМ ЗОДИАКА НА {target_date}</b> ✨

3. Оформи каждый знак зодиака строго по порядку в следующем виде:
<b>♈ Овен (21.03–19.04)</b>
• Фокус: [Краткий уникальный акцент дня, 2-4 слова]
• Энергия: [Реалистичный процент, например: 85%] | Часы удачи: [Индивидуально рассчитанные часы дня]
[2 емких предложения с учетом взаимодействия стихии знака с энергией дня и точным практическим советом]

Порядок знаков:
1. ♈ Овен (21.03–19.04)
2. ♉ Телец (20.04–20.05)
3. ♊ Близнецы (21.05–20.06)
4. ♋ Рак (21.06–22.07)
5. ♌ Лев (23.07–22.08)
6. ♍ Дева (23.08–22.09)
7. ♎ Весы (23.09–22.10)
8. ♏ Скорпион (23.10–21.11)
9. ♐ Стрелец (22.11–21.12)
10. ♑ Козерог (22.12–19.01)
11. ♒ Водолей (20.01–18.02)
12. ♓ Рыбы (19.02–20.03)

4. ОБЪЕМ: строго по 150–220 символов на каждый знак. Общий объем текста: 2200–2600 символов (строго уместиться в одно сообщение).
5. Используй только HTML теги <b> и <i>, без Markdown решеток и звездочек."""


def generate_zodiac_horoscope_text(api_key: str, target_date: str = None) -> str:
    """
    Генерирует гороскоп по 12 знакам зодиака через Google Gemini API с автопоиском и отказоустойчивостью.
    """
    if not target_date:
        target_date = datetime.now().strftime("%d.%m.%Y")

    prompt = build_zodiac_prompt(target_date)
    models = discover_models(api_key)
    if not models:
        models = DEFAULT_MODELS_PRIORITY

    headers = {
        "x-goog-api-key": api_key,
        "Content-Type": "application/json"
    }

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 3000,
            "topP": 0.95
        }
    }

    last_error = None
    for model_name in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
        for attempt in range(1, 3):
            try:
                print(f"🤖 [Зодиак] Запрос к модели {model_name} (попытка {attempt}/2)...")
                response = requests.post(url, headers=headers, json=payload, timeout=40)
                if response.status_code == 200:
                    data = response.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                        if text:
                            print(f"✅ [Зодиак] Гороскоп успешно сгенерирован моделью {model_name} ({len(text)} симв.)!")
                            return text.strip()
                elif response.status_code == 429:
                    print(f"⚠️ [Зодиак] Лимит запросов к {model_name}. Ожидание 5 сек...")
                    time.sleep(5)
                else:
                    last_error = f"HTTP {response.status_code}: {response.text[:200]}"
            except Exception as e:
                last_error = str(e)
                time.sleep(2)

    raise RuntimeError(f"Не удалось сгенерировать гороскоп по знакам зодиака: {last_error}")

