import os
import sys
import hmac
import json
from datetime import datetime, timezone
from typing import Optional

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import firebase_admin
from firebase_admin import auth, credentials, firestore
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
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
        print(f"Внимание: отложенная инициализация Firebase ({e})")

_db_client = None


def get_db():
    """Ленивое получение клиента Firestore (не падает при импорте модуля в unit-тестах без GCP-ключей)."""
    global _db_client
    if _db_client is None:
        _db_client = firestore.client()
    return _db_client


app = FastAPI(title="Cosmic Horoscope API", version="1.2.0")

# ==============================================================================
# Web Push (VAPID) для Apple iPhone (iOS 16.4+) и браузеров
# ==============================================================================
VAPID_PUBLIC_KEY = os.getenv(
    "VAPID_PUBLIC_KEY",
    "BFsxlA77SduX7b8r6PDUqefbVXSOBBqCmI1kzzLtUnX5FZKw6mT1Ew92Nq747FyF9xc9eBLYv5zpOKJhXJ3K9Xg",
)
VAPID_PRIVATE_KEY = os.getenv(
    "VAPID_PRIVATE_KEY",
    "0iaV2c3yyuIc-Fqr5sgZ8ofpUL1PbGozk6L1aefFe80",
)
VAPID_CLAIMS = {"sub": os.getenv("VAPID_SUB", "mailto:oleg.sidorenco@gmail.com")}


def send_web_push(subscription_info: dict, title: str, body: str, url: str = "https://cosmic-horoscope-ru.web.app") -> bool:
    """Отправка системного Web Push уведомления на Apple iPhone (iOS 16.4+) или в браузер."""
    if not subscription_info or not isinstance(subscription_info, dict):
        return False
    try:
        from pywebpush import webpush
        payload = json.dumps({
            "title": title,
            "body": body,
            "url": url,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        webpush(
            subscription_info=subscription_info,
            data=payload,
            vapid_private_key=VAPID_PRIVATE_KEY,
            vapid_claims=VAPID_CLAIMS,
            timeout=10,
        )
        return True
    except Exception as e:
        print(f"Ошибка отправки Web Push: {e}")
        return False


class WebPushSubscribeRequest(BaseModel):
    user_id: str
    subscription: dict
    user_agent: Optional[str] = None


class WebPushTestRequest(BaseModel):
    user_id: str


class HoroscopeTopicItem(BaseModel):
    title: str
    icon: str = "✨"
    content: str


class HoroscopeRequest(BaseModel):
    lang: str = "ru"
    timezone: Optional[str] = None
    utc_offset_minutes: Optional[int] = None
    target_date: Optional[str] = None
    delivery_time: Optional[str] = None
    notifications_enabled: Optional[bool] = None
    force_refresh: bool = False
    profile: Optional[dict] = None


class HoroscopeResponse(BaseModel):
    horoscope: str
    date: str
    iso_date: str = ""
    greeting: str = ""
    topics: list[HoroscopeTopicItem] = Field(default_factory=list)
    updated_at: str = ""
    user_timezone: str = ""
    cached: bool = False


def verify_firebase_token(authorization: str = Header(...)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid token format")
    token = authorization.split("Bearer ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Empty token")
    try:
        return auth.verify_id_token(token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Unauthorized: {str(e)}")


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
        "version": "1.2.0",
    }


@app.get("/app/latest-version")
def get_app_latest_version():
    return {
        "version": "1.0.31",
        "build_number": 31,
        "tag": "app-v1.0.31",
        "download_url": "https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/download/app-v1.0.31/Horoscope-for-all-ru.apk",
        "release_url": "https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/tag/app-v1.0.31",
        "release_notes": {
            "fr": "✨ Version 1.0.31 :\n• Traduction intégrale de l'interface en français (profil natal, paramètres, authentification).\n• Vérification automatique des mises à jour avec téléchargement direct de l'APK.\n• Correction du message de bienvenue et du calcul natal.\n• Localisation automatique des sphères de priorité.",
            "en": "✨ Version 1.0.31:\n• 100% full interface localization (natal profile, settings, auth).\n• Built-in update checker with direct APK download.\n• Personalized greeting and natal chart display fixes.\n• Automatic localization of astrological focus areas.",
            "es": "✨ Versión 1.0.31:\n• Traducción completa de la interfaz (perfil natal, ajustes, autenticación).\n• Comprobador de actualizaciones con descarga directa del APK.\n• Saludo personalizado y corrección de signo natal.\n• Localización automática del enfoque astrológico.",
            "de": "✨ Version 1.0.31:\n• Vollständige Übersetzung der Benutzeroberfläche (Natalprofil, Einstellungen, Authentifizierung).\n• Automatische Update-Prüfung und APK-Download.\n• Korrektur der persönlichen Begrüßung und des Aszendenten.\n• Automatische Lokalisierung der Schwerpunkte.",
            "ru": "✨ Версия 1.0.31:\n• Полный перевод интерфейса (натальный профиль, настройки, авторизация).\n• Встроенное отслеживание релизов с загрузкой APK в один клик.\n• Исправление персонального приветствия и натального знака.\n• Автоматический перевод сфер фокуса в анкете."
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

    gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not gemini_api_key:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY is not configured")

    db = get_db()
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists and not req.profile:
        raise HTTPException(status_code=404, detail="User profile not found")

    raw_profile = (user_doc.to_dict() if user_doc.exists else {}) or {}
    merged_profile = dict(raw_profile)
    if isinstance(req.profile, dict):
        for k, v in req.profile.items():
            if v is not None and v != "":
                merged_profile[k] = v

    # Синхронизируем переданные клиентом настройки часового пояса, времени доставки и языка
    metadata_updates = {}
    lang_clean = (req.lang or raw_profile.get("lang") or "ru").strip().lower()
    if lang_clean and raw_profile.get("lang") != lang_clean:
        merged_profile["lang"] = lang_clean
        metadata_updates["lang"] = lang_clean

    if req.timezone and req.timezone.strip():
        tz_clean = req.timezone.strip()
        merged_profile["timezone"] = tz_clean
        if raw_profile.get("timezone") != tz_clean:
            metadata_updates["timezone"] = tz_clean

    if req.utc_offset_minutes is not None and -840 <= req.utc_offset_minutes <= 840:
        merged_profile["utcOffsetMinutes"] = req.utc_offset_minutes
        if raw_profile.get("utcOffsetMinutes") != req.utc_offset_minutes:
            metadata_updates["utcOffsetMinutes"] = req.utc_offset_minutes

    if req.delivery_time and req.delivery_time.strip():
        merged_profile["deliveryTime"] = req.delivery_time.strip()
        if raw_profile.get("deliveryTime") != req.delivery_time.strip():
            metadata_updates["deliveryTime"] = req.delivery_time.strip()

    if req.notifications_enabled is not None:
        merged_profile["notificationsEnabled"] = req.notifications_enabled
        if raw_profile.get("notificationsEnabled") != req.notifications_enabled:
            metadata_updates["notificationsEnabled"] = req.notifications_enabled

    if metadata_updates:
        metadata_updates["lastSeenAt"] = datetime.now(timezone.utc).isoformat()
        try:
            user_ref.set(metadata_updates, merge=True)
        except Exception as sync_err:
            print(f"⚠️ Не удалось обновить метаданные пользователя {user_id}: {sync_err}")

    norm_profile = normalize_user_profile(merged_profile)
    _, user_tz_label = resolve_user_timezone(norm_profile, fallback_tz="UTC")

    # Вычисляем целевую дату строго по часовому поясу пользователя (с поддержкой предгенерации до +2 дней)
    target_dmy, target_iso = validate_and_resolve_target_date(
        req.target_date,
        norm_profile,
        fallback_tz="UTC",
    )

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
            print(f"⚠️ Ошибка чтения кэша Firestore для {user_id}: {cache_err}")

    try:
        horoscope_text = generate_horoscope_text(
            api_key=gemini_api_key,
            user_profile=norm_profile,
            lang=lang_clean,
            target_date=target_dmy,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Generation Error: {str(e)}")

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
    except Exception as save_err:
        print(f"⚠️ Не удалось сохранить кэш гороскопа для {user_id}: {save_err}")

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


@app.post("/scheduler/tick")
def scheduler_tick(_authorized: bool = Depends(verify_scheduler_secret)):
    """
    Периодический серверный тик (например, раз в 15 минут через Cloud Scheduler):
    1. Проверяет часовой пояс и желаемое время доставки каждого пользователя.
    2. Если пользователь смещен в другие сутки относительно сервера или его время отправки
       раньше стандартного времени генерации — ЗАРАНЕЕ генерирует персональный прогноз
       строго под целевую дату (target_date) и сохраняет в Firestore.
    3. При наступлении локального времени отправки доставляет прогноз в Telegram (если привязан telegramChatId).
    """
    gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not gemini_api_key:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY is not configured")

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
        last_delivered = raw_profile.get("lastDeliveredDate") or raw_profile.get("last_delivered_date")

        plan = compute_user_delivery_plan(
            norm,
            now_utc=now_utc,
            default_delivery_time="07:30",
            server_generation_time=server_gen_time,
            server_tz_name=server_tz_name,
            last_delivered_date=last_delivered,
        )

        if not plan["should_generate_now"] and not plan["should_deliver_now"]:
            continue

        target_dmy = plan["target_date"]
        target_iso = plan["target_iso_date"]
        profile_hash = compute_profile_hash(norm, lang=lang_clean)
        cache_ref = db.collection("users").document(uid).collection("horoscopes").document(f"{target_iso}_{lang_clean}")

        raw_text = ""
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

            if not raw_text:
                raw_text = generate_horoscope_text(
                    api_key=gemini_api_key,
                    user_profile=norm,
                    lang=lang_clean,
                    target_date=target_dmy,
                )
                parsed = parse_horoscope_structure(raw_text, target_dmy)
                cache_ref.set({
                    "date": target_dmy,
                    "iso_date": target_iso,
                    "lang": lang_clean,
                    "profile_hash": profile_hash,
                    "user_timezone": plan["user_timezone"],
                    "greeting": parsed["greeting"],
                    "raw_text": parsed["raw_text"],
                    "topics": parsed["topics"],
                    "updated_at": parsed["updated_at"],
                    "pregenerated": True,
                })
                pregenerated += 1

            tg_chat_id = norm.get("telegram_chat_id")
            if plan["should_deliver_now"] and tg_chat_id and telegram_token and raw_text:
                if send_text_message(telegram_token, tg_chat_id, raw_text):
                    db.collection("users").document(uid).set(
                        {
                            "lastDeliveredDate": target_dmy,
                            "lastDeliveredAt": now_utc.isoformat(),
                        },
                        merge=True,
                    )
                    delivered_tg += 1

            # Доставка Web Push на iPhone (iOS 16.4+) / Web PWA
            web_sub = raw_profile.get("web_push_subscription")
            if plan["should_deliver_now"] and web_sub and raw_text:
                greeting_line = (parsed.get("greeting") or "").strip().split("\n")[0]
                if len(greeting_line) > 120:
                    greeting_line = greeting_line[:117] + "..."
                if not greeting_line:
                    greeting_line = "Твой персональный астрологический прогноз уже готов! Открой приложение."
                push_title = f"✨ Гороскоп на {target_dmy}"
                if send_web_push(web_sub, title=push_title, body=greeting_line):
                    delivered_web += 1
        except Exception as usr_err:
            errors.append(f"{uid}: {usr_err}")

    return {
        "status": "ok",
        "timestamp_utc": now_utc.isoformat(),
        "checked_users": checked,
        "pregenerated_forecasts": pregenerated,
        "delivered_telegram": delivered_tg,
        "delivered_web_push": delivered_web,
        "errors": errors[:20],
    }


# ==============================================================================
# Web Push эндпоинты для Apple iPhone (iOS 16.4+) и браузеров
# ==============================================================================
@app.get("/api/notifications/vapid-public-key")
def get_vapid_public_key():
    """Возвращает публичный VAPID ключ для оформления Web Push подписки в PWA."""
    return {"public_key": VAPID_PUBLIC_KEY}


@app.post("/api/notifications/web-subscribe")
def subscribe_web_push(req: WebPushSubscribeRequest):
    """Сохранение Web Push подписки iPhone/браузера в профиль пользователя в Firestore."""
    if not req.user_id or not req.subscription:
        raise HTTPException(status_code=400, detail="Missing user_id or subscription")
    db = get_db()
    db.collection("users").document(req.user_id).set({
        "web_push_subscription": req.subscription,
        "web_notifications_enabled": True,
        "web_push_updated_at": datetime.now(timezone.utc).isoformat(),
        "web_push_user_agent": req.user_agent or "",
    }, merge=True)
    return {"status": "subscribed", "user_id": req.user_id}


@app.post("/api/notifications/send-test")
def send_test_web_push(req: WebPushTestRequest):
    """Тестовая отправка push-уведомления на iPhone/устройство пользователя."""
    if not req.user_id:
        raise HTTPException(status_code=400, detail="Missing user_id")
    db = get_db()
    user_doc = db.collection("users").document(req.user_id).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    data = user_doc.to_dict() or {}
    sub = data.get("web_push_subscription")
    if not sub:
        raise HTTPException(status_code=400, detail="User has no web_push_subscription")
    name = data.get("name") or "друг"
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
    return {"status": "sent", "user_id": req.user_id}


@app.delete("/user/account")
def delete_user_account(user_token: dict = Depends(verify_firebase_token)):
    """Полное удаление профиля пользователя и его кэшированных гороскопов из Firestore (GDPR / Google Play Policy)."""
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
        raise HTTPException(status_code=500, detail=f"Failed to delete Firestore data: {str(e)}")

    return {"status": "deleted", "uid": user_id}
