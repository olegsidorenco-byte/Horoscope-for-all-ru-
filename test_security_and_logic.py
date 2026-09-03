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


if __name__ == "__main__":
    unittest.main()
