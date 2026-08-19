"""
Главный координирующий модуль Telegram-бота ежедневного гороскопа.
Выполняет загрузку конфигурации, генерацию прогноза через Google AI
и гарантированную доставку текста и иллюстрации в Telegram.
"""

import sys
from pathlib import Path

from config_loader import get_config, validate_secrets
from ai_service import generate_horoscope_text, generate_cosmic_image
from telegram_service import send_text_message, send_photo

DEFAULT_COVER_PATH = str(Path(__file__).resolve().parent / "assets" / "default_cover.png")


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
    bot_settings = config["bot_settings"]

    try:
        # 2. Генерация текста гороскопа
        print("🔮 Расчет натальных аспектов и генерация прогноза дня...")
        horoscope_text = generate_horoscope_text(api_key, user_profile)

        # 3. Доставка текста в Telegram
        print("📤 Отправка прогноза в Telegram...")
        send_text_message(bot_token, chat_id, horoscope_text)

        # 4. Генерация и отправка космической картины дня
        if bot_settings.get("send_image", True):
            print("🎨 Создание космической визуализации дня...")
            image_data = generate_cosmic_image(api_key, horoscope_text)
            
            if image_data:
                send_photo(bot_token, chat_id, image_data)
            else:
                print("🖼️ Отправка резервной графической обложки...")
                send_photo(bot_token, chat_id, DEFAULT_COVER_PATH)

        print("✨ Ежедневная рассылка успешно завершена!")

    except Exception as e:
        print(f"❌ Критическая ошибка выполнения: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
