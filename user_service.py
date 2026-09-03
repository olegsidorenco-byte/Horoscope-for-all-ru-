"""
Модуль учета и управления натальными профилями пользователей.
Хранит реестр зарегистрированных пользователей в data/users/users_registry.json.
Используется для генерации персональных ежедневных гороскопов с учетом натальных данных
(дата рождения, время, место рождения для домов гороскопа и место пребывания для локальных транзитов).
"""

import os
import json
from datetime import datetime, timezone

DATA_USERS_DIR = os.path.join(os.path.dirname(__file__), "data", "users")
USERS_REGISTRY_FILE = os.path.join(DATA_USERS_DIR, "users_registry.json")


def ensure_users_dir():
    """Создает каталог data/users при необходимости."""
    os.makedirs(DATA_USERS_DIR, exist_ok=True)
    if not os.path.exists(USERS_REGISTRY_FILE):
        with open(USERS_REGISTRY_FILE, "w", encoding="utf-8") as f:
            json.dump([], f, ensure_ascii=False, indent=2)


def get_all_users() -> list:
    """Возвращает список всех зарегистрированных пользователей."""
    ensure_users_dir()
    try:
        with open(USERS_REGISTRY_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []


def register_or_update_user(user_data: dict) -> dict:
    """
    Регистрирует нового пользователя или обновляет существующего.
    Строгое правило «Один телефон или почта — один аккаунт»:
    проверяет уникальность email и phone среди всех зарегистрированных записей.
    """
    ensure_users_dir()
    users = get_all_users()

    email = user_data.get("email", "").strip().lower()
    phone = user_data.get("phone", "").strip()
    telegram_username = user_data.get("telegram_username", "").strip().replace("@", "")
    user_id = user_data.get("id")

    if not email and not phone and not telegram_username:
        raise ValueError("Для регистрации пользователя необходим уникальный контакт (Email, Телефон или Telegram)")

    now_iso = datetime.now(timezone.utc).isoformat()

    # 1. Поиск существующего профиля по ID
    existing_index_by_id = -1
    if user_id:
        for i, u in enumerate(users):
            if u.get("id") == user_id:
                existing_index_by_id = i
                break

    # 2. Строгая проверка на конфликт уникальности контактов с ДРУГИМИ пользователями
    for i, u in enumerate(users):
        if existing_index_by_id != -1 and i == existing_index_by_id:
            continue  # Сам пользователь может сохранять и обновлять свои данные
        u_email = u.get("email", "").strip().lower()
        u_phone = u.get("phone", "").strip()
        u_tg = u.get("telegram_username", "").strip().replace("@", "")

        if email and u_email == email:
            raise ValueError(f"Пользователь с email '{email}' уже зарегистрирован!")
        if phone and u_phone == phone:
            raise ValueError(f"Пользователь с номером телефона '{phone}' уже зарегистрирован!")
        if telegram_username and u_tg and u_tg.lower() == telegram_username.lower():
            raise ValueError(f"Пользователь с Telegram '@{telegram_username}' уже зарегистрирован!")

    # 3. Определение индекса для обновления или создания
    match_index = existing_index_by_id
    if match_index == -1:
        # Если ID не был передан, ищем по контакту
        for i, u in enumerate(users):
            u_email = u.get("email", "").strip().lower()
            u_phone = u.get("phone", "").strip()
            u_tg = u.get("telegram_username", "").strip().replace("@", "")
            if (email and u_email == email) or (phone and u_phone == phone) or (telegram_username and u_tg and u_tg.lower() == telegram_username.lower()):
                match_index = i
                break

    user_entry = {
        "id": user_id or (users[match_index].get("id") if match_index != -1 else f"usr_{int(datetime.now(timezone.utc).timestamp())}"),
        "name": user_data.get("name", "").strip(),
        "email": email,
        "phone": phone,
        "auth_type": user_data.get("auth_type", "email" if email else ("phone" if phone else "telegram")),
        "telegram_username": telegram_username,
        "birth_date": user_data.get("birth_date", "2000-01-01"),
        "birth_time": user_data.get("birth_time", "12:00"),
        "is_time_exact": user_data.get("is_time_exact", False),
        "birth_place": user_data.get("birth_place", "").strip(),
        "current_city": user_data.get("current_city", "").strip(),
        "gender": user_data.get("gender", "female"),
        "updated_at": now_iso
    }

    if match_index != -1:
        # Сохраняем created_at старой записи
        user_entry["created_at"] = users[match_index].get("created_at", now_iso)
        users[match_index] = user_entry
        updated = True
    else:
        user_entry["created_at"] = now_iso
        users.append(user_entry)
        updated = False

    with open(USERS_REGISTRY_FILE, "w", encoding="utf-8") as f:
        json.dump(users, f, ensure_ascii=False, indent=2)

    action_str = "обновлен" if updated else "зарегистрирован"
    contact_display = email or phone or f"@{telegram_username}"
    print(f"👤 Пользователь {user_entry['name']} ({contact_display}) успешно {action_str} в реестре.")
    return user_entry
