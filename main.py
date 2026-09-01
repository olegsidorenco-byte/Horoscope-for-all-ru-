"""
Главный координирующий модуль Telegram-бота ежедневного гороскопа.
Выполняет загрузку конфигурации, генерацию прогноза через Google AI
и безопасную доставку прогноза по темам отдельными сообщениями в Telegram.
"""

import sys

from config_loader import get_config, validate_secrets
from ai_service import generate_horoscope_text
from telegram_service import send_text_message
from archive_service import save_horoscope_to_archive


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
        # 2. Генерация текста гороскопа
        print("🔮 Расчет натальных аспектов и генерация прогноза дня...")
        horoscope_text = generate_horoscope_text(api_key, user_profile)
        print(f"📝 Текст гороскопа успешно сформирован (объем: {len(horoscope_text)} симв.).")

        # 3. Сохранение в архив по дням и публикация в data/
        print("🗄️ Сохранение прогноза в архив по дням...")
        save_horoscope_to_archive(horoscope_text)

        # 4. Доставка гороскопа единым сообщением в Telegram
        print("📤 Отправка гороскопа в Telegram единым сообщением...")
        send_text_message(bot_token, chat_id, horoscope_text)

        print("✨ Ежедневная рассылка и архивация успешно завершены!")

    except Exception as e:
        print(f"❌ Критическая ошибка выполнения: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

