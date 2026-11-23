import ipaddress
import logging
import os
import re
import sys
import time
import hmac
import json
from collections import defaultdict, deque
from datetime import datetime, timezone
from typing import Any, Optional
from urllib.parse import urlparse

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import firebase_admin
from firebase_admin import auth, credentials, firestore
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
from dotenv import load_dotenv

from ai_service import generate_horoscope_text, has_unwanted_cyrillic, normalize_user_profile
from archive_service import parse_horoscope_structure
from telegram_service import send_text_message
from timezone_scheduler import (
    compute_profile_hash,
    compute_user_delivery_plan,
    resolve_user_timezone,
    validate_and_resolve_target_date,
)

load_dotenv()

logger = logging.getLogger("cosmic_horoscope_api")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO)

# Инициализация Firebase Admin SDK (безопасная при локальном импорте и тестах)
firebase_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
if firebase_cred_path and os.path.exists(firebase_cred_path):
    cred = credentials.Certificate(firebase_cred_path)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
else:
    try:
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
    except Exception as e:
        logger.warning("Отложенная инициализация Firebase: %s", e)

_db_client = None


def get_db():
    """Ленивое получение клиента Firestore (не падает при импорте модуля в unit-тестах без GCP-ключей)."""
    global _db_client
    if _db_client is None:
        _db_client = firestore.client()
    return _db_client


app = FastAPI(title="Cosmic Horoscope API", version="1.3.0")

# ==============================================================================
# Настройка CORS для Web PWA (Firebase Hosting) и локальной разработки
# ==============================================================================
_default_cors_origins = [
    "https://cosmic-horoscope-ru.web.app",
    "https://cosmic-horoscope-ru.firebaseapp.com",
]
_env_cors = os.getenv("CORS_ALLOWED_ORIGINS", "").strip()
_cors_origins = (
    [o.strip() for o in _env_cors.split(",") if o.strip()]
    if _env_cors
    else _default_cors_origins
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Scheduler-Secret"],
)

# ==============================================================================
# Константы безопасности, квот и поддерживаемых языков
# ==============================================================================
SUPPORTED_LANGS = {"ru", "en", "es", "de", "fr"}
MAX_DAILY_AI_GENERATIONS = max(1, int(os.getenv("MAX_DAILY_AI_GENERATIONS", "12")))
BURST_RATE_WINDOW_SEC = 60
BURST_RATE_MAX_CALLS = 15
_burst_requests: dict[str, deque[float]] = defaultdict(deque)

# ==============================================================================
# Web Push (VAPID) для Apple iPhone (iOS 16.4+) и браузеров
# Секретный ключ НЕ имеет дефолтного значения в коде — задается строго через env/Secret Manager
# ==============================================================================
VAPID_PUBLIC_KEY = os.getenv("VAPID_PUBLIC_KEY", "").strip()
VAPID_PRIVATE_KEY = os.getenv("VAPID_PRIVATE_KEY", "").strip()
VAPID_CLAIMS = {"sub": os.getenv("VAPID_SUB", "mailto:oleg.sidorenco@gmail.com")}


def _check_burst_rate_limit(key: str, max_calls: int = BURST_RATE_MAX_CALLS, window_sec: int = BURST_RATE_WINDOW_SEC):
    now = time.monotonic()
    q = _burst_requests[key]
    while q and now - q[0] > window_sec:
        q.popleft()
    if len(q) >= max_calls:
        raise HTTPException(status_code=429, detail="Too many requests. Please try again shortly.")
    q.append(now)


def _sanitize_text_field(val: Optional[str], max_len: int) -> Optional[str]:
    if val is None:
        return None
    cleaned = re.sub(r"[\x00-\x1f\x7f<>`{}]", " ", str(val))
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned[:max_len]


def sanitize_web_push_subscription(sub: Any) -> dict:
    """Проверяет и нормализует Web Push подписку (защита от SSRF и произвольных данных в Firestore)."""
    if not isinstance(sub, dict):
        raise HTTPException(status_code=400, detail="Invalid push subscription payload")

    endpoint = str(sub.get("endpoint") or "").strip()
    if not endpoint or len(endpoint) > 2048:
        raise HTTPException(status_code=400, detail="Invalid push endpoint")

    parsed = urlparse(endpoint)
    hostname = (parsed.hostname or "").strip().lower()
    if parsed.scheme != "https" or not hostname:
        raise HTTPException(status_code=400, detail="Push endpoint must use HTTPS")

    blocked_hosts = {"localhost", "127.0.0.1", "0.0.0.0", "metadata.google.internal", "metadata"}
    if hostname in blocked_hosts or hostname.endswith(".local") or hostname.endswith(".internal"):
        raise HTTPException(status_code=400, detail="Forbidden push endpoint host")

    try:
        ip_obj = ipaddress.ip_address(hostname)
        if (
            ip_obj.is_private
            or ip_obj.is_loopback
            or ip_obj.is_link_local
            or ip_obj.is_reserved
            or ip_obj.is_multicast
        ):
            raise HTTPException(status_code=400, detail="Forbidden push endpoint IP")
    except ValueError:
        pass

    keys = sub.get("keys")
    if not isinstance(keys, dict):
        raise HTTPException(status_code=400, detail="Missing push subscription keys")

    p256dh = str(keys.get("p256dh") or "").strip()
    auth_key = str(keys.get("auth") or "").strip()
    if not p256dh or not auth_key or len(p256dh) > 512 or len(auth_key) > 512:
        raise HTTPException(status_code=400, detail="Invalid push subscription keys")

    clean_sub: dict[str, Any] = {
        "endpoint": endpoint,
        "keys": {
            "p256dh": p256dh,
            "auth": auth_key,
        },
    }
    if sub.get("expirationTime") is not None:
        clean_sub["expirationTime"] = sub.get("expirationTime")
    return clean_sub


def send_web_push(subscription_info: dict, title: str, body: str, url: str = "https://cosmic-horoscope-ru.web.app") -> bool:
    """Отправка системного Web Push уведомления на Apple iPhone (iOS 16.4+) или в браузер."""
    if not VAPID_PRIVATE_KEY:
        logger.error("Web Push disabled: VAPID_PRIVATE_KEY is not configured")
        return False
    if not subscription_info or not isinstance(subscription_info, dict):
        return False
    try:
        safe_sub = sanitize_web_push_subscription(subscription_info)
        from pywebpush import webpush

        payload = json.dumps({
            "title": title,
            "body": body,
            "url": url,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        webpush(
            subscription_info=safe_sub,
            data=payload,
            vapid_private_key=VAPID_PRIVATE_KEY,
            vapid_claims=VAPID_CLAIMS,
            timeout=10,
        )
        return True
    except Exception as e:
        logger.warning("Ошибка отправки Web Push: %s", e)
        return False


class ProfilePayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: Optional[str] = Field(default=None, max_length=80)
    birthDate: Optional[str] = Field(default=None, max_length=40)
    birth_date: Optional[str] = Field(default=None, max_length=40)
    birthTime: Optional[str] = Field(default=None, max_length=16)
    birth_time: Optional[str] = Field(default=None, max_length=16)
    isTimeExact: Optional[bool] = None
    is_time_exact: Optional[bool] = None
    birthPlace: Optional[str] = Field(default=None, max_length=100)
    birth_place: Optional[str] = Field(default=None, max_length=100)
    birth_city: Optional[str] = Field(default=None, max_length=100)
    currentCity: Optional[str] = Field(default=None, max_length=100)
    current_city: Optional[str] = Field(default=None, max_length=100)
    city: Optional[str] = Field(default=None, max_length=100)
    gender: Optional[str] = Field(default=None, max_length=20)
    focus: Optional[str] = Field(default=None, max_length=240)
    timezone: Optional[str] = Field(default=None, max_length=64)
    timeZone: Optional[str] = Field(default=None, max_length=64)
    utcOffsetMinutes: Optional[int] = Field(default=None, ge=-840, le=840)
    utc_offset_minutes: Optional[int] = Field(default=None, ge=-840, le=840)
    deliveryTime: Optional[str] = Field(default=None, max_length=16)
    delivery_time: Optional[str] = Field(default=None, max_length=16)
    notificationsEnabled: Optional[bool] = None
    notifications_enabled: Optional[bool] = None
    lang: Optional[str] = Field(default=None, max_length=10)
    language: Optional[str] = Field(default=None, max_length=10)


class WebPushSubscribeRequest(BaseModel):
    user_id: Optional[str] = Field(default=None, max_length=128)
    subscription: dict
    user_agent: Optional[str] = Field(default=None, max_length=300)


class WebPushTestRequest(BaseModel):
    user_id: Optional[str] = Field(default=None, max_length=128)


class HoroscopeTopicItem(BaseModel):
    title: str
    icon: str = "✨"
    content: str


class HoroscopeRequest(BaseModel):
    lang: str = Field(default="ru", max_length=10)
    timezone: Optional[str] = Field(default=None, max_length=64)
    utc_offset_minutes: Optional[int] = Field(default=None, ge=-840, le=840)
    target_date: Optional[str] = Field(default=None, max_length=40)
    delivery_time: Optional[str] = Field(default=None, max_length=16)
    notifications_enabled: Optional[bool] = None
    force_refresh: bool = False
    profile: Optional[ProfilePayload] = None


class HoroscopeResponse(BaseModel):
    horoscope: str
    date: str
    iso_date: str = ""
    greeting: str = ""
    topics: list[HoroscopeTopicItem] = Field(default_factory=list)
    updated_at: str = ""
    user_timezone: str = ""
    cached: bool = False


def verify_firebase_token(authorization: Optional[str] = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    token = authorization.split("Bearer ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Empty authentication token")
    try:
        return auth.verify_id_token(token)
    except Exception as e:
        logger.warning("Firebase ID token verification failed: %s", e)
        raise HTTPException(status_code=401, detail="Invalid or expired authentication token")


def verify_scheduler_secret(x_scheduler_secret: Optional[str] = Header(default=None)):
    expected = os.getenv("SCHEDULER_SECRET", "").strip()
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="SCHEDULER_SECRET is not configured on the server",
        )
    if not x_scheduler_secret or not hmac.compare_digest(x_scheduler_secret.strip(), expected):
        raise HTTPException(status_code=403, detail="Invalid scheduler secret")
    return True


@app.get("/")
def read_root():
    return {
        "status": "ok",
        "message": "Cosmic Horoscope API is running",
        "version": "1.3.0",
    }


@app.get("/app/latest-version")
def get_app_latest_version():
    return {
        "version": "1.0.33",
        "build_number": 33,
        "tag": "app-v1.0.33",
        "download_url": "https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/download/app-v1.0.33/Horoscope-for-all-ru.apk",
        "release_url": "https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/tag/app-v1.0.33",
        "release_notes": {
            "fr": "✨ Version 1.0.33 :\n• Saisie directe de la date et de l'heure de naissance avec séparateurs automatiques (JJ.MM.AAAA et HH:MM) et validation stricte.\n• Sélection visuelle toujours disponible via les icônes calendrier et horloge.\n• Nettoyage du workflow de déploiement Web.",
            "en": "✨ Version 1.0.33:\n• Direct birth date and time entry with automatic separators (DD.MM.YYYY and HH:MM) and strict validation.\n• Calendar and clock pickers remain available via field icons.\n• Clean Firebase Hosting deploy workflow.",
            "es": "✨ Versión 1.0.33:\n• Entrada directa de fecha y hora de nacimiento con separadores automáticos (DD.MM.AAAA y HH:MM) y validación estricta.\n• Los selectores visuales de calendario y reloj siguen disponibles mediante los iconos.\n• Flujo de despliegue web limpio.",
            "de": "✨ Version 1.0.33:\n• Direkte Eingabe von Geburtsdatum und -zeit mit automatischen Trennzeichen (TT.MM.JJJJ und SS:MM) und strenger Prüfung.\n• Kalender- und Uhr-Auswahl weiterhin über die Symbole verfügbar.\n• Bereinigter Web-Deploy-Workflow.",
            "ru": "✨ Версия 1.0.33:\n• Прямой ввод даты и времени рождения с автоматической расстановкой разделителей (ДД.ММ.ГГГГ и ЧЧ:ММ) и строгой проверкой календаря.\n• Выбор через календарь и циферблат по-прежнему доступен по иконкам справа в полях.\n• Очистка конфигурации автодеплоя веб-версии."
        }
    }


@app.post("/horoscope/personal", response_model=HoroscopeResponse)
def get_personal_horoscope(
    req: HoroscopeRequest,
    user_token: dict = Depends(verify_firebase_token),
):
    user_id = user_token.get("uid")
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing uid in token")

    _check_burst_rate_limit(f"personal:{user_id}")

    gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not gemini_api_key:
        raise HTTPException(status_code=500, detail="AI service is not configured")

    db = get_db()
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists and not req.profile:
        raise HTTPException(status_code=404, detail="User profile not found")

    raw_profile = (user_doc.to_dict() if user_doc.exists else {}) or {}
    merged_profile = dict(raw_profile)
    if req.profile is not None:
        profile_dict = req.profile.model_dump(exclude_none=True)
        for text_key, max_l in (
            ("name", 80),
            ("birthPlace", 100),
            ("birth_place", 100),
            ("birth_city", 100),
            ("currentCity", 100),
            ("current_city", 100),
            ("city", 100),
            ("focus", 240),
            ("gender", 20),
            ("timezone", 64),
            ("timeZone", 64),
        ):
            if text_key in profile_dict:
                profile_dict[text_key] = _sanitize_text_field(profile_dict[text_key], max_l)

        for k, v in profile_dict.items():
            if v is not None and v != "":
                merged_profile[k] = v

    # Синхронизируем переданные клиентом настройки часового пояса, времени доставки и языка
    metadata_updates = {}
    lang_candidate = (req.lang or raw_profile.get("lang") or "ru").strip().lower()
    lang_clean = lang_candidate if lang_candidate in SUPPORTED_LANGS else "ru"
    if lang_clean and raw_profile.get("lang") != lang_clean:
        merged_profile["lang"] = lang_clean
        metadata_updates["lang"] = lang_clean

    if req.timezone and req.timezone.strip():
        tz_clean = _sanitize_text_field(req.timezone, 64) or ""
        if tz_clean:
            merged_profile["timezone"] = tz_clean
            if raw_profile.get("timezone") != tz_clean:
                metadata_updates["timezone"] = tz_clean

    if req.utc_offset_minutes is not None and -840 <= req.utc_offset_minutes <= 840:
        merged_profile["utcOffsetMinutes"] = req.utc_offset_minutes
        if raw_profile.get("utcOffsetMinutes") != req.utc_offset_minutes:
            metadata_updates["utcOffsetMinutes"] = req.utc_offset_minutes

    if req.delivery_time and req.delivery_time.strip():
        d_clean = req.delivery_time.strip()[:16]
        merged_profile["deliveryTime"] = d_clean
        if raw_profile.get("deliveryTime") != d_clean:
            metadata_updates["deliveryTime"] = d_clean

    if req.notifications_enabled is not None:
        merged_profile["notificationsEnabled"] = req.notifications_enabled
        if raw_profile.get("notificationsEnabled") != req.notifications_enabled:
            metadata_updates["notificationsEnabled"] = req.notifications_enabled

    if metadata_updates:
        metadata_updates["lastSeenAt"] = datetime.now(timezone.utc).isoformat()
        try:
            user_ref.set(metadata_updates, merge=True)
        except Exception as sync_err:
            logger.warning("Не удалось обновить метаданные пользователя %s: %s", user_id, sync_err)

    norm_profile = normalize_user_profile(merged_profile)
    _, user_tz_label = resolve_user_timezone(norm_profile, fallback_tz="UTC")

    # Вычисляем целевую дату строго по часовому поясу пользователя (с поддержкой предгенерации до +2 дней)
    try:
        target_dmy, target_iso = validate_and_resolve_target_date(
            req.target_date,
            norm_profile,
            fallback_tz="UTC",
        )
    except ValueError as date_err:
        raise HTTPException(status_code=400, detail=str(date_err))

    profile_hash = compute_profile_hash(norm_profile, lang=lang_clean)
    cache_doc_id = f"{target_iso}_{lang_clean}"
    cache_ref = user_ref.collection("horoscopes").document(cache_doc_id)

    if not req.force_refresh:
        try:
            cached_doc = cache_ref.get()
            if cached_doc.exists:
                c_data = cached_doc.to_dict() or {}
                raw_cached = c_data.get("raw_text", "")
                if (
                    c_data.get("profile_hash") == profile_hash
                    and raw_cached
                    and not has_unwanted_cyrillic(raw_cached, lang_clean)
                ):
                    return HoroscopeResponse(
                        horoscope=raw_cached,
                        date=c_data.get("date", target_dmy),
                        iso_date=c_data.get("iso_date", target_iso),
                        greeting=c_data.get("greeting", ""),
                        topics=c_data.get("topics", []),
                        updated_at=c_data.get("updated_at", ""),
                        user_timezone=user_tz_label,
                        cached=True,
                    )
        except Exception as cache_err:
            logger.warning("Ошибка чтения кэша Firestore для %s: %s", user_id, cache_err)

    # Суточный лимит на генерации ИИ (защита квоты и биллинга от злоупотреблений force_refresh)
    today_utc_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    gen_date = str(raw_profile.get("aiGenDate") or "")
    gen_count = int(raw_profile.get("aiGenCount") or 0) if gen_date == today_utc_str else 0
    if gen_count >= MAX_DAILY_AI_GENERATIONS:
        raise HTTPException(
            status_code=429,
            detail="Daily AI generation limit reached for this account",
        )

    try:
        horoscope_text = generate_horoscope_text(
            api_key=gemini_api_key,
            user_profile=norm_profile,
            lang=lang_clean,
            target_date=target_dmy,
        )
    except Exception as e:
        logger.error("AI generation error for %s: %s", user_id, e)
        raise HTTPException(status_code=500, detail="Failed to generate horoscope")

    parsed = parse_horoscope_structure(horoscope_text, target_dmy)
    cache_payload = {
        "date": target_dmy,
        "iso_date": target_iso,
        "lang": lang_clean,
        "profile_hash": profile_hash,
        "user_timezone": user_tz_label,
        "greeting": parsed["greeting"],
        "raw_text": parsed["raw_text"],
        "topics": parsed["topics"],
        "updated_at": parsed["updated_at"],
    }
    try:
        cache_ref.set(cache_payload)
        user_ref.set(
            {
                "aiGenDate": today_utc_str,
                "aiGenCount": gen_count + 1,
            },
            merge=True,
        )
    except Exception as save_err:
        logger.warning("Не удалось сохранить кэш гороскопа для %s: %s", user_id, save_err)

    return HoroscopeResponse(
        horoscope=parsed["raw_text"],
        date=target_dmy,
        iso_date=target_iso,
        greeting=parsed["greeting"],
        topics=parsed["topics"],
        updated_at=parsed["updated_at"],
        user_timezone=user_tz_label,
        cached=False,
    )


def _localized_push_title_and_fallback(lang: str, target_dmy: str) -> tuple[str, str]:
    titles = {
        "fr": (f"✨ Horoscope du {target_dmy}", "Votre prévision astrologique personnelle est prête !"),
        "en": (f"✨ Horoscope for {target_dmy}", "Your personal astrological forecast is ready!"),
        "es": (f"✨ Horóscopo del {target_dmy}", "¡Tu pronóstico astrológico personal ya está listo!"),
        "de": (f"✨ Horoskop für {target_dmy}", "Ihre persönliche astrologische Prognose ist bereit!"),
        "ru": (f"✨ Гороскоп на {target_dmy}", "Твой персональный астрологический прогноз уже готов! Открой приложение."),
    }
    return titles.get(lang, titles["ru"])


@app.post("/scheduler/tick")
def scheduler_tick(_authorized: bool = Depends(verify_scheduler_secret)):
    """
    Периодический серверный тик (например, раз в 15 минут через Cloud Scheduler):
    1. Проверяет часовой пояс и желаемое время доставки каждого пользователя.
    2. Если пользователь смещен в другие сутки относительно сервера или его время отправки
       раньше стандартного времени генерации — ЗАРАНЕЕ генерирует персональный прогноз
       строго под целевую дату (target_date) и сохраняет в Firestore.
    3. При наступлении локального времени отправки доставляет прогноз в Telegram и Web Push.
    """
    gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not gemini_api_key:
        raise HTTPException(status_code=500, detail="AI service is not configured")

    telegram_token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip() or os.getenv("TELEGRAM_TOKEN", "").strip()
    server_tz_name = os.getenv("SERVER_TIMEZONE", "UTC").strip() or "UTC"
    server_gen_time = os.getenv("SERVER_GENERATION_TIME", "06:30").strip() or "06:30"

    db = get_db()
    now_utc = datetime.now(timezone.utc)

    checked = 0
    pregenerated = 0
    delivered_tg = 0
    delivered_web = 0
    errors = []

    for doc in db.collection("users").stream():
        checked += 1
        uid = doc.id
        raw_profile = doc.to_dict() or {}
        norm = normalize_user_profile(raw_profile)
        if not norm.get("birth_date"):
            continue

        lang_clean = norm.get("lang") or "ru"
        if lang_clean not in SUPPORTED_LANGS:
            lang_clean = "ru"

        tg_chat_id = norm.get("telegram_chat_id")
        web_sub = raw_profile.get("web_push_subscription")
        web_enabled = raw_profile.get("web_notifications_enabled", True)

        tg_last = raw_profile.get("lastDeliveredDateTg") or raw_profile.get("lastDeliveredDate") or raw_profile.get("last_delivered_date")
        web_last = raw_profile.get("lastDeliveredDateWeb") or raw_profile.get("lastDeliveredDate") or raw_profile.get("last_delivered_date")

        # Для выбора общего слота учитываем самый отстающий канал, чтобы доставка не пропускалась
        effective_last = raw_profile.get("lastDeliveredDate") or raw_profile.get("last_delivered_date")
        plan = compute_user_delivery_plan(
            norm,
            now_utc=now_utc,
            default_delivery_time="07:30",
            server_generation_time=server_gen_time,
            server_tz_name=server_tz_name,
            last_delivered_date=effective_last,
        )

        if not plan["should_generate_now"] and not plan["should_deliver_now"]:
            continue

        target_dmy = plan["target_date"]
        target_iso = plan["target_iso_date"]
        profile_hash = compute_profile_hash(norm, lang=lang_clean)
        cache_ref = db.collection("users").document(uid).collection("horoscopes").document(f"{target_iso}_{lang_clean}")

        raw_text = ""
        greeting_text = ""
        try:
            cached_snap = cache_ref.get()
            if cached_snap.exists:
                c_data = cached_snap.to_dict() or {}
                cand_text = c_data.get("raw_text", "")
                if (
                    c_data.get("profile_hash") == profile_hash
                    and cand_text
                    and not has_unwanted_cyrillic(cand_text, lang_clean)
                ):
                    raw_text = cand_text
                    greeting_text = c_data.get("greeting", "") or ""

            if not raw_text:
                raw_text = generate_horoscope_text(
                    api_key=gemini_api_key,
                    user_profile=norm,
                    lang=lang_clean,
                    target_date=target_dmy,
                )
                parsed = parse_horoscope_structure(raw_text, target_dmy)
                greeting_text = parsed.get("greeting", "") or ""
                cache_ref.set({
                    "date": target_dmy,
                    "iso_date": target_iso,
                    "lang": lang_clean,
                    "profile_hash": profile_hash,
                    "user_timezone": plan["user_timezone"],
                    "greeting": greeting_text,
                    "raw_text": parsed["raw_text"],
                    "topics": parsed["topics"],
                    "updated_at": parsed["updated_at"],
                    "pregenerated": True,
                })
                pregenerated += 1

            delivery_updates: dict[str, Any] = {}

            if plan["should_deliver_now"] and tg_chat_id and telegram_token and raw_text and tg_last != target_dmy:
                if send_text_message(telegram_token, tg_chat_id, raw_text):
                    delivery_updates["lastDeliveredDateTg"] = target_dmy
                    delivery_updates["lastDeliveredAt"] = now_utc.isoformat()
                    delivered_tg += 1

            if plan["should_deliver_now"] and web_sub and web_enabled and raw_text and web_last != target_dmy:
                greeting_line = greeting_text.strip().split("\n")[0] if greeting_text else ""
                if len(greeting_line) > 120:
                    greeting_line = greeting_line[:117] + "..."
                push_title, fallback_body = _localized_push_title_and_fallback(lang_clean, target_dmy)
                if not greeting_line:
                    greeting_line = fallback_body
                if send_web_push(web_sub, title=push_title, body=greeting_line):
                    delivery_updates["lastDeliveredDateWeb"] = target_dmy
                    delivery_updates["lastDeliveredWebAt"] = now_utc.isoformat()
                    delivered_web += 1

            # Помечаем дату полностью доставленной, когда все подключенные каналы отработали
            if delivery_updates:
                tg_done = (not tg_chat_id) or (delivery_updates.get("lastDeliveredDateTg") == target_dmy) or (tg_last == target_dmy)
                web_done = (not (web_sub and web_enabled)) or (delivery_updates.get("lastDeliveredDateWeb") == target_dmy) or (web_last == target_dmy)
                if tg_done and web_done:
                    delivery_updates["lastDeliveredDate"] = target_dmy
                db.collection("users").document(uid).set(delivery_updates, merge=True)
        except Exception as usr_err:
            logger.error("Scheduler error for user %s: %s", uid, usr_err)
            errors.append(f"{uid}: processing error")

    return {
        "status": "ok",
        "timestamp_utc": now_utc.isoformat(),
        "checked_users": checked,
        "pregenerated_forecasts": pregenerated,
        "delivered_telegram": delivered_tg,
        "delivered_web_push": delivered_web,
        "errors_count": len(errors),
    }


# ==============================================================================
# Web Push эндпоинты для Apple iPhone (iOS 16.4+) и браузеров
# ==============================================================================
@app.get("/api/notifications/vapid-public-key")
def get_vapid_public_key():
    """Возвращает публичный VAPID ключ для оформления Web Push подписки в PWA."""
    if not VAPID_PUBLIC_KEY:
        raise HTTPException(status_code=503, detail="Web Push VAPID key is not configured")
    return {"public_key": VAPID_PUBLIC_KEY}


@app.post("/api/notifications/web-subscribe")
def subscribe_web_push(
    req: WebPushSubscribeRequest,
    user_token: dict = Depends(verify_firebase_token),
):
    """Сохранение Web Push подписки авторизованного пользователя в Firestore."""
    user_id = user_token.get("uid")
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing uid in token")
    if req.user_id and req.user_id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden: user_id mismatch")

    _check_burst_rate_limit(f"push_sub:{user_id}", max_calls=10, window_sec=60)
    clean_sub = sanitize_web_push_subscription(req.subscription)

    db = get_db()
    db.collection("users").document(user_id).set({
        "web_push_subscription": clean_sub,
        "web_notifications_enabled": True,
        "web_push_updated_at": datetime.now(timezone.utc).isoformat(),
        "web_push_user_agent": (_sanitize_text_field(req.user_agent, 250) or ""),
    }, merge=True)
    return {"status": "subscribed", "user_id": user_id}


@app.post("/api/notifications/send-test")
def send_test_web_push(
    req: Optional[WebPushTestRequest] = None,
    user_token: dict = Depends(verify_firebase_token),
):
    """Тестовая отправка push-уведомления на устройство авторизованного пользователя."""
    user_id = user_token.get("uid")
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing uid in token")
    if req and req.user_id and req.user_id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden: user_id mismatch")

    _check_burst_rate_limit(f"push_test:{user_id}", max_calls=5, window_sec=300)

    db = get_db()
    user_doc = db.collection("users").document(user_id).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    data = user_doc.to_dict() or {}
    sub = data.get("web_push_subscription")
    if not sub:
        raise HTTPException(status_code=400, detail="User has no web_push_subscription")
    name = _sanitize_text_field(data.get("name"), 60) or "друг"
    lang = (data.get("language") or data.get("lang") or "ru").lower()

    if lang == "fr":
        title = "✨ Test d'alerte : Astro Horoscope"
        body = f"Bonjour {name} ! Les notifications Web Push fonctionnent parfaitement sur votre iPhone 📲"
    elif lang == "en":
        title = "✨ Test Alert: Astro Horoscope"
        body = f"Hello {name}! Web Push notifications are working perfectly on your iPhone 📲"
    elif lang == "es":
        title = "✨ Notificación de prueba: Astro Horóscopo"
        body = f"¡Hola {name}! Las notificaciones Web Push funcionan en tu iPhone 📲"
    elif lang == "de":
        title = "✨ Test-Benachrichtigung: Astro Horoskop"
        body = f"Hallo {name}! Web Push Benachrichtigungen funktionieren auf deinem iPhone 📲"
    else:
        title = "✨ Тестовое оповещение: Астро Гороскоп"
        body = f"Привет, {name}! Уведомления Web Push успешно подключены и работают на твоем iPhone 📲"

    ok = send_web_push(sub, title=title, body=body)
    if not ok:
        raise HTTPException(status_code=500, detail="Failed to deliver Web Push to endpoint")
    return {"status": "sent", "user_id": user_id}


@app.delete("/user/account")
def delete_user_account(user_token: dict = Depends(verify_firebase_token)):
    """Полное удаление профиля, кэша гороскопов из Firestore и учетной записи Firebase Auth (GDPR / Google Play Policy)."""
    user_id = user_token.get("uid")
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing uid in token")

    db = get_db()
    user_ref = db.collection("users").document(user_id)
    try:
        for h_doc in user_ref.collection("horoscopes").stream():
            h_doc.reference.delete()
        user_ref.delete()
    except Exception as e:
        logger.error("Failed to delete Firestore data for %s: %s", user_id, e)
        raise HTTPException(status_code=500, detail="Failed to delete user data")

    try:
        auth.delete_user(user_id)
    except auth.UserNotFoundError:
        pass
    except Exception as e:
        logger.error("Failed to delete Firebase Auth user %s: %s", user_id, e)
        raise HTTPException(status_code=500, detail="Failed to delete authentication account")

    return {"status": "deleted", "uid": user_id}
