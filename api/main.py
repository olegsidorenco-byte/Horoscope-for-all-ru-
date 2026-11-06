import os
import sys
import hmac
from datetime import datetime, timezone
from typing import Optional

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import firebase_admin
from firebase_admin import auth, credentials, firestore
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from dotenv import load_dotenv

from ai_service import generate_horoscope_text, normalize_user_profile
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
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User profile not found")

    raw_profile = user_doc.to_dict() or {}
    merged_profile = dict(raw_profile)

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
                if c_data.get("profile_hash") == profile_hash and c_data.get("raw_text"):
                    return HoroscopeResponse(
                        horoscope=c_data["raw_text"],
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
                if c_data.get("profile_hash") == profile_hash and c_data.get("raw_text"):
                    raw_text = c_data["raw_text"]

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
        except Exception as usr_err:
            errors.append(f"{uid}: {usr_err}")

    return {
        "status": "ok",
        "timestamp_utc": now_utc.isoformat(),
        "checked_users": checked,
        "pregenerated_forecasts": pregenerated,
        "delivered_telegram": delivered_tg,
        "errors": errors[:20],
    }


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
