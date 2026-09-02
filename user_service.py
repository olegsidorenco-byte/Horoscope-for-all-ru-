"""
Модуль учета и управления натальными профилями пользователей.
Хранит реестр зарегистрированных пользователей в data/users/users_registry.json.
Используется для генерации персональных ежедневных гороскопов с учетом натальных данных
(дата рождения, время, место рождения для домов гороскопа и место пребывания для локальных транзитов).
"""

import os
import json
from datetime import datetime

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
    Регистрирует нового пользователя или обновляет существующего по email.
    Обязательные поля: email, name, birth_date, birth_time, birth_place, current_city.
    """
    ensure_users_dir()
    users = get_all_users()
    email = user_data.get("email", "").strip().lower()
    if not email:
        raise ValueError("Email обязателен для регистрации пользователя")

    now_iso = datetime.utcnow().isoformat() + "Z"
    user_entry = {
        "id": user_data.get("id") or f"usr_{int(datetime.utcnow().timestamp())}",
        "name": user_data.get("name", "").strip(),
        "email": email,
        "birth_date": user_data.get("birth_date", "2000-01-01"),
        "birth_time": user_data.get("birth_time", "12:00"),
        "is_time_exact": user_data.get("is_time_exact", False),
        "birth_place": user_data.get("birth_place", "").strip(),
        "current_city": user_data.get("current_city", "").strip(),
        "gender": user_data.get("gender", "female"),
        "updated_at": now_iso
    }

    updated = False
    for i, u in enumerate(users):
        if u.get("email", "").lower() == email:
            users[i] = user_entry
            updated = True
            break

    if not updated:
        user_entry["created_at"] = now_iso
        users.append(user_entry)

    with open(USERS_REGISTRY_FILE, "w", encoding="utf-8") as f:
        json.dump(users, f, ensure_ascii=False, indent=2)

    action_str = "обновлен" if updated else "зарегистрирован"
    print(f"👤 Пользователь {user_entry['name']} ({email}) успешно {action_str} в реестре.")
    return user_entry
