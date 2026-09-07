#!/usr/bin/env python3
"""
Скрипт для автоматической привязки личного Telegram-чата автора.
Позволяет боту отправлять персональный гороскоп лично в ЛС,
а общий гороскоп по 12 знакам — в публичный канал.
"""

import sys
import os
import time
import requests
from pathlib import Path
import config_loader

BASE_DIR = Path(__file__).resolve().parent
ENV_FILE = BASE_DIR / ".env"


def update_env_variable(key: str, value: str):
    """Обновляет или добавляет переменную в .env файл."""
    lines = []
    found = False
    if ENV_FILE.exists():
        with open(ENV_FILE, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip().startswith(f"{key}=") or line.strip().startswith(f"{key} ="):
                    lines.append(f"{key}={value}\n")
                    found = True
                else:
                    lines.append(line)
    if not found:
        lines.append(f"{key}={value}\n")

    with open(ENV_FILE, "w", encoding="utf-8") as f:
        f.writelines(lines)
    os.environ[key] = value


def send_confirmation(token: str, chat_id: str, name: str = "Олег"):
    """Отправляет подтверждающее приветственное сообщение в ЛС."""
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": f"✨ <b>Здравствуйте, {name}!</b>\n\nВаш личный Telegram успешно привязан! Теперь каждое утро в 06:30 Ваш глубокий персональный натальный гороскоп будет приходить <b>только сюда</b> в личные сообщения.\n\nВ публичный канал будет уходить только общий гороскоп по 12 знакам зодиака.",
        "parse_mode": "HTML"
    }
    try:
        requests.post(url, json=payload, timeout=10)
    except Exception as e:
        print(f"⚠️ Не удалось отправить приветственное сообщение: {e}")


def main():
    cfg = config_loader.get_config()
    token = cfg.get("telegram_token")
    if not token:
        print("❌ Ошибка: В .env отсутствует TELEGRAM_TOKEN.")
        sys.exit(1)

    # 1. Проверяем аргументы командной строки
    if len(sys.argv) > 1:
        arg_id = sys.argv[1].replace("--id=", "").strip()
        if arg_id.isdigit():
            print(f"🔗 Привязка переданного ID: {arg_id}...")
            update_env_variable("TELEGRAM_PERSONAL_CHAT_ID", arg_id)
            send_confirmation(token, arg_id, cfg["user_profile"].get("name", "Олег"))
            print(f"✅ Успешно! TELEGRAM_PERSONAL_CHAT_ID={arg_id} сохранен в .env.")
            sys.exit(0)

    # 2. Интерактивный поиск через бота
    bot_username = "Horoscope_SiDoReCo_bot"
    try:
        me_resp = requests.get(f"https://api.telegram.org/bot{token}/getMe", timeout=10).json()
        if me_resp.get("ok"):
            bot_username = me_resp.get("result", {}).get("username", bot_username)
    except Exception:
        pass

    print("=" * 60)
    print("🔮 АВТОМАТИЧЕСКАЯ ПРИВЯЗКА ВАШЕГО ЛИЧНОГО TELEGRAM ЧАТА")
    print("=" * 60)
    print(f"1. Откройте в Telegram диалог с вашим ботом: https://t.me/{bot_username}")
    print("2. Нажмите кнопку 'Start' (или отправьте любое сообщение, например 'Привет').")
    print("⏳ Ожидание входящего сообщения от вас...")

    # Сначала очищаем старый оффсет если есть
    last_update_id = 0
    try:
        init_r = requests.get(f"https://api.telegram.org/bot{token}/getUpdates", timeout=10).json()
        if init_r.get("ok") and init_r.get("result"):
            last_update_id = init_r["result"][-1]["update_id"]
    except Exception:
        pass

    start_wait = time.time()
    while time.time() - start_wait < 120:  # ждем до 2 минут
        try:
            updates_url = f"https://api.telegram.org/bot{token}/getUpdates?offset={last_update_id + 1}&timeout=5"
            resp = requests.get(updates_url, timeout=10).json()
            if resp.get("ok") and resp.get("result"):
                for u in resp["result"]:
                    last_update_id = u["update_id"]
                    msg = u.get("message")
                    if msg:
                        from_user = msg.get("from", {})
                        chat = msg.get("chat", {})
                        chat_id = str(chat.get("id", ""))
                        chat_type = chat.get("type", "")
                        
                        if chat_type == "private" and chat_id:
                            first_name = from_user.get("first_name", "Олег")
                            username = from_user.get("username", "")
                            print(f"\n🎉 Найдено сообщение от: {first_name} (@{username}), Chat ID: {chat_id}")
                            
                            update_env_variable("TELEGRAM_PERSONAL_CHAT_ID", chat_id)
                            send_confirmation(token, chat_id, first_name)
                            print(f"✅ Отлично! Переменная TELEGRAM_PERSONAL_CHAT_ID={chat_id} сохранена в .env.")
                            print("📩 В ваш Telegram бот только что отправил подтверждение.")
                            print("=" * 60)
                            sys.exit(0)
        except Exception as e:
            pass
        time.sleep(2)

    print("\n⏱️ Время ожидания истекло. Вы можете запустить скрипт снова или передать ID вручную: python3 link_personal_telegram.py --id=<ВАШ_ID>")


if __name__ == "__main__":
    main()
