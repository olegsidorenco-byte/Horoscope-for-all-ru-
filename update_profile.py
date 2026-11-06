#!/usr/bin/env python3
"""
Скрипт управления и синхронизации натальных профилей автора и подписчиков.
Позволяет обновлять дату/время рождения, место рождения, город проживания,
желаемое время доставки (delivery_time) и часовой пояс в config.json и data/users/users_registry.json,
а также обрабатывать входящие команды из Telegram-бота с сохранением offset (без повторного чтения старых апдейтов).
"""

import re
import json
import sys
import argparse
from pathlib import Path
from datetime import datetime, timezone
import requests

from ai_service import format_date_iso, normalize_time_hhmm, resolve_user_tzinfo
from user_service import register_or_update_user, get_all_users

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
DATA_USERS_DIR = BASE_DIR / "data" / "users"
USERS_REGISTRY_FILE = DATA_USERS_DIR / "users_registry.json"
TELEGRAM_OFFSET_FILE = DATA_USERS_DIR / "telegram_offset.json"
SUBSCRIBERS_FILE = DATA_USERS_DIR / "telegram_subscribers.json"


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


def _load_telegram_offset() -> int:
    if not TELEGRAM_OFFSET_FILE.exists():
        return 0
    try:
        with open(TELEGRAM_OFFSET_FILE, "r", encoding="utf-8") as f:
            return int(json.load(f).get("last_update_id", 0))
    except Exception:
        return 0


def _save_telegram_offset(last_update_id: int):
    DATA_USERS_DIR.mkdir(parents=True, exist_ok=True)
    with open(TELEGRAM_OFFSET_FILE, "w", encoding="utf-8") as f:
        json.dump(
            {
                "last_update_id": last_update_id,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            },
            f,
            ensure_ascii=False,
            indent=2,
        )


def update_registry(profile: dict, personal_chat_id: str = ""):
    """Обновляет профиль основного автора (usr_oleg_main) в users_registry.json."""
    DATA_USERS_DIR.mkdir(parents=True, exist_ok=True)
    users = get_all_users()
    now_iso = datetime.now(timezone.utc).isoformat()
    matched = False

    for u in users:
        if u.get("id") == "usr_oleg_main" or u.get("name", "").lower() == str(profile.get("name", "")).lower():
            u["birth_time"] = profile.get("birth_time", u.get("birth_time", "00:50"))
            u["birth_date"] = profile.get("birth_date", u.get("birth_date", "1978-05-23"))
            u["is_time_exact"] = profile.get("is_time_exact", u.get("is_time_exact", True))
            u["birth_place"] = profile.get("birth_city", profile.get("birth_place", u.get("birth_place", "Кишинев")))
            u["current_city"] = profile.get("current_city", u.get("current_city", "Кишинев"))
            u["gender"] = profile.get("gender", u.get("gender", "male"))
            u["focus"] = profile.get("focus", u.get("focus", "бизнес, деловые переговоры, финансы и здоровье"))
            if profile.get("timezone"):
                u["timezone"] = profile["timezone"]
            if profile.get("delivery_time"):
                u["delivery_time"] = profile["delivery_time"]
            if personal_chat_id:
                u["telegram_chat_id"] = str(personal_chat_id)
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
            "telegram_chat_id": str(personal_chat_id or ""),
            "birth_date": profile.get("birth_date", "1978-05-23"),
            "birth_time": profile.get("birth_time", "00:50"),
            "is_time_exact": profile.get("is_time_exact", True),
            "birth_place": profile.get("birth_city", "Кишинев"),
            "current_city": profile.get("current_city", "Кишинев"),
            "gender": profile.get("gender", "male"),
            "focus": profile.get("focus", "бизнес, деловые переговоры, финансы и здоровье"),
            "timezone": profile.get("timezone", "Europe/Chisinau"),
            "delivery_time": profile.get("delivery_time", "06:30"),
            "notifications_enabled": True,
            "updated_at": now_iso,
            "created_at": now_iso,
        })

    with open(USERS_REGISTRY_FILE, "w", encoding="utf-8") as f:
        json.dump(users, f, ensure_ascii=False, indent=2)
        f.write("\n")


def _send_tg_reply(token: str, chat_id: str, html_text: str):
    if not token or not chat_id:
        return
    try:
        requests.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={"chat_id": chat_id, "text": html_text, "parse_mode": "HTML"},
            timeout=10,
        )
    except Exception as err:
        print(f"⚠️ Ошибка отправки ответа в Telegram ({chat_id}): {err}")


def sync_from_telegram_updates() -> bool:
    """
    Опрашивает Telegram-бота с учетом сохраненного offset:
    • /start — регистрация подписчика и привязка telegram_chat_id
    • /profile ДД.ММ.ГГГГ ЧЧ:ММ|неизвестно Город_рождения [| Город_проживания]
    • /set_time ЧЧ:ММ — уточнение времени рождения
    • /delivery ЧЧ:ММ [Город_или_IANA_таймзона] — персональное время получения гороскопа в часовом поясе пользователя
    • /update_natal_profile {json}
    """
    import config_loader
    cfg = config_loader.get_config()
    token = cfg.get("telegram_token")
    if not token:
        return False

    last_offset = _load_telegram_offset()
    params = {"timeout": 3}
    if last_offset > 0:
        params["offset"] = last_offset + 1

    url = f"https://api.telegram.org/bot{token}/getUpdates"
    try:
        res = requests.get(url, params=params, timeout=10).json()
        if not res.get("ok"):
            return False

        updates = res.get("result", [])
        if not updates:
            return False

        max_update_id = last_offset
        author_updated = False
        any_updated = False
        personal_id = str(cfg.get("telegram_personal_chat_id", "")).strip()
        author_profile = load_config_profile()

        subscribers = set()
        if SUBSCRIBERS_FILE.exists():
            try:
                with open(SUBSCRIBERS_FILE, "r", encoding="utf-8") as sf:
                    subscribers = set(str(x) for x in json.load(sf))
            except Exception:
                subscribers = set()

        for u in updates:
            upd_id = int(u.get("update_id", 0))
            if upd_id > max_update_id:
                max_update_id = upd_id

            msg = u.get("message") or {}
            text = str(msg.get("text", "")).strip()
            if not text:
                continue

            sender = msg.get("from") or {}
            from_id = str((msg.get("chat") or {}).get("id") or sender.get("id") or "").strip()
            from_name = str(sender.get("first_name") or "Читатель").strip()
            from_username = str(sender.get("username") or "").strip().lstrip("@")
            if not from_id:
                continue

            is_author = bool(personal_id and from_id == personal_id)

            # Регистрируем в списке подписчиков при любом обращении к боту
            if from_id not in subscribers:
                subscribers.add(from_id)
                DATA_USERS_DIR.mkdir(parents=True, exist_ok=True)
                with open(SUBSCRIBERS_FILE, "w", encoding="utf-8") as sf:
                    json.dump(sorted(subscribers), sf, ensure_ascii=False, indent=2)

            # Если пользователь уже есть в реестре по @username, привязываем его telegram_chat_id
            if from_username and not is_author:
                existing_users = get_all_users()
                matched_u = next(
                    (item for item in existing_users if str(item.get("telegram_username", "")).lower() == from_username.lower()),
                    None,
                )
                if matched_u and not matched_u.get("telegram_chat_id"):
                    matched_u["telegram_chat_id"] = from_id
                    register_or_update_user(matched_u)

            if text == "/start" or text.startswith("/start"):
                welcome_text = (
                    f"👋 Здравствуйте, {from_name}!\n\n"
                    f"Добро пожаловать в официальный бот сервиса <b>«Астро Гороскоп»</b>! 🪐\n\n"
                    f"Ваш Telegram Chat ID: <code>{from_id}</code>\n"
                    f"Мы рассчитываем персональный натальный прогноз по дате и точному времени Вашего рождения "
                    f"и доставляем его строго в выбранное Вами время по <b>Вашему местному часовому поясу</b> "
                    f"(даже если у Вас другие сутки относительно сервера — прогноз готовится заранее под Вашу дату!).\n\n"
                    f"💡 <b>Команды настройки персонального гороскопа:</b>\n"
                    f"• <code>/profile ДД.ММ.ГГГГ ЧЧ:ММ Город_рождения | Город_проживания</code>\n"
                    f"  <i>Пример:</i> <code>/profile 15.08.1990 14:30 Киев | Варшава</code>\n"
                    f"  <i>(если время рождения неизвестно, укажите</i> <code>неизвестно</code> <i>вместо ЧЧ:ММ)</i>\n"
                    f"• <code>/delivery ЧЧ:ММ Город_или_пояс</code> — время получения гороскопа по Вашим часам\n"
                    f"  <i>Пример:</i> <code>/delivery 07:15 Владивосток</code> или <code>/delivery 06:30 Europe/Berlin</code>\n"
                    f"• <code>/set_time ЧЧ:ММ</code> — уточнить время рождения"
                )
                _send_tg_reply(token, from_id, welcome_text)
                continue

            # 1. Команда настройки времени доставки и часового пояса: /delivery ЧЧ:ММ [Город/Таймзона]
            delivery_match = re.match(r"^/delivery\s+(\d{1,2}[:.]\d{2})(?:\s+(.+))?$", text, re.IGNORECASE)
            if delivery_match:
                d_time = normalize_time_hhmm(delivery_match.group(1))
                loc_arg = (delivery_match.group(2) or "").strip()
                if not d_time:
                    _send_tg_reply(token, from_id, "⚠️ Укажите корректное время в формате <code>ЧЧ:ММ</code> (например: <code>/delivery 07:00</code>).")
                    continue

                if is_author:
                    author_profile["delivery_time"] = d_time
                    if loc_arg:
                        if "/" in loc_arg or loc_arg.upper().startswith(("UTC", "GMT", "+", "-")):
                            author_profile["timezone"] = loc_arg
                        else:
                            author_profile["current_city"] = loc_arg
                    author_updated = True
                    any_updated = True
                    _, tz_lbl = resolve_user_tzinfo(author_profile)
                else:
                    existing = next((x for x in get_all_users() if str(x.get("telegram_chat_id", "")) == from_id), None) or {}
                    payload = dict(existing)
                    payload["id"] = existing.get("id") or f"usr_tg_{from_id}"
                    payload["name"] = existing.get("name") or from_name
                    payload["telegram_chat_id"] = from_id
                    if from_username:
                        payload["telegram_username"] = from_username
                    payload["delivery_time"] = d_time
                    if loc_arg:
                        if "/" in loc_arg or loc_arg.upper().startswith(("UTC", "GMT", "+", "-")):
                            payload["timezone"] = loc_arg
                        else:
                            payload["current_city"] = loc_arg
                    saved = register_or_update_user(payload)
                    any_updated = True
                    _, tz_lbl = resolve_user_tzinfo(saved)

                _send_tg_reply(
                    token,
                    from_id,
                    f"⏰ <b>Время доставки обновлено!</b>\n\n"
                    f"Ваш гороскоп будет приходить в <b>{d_time}</b> по Вашему местному времени (<b>{tz_lbl}</b>).\n"
                    f"При разнице часовых поясов или раннем утреннем времени прогноз рассчитывается заранее специально под Вашу дату.",
                )
                continue

            # 2. Полное обновление анкеты: /profile ДД.ММ.ГГГГ <ЧЧ:ММ|неизвестно> <Город рождения [| Город проживания]>
            birth_match = re.match(
                r"^(?:/set_birth|/profile)\s+(\d{2}[\.\-\/]\d{2}[\.\-\/]\d{4}|\d{4}-\d{2}-\d{2})\s+(\d{1,2}[:.]\d{2}|неизвестно|unknown|-)(?:\s+(.+))?$",
                text,
                re.IGNORECASE,
            )
            if birth_match:
                raw_bdate, raw_btime, cities_part = birth_match.groups()
                iso_bdate = format_date_iso(raw_bdate)
                if not iso_bdate:
                    _send_tg_reply(token, from_id, "⚠️ Некорректная дата рождения. Используйте формат <code>ДД.ММ.ГГГГ</code>.")
                    continue

                if raw_btime.lower() in ("неизвестно", "unknown", "-"):
                    norm_btime = "12:00"
                    exact_flag = False
                else:
                    norm_btime = normalize_time_hhmm(raw_btime) or "12:00"
                    exact_flag = True

                b_city = ""
                c_city = ""
                if cities_part:
                    if "|" in cities_part:
                        parts_c = [p.strip() for p in cities_part.split("|", 1)]
                        b_city, c_city = parts_c[0], parts_c[1]
                    else:
                        b_city = cities_part.strip()
                        c_city = b_city

                if is_author:
                    author_profile["birth_date"] = iso_bdate
                    author_profile["birth_time"] = norm_btime
                    author_profile["is_time_exact"] = exact_flag
                    if b_city:
                        author_profile["birth_city"] = b_city
                    if c_city:
                        author_profile["current_city"] = c_city
                    author_updated = True
                    any_updated = True
                    target_prof = author_profile
                else:
                    existing = next((x for x in get_all_users() if str(x.get("telegram_chat_id", "")) == from_id), None) or {}
                    payload = dict(existing)
                    payload["id"] = existing.get("id") or f"usr_tg_{from_id}"
                    payload["name"] = existing.get("name") or from_name
                    payload["telegram_chat_id"] = from_id
                    if from_username:
                        payload["telegram_username"] = from_username
                    payload["birth_date"] = iso_bdate
                    payload["birth_time"] = norm_btime
                    payload["is_time_exact"] = exact_flag
                    if b_city:
                        payload["birth_place"] = b_city
                    if c_city:
                        payload["current_city"] = c_city
                    target_prof = register_or_update_user(payload)
                    any_updated = True

                _, tz_lbl = resolve_user_tzinfo(target_prof)
                time_desc = f"<b>{norm_btime}</b> (точный натальный Асцендент)" if exact_flag else "неизвестно (Солнечная космограмма на полдень)"
                _send_tg_reply(
                    token,
                    from_id,
                    f"✨ <b>Натальные данные успешно сохранены!</b>\n\n"
                    f"👤 Имя: {target_prof.get('name', from_name)}\n"
                    f"📅 Дата рождения: <b>{iso_bdate}</b>\n"
                    f"⏰ Время рождения: {time_desc}\n"
                    f"📍 Место рождения: {b_city or target_prof.get('birth_place') or target_prof.get('birth_city') or 'Кишинев'}\n"
                    f"🌍 Текущий часовой пояс: <b>{tz_lbl}</b>",
                )
                continue

            # 3. Быстрое уточнение времени рождения: /set_time ЧЧ:ММ
            time_match = re.search(r"(?:/set_time\s+|время(?:\s*рождения)?[:\s]+)(\d{1,2}[:.]\d{2})", text, re.IGNORECASE)
            if time_match:
                new_time = normalize_time_hhmm(time_match.group(1))
                if new_time:
                    if is_author:
                        author_profile["birth_time"] = new_time
                        author_profile["is_time_exact"] = True
                        author_updated = True
                        any_updated = True
                    else:
                        existing = next((x for x in get_all_users() if str(x.get("telegram_chat_id", "")) == from_id), None) or {}
                        payload = dict(existing)
                        payload["id"] = existing.get("id") or f"usr_tg_{from_id}"
                        payload["name"] = existing.get("name") or from_name
                        payload["telegram_chat_id"] = from_id
                        if from_username:
                            payload["telegram_username"] = from_username
                        payload["birth_time"] = new_time
                        payload["is_time_exact"] = True
                        register_or_update_user(payload)
                        any_updated = True

                    _send_tg_reply(
                        token,
                        from_id,
                        f"✅ Точное время рождения обновлено: <b>{new_time}</b>. Асцендент и дома натальной карты пересчитаны!",
                    )
                continue

            # 4. JSON-синхронизация (только для авторизованного автора или своего профиля)
            if text.startswith("/update_natal_profile"):
                payload_str = text.replace("/update_natal_profile", "", 1).strip()
                try:
                    payload = json.loads(payload_str)
                    if isinstance(payload, dict):
                        if is_author:
                            for k, v in payload.items():
                                if v is not None and v != "":
                                    author_profile[k] = v
                            author_updated = True
                            any_updated = True
                        else:
                            existing = next((x for x in get_all_users() if str(x.get("telegram_chat_id", "")) == from_id), None) or {}
                            merged = dict(existing)
                            merged.update({k: v for k, v in payload.items() if k not in ("id",) and v is not None})
                            merged["id"] = existing.get("id") or f"usr_tg_{from_id}"
                            merged["telegram_chat_id"] = from_id
                            register_or_update_user(merged)
                            any_updated = True
                        _send_tg_reply(token, from_id, "✅ Натальный профиль успешно синхронизирован!")
                except Exception as e:
                    print(f"⚠️ Не удалось распарсить payload из Telegram: {e}")

        if author_updated:
            save_config_profile(author_profile)
            update_registry(author_profile, personal_chat_id=personal_id)
            print("✅ Натальный профиль автора синхронизирован в config.json и users_registry.json!")

        if max_update_id > last_offset:
            _save_telegram_offset(max_update_id)

        return any_updated

    except Exception as e:
        print(f"⚠️ Ошибка при опросе Telegram: {e}")

    return False


def main():
    parser = argparse.ArgumentParser(description="Управление натальным профилем пользователя")
    parser.add_argument("--time", "-t", type=str, help="Новое время рождения (например: 00:50, 14:15)")
    parser.add_argument("--date", "-d", type=str, help="Новая дата рождения (например: 23.05.1978)")
    parser.add_argument("--city", "-c", type=str, help="Город рождения (например: Кишинев)")
    parser.add_argument("--current-city", type=str, help="Город текущего проживания")
    parser.add_argument("--delivery-time", type=str, help="Желаемое время доставки гороскопа по местному времени (например: 06:30)")
    parser.add_argument("--timezone", type=str, help="Часовой пояс IANA (например: Europe/Chisinau, Asia/Vladivostok)")
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
        profile["birth_time"] = normalize_time_hhmm(args.time) or args.time.strip()
        profile["is_time_exact"] = True
        modified = True
    if args.date:
        profile["birth_date"] = format_date_iso(args.date) or args.date.strip()
        modified = True
    if args.city:
        profile["birth_city"] = args.city.strip()
        modified = True
    if args.current_city:
        profile["current_city"] = args.current_city.strip()
        modified = True
    if args.delivery_time:
        profile["delivery_time"] = normalize_time_hhmm(args.delivery_time) or args.delivery_time.strip()
        modified = True
    if args.timezone:
        profile["timezone"] = args.timezone.strip()
        modified = True
    if args.focus:
        profile["focus"] = args.focus.strip()
        modified = True

    if modified:
        save_config_profile(profile)
        update_registry(profile)
        print("✅ Профиль успешно обновлен в config.json и users_registry.json:")
        print(json.dumps(profile, ensure_ascii=False, indent=2))
    elif args.show or len(sys.argv) == 1:
        print("👤 Текущий натальный профиль:")
        print(json.dumps(profile, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
