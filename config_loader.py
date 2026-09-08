"""
Модуль загрузки конфигурации и секретов.
Поддерживает чтение переменных окружения из GitHub Actions или локального файла .env,
а также загрузку пользовательского профиля из config.json.
"""

import json
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
ENV_PATH = BASE_DIR / ".env"
CONFIG_PATH = BASE_DIR / "config.json"


def load_env_file(filepath=ENV_PATH):
    """
    Загружает переменные из файла .env в os.environ (без сторонних библиотек).
    """
    if not os.path.exists(filepath):
        return

    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # Пропускаем пустые строки и комментарии
            if not line or line.startswith("#") or "=" not in line:
                continue
            
            key, val = line.split("=", 1)
            key = key.strip()
            val = val.strip().strip("'\"")
            
            # Устанавливаем в os.environ, если еще не задано
            if key and key not in os.environ:
                os.environ[key] = val


# Загружаем .env при импорте модуля
load_env_file()


def get_config():
    """
    Загружает config.json с настройками пользователя и параметры окружения.
    """
    default_config = {
        "user_profile": {
            "name": "Пользователь",
            "birth_date": "",
            "birth_time": "",
            "birth_city": "",
            "is_general": True
        },
        "bot_settings": {
            "send_image": False,
            "delay_between_messages_seconds": 2,
            "timezone": "Europe/Moscow"
        }
    }

    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                raw_lines = f.readlines()
            # Очищаем строки от комментариев # и // для безопасного парсинга JSON
            cleaned_lines = []
            for line in raw_lines:
                stripped = line.strip()
                if stripped.startswith("#") or stripped.startswith("//"):
                    continue
                # Удаляем строчные комментарии если строка не является строковым значением
                cleaned_lines.append(line)
            
            clean_json_str = "".join(cleaned_lines)
            loaded = json.loads(clean_json_str)
            if isinstance(loaded, dict):
                if "user_profile" in loaded:
                    default_config["user_profile"].update(loaded["user_profile"])
                if "bot_settings" in loaded:
                    default_config["bot_settings"].update(loaded["bot_settings"])
        except Exception as e:
            print(f"⚠️ Предупреждение: Не удалось прочитать config.json ({e}). Используются настройки по умолчанию (общий прогноз).")

    # Проверяем реестр пользователей data/users/users_registry.json на предмет более свежих данных
    registry_file = BASE_DIR / "data" / "users" / "users_registry.json"
    if registry_file.exists():
        try:
            with open(registry_file, "r", encoding="utf-8") as f:
                reg_users = json.load(f)
            for u in reg_users:
                if u.get("id") == "usr_oleg_main" or u.get("name", "").lower() == default_config["user_profile"].get("name", "").lower():
                    if u.get("birth_time"):
                        default_config["user_profile"]["birth_time"] = u["birth_time"]
                    if u.get("birth_date"):
                        default_config["user_profile"]["birth_date"] = u["birth_date"]
                    if u.get("birth_place"):
                        default_config["user_profile"]["birth_city"] = u["birth_place"]
                    if u.get("current_city"):
                        default_config["user_profile"]["current_city"] = u["current_city"]
                    if u.get("focus"):
                        default_config["user_profile"]["focus"] = u["focus"]
                    break
        except Exception:
            pass

    # Получаем секретные ключи
    gemini_api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    telegram_token = os.environ.get("TELEGRAM_TOKEN", os.environ.get("TELEGRAM_BOT_TOKEN", "")).strip()
    
    # Поддержка разделения канала и личного чата
    telegram_channel_chat_id = (os.environ.get("TELEGRAM_CHANNEL_CHAT_ID", "").strip() or 
                                os.environ.get("TELEGRAM_CHAT_ID", "").strip())
    telegram_personal_chat_id = os.environ.get("TELEGRAM_PERSONAL_CHAT_ID", "").strip()

    return {
        "gemini_api_key": gemini_api_key,
        "telegram_token": telegram_token,
        "telegram_chat_id": telegram_channel_chat_id,
        "telegram_channel_chat_id": telegram_channel_chat_id,
        "telegram_personal_chat_id": telegram_personal_chat_id,
        "user_profile": default_config["user_profile"],
        "bot_settings": default_config["bot_settings"]
    }


def validate_secrets(cfg=None):
    """
    Проверяет наличие всех обязательных ключей.
    Возвращает (is_valid, list_of_errors).
    """
    if cfg is None:
        cfg = get_config()

    errors = []
    if not cfg["gemini_api_key"]:
        errors.append("Отсутствует GEMINI_API_KEY. Получите ключ в Google AI Studio.")
    if not cfg["telegram_token"]:
        errors.append("Отсутствует TELEGRAM_TOKEN. Получите токен у @BotFather в Telegram.")
    if not cfg.get("telegram_channel_chat_id") and not cfg.get("telegram_personal_chat_id"):
        errors.append("Отсутствует идентификатор чата (TELEGRAM_CHAT_ID / TELEGRAM_CHANNEL_CHAT_ID или TELEGRAM_PERSONAL_CHAT_ID).")

    return len(errors) == 0, errors
