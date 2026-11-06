"""
Планировщик часовых поясов, опережающей (сдвинутой) генерации и персональной доставки прогнозов.

Решает ключевые задачи:
1. Определение локального времени и календарной даты строго по часовому поясу пользователя
   (IANA timezone, дробное смещение UTC в минутах +5:30/+5:45/-4:00, город пребывания или рождения).
2. Расчет плана опережающей генерации (pre-generation) под конкретную целевую дату (target_date), если:
   - пользователь смещен по часовому поясу в другие календарные сутки относительно сервера (на восток или на запад), ИЛИ
   - выбранное пользователем время доставки (delivery_time) раньше стандартного времени генерации сервера.
3. Кэширование персональных прогнозов с привязкой к хэшу натального профиля (дата/время/место рождения)
   и контроль идемпотентности доставки по каналам (Telegram / Mobile API).
"""

import os
import re
import json
import hashlib
import zoneinfo
from datetime import datetime, timedelta, timezone

from ai_service import (
    normalize_user_profile,
    resolve_user_tzinfo,
    parse_date_parts,
    format_date_dmy,
    format_date_iso,
    normalize_time_hhmm,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
USERS_DATA_DIR = os.path.join(DATA_DIR, "users")
USER_FORECASTS_DIR = os.path.join(DATA_DIR, "user_forecasts")
DELIVERY_STATE_FILE = os.path.join(USERS_DATA_DIR, "delivery_state.json")


def ensure_scheduler_dirs():
    """Создает служебные каталоги для хранения кэша персональных прогнозов и статусов доставки."""
    os.makedirs(USERS_DATA_DIR, exist_ok=True)
    os.makedirs(USER_FORECASTS_DIR, exist_ok=True)


def _ensure_utc(dt: datetime | None = None) -> datetime:
    """Возвращает гарантированно timezone-aware datetime в UTC."""
    if dt is None:
        return datetime.now(timezone.utc)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def resolve_server_tz(server_tz_name: str = "Europe/Chisinau"):
    """Возвращает объект часового пояса сервера (по умолчанию Europe/Chisinau или из переменной окружения SERVER_TIMEZONE)."""
    tz_name = os.getenv("SERVER_TIMEZONE", server_tz_name).strip() or "UTC"
    try:
        return zoneinfo.ZoneInfo(tz_name), tz_name
    except Exception:
        return timezone.utc, "UTC"


def resolve_user_timezone(user_profile: dict | None, fallback_tz: str = "Europe/Chisinau") -> tuple:
    """Возвращает (tzinfo, tz_label) для профиля пользователя."""
    return resolve_user_tzinfo(user_profile, fallback_tz=fallback_tz)


def get_user_local_now(
    user_profile: dict | None,
    now_utc: datetime | None = None,
    fallback_tz: str = "Europe/Chisinau",
) -> datetime:
    """Возвращает текущее локальное время пользователя с учетом его часового пояса."""
    utc_dt = _ensure_utc(now_utc)
    user_tz, _ = resolve_user_tzinfo(user_profile, fallback_tz=fallback_tz)
    return utc_dt.astimezone(user_tz)


def get_user_current_date_str(
    user_profile: dict | None,
    now_utc: datetime | None = None,
    fallback_tz: str = "Europe/Chisinau",
) -> str:
    """Возвращает текущую календарную дату в часовом поясе пользователя в формате DD.MM.YYYY."""
    return get_user_local_now(user_profile, now_utc=now_utc, fallback_tz=fallback_tz).strftime("%d.%m.%Y")


def validate_and_resolve_target_date(
    requested_date: str | None,
    user_profile: dict | None,
    now_utc: datetime | None = None,
    max_past_days: int = 60,
    max_future_days: int = 2,
    fallback_tz: str = "Europe/Chisinau",
) -> tuple[str, str]:
    """
    Определяет и валидирует целевую дату прогноза (возвращает (dmy 'DD.MM.YYYY', iso 'YYYY-MM-DD')).
    Если дата не передана — берется текущая дата в часовом поясе пользователя.
    Разрешает опережающий запрос до +2 суток вперед (для предзагрузки перед полуночью/утром).
    """
    user_now = get_user_local_now(user_profile, now_utc=now_utc, fallback_tz=fallback_tz)
    user_today = user_now.date()

    if requested_date and str(requested_date).strip():
        parsed = parse_date_parts(requested_date)
        if not parsed:
            raise ValueError(f"Некорректный формат даты: {requested_date}")
        candidate = datetime(parsed[0], parsed[1], parsed[2]).date()
        delta_days = (candidate - user_today).days
        if not (-max_past_days <= delta_days <= max_future_days):
            raise ValueError(
                f"Дата {requested_date} выходит за допустимый диапазон [-{max_past_days}, +{max_future_days}] дней"
            )
        return candidate.strftime("%d.%m.%Y"), candidate.strftime("%Y-%m-%d")

    return user_today.strftime("%d.%m.%Y"), user_today.strftime("%Y-%m-%d")


def compute_profile_hash(user_profile: dict | None, lang: str = "ru") -> str:
    """
    Вычисляет детерминированный короткий хэш натальных параметров пользователя.
    При любом изменении даты/времени рождения, признака точности времени, города или языка
    хэш меняется, что автоматически инвалидирует старый кэш прогноза.
    """
    norm = normalize_user_profile(user_profile)
    _, tz_label = resolve_user_tzinfo(norm)
    canonical = {
        "name": norm["name"],
        "birth_date": norm["birth_date"],
        "birth_time": norm["birth_time"],
        "is_time_exact": norm["is_time_exact"],
        "birth_city": norm["birth_city"],
        "current_city": norm["current_city"],
        "gender": norm["gender"].lower(),
        "focus": norm["focus"],
        "tz": tz_label,
        "lang": (lang or norm["lang"] or "ru").lower(),
    }
    raw = json.dumps(canonical, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def compute_user_delivery_plan(
    user_profile: dict | None,
    now_utc: datetime | None = None,
    default_delivery_time: str = "07:30",
    server_generation_time: str = "06:30",
    server_tz_name: str = "Europe/Chisinau",
    lead_minutes: int = 60,
    advance_lead_minutes: int = 480,
    grace_minutes: int = 240,
    last_delivered_date: str | None = None,
) -> dict:
    """
    Вычисляет расписание генерации и отправки прогноза для конкретного пользователя.

    Логика опережающей генерации:
    - Время отправки (delivery_time) интерпретируется СТРОГО в часовом поясе пользователя.
    - Определяется ближайший актуальный слот отправки в локальном времени пользователя
      и его точная календарная дата `target_date` (DD.MM.YYYY).
    - Если пользователь смещен по часовому поясу в другие сутки относительно сервера
      (`is_shifted_day_vs_server`) ИЛИ его время отправки наступает раньше времени генерации сервера
      (`is_before_server_generation`), активируется расширенное окно заблаговременной генерации
      (`advance_lead_minutes`, по умолчанию за 8 часов до локального момента доставки) строго на `target_date`.
    """
    utc_now = _ensure_utc(now_utc)
    norm = normalize_user_profile(user_profile)

    try:
        server_tz = zoneinfo.ZoneInfo(server_tz_name)
    except Exception:
        server_tz = timezone.utc
        server_tz_name = "UTC"

    user_tz, user_tz_label = resolve_user_tzinfo(norm, fallback_tz=server_tz_name)

    user_now = utc_now.astimezone(user_tz)
    server_now = utc_now.astimezone(server_tz)

    delivery_hhmm = (
        norm["delivery_time"]
        or normalize_time_hhmm(default_delivery_time)
        or "07:30"
    )
    deliv_h, deliv_m = [int(x) for x in delivery_hhmm.split(":")]

    srv_hhmm = normalize_time_hhmm(server_generation_time) or "06:30"
    srv_h, srv_m = [int(x) for x in srv_hhmm.split(":")]

    last_deliv_dmy = format_date_dmy(last_delivered_date) if last_delivered_date else ""

    # Слот сегодняшних суток по локальным часам пользователя
    today_slot_local = datetime(
        user_now.year, user_now.month, user_now.day, deliv_h, deliv_m, tzinfo=user_tz
    )
    today_slot_utc = today_slot_local.astimezone(timezone.utc)
    today_dmy = today_slot_local.strftime("%d.%m.%Y")

    # Если за сегодняшние локальные сутки прогноз уже доставлен ИЛИ окно доставки (+grace_minutes) уже прошло,
    # планируем следующий слот — завтрашние сутки в часовом поясе пользователя (например, для слотов 00:15 или утренних слотов восточных поясов)
    if last_deliv_dmy == today_dmy or utc_now > today_slot_utc + timedelta(minutes=grace_minutes):
        next_day = user_now.date() + timedelta(days=1)
        target_slot_local = datetime(
            next_day.year, next_day.month, next_day.day, deliv_h, deliv_m, tzinfo=user_tz
        )
    else:
        target_slot_local = today_slot_local

    target_slot_utc = target_slot_local.astimezone(timezone.utc)
    target_date = target_slot_local.strftime("%d.%m.%Y")
    target_iso_date = target_slot_local.strftime("%Y-%m-%d")
    target_archive_key = target_slot_local.strftime("%Y_%m_%d")

    # Стандартный момент генерации сервера для тех же календарных суток target_slot_local.date()
    server_gen_local_for_target = datetime(
        target_slot_local.year,
        target_slot_local.month,
        target_slot_local.day,
        srv_h,
        srv_m,
        tzinfo=server_tz,
    )
    server_gen_utc_for_target = server_gen_local_for_target.astimezone(timezone.utc)

    # Условие 1: Пользователь или целевая дата доставки смещены в другие сутки относительно сервера
    is_shifted_day_vs_server = (
        target_slot_local.date() != server_now.date()
        or user_now.date() != server_now.date()
    )

    # Условие 2: Момент доставки наступает раньше момента генерации на сервере (в абсолютном UTC или по локальным часам)
    is_before_server_generation = (
        target_slot_utc < server_gen_utc_for_target
        or (deliv_h, deliv_m) < (srv_h, srv_m)
    )

    requires_advance_generation = is_shifted_day_vs_server or is_before_server_generation

    effective_lead_mins = advance_lead_minutes if requires_advance_generation else lead_minutes
    pregen_start_utc = target_slot_utc - timedelta(minutes=effective_lead_mins)

    # Для обычных дневных слотов в те же сутки разрешаем генерацию также вместе с общим утренним запуском сервера
    if not requires_advance_generation and target_slot_local.date() == server_now.date():
        pregen_start_utc = min(pregen_start_utc, server_gen_utc_for_target)

    already_delivered = last_deliv_dmy == target_date
    notifications_enabled = norm["notifications_enabled"]
    delivery_deadline_utc = target_slot_utc + timedelta(minutes=grace_minutes)

    should_generate_now = (
        not already_delivered
        and pregen_start_utc <= utc_now <= delivery_deadline_utc
    )
    should_deliver_now = (
        notifications_enabled
        and not already_delivered
        and target_slot_utc <= utc_now <= delivery_deadline_utc
    )

    minutes_until_delivery = round((target_slot_utc - utc_now).total_seconds() / 60.0, 1)

    return {
        "user_timezone": user_tz_label,
        "server_timezone": server_tz_name,
        "delivery_time": delivery_hhmm,
        "server_generation_time": srv_hhmm,
        "user_local_now": user_now.isoformat(),
        "server_local_now": server_now.isoformat(),
        "user_current_date": user_now.strftime("%d.%m.%Y"),
        "server_current_date": server_now.strftime("%d.%m.%Y"),
        "target_date": target_date,
        "target_iso_date": target_iso_date,
        "target_archive_key": target_archive_key,
        "target_delivery_local": target_slot_local.isoformat(),
        "target_delivery_utc": target_slot_utc.isoformat(),
        "pregeneration_start_utc": pregen_start_utc.isoformat(),
        "is_shifted_day_vs_server": is_shifted_day_vs_server,
        "is_before_server_generation": is_before_server_generation,
        "requires_advance_generation": requires_advance_generation,
        "already_delivered": already_delivered,
        "should_generate_now": should_generate_now,
        "should_deliver_now": should_deliver_now,
        "minutes_until_delivery": minutes_until_delivery,
    }


def compute_zodiac_target_dates(
    now_utc: datetime | None = None,
    server_tz_name: str = "Europe/Chisinau",
    east_horizon_hours: int = 15,
) -> dict:
    """
    Определяет список календарных дат (DD.MM.YYYY), для которых к текущему моменту
    должны быть подготовлены общие прогнозы 12 знаков зодиака.
    Учитывает самый ранний часовой пояс Земли (UTC+14 + запас 1 час = +15ч от UTC),
    чтобы пользователи Дальнего Востока, Азии и Океании получали прогноз на новый день заранее.
    """
    utc_now = _ensure_utc(now_utc)
    try:
        server_tz = zoneinfo.ZoneInfo(server_tz_name)
    except Exception:
        server_tz = timezone.utc

    server_today_date = utc_now.astimezone(server_tz).date()
    server_today_dmy = server_today_date.strftime("%d.%m.%Y")

    east_date = (utc_now + timedelta(hours=east_horizon_hours)).date()
    east_dmy = east_date.strftime("%d.%m.%Y")

    dates = [server_today_dmy]
    if east_dmy not in dates:
        dates.append(east_dmy)

    return {
        "server_today": server_today_dmy,
        "dates_to_ensure": dates,
    }


# ─── Локальное хранилище состояния доставки и кэша прогнозов (для бота и CLI) ───

def _safe_id(raw_id: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_\-]", "_", str(raw_id or "default"))[:64]


def load_delivery_state() -> dict:
    ensure_scheduler_dirs()
    if not os.path.exists(DELIVERY_STATE_FILE):
        return {}
    try:
        with open(DELIVERY_STATE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_delivery_state(state: dict):
    ensure_scheduler_dirs()
    with open(DELIVERY_STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def get_last_delivered_date(user_id: str, channel: str = "telegram") -> str:
    state = load_delivery_state()
    key = f"{channel}:{_safe_id(user_id)}"
    entry = state.get(key, {})
    return entry.get("last_delivered_date", "") if isinstance(entry, dict) else ""


def mark_user_delivered(user_id: str, target_date: str, channel: str = "telegram"):
    state = load_delivery_state()
    key = f"{channel}:{_safe_id(user_id)}"
    state[key] = {
        "last_delivered_date": format_date_dmy(target_date) or target_date,
        "delivered_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    save_delivery_state(state)


def get_cached_user_forecast(
    user_id: str,
    target_date: str,
    lang: str = "ru",
    profile_hash: str | None = None,
) -> dict | None:
    """Возвращает ранее сгенерированный персональный прогноз из локального кэша, если хэш натальных данных совпадает."""
    ensure_scheduler_dirs()
    iso_key = format_date_iso(target_date).replace("-", "_")
    if not iso_key:
        return None
    lang_clean = (lang or "ru").strip().lower()
    fname = f"{_safe_id(user_id)}_{iso_key}_{lang_clean}.json"
    fpath = os.path.join(USER_FORECASTS_DIR, fname)
    if not os.path.exists(fpath):
        return None
    try:
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)
        if profile_hash and data.get("profile_hash") and data.get("profile_hash") != profile_hash:
            return None
        if not data.get("raw_text"):
            return None
        return data
    except Exception:
        return None


def save_cached_user_forecast(
    user_id: str,
    target_date: str,
    lang: str,
    profile_hash: str,
    payload: dict,
) -> str:
    """Сохраняет сгенерированный персональный прогноз в локальный кэш и очищает записи старше 14 дней."""
    ensure_scheduler_dirs()
    iso_key = format_date_iso(target_date).replace("-", "_")
    lang_clean = (lang or "ru").strip().lower()
    fname = f"{_safe_id(user_id)}_{iso_key}_{lang_clean}.json"
    fpath = os.path.join(USER_FORECASTS_DIR, fname)

    record = dict(payload)
    record["user_id"] = str(user_id)
    record["date"] = format_date_dmy(target_date) or target_date
    record["iso_date"] = format_date_iso(target_date)
    record["lang"] = lang_clean
    record["profile_hash"] = profile_hash
    record["cached_at_utc"] = datetime.now(timezone.utc).isoformat()

    with open(fpath, "w", encoding="utf-8") as f:
        json.dump(record, f, ensure_ascii=False, indent=2)

    _prune_user_forecasts_cache(max_age_days=14)
    return fpath


def _prune_user_forecasts_cache(max_age_days: int = 14):
    """Удаляет временные кэш-файлы персональных прогнозов старше max_age_days."""
    if not os.path.exists(USER_FORECASTS_DIR):
        return
    cutoff = datetime.now(timezone.utc).timestamp() - max_age_days * 86400
    for name in os.listdir(USER_FORECASTS_DIR):
        if not name.endswith(".json"):
            continue
        p = os.path.join(USER_FORECASTS_DIR, name)
        try:
            if os.path.getmtime(p) < cutoff:
                os.remove(p)
        except OSError:
            pass

