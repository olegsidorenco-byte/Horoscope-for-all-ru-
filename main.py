"""
Главный координирующий модуль Telegram-бота ежедневного гороскопа.
Выполняет загрузку конфигурации, генерацию персонального прогноза и гороскопа
по 12 знакам зодиака через Google AI, сохранение в архив и доставку в Telegram.
"""

import sys
import time

from config_loader import get_config, validate_secrets
from ai_service import generate_horoscope_text, generate_zodiac_horoscope_text
from telegram_service import send_text_message
from archive_service import save_horoscope_to_archive, save_zodiac_to_archive


def main():
    print("🚀 Запуск автономного астрологического бота...")
    
    # 1. Загрузка и валидация конфигурации
    config = get_config()
    is_valid, errors = validate_secrets(config)
    if not is_valid:
        print("❌ Ошибка конфигурации:")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    api_key = config["gemini_api_key"]
    bot_token = config["telegram_token"]
    chat_id = config["telegram_chat_id"]
    user_profile = config["user_profile"]

    bot_settings = config.get("bot_settings", {})
    delay_seconds = bot_settings.get("delay_between_messages_seconds", 2.0)

    try:
        # 2. Генерация и доставка Персонального прогноза (Сообщение 1)
        print("🔮 1/2. Расчет натальных аспектов и генерация персонального прогноза дня...")
        horoscope_text = generate_horoscope_text(api_key, user_profile)
        print(f"📝 Персональный гороскоп сформирован (объем: {len(horoscope_text)} симв.).")

        print("🗄️ Сохранение персонального прогноза в архив...")
        save_horoscope_to_archive(horoscope_text)

        print("📤 Отправка персонального прогноза в Telegram (Сообщение 1)...")
        send_text_message(bot_token, chat_id, horoscope_text)

        time.sleep(delay_seconds)

        # 3. Генерация и доставка Гороскопа по 12 знакам зодиака (Сообщение 2)
        print("♈ 2/2. Расчет и генерация гороскопа по 12 знакам зодиака...")
        zodiac_text = generate_zodiac_horoscope_text(api_key)
        print(f"📝 Гороскоп по знакам зодиака сформирован (объем: {len(zodiac_text)} симв.).")

        print("🗄️ Сохранение гороскопа по знакам в архив...")
        save_zodiac_to_archive(zodiac_text)

        print("📤 Отправка гороскопа по знакам в Telegram (Сообщение 2)...")
        send_text_message(bot_token, chat_id, zodiac_text)

        print("✨ Все астрологические рассылки и архивация успешно завершены!")

    except Exception as e:
        print(f"❌ Критическая ошибка выполнения: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
