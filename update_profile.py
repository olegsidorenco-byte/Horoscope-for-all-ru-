#!/usr/bin/env python3
"""
Скрипт управления и синхронизации натального профиля пользователя.
Позволяет обновлять время, дату, место рождения и фокус внимания
в config.json и data/users/users_registry.json, а также считывать
обновления из Telegram-бота или мобильного приложения.
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime, timezone
import requests

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
DATA_USERS_DIR = BASE_DIR / "data" / "users"
USERS_REGISTRY_FILE = DATA_USERS_DIR / "users_registry.json"


def load_config_profile() -> dict:
    if not CONFIG_PATH.exists():
        return {}
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    return cfg.get("user_profile", {})


def save_config_profile(profile: dict):
    cfg = {}
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            cfg = json.load(f)
    cfg["user_profile"] = profile
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
        f.write("\n")


def update_registry(profile: dict):
    DATA_USERS_DIR.mkdir(parents=True, exist_ok=True)
    users = []
    if USERS_REGISTRY_FILE.exists():
        try:
            with open(USERS_REGISTRY_FILE, "r", encoding="utf-8") as f:
                users = json.load(f)
        except Exception:
            users = []

    now_iso = datetime.now(timezone.utc).isoformat()
    matched = False
    for u in users:
        # Ищем профиль Олега или по id
        if u.get("id") == "usr_oleg_main" or u.get("name", "").lower() == profile.get("name", "").lower():
            u["birth_time"] = profile.get("birth_time", u.get("birth_time", "00:05"))
            u["birth_date"] = profile.get("birth_date", u.get("birth_date", "1978-05-23"))
            u["birth_place"] = profile.get("birth_city", profile.get("birth_place", u.get("birth_place", "Кишинев")))
            u["current_city"] = profile.get("current_city", u.get("current_city", "Кишинев"))
            u["gender"] = profile.get("gender", u.get("gender", "male"))
            u["focus"] = profile.get("focus", u.get("focus", "бизнес, деловые переговоры, финансы и здоровье"))
            u["updated_at"] = now_iso
            matched = True
            break

    if not matched:
        users.append({
            "id": "usr_oleg_main",
            "name": profile.get("name", "Олег"),
            "email": "sidorenco@horoscope.ru",
            "phone": "",
            "auth_type": "email",
            "telegram_username": "olegsidorenco",
            "birth_date": profile.get("birth_date", "1978-05-23"),
            "birth_time": profile.get("birth_time", "00:05"),
            "is_time_exact": True,
            "birth_place": profile.get("birth_city", "Кишинев"),
            "current_city": profile.get("current_city", "Кишинев"),
            "gender": profile.get("gender", "male"),
            "focus": profile.get("focus", "бизнес, деловые переговоры, финансы и здоровье"),
            "updated_at": now_iso,
            "created_at": now_iso
        })

    with open(USERS_REGISTRY_FILE, "w", encoding="utf-8") as f:
        json.dump(users, f, ensure_ascii=False, indent=2)
        f.write("\n")


def sync_from_telegram_updates() -> bool:
    """
    Опрашивает Telegram-бота на предмет команд обновления профиля:
    /set_time 06:15
    /set_birth 23.05.1978 06:15 Кишинев
    /update_natal_profile {json}
    """
    import config_loader
    cfg = config_loader.get_config()
    token = cfg.get("telegram_token")
    if not token:
        return False

    url = f"https://api.telegram.org/bot{token}/getUpdates"
    try:
        res = requests.get(url, timeout=10).json()
        if not res.get("ok"):
            return False

        updates = res.get("result", [])
        updated = False
        current_profile = load_config_profile()

        SUBSCRIBERS_FILE = DATA_USERS_DIR / "telegram_subscribers.json"
        subscribers = set()
        if SUBSCRIBERS_FILE.exists():
            try:
                with open(SUBSCRIBERS_FILE, "r", encoding="utf-8") as sf:
                    subscribers = set(json.load(sf))
            except Exception:
                subscribers = set()

        for u in updates:
            msg = u.get("message", {})
            text = msg.get("text", "").strip()
            from_id = str(msg.get("from", {}).get("id", ""))
            from_name = msg.get("from", {}).get("first_name", "Пользователь")
            personal_id = str(cfg.get("telegram_personal_chat_id", ""))

            # Обработка команды /start для всех пользователей
            if text == "/start" or text.startswith("/start"):
                if from_id not in subscribers:
                    subscribers.add(from_id)
                    try:
                        DATA_USERS_DIR.mkdir(parents=True, exist_ok=True)
                        with open(SUBSCRIBERS_FILE, "w", encoding="utf-8") as sf:
                            json.dump(list(subscribers), sf, ensure_ascii=False, indent=2)
                    except Exception as se:
                        print(f"⚠️ Ошибка сохранения подписчиков: {se}")

                if token and from_id:
                    welcome_text = (
                        f"👋 Здравствуйте, {from_name}!\n\n"
                        f"Добро пожаловать в официальный бот сервиса <b>«Астро Гороскоп»</b>! 🪐\n\n"
                        f"Ваш Telegram Chat ID: <code>{from_id}</code>\n"
                        f"Бот успешно подключен! Каждое утро ровно в <b>06:30</b> мы доставляем персональный "
                        f"астрологический расчет дня прямо в этот диалог — без системных задержек Android.\n\n"
                        f"💡 <b>Быстрые команды:</b>\n"
                        f"• <code>/set_time ЧЧ:ММ</code> — скорректировать время рождения (например, <code>/set_time 00:50</code>)\n"
                        f"• <code>/profile ДД.ММ.ГГГГ ЧЧ:ММ Город</code> — обновить полные данные анкеты\n\n"
                        f"Укажите ваш логин Telegram в мобильном приложении для полной синхронизации профиля!"
                    )
                    try:
                        requests.post(
                            f"https://api.telegram.org/bot{token}/sendMessage",
                            json={"chat_id": from_id, "text": welcome_text, "parse_mode": "HTML"},
                            timeout=10
                        )
                    except Exception as we:
                        print(f"⚠️ Ошибка отправки /start: {we}")
                continue

            # Принимаем команды модификации данных только от авторизованного пользователя
            if personal_id and from_id != personal_id:
                continue

            import re
            time_match = re.search(r'(?:/set_time\s+|время(?:\s*рождения)?[:\s]+)(\d{1,2}[:.]\d{2})', text, re.IGNORECASE)
            birth_match = re.search(r'(?:/set_birth|/profile)\s+(\d{2}\.\d{2}\.\d{4})\s+(\d{1,2}[:.]\d{2})(?:\s+(.+))?', text, re.IGNORECASE)

            if birth_match:
                b_date, b_time, b_city = birth_match.groups()
                # Нормализация даты к ISO ГГГГ-ММ-ДД
                parts = b_date.split('.')
                iso_date = f"{parts[2]}-{parts[1]}-{parts[0]}" if len(parts) == 3 else b_date
                current_profile["birth_date"] = iso_date
                current_profile["birth_time"] = b_time.replace('.', ':')
                if b_city:
                    current_profile["birth_city"] = b_city.strip()
                updated = True
                print(f"🔄 Из Telegram получены полные данные: {b_date} {b_time} {b_city or ''}")

            elif time_match:
                new_time = time_match.group(1).replace('.', ':')
                if len(new_time.split(':')[0]) == 1:
                    new_time = f"0{new_time}"
                current_profile["birth_time"] = new_time
                updated = True
                print(f"🔄 Из Telegram получено новое время рождения: {new_time}")

            elif text.startswith("/update_natal_profile"):
                payload_str = text.replace("/update_natal_profile", "").strip()
                try:
                    payload = json.loads(payload_str)
                    if isinstance(payload, dict):
                        for k, v in payload.items():
                            if v:
                                current_profile[k] = v
                        updated = True
                        print(f"🔄 Из Telegram получены обновленные натальные данные: {payload}")
                except Exception as e:
                    print(f"⚠️ Не удалось распарсить payload из Telegram: {e}")

        if updated:
            save_config_profile(current_profile)
            update_registry(current_profile)
            print("✅ Натальный профиль успешно синхронизирован и сохранен!")
            
            # Отправляем подтверждение пользователю в Telegram
            if token and personal_id:
                try:
                    b_time = current_profile.get("birth_time", "")
                    b_date = current_profile.get("birth_date", "")
                    b_city = current_profile.get("birth_city", current_profile.get("birth_place", ""))
                    confirm_text = (
                        f"✨ <b>Натальные данные успешно обновлены!</b>\n\n"
                        f"👤 Имя: {current_profile.get('name', 'Олег')}\n"
                        f"📅 Дата: {b_date}\n"
                        f"⏰ Время рождения: <b>{b_time}</b>\n"
                        f"📍 Место: {b_city}\n\n"
                        f"Все последующие персональные астрологические расчеты будут выполняться строго по этим данным."
                    )
                    requests.post(
                        f"https://api.telegram.org/bot{token}/sendMessage",
                        json={"chat_id": personal_id, "text": confirm_text, "parse_mode": "HTML"},
                        timeout=10
                    )
                except Exception as e:
                    print(f"⚠️ Не удалось отправить подтверждение в Telegram: {e}")

            return True

    except Exception as e:
        print(f"⚠️ Ошибка при опросе Telegram: {e}")

    return False


def main():
    parser = argparse.ArgumentParser(description="Управление натальным профилем пользователя")
    parser.add_argument("--time", "-t", type=str, help="Новое время рождения (например: 06:30, 14:15)")
    parser.add_argument("--date", "-d", type=str, help="Новая дата рождения (например: 23.05.1978)")
    parser.add_argument("--city", "-c", type=str, help="Город рождения (например: Кишинев)")
    parser.add_argument("--current-city", type=str, help="Город текущего проживания")
    parser.add_argument("--focus", "-f", type=str, help="Приоритетные сферы внимания")
    parser.add_argument("--sync-telegram", action="store_true", help="Синхронизировать обновления из Telegram-бота")
    parser.add_argument("--show", action="store_true", help="Показать текущий натальный профиль")

    args = parser.parse_args()

    if args.sync_telegram:
        sync_from_telegram_updates()
        return

    profile = load_config_profile()

    modified = False
    if args.time:
        profile["birth_time"] = args.time.strip()
        modified = True
    if args.date:
        profile["birth_date"] = args.date.strip()
        modified = True
    if args.city:
        profile["birth_city"] = args.city.strip()
        modified = True
    if args.current_city:
        profile["current_city"] = args.current_city.strip()
        modified = True
    if args.focus:
        profile["focus"] = args.focus.strip()
        modified = True

    if modified:
        save_config_profile(profile)
        update_registry(profile)
        print(f"✅ Профиль успешно обновлен в config.json и users_registry.json:")
        print(json.dumps(profile, ensure_ascii=False, indent=2))
    elif args.show or len(sys.argv) == 1:
        print("👤 Текущий натальный профиль:")
        print(json.dumps(profile, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
