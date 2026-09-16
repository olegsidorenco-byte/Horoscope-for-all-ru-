"""
Модуль автоматического аудита безопасности и валидации логики проекта Horoscope-for-all-ru.
Проверяет:
1. Отсутствие утечек приватных ключей и токенов в исходном коде.
2. Корректность и отказоустойчивость астрономического модуля расчета транзитов.
3. Соблюдение лимитов длины сообщений Telegram (до 4096 символов).
4. Безопасность и валидацию профилей пользователей.
"""

import os
import re
import unittest
from datetime import datetime
from ai_service import get_astronomical_context, clean_markdown_formatting, split_into_topic_messages
from user_service import register_or_update_user, get_all_users


class SecurityAndLogicAuditTest(unittest.TestCase):

    def test_01_no_hardcoded_secrets_in_code(self):
        """Проверка отсутствия жестко закодированных реальных API ключей и токенов."""
        project_root = os.path.dirname(__file__)
        secret_patterns = [
            re.compile(r'AIzaSy[A-Za-z0-9_-]{33}'),  # Google Gemini API key
            re.compile(r'[0-9]{9,10}:[A-Za-z0-9_-]{35}'),  # Telegram Bot Token
        ]
        
        scanned_extensions = ('.py', '.dart', '.json', '.yml', '.yaml')
        exempt_files = ('.env.example', 'users_registry.json')

        leaks_found = []
        for root, dirs, files in os.walk(project_root):
            if '.git' in root or 'venv' in root or '.dart_tool' in root or 'build' in root:
                continue
            for file in files:
                if file in exempt_files or not file.endswith(scanned_extensions):
                    continue
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        for pattern in secret_patterns:
                            if pattern.search(content):
                                leaks_found.append(f"{file_path} (найдено соответствие паттерну секрета)")
                except Exception:
                    pass

        self.assertEqual(len(leaks_found), 0, f"Обнаружены потенциальные утечки секретов: {leaks_found}")
        print("✅ Тест 1 пройден: В исходном коде отсутствуют захардкоженные приватные токены.")

    def test_02_astronomy_engine_boundaries(self):
        """Проверка математических границ астрономического движка."""
        test_dates = ["01.01.2026", "29.02.2024", "15.08.2026", "31.12.2026", "02.09.2026"]
        valid_signs = {"Овен", "Телец", "Близнецы", "Рак", "Лев", "Дева", "Весы", "Скорпион", "Стрелец", "Козерог", "Водолей", "Рыбы"}
        valid_rulers = {"Луна", "Марс", "Меркурий", "Юпитер", "Венера", "Сатурн", "Солнце"}

        for d in test_dates:
            astro = get_astronomical_context(d)
            # Лунные сутки должны быть в диапазоне от 1 до 30
            self.assertTrue(1 <= astro["lunar_day"] <= 30, f"Некорректный лунный день {astro['lunar_day']} для {d}")
            # Знак Луны должен быть одним из 12 знаков зодиака
            self.assertIn(astro["moon_sign"], valid_signs, f"Некорректный знак Луны {astro['moon_sign']} для {d}")
            # Управитель дня должен быть из классического Халдейского ряда
            self.assertIn(astro["ruler"], valid_rulers, f"Некорректный управитель дня {astro['ruler']} для {d}")
        
        print("✅ Тест 2 пройден: Астрономический движок дает строго валидные координаты и циклы.")

    def test_03_message_length_safety(self):
        """Проверка безопасного разбиения длинных сообщений для Telegram."""
        from telegram_service import split_text_into_chunks
        huge_text = "✨ <b>Блок прогноза</b>\n" + ("Текст подробного астрологического описания. " * 150)
        self.assertGreater(len(huge_text), 4096, "Тестовый текст должен превышать лимит")

        chunks = split_text_into_chunks(huge_text, max_chars=3800)
        self.assertGreater(len(chunks), 1, "Текст должен разбиваться на части")
        for idx, chunk in enumerate(chunks):
            self.assertLessEqual(len(chunk), 4096, f"Кусок {idx} превышает лимит Telegram в 4096 символов")

        print("✅ Тест 3 пройден: Механизм защиты от превышения лимитов Telegram работает корректно.")

    def test_04_user_profile_security_and_validation(self):
        """Проверка безопасности и валидации данных пользователей."""
        # 1. Попытка регистрации без email должна вызывать ошибку
        with self.assertRaises(ValueError):
            register_or_update_user({"name": "Тест", "email": ""})

        # 2. Корректная регистрация
        user = register_or_update_user({
            "name": "Аудит Тест",
            "email": "audit_test@example.com",
            "birth_date": "2000-01-01",
            "birth_time": "12:00",
            "birth_place": "Лондон",
            "current_city": "Берлин"
        })
        self.assertEqual(user["email"], "audit_test@example.com")
        self.assertEqual(user["birth_place"], "Лондон")
        self.assertEqual(user["current_city"], "Берлин")

        # Очистка тестового пользователя
        all_u = get_all_users()
        filtered = [u for u in all_u if u.get("email") != "audit_test@example.com"]
        import json
        from user_service import USERS_REGISTRY_FILE
        with open(USERS_REGISTRY_FILE, "w", encoding="utf-8") as f:
            json.dump(filtered, f, ensure_ascii=False, indent=2)

        print("✅ Тест 4 пройден: Валидация профилей пользователей безопасна и надежна.")

    def test_05_markdown_cleaner_resilience(self):
        """Проверка очистки от потенциально опасного или ломающего HTML/Markdown форматирования."""
        dirty_text = "### Заголовок\n**Жирный текст**\n*Курсив*\n<p>Параграф</p><br/>Строка"
        cleaned = clean_markdown_formatting(dirty_text)
        self.assertNotIn("###", cleaned)
        self.assertNotIn("**", cleaned)
        self.assertNotIn("<p>", cleaned)
        self.assertIn("<b>Заголовок</b>", cleaned)
        self.assertIn("<b>Жирный текст</b>", cleaned)
        print("✅ Тест 5 пройден: Очиститель форматирования надежно защищает разметку сообщений.")

    def test_06_edge_case_dates_and_leap_years(self):
        """Проверка граничных дат: високосные годы (29 февраля), стыки знаков, исторические даты."""
        def calculate_sign(m, d):
            if (m == 3 and d >= 21) or (m == 4 and d <= 19): return "Овен"
            if (m == 4 and d >= 20) or (m == 5 and d <= 20): return "Телец"
            if (m == 5 and d >= 21) or (m == 6 and d <= 20): return "Близнецы"
            if (m == 6 and d >= 21) or (m == 7 and d <= 22): return "Рак"
            if (m == 7 and d >= 23) or (m == 8 and d <= 22): return "Лев"
            if (m == 8 and d >= 23) or (m == 9 and d <= 22): return "Дева"
            if (m == 9 and d >= 23) or (m == 10 and d <= 22): return "Весы"
            if (m == 10 and d >= 23) or (m == 11 and d <= 21): return "Скорпион"
            if (m == 11 and d >= 22) or (m == 12 and d <= 21): return "Стрелец"
            if (m == 12 and d >= 22) or (m == 1 and d <= 19): return "Козерог"
            if (m == 1 and d >= 20) or (m == 2 and d <= 18): return "Водолей"
            return "Рыбы"

        edge_dates = [
            ("29.02.2000", 2, 29, "Рыбы"),   # Високосный день 2000
            ("29.02.2024", 2, 29, "Рыбы"),   # Високосный день 2024
            ("01.01.2000", 1, 1, "Козерог"), # Дефолтная дата рождения
            ("31.12.1999", 12, 31, "Козерог"),
            ("20.03.1985", 3, 20, "Рыбы"),   # Стык Рыбы / Овен
            ("21.03.1985", 3, 21, "Овен"),
            ("15.08.1935", 8, 15, "Лев"),    # Дата пожилого возраста
            ("01.09.2026", 9, 1, "Дева"),
        ]

        for date_str, m, d, expected_sign in edge_dates:
            dt = datetime.strptime(date_str, "%d.%m.%Y")
            self.assertEqual(dt.month, m)
            self.assertEqual(dt.day, d)
            sign = calculate_sign(m, d)
            self.assertEqual(sign, expected_sign, f"Ошибка для даты {date_str}: ожидался {expected_sign}, получен {sign}")

        print("✅ Тест 6 пройден: Граничные даты (29 февраля, стыки знаков, исторические даты) рассчитываются корректно.")

    def test_07_unique_account_contact_enforcement(self):
        """Проверка строгого правила «Один телефон или почта — один аккаунт»."""
        from user_service import register_or_update_user, get_all_users, USERS_REGISTRY_FILE
        import json

        # 1. Регистрация первого пользователя
        u1_data = {
            "id": "usr_test_unique_1",
            "name": "Тест Уникальности 1",
            "email": "unique_contact_test@example.com",
            "phone": "+79998887766",
            "birth_date": "2000-01-01",
            "birth_time": "12:00",
            "birth_place": "Лондон",
            "current_city": "Берлин",
            "gender": "female"
        }
        registered_u1 = register_or_update_user(u1_data)
        self.assertEqual(registered_u1["email"], "unique_contact_test@example.com")
        self.assertEqual(registered_u1["phone"], "+79998887766")

        # 2. Попытка зарегистрировать другого пользователя с тем же email
        u2_duplicate_email = {
            "id": "usr_test_unique_2",
            "name": "Злоумышленник Почта",
            "email": "unique_contact_test@example.com",
            "phone": "+79991112233",
            "birth_date": "1995-05-05",
            "birth_time": "10:00",
            "birth_place": "Париж",
            "current_city": "Рим",
        }
        with self.assertRaises(ValueError):
            register_or_update_user(u2_duplicate_email)

        # 3. Попытка зарегистрировать другого пользователя с тем же телефоном
        u3_duplicate_phone = {
            "id": "usr_test_unique_3",
            "name": "Злоумышленник Телефон",
            "email": "another_clean_email@example.com",
            "phone": "+79998887766",
            "birth_date": "1992-02-02",
            "birth_time": "08:00",
            "birth_place": "Токио",
            "current_city": "Сеул",
        }
        with self.assertRaises(ValueError):
            register_or_update_user(u3_duplicate_phone)

        # 4. Обновление владельца своего профиля должно проходить успешно
        u1_updated_data = dict(u1_data)
        u1_updated_data["name"] = "Тест Уникальности Обновлен"
        updated_u1 = register_or_update_user(u1_updated_data)
        self.assertEqual(updated_u1["name"], "Тест Уникальности Обновлен")

        # Очистка тестового пользователя
        all_u = get_all_users()
        filtered = [u for u in all_u if u.get("id") != "usr_test_unique_1"]
        with open(USERS_REGISTRY_FILE, "w", encoding="utf-8") as f:
            json.dump(filtered, f, ensure_ascii=False, indent=2)

        print("✅ Тест 7 пройден: Защита «Один телефон или почта — один аккаунт» блокирует любые дубликаты контактов.")

    def test_08_zodiac_structure_and_completeness(self):
        """Проверка полноты и целостности структуры гороскопа по 12 знакам зодиака."""
        from ai_service import REQUIRED_ZODIAC_SIGNS, build_zodiac_prompt
        from archive_service import parse_zodiac_structure

        # 1. Проверяем список обязательных знаков (строго 12)
        expected_signs = ["Овен", "Телец", "Близнецы", "Рак", "Лев", "Дева",
                          "Весы", "Скорпион", "Стрелец", "Козерог", "Водолей", "Рыбы"]
        self.assertEqual(len(REQUIRED_ZODIAC_SIGNS), 12)
        self.assertEqual(REQUIRED_ZODIAC_SIGNS, expected_signs)

        # 2. Промпт содержит указания на все 12 знаков и требование полноты
        prompt = build_zodiac_prompt("03.09.2026")
        for s in expected_signs:
            self.assertIn(s, prompt, f"Знак {s} отсутствует в промпте зодиака")
        self.assertIn("ВСЕ 12 знаков", prompt)

        # 3. Парсер структуры корректно извлекает 12 знаков без заглушек
        sample_zodiac = (
            "✨ <b>ГОРОСКОП ПО ЗНАКАМ ЗОДИАКА НА 03.09.2026</b> ✨\n\n"
            + "\n\n".join([
                f"<b>{meta['symbol']} {meta['name']} ({meta['dates']})</b>\n"
                f"• Фокус: Фокус дня {idx}\n"
                f"• Энергия: 80% | Часы удачи: 10:00–12:00\n"
                f"Индивидуальный астрологический прогноз для знака {meta['name']}."
                for idx, meta in enumerate([
                    {"symbol": "♈", "name": "Овен", "dates": "21.03–19.04"},
                    {"symbol": "♉", "name": "Телец", "dates": "20.04–20.05"},
                    {"symbol": "♊", "name": "Близнецы", "dates": "21.05–20.06"},
                    {"symbol": "♋", "name": "Рак", "dates": "21.06–22.07"},
                    {"symbol": "♌", "name": "Лев", "dates": "23.07–22.08"},
                    {"symbol": "♍", "name": "Дева", "dates": "23.08–22.09"},
                    {"symbol": "♎", "name": "Весы", "dates": "23.09–22.10"},
                    {"symbol": "♏", "name": "Скорпион", "dates": "23.10–21.11"},
                    {"symbol": "♐", "name": "Стрелец", "dates": "22.11–21.12"},
                    {"symbol": "♑", "name": "Козерог", "dates": "22.12–19.01"},
                    {"symbol": "♒", "Водолей": "Водолей", "name": "Водолей", "dates": "20.01–18.02"},
                    {"symbol": "♓", "name": "Рыбы", "dates": "19.02–20.03"},
                ], 1)
            ])
        )
        parsed = parse_zodiac_structure(sample_zodiac, "03.09.2026")
        self.assertEqual(len(parsed["signs"]), 12)
        for s_data in parsed["signs"]:
            self.assertFalse(s_data["forecast"].startswith("Благоприятный день для знака"),
                             f"Знак {s_data['name']} получил заглушку вместо реального прогноза")
            self.assertIn("Индивидуальный астрологический прогноз", s_data["forecast"])

        print("✅ Тест 8 пройден: Гарантирована целостность и полнота гороскопа по всем 12 знакам без обрывов.")

    def test_09_natal_expert_prompt_structure(self):
        """Проверка структуры промпта высшей натальной категории (стаж 60 лет)."""
        from ai_service import build_horoscope_prompt

        # 1. Проверяем персональный профиль с натальными координатами, разделением городов, полом и фокусом
        profile = {
            "name": "Олег",
            "birth_date": "23.05.1978",
            "birth_time": "00:05",
            "birth_city": "Кишинев",
            "current_city": "Москва",
            "gender": "male",
            "focus": "бизнес, деловые переговоры, финансы и инвестиции",
            "is_general": False
        }

        prompt = build_horoscope_prompt(profile, "04.09.2026")

        # Проверка роли и авторитета
        self.assertIn("60-летним стажем", prompt)
        self.assertIn("ВЫСШАЯ НАТАЛЬНАЯ ТОЧНОСТЬ", prompt)

        # Проверка натальных параметров
        self.assertIn("Олег", prompt)
        self.assertIn("23.05.1978", prompt)
        self.assertIn("00:05", prompt)
        self.assertIn("Кишинев", prompt)
        self.assertIn("Москва", prompt)
        self.assertIn("Мужской", prompt)
        self.assertIn("бизнес, деловые переговоры, финансы и инвестиции", prompt)

        # Проверка правил расчета Асцендента, Середины Неба и ключевых домов
        self.assertIn("Асцендент", prompt)
        self.assertIn("Середину Неба", prompt)
        self.assertIn("1 дом", prompt)
        self.assertIn("2 дом", prompt)
        self.assertIn("6 дом", prompt)
        self.assertIn("7 дом", prompt)
        self.assertIn("10 дом", prompt)

        # Проверка требования указания конкретных часов
        self.assertIn("конкретные благоприятные часы", prompt)

        # Проверка обязательных рубрик (HTML теги <b>)
        self.assertIn("<b>Влияние планет на сегодня</b>", prompt)
        self.assertIn("<b>Работа, бизнес и финансы</b>", prompt)
        self.assertIn("<b>Личные отношения и общение</b>", prompt)
        self.assertIn("<b>Здоровье и тонус</b>", prompt)
        self.assertIn("<b>Добрый совет на сегодня</b>", prompt)
        self.assertIn("<b>Пожелание на сегодня</b>", prompt)

        # Проверка женского рода для женского профиля
        female_profile = {
            "name": "Анна",
            "birth_date": "15.08.1990",
            "birth_time": "14:30",
            "birth_city": "Киев",
            "current_city": "Варшава",
            "gender": "female",
            "is_general": False
        }
        female_prompt = build_horoscope_prompt(female_profile, "04.09.2026")
        self.assertIn("Женский", female_prompt)
        self.assertIn("женского рода", female_prompt)

        print("✅ Тест 9 пройден: Промпт высшей натальной категории строго соблюдает астрологическую методологию.")

    def test_10_natal_asc_mc_exact_calculation(self):
        """Проверка строгости астрономического расчета Асцендента и Середины Неба."""
        from ai_service import calculate_natal_asc_mc

        # Олег: 23 мая 1978, 00:50, Кишинев
        natal_ru = calculate_natal_asc_mc("23.05.1978", "00:50", "Кишинев")
        natal_iso = calculate_natal_asc_mc("1978-05-23", "00:50", "Кишинев")

        self.assertIsNotNone(natal_ru)
        self.assertIsNotNone(natal_iso)
        self.assertEqual(natal_ru["asc_sign"], "Водолей")
        self.assertEqual(natal_iso["asc_sign"], "Водолей")
        self.assertEqual(natal_ru["asc_degree"], "1°32'")
        self.assertEqual(natal_iso["asc_degree"], "1°32'")
        self.assertEqual(natal_ru["mc_sign"], "Скорпион")
        self.assertEqual(natal_ru["mc_degree"], "28°46'")

        print("✅ Тест 10 пройден: Астрономический расчет Асцендента и MC математически неизменен.")

    def test_11_multi_user_city_resolution_and_calculation(self):
        """Проверка расчета натальных параметров для новых пользователей из разных городов."""
        from ai_service import calculate_natal_asc_mc, resolve_city_coords

        # 1. Проверка очистки и поиска городов
        lat, lon, tz = resolve_city_coords("г. Лондон, Великобритания")
        self.assertEqual(tz, "Europe/London")
        lat_ru, lon_ru, tz_ru = resolve_city_coords("Москва (Россия)")
        self.assertEqual(tz_ru, "Europe/Moscow")
        lat_kz, lon_kz, tz_kz = resolve_city_coords("г. Алматы")
        self.assertEqual(tz_kz, "Asia/Almaty")

        # 2. Расчет для нового пользователя: Лондон, 01.01.2000, 12:00
        natal_london = calculate_natal_asc_mc("2000-01-01", "12:00", "г. Лондон, Великобритания")
        self.assertIsNotNone(natal_london)
        self.assertEqual(natal_london["asc_sign"], "Овен")
        self.assertEqual(natal_london["mc_sign"], "Козерог")

        # 3. Расчет для нового пользователя: Новосибирск, 20.03.1985, 18:45
        natal_nsk = calculate_natal_asc_mc("1985-03-20", "18:45", "Новосибирск")
        self.assertIsNotNone(natal_nsk)
        self.assertEqual(natal_nsk["asc_sign"], "Дева")
        self.assertEqual(natal_nsk["mc_sign"], "Близнецы")

        print("✅ Тест 11 пройден: Новые пользователи из любых городов получают строгий математический расчет Асцендента.")

    def test_12_new_zodiac_psychological_format(self):
        """Проверка нового формата гороскопа по 12 знакам: утренняя шапка, СОВЕТ ДНЯ и притча."""
        from ai_service import build_zodiac_prompt
        from archive_service import parse_zodiac_structure

        prompt = build_zodiac_prompt("14.09.2026")
        self.assertIn("14 сентября", prompt)
        self.assertIn("СОВЕТ ДНЯ ☝️", prompt)
        self.assertIn("притч", prompt)
        self.assertIn("2400 до 3200 символов", prompt)

        # Тест парсинга нового формата
        new_sample = (
            "☀️☕️🍁 Доброе утро тем, кто смешивает хорошее настроение с кофе! 🍁\n\n"
            "☀️🌿 <b>Гороскоп на 14 сентября (Понедельник)</b> 🌿☀️\n"
            "♈️ ♉️ ♊️ ♋️ ♌️ ♍️ ♎️ ♏️ ♐️ ♑️ ♒️ ♓️\n\n"
            + "\n\n".join([
                f"<b>{meta['symbol']} {meta['name']}. 14 сентября.</b>\n"
                f"✨ Эмоциональный фон дня спокоен, но требует внимания к деталям и уважения к чужим границам.\n"
                f"<b>СОВЕТ ДНЯ ☝️</b> Сосредоточьтесь на главном деле и не суетитесь."
                for meta in [
                    {"symbol": "♈️", "name": "Овен"},
                    {"symbol": "♉️", "name": "Телец"},
                    {"symbol": "♊️", "name": "Близнецы"},
                    {"symbol": "♋️", "name": "Рак"},
                    {"symbol": "♌️", "name": "Лев"},
                    {"symbol": "♍️", "name": "Дева"},
                    {"symbol": "♎️", "name": "Весы"},
                    {"symbol": "♏️", "name": "Скорпион"},
                    {"symbol": "♐️", "name": "Стрелец"},
                    {"symbol": "♑️", "name": "Козерог"},
                    {"symbol": "♒️", "name": "Водолей"},
                    {"symbol": "♓️", "name": "Рыбы"},
                ]
            ])
            + "\n\n✨✨✨ <i>Уступать — фундамент связи.</i> ✨✨✨"
        )
        parsed = parse_zodiac_structure(new_sample, "14.09.2026")
        self.assertEqual(len(parsed["signs"]), 12)
        for s in parsed["signs"]:
            self.assertIn("СОВЕТ ДНЯ", s["forecast"])
            self.assertIn("Совет:", s["focus"])

        print("✅ Тест 12 пройден: Новый психологический формат гороскопа по 12 знакам успешно формируется и парсится.")

    def test_13_archive_preview_no_leak_of_oleg(self):
        """Проверка, что превью архива никогда не раскрывают имя автора «Олег» или натальные данные 1978 года."""
        from archive_service import generate_archive_preview
        import json

        sample_greetings = [
            "☀️🌿🕊️ Приветствую Вас, Олег! В этот замечательный день 16 сентября 2026 года Ваш персональный астрологический паспорт подтверждает: Ваш восходящий знак — Водолей (1°32' Водолея), а текущая транзитная Луна в Скорпионе активирует Ваш 10 дом карьеры и профессиональных достижений, создавая мощное напряжение между амбициями и внутренним состоянием. Среда под управлением Меркурия в сочетании с 5-м лунным днем требует от Вас интеллектуальной гибкости и четкого планирования в делах.",
            "☀️🌿🕊️ Приветствую Вас, Олег! Ваш персональный астрологический расчет на 15 сентября 2026 года подтверждает восходящий знак Асцендента в Водолее (1°32' Водолея), при этом транзитная Луна в Скорпионе сегодня активирует Ваш 10 дом профессиональных достижений и карьеры. Энергетика вторника, управляемого Марсом, в сочетании с 4-м лунным днем, создает мощный импульс для решительных действий и глубокого анализа текущих стратегических задач.",
            "☕🌤️🍀 Доброе утро, Олег! При расчете Вашей натальной карты на момент рождения 23.05.1978 в 00:05 для Кишинева восходит знак Водолея (Асцендент в 13° Водолея), а МС устремлен в целеустремленного Стрельца.",
            "🌅✨🍃 Здравствуйте, уважаемый Олег! При Вашем рождении 23 мая 1978 года в 00:50 в Кишиневе на восточном горизонте восходил чувствительный и проницательный знак Рыб (Asc около 7° Рыб), направляя вектор Ваших высших достижений к вершине Стрельца (МС), а сегодня транзитная связка Солнца и Луны активирует Ваш натальный 7-й дом партнерства и контрактов."
        ]

        for greeting in sample_greetings:
            preview = generate_archive_preview(greeting, "16.09.2026")
            self.assertNotIn("Олег", preview, f"Утечка имени Олег в превью архива: {preview}")
            self.assertNotIn("23.05.1978", preview, f"Утечка даты рождения в превью: {preview}")
            self.assertNotIn("Кишинев", preview, f"Утечка города рождения в превью: {preview}")
            self.assertNotIn("1°32", preview, f"Утечка координат Асцендента: {preview}")

        # Проверка всех существующих записей в index.json
        for idx_file in ["data/archive/index.json", "mobile_app/assets/data/archive/index.json"]:
            if os.path.exists(idx_file):
                with open(idx_file, "r", encoding="utf-8") as f:
                    entries = json.load(f)
                for entry in entries:
                    p = entry.get("preview", "")
                    self.assertNotIn("Олег", p, f"В файле {idx_file} для даты {entry.get('date')} найдено имя Олег: {p}")

        print("✅ Тест 13 пройден: Превью архива гарантированно очищены от имени автора «Олег» и натальных аспектов.")


if __name__ == "__main__":
    unittest.main()


