"""
Интерактивное меню для локального тестирования Telegram-бота на компьютере.
Позволяет пошагово проверить каждую функцию без риска для рабочей базы.
"""

import os
import sys
from pathlib import Path
import requests

from config_loader import get_config, validate_secrets
from ai_service import discover_models, generate_horoscope_text, generate_cosmic_image
from telegram_service import send_text_message, send_photo


def test_connections():
    """Проверяет корректность ключей и связь с серверами Google и Telegram."""
    print("\n--- 🔑 Проверка ключей и соединений ---")
    config = get_config()
    is_valid, errors = validate_secrets(config)
    
    if not is_valid:
        print("❌ Обнаружены ошибки в настройках секретов (.env или переменные окружения):")
        for err in errors:
            print(f"   • {err}")
        return

    # 1. Проверка Telegram Bot Token
    token = config["telegram_token"]
    print("⏳ Проверка подключения к Telegram Bot API...")
    try:
        tg_res = requests.get(f"https://api.telegram.org/bot{token}/getMe", timeout=10)
        if tg_res.status_code == 200:
            bot_info = tg_res.json().get("result", {})
            print(f"✅ Telegram Bot подключен успешно! Имя бота: @{bot_info.get('username', 'Unknown')}")
        else:
            print(f"❌ Ошибка Telegram токена (HTTP {tg_res.status_code}): {tg_res.text}")
    except Exception as e:
        print(f"❌ Не удалось подключиться к Telegram: {e}")

    # 2. Проверка Google Gemini API Key
    api_key = config["gemini_api_key"]
    print("⏳ Проверка подключения к Google AI Studio...")
    try:
        gemini_res = requests.get(
            "https://generativelanguage.googleapis.com/v1beta/models",
            headers={"x-goog-api-key": api_key},
            timeout=10
        )
        if gemini_res.status_code == 200:
            print("✅ Ключ Google AI Studio (Gemini) валиден и активен!")
        else:
            print(f"❌ Ошибка Google API Key (HTTP {gemini_res.status_code}): {gemini_res.text}")
    except Exception as e:
        print(f"❌ Не удалось подключиться к Google AI: {e}")

    print(f"ℹ️ Целевой Chat ID для отправки: {config['telegram_chat_id']}")


def test_models_discovery():
    """Тестирует автопоиск и приоритизацию моделей Google AI."""
    print("\n--- 🔍 Тестирование автопоиска моделей Google AI ---")
    config = get_config()
    api_key = config["gemini_api_key"]
    if not api_key:
        print("❌ Укажите GEMINI_API_KEY в файле .env")
        return

    print("⏳ Опрос API Google и составление рейтинга моделей...")
    models = discover_models(api_key)
    print(f"\n📊 Найдено и отсортировано доступных моделей ({len(models)}):")
    for i, m in enumerate(models, 1):
        star = "🌟 [Основная]" if i == 1 else "   [Резервная]"
        print(f" {i}. {star} {m}")


def test_text_generation():
    """Генерирует и выводит гороскоп в консоль (без отправки в Telegram)."""
    print("\n--- 📜 Тестирование генерации текста гороскопа ---")
    config = get_config()
    api_key = config["gemini_api_key"]
    if not api_key:
        print("❌ Укажите GEMINI_API_KEY в файле .env")
        return

    print(f"👤 Профиль: {config['user_profile'].get('name', 'Пользователь')}, Дата рождения: {config['user_profile'].get('birth_date') or 'Общий гороскоп'}")
    print("⏳ Генерация прогноза... Пожалуйста, подождите...")
    
    try:
        text = generate_horoscope_text(api_key, config["user_profile"])
        print("\n" + "=" * 50)
        print(text)
        print("=" * 50)
        print(f"✅ Длина сгенерированного текста: {len(text)} символов.")
    except Exception as e:
        print(f"❌ Ошибка при генерации: {e}")


def test_image_generation():
    """Тестирует генерацию космической картины дня и сохраняет локальный файл."""
    print("\n--- 🎨 Тестирование генерации космической картины ---")
    config = get_config()
    api_key = config["gemini_api_key"]
    if not api_key:
        print("❌ Укажите GEMINI_API_KEY в файле .env")
        return

    sample_text = "Гармоничный аспект Юпитера и Солнца дарит вдохновение и творческий подъем."
    print("⏳ Запрос на создание космической картины в Google AI...")
    
    image_bytes = generate_cosmic_image(api_key, sample_text)
    if image_bytes:
        out_file = Path("test_cosmic_image.png")
        out_file.write_bytes(image_bytes)
        print(f"✅ Картина успешно сгенерирована и сохранена в файл: {out_file.resolve()}")
    else:
        print("ℹ️ Онлайн-генератор недоступен для данного ключа. Будет использована обложка: assets/default_cover.png")


def test_full_pipeline():
    """Выполняет полный боевой запуск с отправкой в Telegram."""
    print("\n--- 🚀 Полный боевой тест с отправкой в Telegram ---")
    confirm = input("Отправить тестовый прогноз в Telegram прямо сейчас? (y/n): ").strip().lower()
    if confirm in ["y", "yes", "д", "да"]:
        import main
        main.main()
    else:
        print("Отменено.")


def show_user_profile():
    """Отображает текущий профиль пользователя из config.json."""
    print("\n--- ⚙️ Текущие настройки из config.json ---")
    config = get_config()
    prof = config["user_profile"]
    print(f"• Имя: {prof.get('name')}")
    print(f"• Дата рождения: {prof.get('birth_date') or '(не указана — общий прогноз)'}")
    print(f"• Время рождения: {prof.get('birth_time') or '(не указано)'}")
    print(f"• Город: {prof.get('birth_city') or '(не указан)'}")
    print(f"• Режим общего прогноза: {prof.get('is_general')}")
    print(f"• Отправка иллюстрации: {config['bot_settings'].get('send_image')}")


def main_menu():
    while True:
        print("\n" + "=" * 45)
        print("   🌟 АСТРОЛОГИЧЕСКИЙ БОТ: МЕНЮ ТЕСТОВ 🌟")
        print("=" * 45)
        print(" 1. 🔑 Проверить API-ключи и связь (Gemini & Telegram)")
        print(" 2. 🔍 Проверить автопоиск моделей Google AI")
        print(" 3. 📜 Сгенерировать гороскоп (вывод в консоль)")
        print(" 4. 🎨 Проверить генерацию космической картины")
        print(" 5. 🚀 Полный боевой тест (генерация + отправка)")
        print(" 6. ⚙️ Посмотреть настройки (config.json)")
        print(" 0. ❌ Выход")
        print("=" * 45)
        
        choice = input("Выберите пункт меню (0-6): ").strip()
        
        if choice == "1":
            test_connections()
        elif choice == "2":
            test_models_discovery()
        elif choice == "3":
            test_text_generation()
        elif choice == "4":
            test_image_generation()
        elif choice == "5":
            test_full_pipeline()
        elif choice == "6":
            show_user_profile()
        elif choice in ["0", "q", "exit"]:
            print("До свидания! ✨")
            break
        else:
            print("Неверный ввод. Пожалуйста, введите число от 0 до 6.")


if __name__ == "__main__":
    main_menu()
