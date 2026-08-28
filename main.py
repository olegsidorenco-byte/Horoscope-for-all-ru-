"""
Главный координирующий модуль Telegram-бота ежедневного гороскопа.
Выполняет загрузку конфигурации, генерацию прогноза через Google AI
и безопасную доставку прогноза по темам отдельными сообщениями в Telegram.
"""

import sys

from config_loader import get_config, validate_secrets
from ai_service import generate_horoscope_text, split_into_topic_messages
from telegram_service import send_topic_messages


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

        # 3. Разделение текста на тематические сообщения
        print("📑 Формирование тематических блоков прогноза...")
        topics = split_into_topic_messages(horoscope_text)
        print(f"📦 Сформировано {len(topics)} тематических сообщений.")

        # 4. Безопасная доставка пакета сообщений в Telegram (с защитой от анти-спама)
        print("📤 Отправка тематических сообщений в Telegram...")
        send_topic_messages(bot_token, chat_id, topics, delay_seconds=delay_seconds)

        print("✨ Ежедневная рассылка успешно завершена!")

    except Exception as e:
        print(f"❌ Критическая ошибка выполнения: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

