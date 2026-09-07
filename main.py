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
    channel_chat_id = config.get("telegram_channel_chat_id") or config.get("telegram_chat_id")
    personal_chat_id = config.get("telegram_personal_chat_id")
    user_profile = config["user_profile"]

    bot_settings = config.get("bot_settings", {})
    delay_seconds = bot_settings.get("delay_between_messages_seconds", 2.0)

    try:
        # 2. Генерация и доставка Персонального прогноза (Сообщение 1 -> Личные сообщения)
        print("🔮 1/2. Расчет натальных аспектов и генерация персонального прогноза дня...")
        horoscope_text = generate_horoscope_text(api_key, user_profile)
        print(f"📝 Персональный гороскоп сформирован (объем: {len(horoscope_text)} симв.).")

        print("🗄️ Сохранение персонального прогноза в архив...")
        save_horoscope_to_archive(horoscope_text)

        if personal_chat_id:
            print(f"📤 Отправка персонального прогноза в личные сообщения автору ({personal_chat_id})...")
            send_text_message(bot_token, personal_chat_id, horoscope_text)
            time.sleep(delay_seconds)
        else:
            print("ℹ️ TELEGRAM_PERSONAL_CHAT_ID не задан. Персональный прогноз сохранен в архив, но не отправлен в публичный канал (защита конфиденциальности).")

        # 3. Генерация и доставка Гороскопа по 12 знакам зодиака (Сообщение 2 -> Публичный канал)
        print("♈ 2/2. Расчет и генерация гороскопа по 12 знакам зодиака...")
        zodiac_text = generate_zodiac_horoscope_text(api_key)
        print(f"📝 Гороскоп по знакам зодиака сформирован (объем: {len(zodiac_text)} симв.).")

        print("🗄️ Сохранение гороскопа по знакам в архив...")
        save_zodiac_to_archive(zodiac_text)

        if channel_chat_id:
            print(f"📤 Отправка общего гороскопа по 12 знакам в канал ({channel_chat_id})...")
            send_text_message(bot_token, channel_chat_id, zodiac_text)
        else:
            print("⚠️ Идентификатор канала не задан. Гороскоп по 12 знакам сохранен в архив, но не отправлен в Telegram.")

        print("✨ Все астрологические рассылки и архивация успешно завершены!")

    except Exception as e:
        print(f"❌ Критическая ошибка выполнения: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
