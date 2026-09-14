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
import math
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


CITY_COORDS = {
    # Молдова
    'кишинев': (47.0105, 28.8638, 'Europe/Chisinau'),
    'chisinau': (47.0105, 28.8638, 'Europe/Chisinau'),
    'kishinev': (47.0105, 28.8638, 'Europe/Chisinau'),
    'бельцы': (47.7617, 27.9289, 'Europe/Chisinau'),
    'тирасполь': (46.8403, 29.6433, 'Europe/Chisinau'),
    'бендеры': (46.8319, 29.4778, 'Europe/Chisinau'),
    'рыбница': (47.7667, 29.0000, 'Europe/Chisinau'),
    'кагул': (45.9075, 28.1944, 'Europe/Chisinau'),
    'унгены': (47.2056, 27.7978, 'Europe/Chisinau'),
    'орхей': (47.3856, 28.8239, 'Europe/Chisinau'),
    'комрат': (46.2958, 28.6569, 'Europe/Chisinau'),

    # Россия
    'москва': (55.7558, 37.6173, 'Europe/Moscow'),
    'moscow': (55.7558, 37.6173, 'Europe/Moscow'),
    'санкт-петербург': (59.9343, 30.3351, 'Europe/Moscow'),
    'петербург': (59.9343, 30.3351, 'Europe/Moscow'),
    'питер': (59.9343, 30.3351, 'Europe/Moscow'),
    'новосибирск': (55.0084, 82.9357, 'Asia/Novosibirsk'),
    'екатеринбург': (56.8389, 60.6057, 'Asia/Yekaterinburg'),
    'казань': (55.8304, 49.0661, 'Europe/Moscow'),
    'нижний новгород': (56.3269, 44.0059, 'Europe/Moscow'),
    'челябинск': (55.1644, 61.4368, 'Asia/Yekaterinburg'),
    'красноярск': (56.0153, 92.8932, 'Asia/Krasnoyarsk'),
    'самара': (53.1959, 50.1002, 'Europe/Moscow'),
    'уфа': (54.7388, 55.9721, 'Asia/Yekaterinburg'),
    'ростов-на-дону': (47.2357, 39.7015, 'Europe/Moscow'),
    'ростов': (47.2357, 39.7015, 'Europe/Moscow'),
    'омск': (54.9885, 73.3242, 'Asia/Omsk'),
    'краснодар': (45.0355, 38.9753, 'Europe/Moscow'),
    'воронеж': (51.6608, 39.2003, 'Europe/Moscow'),
    'пермь': (58.0105, 56.2502, 'Asia/Yekaterinburg'),
    'волгоград': (48.7080, 44.5133, 'Europe/Moscow'),
    'саратов': (51.5336, 46.0343, 'Europe/Moscow'),
    'тюмень': (57.1530, 65.5343, 'Asia/Yekaterinburg'),
    'тольятти': (53.5303, 49.3461, 'Europe/Moscow'),
    'барнаул': (53.3548, 83.7698, 'Asia/Novosibirsk'),
    'ижевск': (56.8528, 53.2115, 'Europe/Moscow'),
    'махачкала': (42.9849, 47.5047, 'Europe/Moscow'),
    'хабаровск': (48.4814, 135.0721, 'Asia/Vladivostok'),
    'ульяновск': (54.3142, 48.4031, 'Europe/Moscow'),
    'иркутск': (52.2864, 104.3050, 'Asia/Irkutsk'),
    'владивосток': (43.1155, 131.8855, 'Asia/Vladivostok'),
    'ярославль': (57.6261, 39.8845, 'Europe/Moscow'),
    'севастополь': (44.6167, 33.5254, 'Europe/Moscow'),
    'симферополь': (44.9521, 34.1024, 'Europe/Moscow'),
    'ставрополь': (45.0428, 41.9734, 'Europe/Moscow'),
    'томск': (56.4977, 84.9744, 'Asia/Novosibirsk'),
    'кемерово': (55.3547, 86.0872, 'Asia/Novosibirsk'),
    'новокузнецк': (53.7596, 87.1216, 'Asia/Novosibirsk'),
    'рязань': (54.6295, 39.7425, 'Europe/Moscow'),
    'набережные челны': (55.7436, 52.4089, 'Europe/Moscow'),
    'пенза': (53.2007, 45.0046, 'Europe/Moscow'),
    'киров': (58.6035, 49.6679, 'Europe/Moscow'),
    'липецк': (52.6103, 39.5947, 'Europe/Moscow'),
    'чебоксары': (56.1439, 47.2489, 'Europe/Moscow'),
    'калининград': (54.7104, 20.4522, 'Europe/Kaliningrad'),
    'тула': (54.1961, 37.6182, 'Europe/Moscow'),
    'курск': (51.7304, 36.1926, 'Europe/Moscow'),
    'сочи': (43.6028, 39.7342, 'Europe/Moscow'),
    'тверь': (56.8587, 35.9176, 'Europe/Moscow'),
    'магнитогорск': (53.4186, 58.9732, 'Asia/Yekaterinburg'),
    'иваново': (56.9972, 40.9714, 'Europe/Moscow'),
    'брянск': (53.2436, 34.3634, 'Europe/Moscow'),
    'белгород': (50.5954, 36.5873, 'Europe/Moscow'),
    'сургут': (61.2540, 73.3962, 'Asia/Yekaterinburg'),
    'владимир': (56.1290, 40.4066, 'Europe/Moscow'),
    'чита': (52.0340, 113.4994, 'Asia/Irkutsk'),
    'архангельск': (64.5401, 40.5433, 'Europe/Moscow'),
    'калуга': (54.5138, 36.2612, 'Europe/Moscow'),
    'смоленск': (54.7826, 32.0453, 'Europe/Moscow'),
    'курган': (55.4410, 65.3411, 'Asia/Yekaterinburg'),
    'вологда': (59.2205, 39.8915, 'Europe/Moscow'),
    'орел': (52.9651, 36.0785, 'Europe/Moscow'),
    'владикавказ': (43.0367, 44.6678, 'Europe/Moscow'),
    'мурманск': (68.9707, 33.0750, 'Europe/Moscow'),
    'тамбов': (52.7212, 41.4523, 'Europe/Moscow'),
    'петрозаводск': (61.7850, 34.3469, 'Europe/Moscow'),
    'кострома': (57.7679, 40.9269, 'Europe/Moscow'),
    'новороссийск': (44.7239, 37.7689, 'Europe/Moscow'),
    'йошкар-ола': (56.6388, 47.8868, 'Europe/Moscow'),
    'таганрог': (47.2362, 38.8969, 'Europe/Moscow'),
    'нальчик': (43.4853, 43.6071, 'Europe/Moscow'),
    'благовещенск': (50.2796, 127.5405, 'Asia/Irkutsk'),
    'псков': (57.8193, 28.3318, 'Europe/Moscow'),
    'южно-сахалинск': (46.9591, 142.7381, 'Asia/Vladivostok'),
    'петропавловск-камчатский': (53.0370, 158.6559, 'Asia/Kamchatka'),
    'норильск': (69.3535, 88.2027, 'Asia/Krasnoyarsk'),
    'якутск': (62.0355, 129.6755, 'Asia/Irkutsk'),
    'грозный': (43.3179, 45.6982, 'Europe/Moscow'),

    # Украина
    'киев': (50.4501, 30.5234, 'Europe/Kyiv'),
    'kyiv': (50.4501, 30.5234, 'Europe/Kyiv'),
    'kiev': (50.4501, 30.5234, 'Europe/Kyiv'),
    'харьков': (49.9935, 36.2304, 'Europe/Kyiv'),
    'одесса': (46.4825, 30.7233, 'Europe/Kyiv'),
    'днепр': (48.4647, 35.0462, 'Europe/Kyiv'),
    'донецк': (48.0159, 37.8029, 'Europe/Kyiv'),
    'запорожье': (47.8388, 35.1396, 'Europe/Kyiv'),
    'львов': (49.8397, 24.0297, 'Europe/Kyiv'),
    'кривой рог': (47.9105, 33.3918, 'Europe/Kyiv'),
    'николаев': (46.9750, 31.9946, 'Europe/Kyiv'),
    'мариуполь': (47.0958, 37.5494, 'Europe/Kyiv'),
    'луганск': (48.5740, 39.3078, 'Europe/Kyiv'),
    'винница': (49.2331, 28.4682, 'Europe/Kyiv'),
    'херсон': (46.6354, 32.6169, 'Europe/Kyiv'),
    'полтава': (49.5883, 34.5514, 'Europe/Kyiv'),
    'чернигов': (51.4982, 31.2893, 'Europe/Kyiv'),
    'черкассы': (49.4444, 32.0598, 'Europe/Kyiv'),
    'житомир': (50.2547, 28.6587, 'Europe/Kyiv'),
    'сумы': (50.9077, 34.7981, 'Europe/Kyiv'),
    'хмельницкий': (49.4230, 26.9871, 'Europe/Kyiv'),
    'черновцы': (48.2917, 25.9352, 'Europe/Kyiv'),
    'ровно': (50.6199, 26.2516, 'Europe/Kyiv'),
    'ивано-франковск': (48.9226, 24.7111, 'Europe/Kyiv'),
    'тернополь': (49.5535, 25.5948, 'Europe/Kyiv'),
    'луцк': (50.7472, 25.3254, 'Europe/Kyiv'),
    'ужгород': (48.6208, 22.2879, 'Europe/Kyiv'),

    # Беларусь
    'минск': (53.9006, 27.5590, 'Europe/Minsk'),
    'minsk': (53.9006, 27.5590, 'Europe/Minsk'),
    'гомель': (52.4345, 30.9754, 'Europe/Minsk'),
    'могилев': (53.8981, 30.3325, 'Europe/Minsk'),
    'витебск': (55.1904, 30.2049, 'Europe/Minsk'),
    'гродно': (53.6884, 23.8258, 'Europe/Minsk'),
    'брест': (52.0976, 23.7341, 'Europe/Minsk'),
    'бобруйск': (53.1384, 29.2214, 'Europe/Minsk'),
    'барановичи': (53.1327, 26.0139, 'Europe/Minsk'),

    # Казахстан
    'алматы': (43.2389, 76.8897, 'Asia/Almaty'),
    'almaty': (43.2389, 76.8897, 'Asia/Almaty'),
    'астана': (51.1694, 71.4491, 'Asia/Almaty'),
    'astana': (51.1694, 71.4491, 'Asia/Almaty'),
    'нур-султан': (51.1694, 71.4491, 'Asia/Almaty'),
    'шымкент': (42.3417, 69.5901, 'Asia/Almaty'),
    'караганда': (49.8029, 73.1025, 'Asia/Almaty'),
    'актобе': (50.2839, 57.1670, 'Asia/Almaty'),
    'тараз': (42.9000, 71.3667, 'Asia/Almaty'),
    'павлодар': (52.3000, 76.9500, 'Asia/Almaty'),
    'усть-каменогорск': (49.9500, 82.6167, 'Asia/Almaty'),
    'семей': (50.4111, 80.2275, 'Asia/Almaty'),
    'атырау': (47.1167, 51.8833, 'Asia/Almaty'),
    'костанай': (53.2144, 63.6246, 'Asia/Almaty'),
    'кызылорда': (44.8528, 65.5092, 'Asia/Almaty'),
    'уральск': (51.2333, 51.3667, 'Asia/Almaty'),
    'петропавловск': (54.8753, 69.1628, 'Asia/Almaty'),
    'актау': (43.6500, 51.1667, 'Asia/Almaty'),

    # Узбекистан
    'ташкент': (41.2995, 69.2401, 'Asia/Tashkent'),
    'tashkent': (41.2995, 69.2401, 'Asia/Tashkent'),
    'самарканд': (39.6270, 66.9750, 'Asia/Samarkand'),
    'бухара': (39.7747, 64.4286, 'Asia/Samarkand'),
    'андижан': (40.7821, 72.3442, 'Asia/Tashkent'),
    'наманган': (40.9983, 71.6726, 'Asia/Tashkent'),
    'фергана': (40.3842, 71.7843, 'Asia/Tashkent'),

    # Кавказ и Закавказье
    'баку': (40.4093, 49.8671, 'Asia/Baku'),
    'baku': (40.4093, 49.8671, 'Asia/Baku'),
    'ереван': (40.1792, 44.4991, 'Asia/Yerevan'),
    'yerevan': (40.1792, 44.4991, 'Asia/Yerevan'),
    'тбилиси': (41.7151, 44.8271, 'Asia/Tbilisi'),
    'tbilisi': (41.7151, 44.8271, 'Asia/Tbilisi'),
    'батуми': (41.6168, 41.6367, 'Asia/Tbilisi'),
    'кутаиси': (42.2679, 42.6946, 'Asia/Tbilisi'),

    # Центральная Азия
    'бишкек': (42.8746, 74.5698, 'Asia/Bishkek'),
    'bishkek': (42.8746, 74.5698, 'Asia/Bishkek'),
    'ош': (40.5140, 72.8161, 'Asia/Bishkek'),
    'душанбе': (38.5598, 68.7870, 'Asia/Dushanbe'),
    'dushanbe': (38.5598, 68.7870, 'Asia/Dushanbe'),
    'ашхабад': (37.9601, 58.3261, 'Asia/Ashgabat'),

    # Европа и Мир
    'лондон': (51.5074, -0.1278, 'Europe/London'),
    'london': (51.5074, -0.1278, 'Europe/London'),
    'париж': (48.8566, 2.3522, 'Europe/Paris'),
    'paris': (48.8566, 2.3522, 'Europe/Paris'),
    'берлин': (52.5200, 13.4050, 'Europe/Berlin'),
    'berlin': (52.5200, 13.4050, 'Europe/Berlin'),
    'рим': (41.9028, 12.4964, 'Europe/Rome'),
    'rome': (41.9028, 12.4964, 'Europe/Rome'),
    'мадрид': (40.4168, -3.7038, 'Europe/Madrid'),
    'madrid': (40.4168, -3.7038, 'Europe/Madrid'),
    'варшава': (52.2297, 21.0122, 'Europe/Warsaw'),
    'warsaw': (52.2297, 21.0122, 'Europe/Warsaw'),
    'прага': (50.0755, 14.4378, 'Europe/Prague'),
    'prague': (50.0755, 14.4378, 'Europe/Prague'),
    'вена': (48.2082, 16.3738, 'Europe/Vienna'),
    'vienna': (48.2082, 16.3738, 'Europe/Vienna'),
    'будапешт': (47.4979, 19.0402, 'Europe/Budapest'),
    'budapest': (47.4979, 19.0402, 'Europe/Budapest'),
    'бухарест': (44.4268, 26.1025, 'Europe/Bucharest'),
    'bucharest': (44.4268, 26.1025, 'Europe/Bucharest'),
    'софия': (42.6977, 23.3219, 'Europe/Sofia'),
    'белград': (44.7866, 20.4489, 'Europe/Belgrade'),
    'афины': (37.9838, 23.7275, 'Europe/Athens'),
    'вильнюс': (54.6872, 25.2797, 'Europe/Vilnius'),
    'рига': (56.9496, 24.1052, 'Europe/Riga'),
    'таллин': (59.4370, 24.7535, 'Europe/Tallinn'),
    'хельсинки': (60.1699, 24.9384, 'Europe/Helsinki'),
    'стокгольм': (59.3293, 18.0686, 'Europe/Stockholm'),
    'осло': (59.9139, 10.7522, 'Europe/Oslo'),
    'копенгаген': (55.6761, 12.5683, 'Europe/Copenhagen'),
    'амстердам': (52.3676, 4.9041, 'Europe/Amsterdam'),
    'брюссель': (50.8503, 4.3517, 'Europe/Brussels'),
    'стамбул': (41.0082, 28.9784, 'Europe/Istanbul'),
    'istanbul': (41.0082, 28.9784, 'Europe/Istanbul'),
    'тель-авив': (32.0853, 34.7818, 'Asia/Jerusalem'),
    'tel aviv': (32.0853, 34.7818, 'Asia/Jerusalem'),
    'иерусалим': (31.7683, 35.2137, 'Asia/Jerusalem'),
    'дубай': (25.2048, 55.2708, 'Asia/Dubai'),
    'dubai': (25.2048, 55.2708, 'Asia/Dubai'),
    'нью-йорк': (40.7128, -74.0060, 'America/New_York'),
    'new york': (40.7128, -74.0060, 'America/New_York'),
    'лос-анджелес': (34.0522, -118.2437, 'America/Los_Angeles'),
    'чикаго': (41.8781, -87.6298, 'America/Chicago'),
    'торонто': (43.6532, -79.3832, 'America/Toronto'),
    'пекин': (39.9042, 116.4074, 'Asia/Shanghai'),
    'токио': (35.6762, 139.6503, 'Asia/Tokyo'),
}


def resolve_city_coords(city_raw: str) -> tuple:
    """
    Нормализует введенное название города и возвращает (lat, lon, tz_name).
    Очищает от префиксов ('г. ', 'город '), постфиксов ('Москва, Россия', 'London, UK')
    и находит астрономические координаты и часовой пояс.
    """
    if not city_raw:
        return (47.0105, 28.8638, 'Europe/Chisinau')

    cleaned = city_raw.strip().lower()
    if ',' in cleaned:
        cleaned = cleaned.split(',')[0].strip()
    if '(' in cleaned:
        cleaned = cleaned.split('(')[0].strip()
    for prefix in ['г.', 'город', 'гор.', 'с.', 'село', 'пос.', 'пгт']:
        if cleaned.startswith(prefix + ' ') or cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix):].strip()

    if cleaned in CITY_COORDS:
        return CITY_COORDS[cleaned]

    for name, coords in CITY_COORDS.items():
        if name == cleaned or name in cleaned or cleaned in name:
            return coords

    # Fallback по умолчанию (Кишинев)
    return (47.0105, 28.8638, 'Europe/Chisinau')


def calculate_natal_asc_mc(birth_date_str: str, birth_time_str: str, birth_city: str) -> dict:
    """
    Вычисляет точный астрономический Асцендент (Asc) и Середину Неба (MC)
    по формулам сферической тригонометрии с учетом географических координат и исторического часового пояса.
    """
    try:
        parts = [p.strip() for p in re.split(r'[\.\-\/]', birth_date_str.strip()) if p.strip()]
        if len(parts) != 3:
            return None
        if len(parts[0]) == 4:
            year, month, day = int(parts[0]), int(parts[1]), int(parts[2])
        else:
            day, month, year = int(parts[0]), int(parts[1]), int(parts[2])
            if year < 100:
                year += 1900

        t_parts = birth_time_str.strip().split(':')
        hour = int(t_parts[0])
        minute = int(t_parts[1]) if len(t_parts) > 1 else 0

        lat, lon, tz_name = resolve_city_coords(birth_city)

        try:
            import zoneinfo
            tz = zoneinfo.ZoneInfo(tz_name)
            dt = datetime(year, month, day, hour, minute, tzinfo=tz)
            tz_offset = dt.utcoffset().total_seconds() / 3600.0
        except Exception:
            tz_offset = 3.0 if year < 1990 else 2.0

        utc_hour = hour + minute / 60.0 - tz_offset
        day_calc = day
        if utc_hour < 0:
            utc_hour += 24.0
            day_calc -= 1
        elif utc_hour >= 24.0:
            utc_hour -= 24.0
            day_calc += 1

        y, m = year, month
        a = math.floor(y / 100)
        b = 2 - a + math.floor(a / 4)
        jd0 = math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + day_calc + b - 1524.5
        jd = jd0 + utc_hour / 24.0

        t = (jd - 2451545.0) / 36525.0
        gmst = (280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t**2 - (t**3) / 38710000.0) % 360.0
        lst = (gmst + lon) % 360.0
        eps = 23.441884 - 0.0130125 * t
        eps_rad = math.radians(eps)
        ramc_rad = math.radians(lst)
        lat_rad = math.radians(lat)

        # Середина Неба (MC)
        mc_rad = math.atan2(math.sin(ramc_rad), math.cos(ramc_rad) * math.cos(eps_rad))
        mc_deg = (math.degrees(mc_rad) + 360.0) % 360.0

        # Асцендент (Asc)
        y_asc = math.cos(ramc_rad)
        x_asc = - math.sin(ramc_rad) * math.cos(eps_rad) - math.tan(lat_rad) * math.sin(eps_rad)
        asc_deg = (math.degrees(math.atan2(y_asc, x_asc)) + 360.0) % 360.0

        zodiac_gen = ['Овна', 'Тельца', 'Близнецов', 'Рака', 'Льва', 'Девы', 'Весов', 'Скорпиона', 'Стрельца', 'Козерога', 'Водолея', 'Рыб']
        zodiac_nom = ['Овен', 'Телец', 'Близнецы', 'Рак', 'Лев', 'Дева', 'Весы', 'Скорпион', 'Стрелец', 'Козерог', 'Водолей', 'Рыбы']

        asc_idx = int(asc_deg // 30) % 12
        asc_in_sign = asc_deg % 30
        mc_idx = int(mc_deg // 30) % 12
        mc_in_sign = mc_deg % 30

        return {
            'asc_deg_total': asc_deg,
            'asc_sign': zodiac_nom[asc_idx],
            'asc_sign_gen': zodiac_gen[asc_idx],
            'asc_degree': f"{int(asc_in_sign)}°{int(round((asc_in_sign % 1) * 60)):02d}'",
            'mc_deg_total': mc_deg,
            'mc_sign': zodiac_nom[mc_idx],
            'mc_sign_gen': zodiac_gen[mc_idx],
            'mc_degree': f"{int(mc_in_sign)}°{int(round((mc_in_sign % 1) * 60)):02d}'",
        }
    except Exception:
        return None


def build_horoscope_prompt(user_profile: dict, target_date: str = None) -> str:
    """
    Формирует структурированный промпт высшей натальной категории (стаж 60 лет)
    с расчетом Асцендента, 12 домов натала, разделением города рождения и проживания,
    учетом пола пользователя, фокуса внимания и точных временных интервалов.
    """
    name = user_profile.get("name", "").strip() or "Уважаемый читатель"
    birth_date = user_profile.get("birth_date", "").strip()
    birth_time = user_profile.get("birth_time", "").strip()
    birth_city = user_profile.get("birth_city", "").strip() or user_profile.get("birth_place", "").strip()
    current_city = user_profile.get("current_city", "").strip() or user_profile.get("city", "").strip()
    if not current_city and birth_city:
        current_city = birth_city
    elif not birth_city and current_city:
        birth_city = current_city

    gender = user_profile.get("gender", "").strip().lower()
    if gender in ["male", "мужской", "м"]:
        gender_display = "Мужской"
        gender_instruction = "Обращайся к пользователю как к мужчине (используй грамматические формы мужского рода в прошедшем времени: 'Вы почувствовали', 'был готов', 'настроен' без скобок '(а)')."
    elif gender in ["female", "женский", "ж"]:
        gender_display = "Женский"
        gender_instruction = "Обращайся к пользователю как к женщине (используй грамматические формы женского рода в прошедшем времени: 'Вы почувствовали', 'была готова', 'настроена' без скобок '(а)')."
    else:
        gender_display = "Не указан"
        gender_instruction = "Используй уважительные, гармоничные грамматические конструкции на 'Вы'."

    focus = user_profile.get("focus", "").strip() or "бизнес, деловые переговоры, финансы и здоровье"
    is_general = user_profile.get("is_general", False) or not birth_date

    astro = get_astronomical_context(target_date)

    natal = None
    if not is_general and birth_date and birth_time:
        natal = calculate_natal_asc_mc(birth_date, birth_time, birth_city)

    if not is_general:
        if natal:
            natal_calc_text = (
                f"• ТОЧНЫЙ АСТРОНОМИЧЕСКИЙ АСЦЕНДЕНТ: {natal['asc_sign']} ({natal['asc_degree']} {natal['asc_sign_gen']})\n"
                f"• ТОЧНАЯ СЕРЕДИНА НЕБА (МС, 10 ДОМ КАРЬЕРЫ): {natal['mc_sign']} ({natal['mc_degree']} {natal['mc_sign_gen']})\n"
                f"• СТРОЖАЙШИЙ ЗАПРЕТ НА ГАЛЛЮЦИНАЦИИ: Восходящий знак натальной карты {name} — СТРОГО {natal['asc_sign'].upper()} ({natal['asc_degree']})! Середина Неба — в {natal['mc_sign_gen']}. КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО называть любой другой знак (никаких Рыб, Овна, Тельца и т.д.)! Расчет зафиксирован астрономически.\n"
            )
            asc_str = f"{natal['asc_sign']} ({natal['asc_degree']} {natal['asc_sign_gen']})"
            mc_str = f"{natal['mc_sign']} ({natal['mc_degree']} {natal['mc_sign_gen']})"
        else:
            natal_calc_text = ""
            asc_str = "восходящий знак по времени рождения"
            mc_str = "Середина Неба (МС)"

        natal_precision_rules = (
            f"КРИТИЧЕСКИ ВАЖНО (ВЫСШАЯ НАТАЛЬНАЯ ТОЧНОСТЬ):\n"
            f"• Имя: {name}\n"
            f"• Точная дата рождения: {birth_date}\n"
            f"• Точное время рождения: {birth_time if birth_time else 'не указано (расчет на полдень)'}\n"
            f"• Город рождения (координаты натальной карты): {birth_city if birth_city else 'Кишинев'}\n"
            f"{natal_calc_text}"
            f"• Текущее местонахождение (локальные транзиты): {current_city if current_city else 'Кишинев'}\n"
            f"• Пол: {gender_display} ({gender_instruction})\n"
            f"• Приоритетные сферы внимания пользователя: '{focus}'\n\n"
            "СТРОГИЕ АСТРОЛОГИЧЕСКИЕ ПРАВИЛА РАСЧЕТА:\n"
            f"1. Восходящий знак Асцендента — строго {asc_str}! Учитывай Середину Неба (МС) — {mc_str}.\n"
            "2. Рассчитай проекцию текущих транзитных планет в дома натала пользователя: 1 дом (личность и тонус), 2 дом (личные финансы и доходы), 6 дом (здоровье и работа), 7 дом (партнерство, брак и переговоры), 8 дом (чужие ресурсы, аудит, инвестиции), 10 дом (профессиональные цели).\n"
            f"3. В САМОМ НАЧАЛЕ сообщения сразу после приветствия ОБЯЗАТЕЛЬНО включи персональный натальный расчет: назови восходящий знак ({asc_str}) и активированный сегодня транзитный дом/аспект для натальной карты {name} ({birth_date}" + (f", {birth_time}" if birth_time else "") + "). Пользователь должен сразу видеть неизменную астрономическую точность!\n"
            f"4. С учетом фокуса '{focus}' сделай прицельный практический акцент в рубрике 'Работа, бизнес и финансы' (стратегия, переговоры, сделки) и 'Здоровье и тонус'.\n"
        )
    else:
        natal_precision_rules = (
            "Тип прогноза: Точный классический астрологический прогноз дня по реальным астрономическим транзитам.\n"
        )

    prompt = f"""Ты — выдающийся профессиональный астролог высшей категории с 60-летним стажем.
Ты в совершенстве владеешь классической натальной, хорарной и транзитной астрологией. Твои прогнозы сочетают высочайшую экспертную глубину с кристальной практической пользой для реальной жизни.

АСТРОНОМИЧЕСКИЙ ПАСПОРТ ДНЯ НА {target_date}:
• День недели: {astro['weekday']} (Планетарный управитель: {astro['ruler']} {astro['ruler_symbol']}, фокус: {astro['focus']})
• Лунная динамика: {astro['lunar_day']}-й лунный день, фаза: {astro['lunar_phase']}
• Положение Луны: транзитная Луна в знаке {astro['moon_sign']}
• Положение Солнца: {astro['sun_sign']}

{natal_precision_rules}
СТРОГИЕ ТРЕБОВАНИЯ К ОБЪЕМУ И СТИЛЮ:
1. ОБЪЕМ: строго от 2000 до 3200 символов (строго помещается в ОДНО сообщение Telegram). Никакой 'воды', каждая мысль должна быть емкой, экспертной и полезной.
2. ОБРАЩЕНИЕ: строго уважительное на 'Вы' (Ваш, Вам, Вы).
3. ТОЧНЫЕ ВРЕМЕННЫЕ ОКНА: В рубрике 'Работа, бизнес и финансы' ОБЯЗАТЕЛЬНО укажи точные интервалы часов дня для переговоров, звонков и сделок (например: 'с 11:20 до 13:45'), рассчитанные на основе аспектов Луны и управителя дня {astro['ruler']}а!
4. КОМПЕНСАТОРНАЯ АСТРОЛОГИЯ В РУБРИКЕ 'ДОБРЫЙ СОВЕТ НА СЕГОДНЯ':
   - Если в аспектах есть напряжение (квадратуры, оппозиции, пораженная Луна, спад сил, конфликтные планеты) — ОБЯЗАТЕЛЬНО дай четкую, полезную рекомендацию по НЕЙТРАЛИЗАЦИИ негатива (осознанное заземление, перенос споров, вода, спорт, ревизия бумаг).
   - Если день гармоничный — подскажи, как созидательно приумножить удачу.
5. РУБРИКА 'ПОЖЕЛАНИЕ НА СЕГОДНЯ':
   - Искренне теплое, поэтично-образное и жизнеутверждающее напутствие без банальностей, вселяющее душевный покой и веру в свои силы.
6. ФОРМАТИРОВАНИЕ:
   - Заголовки рубрик (со 2 по 7) выделять ТОЛЬКО тегом <b>...</b> с эмодзи.
   - Разделение блоков строго двумя переносами строки (\\n\\n).
   - КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНЫ Markdown-символы (*, **, #, ##, -) и теги <p>, <br>, <h1>.

ОБЯЗАТЕЛЬНАЯ СТРУКТУРА СООБЩЕНИЯ:

1. Вводная часть (БЕЗ тега заголовка):
Теплое утреннее приветствие в обрамлении гармоничных эмодзи (каждый день разные: ☀️🌸🌿, 🌅✨🍃, ☕🌤️🍀, 🌸🌿🕊️, 💫🌻🌱 и др.) с обращением по имени {name}. СРАЗУ после приветствия — 2-3 плотных предложения: персональный натальный расчет (Асцендент/активированный дом натала для {name}) и обобщенный астрономический фон дня ({astro['weekday']}, {astro['lunar_day']}-й лунный день, влияние {astro['ruler']}а).

2. 🪐 <b>Влияние планет на сегодня</b>
(2-3 емких предложения: влияние транзитов к наталу, Асцендент/дома, Луна в знаке {astro['moon_sign']}, аспект управителя дня).

3. 💼 <b>Работа, бизнес и финансы</b>
(2-3 конкретных предложения с учетом приоритета '{focus}': стратегия, переговоры, сделки, СТРОГО конкретные благоприятные часы активности).

4. ❤️ <b>Личные отношения и общение</b>
(2-3 предложения: семейная гармония, деловые и личные контакты, эмоциональный фон).

5. 🌿 <b>Здоровье и тонус</b>
(2 предложения: энергоресурс, самочувствие, поддержание сил, совет по вечерней разгрузке).

6. 💡 <b>Добрый совет на сегодня</b>
(1-2 мудрых фокуса внимания от опытного астролога; при наличии напряжения планет — четкий совет по компенсации и нейтрализации негатива).

7. ✨ <b>Пожелание на сегодня</b>
(1-2 душевных, возвышающих предложения на день).

Сгенерируй безупречный, глубокий и персонализированный прогноз."""

    return prompt


def generate_horoscope_text(api_key: str, user_profile: dict) -> str:
    """
    Генерирует текст гороскопа с автопоиском моделей и автопереключением (Fallback).
    Делает до 2 попыток на каждую модель при временных сбоях.
    Оптимизирован по токенам (maxOutputTokens: 8192, thinkingBudget: 0).
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
            "maxOutputTokens": 8192,
            "topP": 0.95,
            "thinkingConfig": {
                "thinkingBudget": 0
            }
        }
    }

    last_error = ""

    for model in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        
        for attempt in range(1, 3):
            try:
                print(f"🤖 Запрос к модели {model} (попытка {attempt}/2)...")
                response = requests.post(url, headers=headers, json=payload, timeout=50)
                
                # Если модель не поддерживает thinkingConfig (HTTP 400), повторяем без нее
                if response.status_code == 400 and "thinkingConfig" in response.text:
                    import copy
                    fallback_payload = copy.deepcopy(payload)
                    fallback_payload["generationConfig"].pop("thinkingConfig", None)
                    response = requests.post(url, headers=headers, json=fallback_payload, timeout=50)

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
                            print(f"✅ Текст успешно сгенерирован моделью {model} ({len(cleaned_text)} симв.)!")
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
        url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        headers = {"x-goog-api-key": api_key, "Content-Type": "application/json"}
        prompt_request = {
            "contents": [{
                "parts": [{"text": (
                    "Based on this astrological forecast, create a single short visual prompt (in English, 1-2 sentences) "
                    "for an AI image generator depicting the cosmic and planetary energy of this day. "
                    "Only output the prompt text, no quotes, no explanations:\n\n" + horoscope_text[:1500]
                )}]
            }],
            "generationConfig": {
                "temperature": 0.5,
                "maxOutputTokens": 1000,
                "thinkingConfig": {"thinkingBudget": 0}
            }
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
1. Никаких шаблонных повторов! Рассчитайте уникальные для сегодняшнего дня часы удачи для каждого знака исходя из взаимодействия стихии знака с Луной в знаке {astro['moon_sign']} и влияния {astro['ruler']}а. Если планетарные аспекты для определенного знака напряженные (квадратуры, оппозиции, спад сил, риск споров) — обязательно включите в совет четкую полезную рекомендацию по компенсации и нейтрализации негатива. Общий тон прогноза должен быть позитивным, вдохновляющим и конструктивным!
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

4. ОБЪЕМ: строго по 150–220 символов на каждый знак. Общий объем текста: 2500–3200 символов (строго уместиться в одно сообщение Telegram).
5. ВАЖНО: Текст ОБЯЗАТЕЛЬНО должен содержать ВСЕ 12 знаков зодиака (от ♈ Овен до ♓ Рыбы) без сокращений и обрывов!
6. Используй только HTML теги <b> и <i>, без Markdown решеток и звездочек."""


REQUIRED_ZODIAC_SIGNS = [
    "Овен", "Телец", "Близнецы", "Рак", "Лев", "Дева",
    "Весы", "Скорпион", "Стрелец", "Козерог", "Водолей", "Рыбы"
]


def generate_zodiac_horoscope_text(api_key: str, target_date: str = None) -> str:
    """
    Генерирует гороскоп по 12 знакам зодиака через Google Gemini API с автопоиском и отказоустойчивостью.
    Гарантирует генерацию ВСЕХ 12 знаков без обрыва по лимиту токенов (MAX_TOKENS).
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
            "maxOutputTokens": 8192,
            "topP": 0.95,
            "thinkingConfig": {
                "thinkingBudget": 0
            }
        }
    }

    last_error = None
    for model_name in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
        for attempt in range(1, 3):
            try:
                print(f"🤖 [Зодиак] Запрос к модели {model_name} (попытка {attempt}/2)...")
                response = requests.post(url, headers=headers, json=payload, timeout=50)
                
                # Если модель не поддерживает thinkingConfig (HTTP 400), пробуем без него
                if response.status_code == 400 and "thinkingConfig" in response.text:
                    import copy
                    fallback_payload = copy.deepcopy(payload)
                    fallback_payload["generationConfig"].pop("thinkingConfig", None)
                    response = requests.post(url, headers=headers, json=fallback_payload, timeout=50)

                if response.status_code == 200:
                    data = response.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        candidate = candidates[0]
                        finish_reason = candidate.get("finishReason", "")
                        text = candidate.get("content", {}).get("parts", [{}])[0].get("text", "")

                        # Проверяем на обрыв генерации по лимиту токенов
                        if finish_reason == "MAX_TOKENS":
                            print(f"⚠️ [Зодиак] Модель {model_name} прервала ответ по MAX_TOKENS. Длина: {len(text)}.")
                            last_error = f"Превышен лимит токенов (MAX_TOKENS) на модели {model_name}"
                            continue

                        # Проверяем наличие всех 12 знаков
                        missing_signs = [s for s in REQUIRED_ZODIAC_SIGNS if s not in text]
                        if missing_signs:
                            print(f"⚠️ [Зодиак] Модель {model_name} вернула неполный гороскоп (нет знаков: {missing_signs}).")
                            last_error = f"Неполный гороскоп: отсутствуют знаки {missing_signs}"
                            continue

                        if text:
                            print(f"✅ [Зодиак] Гороскоп успешно сгенерирован моделью {model_name} ({len(text)} симв., все 12 знаков на месте)!")
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

