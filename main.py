"""
Главный координирующий модуль астрологического сервиса и Telegram-бота.
Поддерживает два режима работы:
1. Полный запуск (`python main.py [--date DD.MM.YYYY]`): немедленная мультиязычная генерация,
   архивация и отправка автору, в канал и активным подписчикам.
2. Почасовой/15-минутный планировщик (`python main.py --scheduled`):
   учет часового пояса каждого пользователя (автора и подписчиков), заблаговременная (сдвинутая)
   генерация прогнозов под конкретную целевую дату пользователя и отправка строго в выбранное
   пользователем локальное время.
"""

import os
import sys
import json
import time
import shutil
import argparse
from datetime import datetime, timezone

from config_loader import get_config, validate_secrets
from ai_service import (
    generate_horoscope_text,
    generate_zodiac_horoscope_text,
    normalize_user_profile,
    format_date_dmy,
)
from telegram_service import send_text_message
from archive_service import (
    DATA_DIR,
    ARCHIVE_DIR,
    SUPPORTED_LANGS,
    parse_horoscope_structure,
    save_horoscope_to_archive,
    save_zodiac_to_archive,
)
from user_service import get_all_users
from timezone_scheduler import (
    compute_profile_hash,
    compute_user_delivery_plan,
    compute_zodiac_target_dates,
    get_cached_user_forecast,
    get_last_delivered_date,
    get_user_current_date_str,
    mark_user_delivered,
    save_cached_user_forecast,
)


def _date_to_iso_key(dmy_str: str) -> str:
    try:
        return datetime.strptime(dmy_str, "%d.%m.%Y").strftime("%Y_%m_%d")
    except Exception:
        return dmy_str.replace(".", "_")


def _promote_archive_to_latest_if_needed(prefix: str, target_dmy: str) -> bool:
    """
    Если архивный файл на сегодняшнюю дату сервера был сгенерирован заранее вчера вечером,
    продвигает его в latest_<prefix>[_<lang>].json и mobile_app/assets/data/ без повторного вызова ИИ.
    """
    promoted = False
    iso_key = _date_to_iso_key(target_dmy)
    assets_dir = os.path.join(os.path.dirname(__file__), "mobile_app", "assets", "data")

    for lang in SUPPORTED_LANGS:
        arch_name = f"{prefix}_{iso_key}.json" if lang == "ru" else f"{prefix}_{iso_key}_{lang}.json"
        arch_path = os.path.join(ARCHIVE_DIR, arch_name)
        if not os.path.exists(arch_path):
            continue

        latest_name = f"latest_{prefix}.json" if lang == "ru" else f"latest_{prefix}_{lang}.json"
        latest_path = os.path.join(DATA_DIR, latest_name)

        need_copy = True
        if os.path.exists(latest_path):
            try:
                with open(latest_path, "r", encoding="utf-8") as f:
                    cur = json.load(f)
                if cur.get("date") == target_dmy:
                    need_copy = False
            except Exception:
                need_copy = True

        if need_copy:
            shutil.copyfile(arch_path, latest_path)
            if os.path.exists(assets_dir):
                try:
                    shutil.copyfile(arch_path, os.path.join(assets_dir, latest_name))
                except Exception:
                    pass
            promoted = True

    return promoted


def _ensure_multilingual_zodiac_for_date(api_key: str, target_dmy: str, update_latest: bool) -> bool:
    """Гарантирует наличие гороскопа по 12 знакам на все языки для заданной даты target_dmy."""
    changed = False
    iso_key = _date_to_iso_key(target_dmy)

    for lang in SUPPORTED_LANGS:
        arch_name = f"zodiac_{iso_key}.json" if lang == "ru" else f"zodiac_{iso_key}_{lang}.json"
        arch_path = os.path.join(ARCHIVE_DIR, arch_name)
        if os.path.exists(arch_path):
            continue

        print(f"⏳ [Зодиак {target_dmy}] Опережающая/плановая генерация для языка: {lang}...")
        zodiac_text = generate_zodiac_horoscope_text(api_key, target_date=target_dmy, lang=lang)
        save_zodiac_to_archive(zodiac_text, target_date=target_dmy, lang=lang, update_latest=update_latest)
        changed = True

    if update_latest:
        if _promote_archive_to_latest_if_needed("zodiac", target_dmy):
            changed = True

    return changed


def _ensure_author_multilingual_for_date(
    api_key: str,
    author_profile: dict,
    target_dmy: str,
    update_latest: bool,
) -> tuple[str, bool]:
    """
    Гарантирует наличие мультиязычного архивного прогноза автора на target_dmy
    с проверкой хэша натальных данных (при изменении времени/даты рождения пересчитывает автоматически).
    Возвращает (ru_raw_text, public_files_changed).
    """
    changed = False
    iso_key = _date_to_iso_key(target_dmy)
    ru_hash = compute_profile_hash(author_profile, lang="ru")
    cached_ru = get_cached_user_forecast("usr_oleg_main", target_dmy, lang="ru", profile_hash=ru_hash)
    ru_text = cached_ru["raw_text"] if cached_ru else ""

    for lang in SUPPORTED_LANGS:
        arch_name = f"horoscope_{iso_key}.json" if lang == "ru" else f"horoscope_{iso_key}_{lang}.json"
        arch_path = os.path.join(ARCHIVE_DIR, arch_name)

        # Если файл уже есть И для RU совпадает актуальный натальный хэш — пропускаем повторную генерацию
        if os.path.exists(arch_path) and (lang != "ru" or bool(ru_text)):
            if lang == "ru" and not ru_text:
                try:
                    with open(arch_path, "r", encoding="utf-8") as f:
                        ru_text = json.load(f).get("raw_text", "")
                except Exception:
                    pass
            continue

        print(f"⏳ [Персональный {target_dmy}] Генерация прогноза для языка: {lang}...")
        h_text = generate_horoscope_text(api_key, author_profile, lang=lang, target_date=target_dmy)
        payload = save_horoscope_to_archive(h_text, target_date=target_dmy, lang=lang, update_latest=update_latest)
        changed = True

        if lang == "ru":
            ru_text = h_text
            save_cached_user_forecast("usr_oleg_main", target_dmy, "ru", ru_hash, payload)

    if update_latest:
        if _promote_archive_to_latest_if_needed("horoscope", target_dmy):
            changed = True

    if not ru_text:
        ru_arch = os.path.join(ARCHIVE_DIR, f"horoscope_{iso_key}.json")
        if os.path.exists(ru_arch):
            try:
                with open(ru_arch, "r", encoding="utf-8") as f:
                    ru_text = json.load(f).get("raw_text", "")
            except Exception:
                pass

    return ru_text, changed


def _collect_subscribers(personal_chat_id: str, channel_chat_id: str) -> list[dict]:
    """Собирает список подписчиков Telegram (как с заполненным натальным профилем, так и после /start)."""
    registry_users = get_all_users()
    by_chat_id = {}
    excluded_ids = {str(personal_chat_id or "").strip(), str(channel_chat_id or "").strip(), ""}

    for u in registry_users:
        if u.get("id") == "usr_oleg_main":
            continue
        chat_id = str(u.get("telegram_chat_id") or "").strip()
        if chat_id and chat_id not in excluded_ids:
            by_chat_id[chat_id] = u

    subs_file = os.path.join(os.path.dirname(__file__), "data", "users", "telegram_subscribers.json")
    if os.path.exists(subs_file):
        try:
            with open(subs_file, "r", encoding="utf-8") as f:
                raw_ids = json.load(f)
            for cid in raw_ids:
                scid = str(cid).strip()
                if scid and scid not in excluded_ids and scid not in by_chat_id:
                    by_chat_id[scid] = {
                        "id": f"usr_tg_{scid}",
                        "name": "Уважаемый подписчик",
                        "telegram_chat_id": scid,
                        "birth_date": "",
                        "delivery_time": "07:30",
                        "notifications_enabled": True,
                        "lang": "ru",
                    }
        except Exception:
            pass

    return list(by_chat_id.values())


def _process_subscribers_schedule(
    api_key: str,
    bot_token: str,
    personal_chat_id: str,
    channel_chat_id: str,
    server_tz_name: str,
    server_gen_time: str,
    delay_seconds: float = 1.5,
):
    """
    Обрабатывает всех подписчиков с учетом их индивидуальных часовых поясов,
    даты/времени рождения и желаемого времени доставки:
    - Генерирует персональный прогноз ЗАРАНЕЕ на целевую дату пользователя, если пользователь
      в другом часовом поясе/сутках или его время доставки раньше серверного.
    - Отправляет сообщение строго в локальное окно доставки пользователя.
    """
    now_utc = datetime.now(timezone.utc)
    subscribers = _collect_subscribers(personal_chat_id, channel_chat_id)
    if not subscribers:
        return

    for sub in subscribers:
        sub_id = str(sub.get("id") or f"usr_tg_{sub.get('telegram_chat_id')}").strip()
        chat_id = str(sub.get("telegram_chat_id") or "").strip()
        if not chat_id:
            continue

        norm_sub = normalize_user_profile(sub)
        last_deliv = get_last_delivered_date(sub_id, channel="telegram")

        plan = compute_user_delivery_plan(
            norm_sub,
            now_utc=now_utc,
            default_delivery_time="07:30",
            server_generation_time=server_gen_time,
            server_tz_name=server_tz_name,
            last_delivered_date=last_deliv,
        )

        if not plan["should_generate_now"] and not plan["should_deliver_now"]:
            continue

        target_dmy = plan["target_date"]
        lang_clean = norm_sub.get("lang") or "ru"
        has_natal_date = bool(norm_sub.get("birth_date"))

        try:
            if has_natal_date:
                p_hash = compute_profile_hash(norm_sub, lang=lang_clean)
                cached = get_cached_user_forecast(sub_id, target_dmy, lang=lang_clean, profile_hash=p_hash)
                if cached:
                    forecast_text = cached["raw_text"]
                else:
                    mode_tag = "ОПЕРЕЖАЮЩАЯ ГЕНЕРАЦИЯ" if plan["requires_advance_generation"] else "ГЕНЕРАЦИЯ"
                    print(
                        f"🔮 [{mode_tag}] Подписчик {norm_sub['name'] or sub_id} "
                        f"({plan['user_timezone']}, доставка {plan['delivery_time']}) -> дата прогноза {target_dmy}..."
                    )
                    forecast_text = generate_horoscope_text(
                        api_key,
                        norm_sub,
                        lang=lang_clean,
                        target_date=target_dmy,
                    )
                    parsed = parse_horoscope_structure(forecast_text, target_dmy)
                    save_cached_user_forecast(sub_id, target_dmy, lang_clean, p_hash, parsed)
            else:
                # Подписчик без анкеты — подготавливаем общий прогноз 12 знаков на его локальную дату
                iso_key = _date_to_iso_key(target_dmy)
                z_path = os.path.join(ARCHIVE_DIR, f"zodiac_{iso_key}.json")
                if not os.path.exists(z_path):
                    z_raw = generate_zodiac_horoscope_text(api_key, target_date=target_dmy, lang="ru")
                    save_zodiac_to_archive(z_raw, target_date=target_dmy, lang="ru", update_latest=False)
                with open(z_path, "r", encoding="utf-8") as f:
                    forecast_text = json.load(f).get("raw_text", "")

            if plan["should_deliver_now"] and forecast_text and bot_token:
                print(
                    f"📤 Доставка прогноза на {target_dmy} подписчику {norm_sub['name'] or chat_id} "
                    f"(местное время {plan['delivery_time']}, пояс {plan['user_timezone']})..."
                )
                if send_text_message(bot_token, chat_id, forecast_text):
                    mark_user_delivered(sub_id, target_dmy, channel="telegram")
                    time.sleep(delay_seconds)
        except Exception as sub_err:
            print(f"⚠️ Ошибка обработки подписчика {sub_id}: {sub_err}")


def run_scheduled_tick(config: dict | None = None) -> bool:
    """
    Выполняет один идемпотентный тик планировщика с учетом часовых поясов всех получателей.
    Возвращает True, если публичные архивные файлы в data/ были созданы или обновлены.
    """
    if config is None:
        config = get_config()
    is_valid, errors = validate_secrets(config)
    if not is_valid:
        for err in errors:
            print(f"❌ Ошибка конфигурации: {err}")
        sys.exit(1)

    api_key = config["gemini_api_key"]
    bot_token = config["telegram_token"]
    channel_chat_id = config.get("telegram_channel_chat_id") or config.get("telegram_chat_id")
    personal_chat_id = config.get("telegram_personal_chat_id")
    author_profile = config["user_profile"]

    bot_settings = config.get("bot_settings", {})
    delay_seconds = bot_settings.get("delay_between_messages_seconds", 2.0)
    server_tz_name = bot_settings.get("server_timezone", "Europe/Chisinau")
    server_gen_time = bot_settings.get("server_generation_time", "06:30")

    now_utc = datetime.now(timezone.utc)
    public_changed = False

    # 1. Предгенерация и поддержание актуальности гороскопа 12 знаков (для сервера и восточных поясов UTC+14)
    zodiac_dates_info = compute_zodiac_target_dates(now_utc=now_utc, server_tz_name=server_tz_name)
    server_today = zodiac_dates_info["server_today"]
    for z_date in zodiac_dates_info["dates_to_ensure"]:
        if _ensure_multilingual_zodiac_for_date(
            api_key,
            target_dmy=z_date,
            update_latest=(z_date == server_today),
        ):
            public_changed = True

    # 2. Персональный прогноз автора + эталонный архив приложения по часовому поясу и времени автора
    author_last = get_last_delivered_date("usr_oleg_main", channel="telegram")
    author_plan = compute_user_delivery_plan(
        author_profile,
        now_utc=now_utc,
        default_delivery_time=server_gen_time,
        server_generation_time=server_gen_time,
        server_tz_name=server_tz_name,
        last_delivered_date=author_last,
    )

    # Обеспечиваем наличие сегодняшнего публичного архива, а также опережающую генерацию для слота автора
    if _promote_archive_to_latest_if_needed("horoscope", server_today):
        public_changed = True

    author_ru_text = ""
    if author_plan["should_generate_now"] or author_plan["should_deliver_now"]:
        author_ru_text, chg = _ensure_author_multilingual_for_date(
            api_key,
            author_profile,
            target_dmy=author_plan["target_date"],
            update_latest=(author_plan["target_date"] == server_today),
        )
        if chg:
            public_changed = True

    if author_plan["should_deliver_now"] and personal_chat_id and author_ru_text:
        print(
            f"📤 Отправка персонального прогноза автору ({personal_chat_id}) на {author_plan['target_date']} "
            f"(пояс {author_plan['user_timezone']}, слот {author_plan['delivery_time']})..."
        )
        if send_text_message(bot_token, personal_chat_id, author_ru_text):
            mark_user_delivered("usr_oleg_main", author_plan["target_date"], channel="telegram")
            time.sleep(delay_seconds)

    # 3. Публикация общего гороскопа 12 знаков в Telegram-канал по расписанию канала
    if channel_chat_id:
        chan_last = get_last_delivered_date("channel_main", channel="telegram")
        chan_plan = compute_user_delivery_plan(
            {"timezone": server_tz_name, "delivery_time": server_gen_time, "notifications_enabled": True},
            now_utc=now_utc,
            default_delivery_time=server_gen_time,
            server_generation_time=server_gen_time,
            server_tz_name=server_tz_name,
            last_delivered_date=chan_last,
        )
        if chan_plan["should_deliver_now"]:
            z_iso = _date_to_iso_key(chan_plan["target_date"])
            z_arch = os.path.join(ARCHIVE_DIR, f"zodiac_{z_iso}.json")
            if os.path.exists(z_arch):
                with open(z_arch, "r", encoding="utf-8") as f:
                    z_text = json.load(f).get("raw_text", "")
                if z_text and send_text_message(bot_token, channel_chat_id, z_text):
                    mark_user_delivered("channel_main", chan_plan["target_date"], channel="telegram")
                    time.sleep(delay_seconds)

    # 4. Опережающая генерация и доставка по индивидуальным часовым поясам подписчиков
    _process_subscribers_schedule(
        api_key=api_key,
        bot_token=bot_token,
        personal_chat_id=personal_chat_id,
        channel_chat_id=channel_chat_id,
        server_tz_name=server_tz_name,
        server_gen_time=server_gen_time,
        delay_seconds=delay_seconds,
    )

    return public_changed


def main():
    parser = argparse.ArgumentParser(description="Автономный астрологический сервис и Telegram-бот")
    parser.add_argument("--scheduled", action="store_true", help="Режим периодического тика планировщика часовых поясов")
    parser.add_argument("--date", type=str, default=None, help="Целевая дата прогноза (DD.MM.YYYY или YYYY-MM-DD)")
    args, _ = parser.parse_known_args()

    config = get_config()
    is_valid, errors = validate_secrets(config)
    if not is_valid:
        print("❌ Ошибка конфигурации:")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    if args.scheduled:
        print("⏱️ Запуск планового тика астрологического планировщика часовых поясов...")
        run_scheduled_tick(config)
        print("✅ Тик планировщика успешно завершен.")
        return

    print("🚀 Запуск автономного астрологического бота (полный цикл)...")

    api_key = config["gemini_api_key"]
    bot_token = config["telegram_token"]
    channel_chat_id = config.get("telegram_channel_chat_id") or config.get("telegram_chat_id")
    personal_chat_id = config.get("telegram_personal_chat_id")
    user_profile = config["user_profile"]

    bot_settings = config.get("bot_settings", {})
    delay_seconds = bot_settings.get("delay_between_messages_seconds", 2.0)
    server_tz_name = bot_settings.get("server_timezone", "Europe/Chisinau")
    server_gen_time = bot_settings.get("server_generation_time", "06:30")

    # Целевая дата определяется по часовому поясу автора (или явному флагу --date)
    target_dmy = format_date_dmy(args.date) if args.date else ""
    if not target_dmy:
        target_dmy = get_user_current_date_str(user_profile, fallback_tz=server_tz_name)

    try:
        # 1. Генерация и доставка Персонального прогноза автора (Multilingual)
        print(f"🔮 1/3. Расчет натальных аспектов и генерация персонального прогноза на {target_dmy} (Multilingual)...")
        ru_personal_text = ""
        ru_hash = compute_profile_hash(user_profile, lang="ru")
        for lang in SUPPORTED_LANGS:
            print(f"⏳ Генерация персонального прогноза для языка: {lang}...")
            horoscope_text = generate_horoscope_text(api_key, user_profile, lang=lang, target_date=target_dmy)
            print(f"📝 Персональный гороскоп ({lang}) сформирован (объем: {len(horoscope_text)} симв.).")
            payload = save_horoscope_to_archive(horoscope_text, target_date=target_dmy, lang=lang, update_latest=True)

            if lang == "ru":
                ru_personal_text = horoscope_text
                save_cached_user_forecast("usr_oleg_main", target_dmy, "ru", ru_hash, payload)
                if personal_chat_id:
                    print(f"📤 Отправка персонального прогноза (RU) в личные сообщения автору ({personal_chat_id})...")
                    if send_text_message(bot_token, personal_chat_id, ru_personal_text):
                        mark_user_delivered("usr_oleg_main", target_dmy, channel="telegram")
                    time.sleep(delay_seconds)

        # 2. Генерация и доставка Гороскопа по 12 знакам зодиака (Multilingual + предгенерация для восточных поясов)
        print(f"♈ 2/3. Расчет и генерация гороскопа по 12 знакам зодиака на {target_dmy} (Multilingual)...")
        for lang in SUPPORTED_LANGS:
            print(f"⏳ Генерация общего гороскопа для языка: {lang}...")
            zodiac_text = generate_zodiac_horoscope_text(api_key, target_date=target_dmy, lang=lang)
            print(f"📝 Гороскоп по знакам зодиака ({lang}) сформирован (объем: {len(zodiac_text)} симв.).")
            save_zodiac_to_archive(zodiac_text, target_date=target_dmy, lang=lang, update_latest=True)

            if lang == "ru" and channel_chat_id:
                print(f"📤 Отправка общего гороскопа (RU) в канал ({channel_chat_id})...")
                if send_text_message(bot_token, channel_chat_id, zodiac_text):
                    mark_user_delivered("channel_main", target_dmy, channel="telegram")
            elif lang == "ru" and not channel_chat_id:
                print("⚠️ Идентификатор канала не задан. Гороскоп по 12 знакам сохранен в архив, но не отправлен в Telegram.")

        # Если восточные пояса (UTC+14) уже переходят в следующие сутки, заранее создаем архив на завтра
        zodiac_dates_info = compute_zodiac_target_dates(server_tz_name=server_tz_name)
        for extra_date in zodiac_dates_info["dates_to_ensure"]:
            if extra_date != target_dmy:
                _ensure_multilingual_zodiac_for_date(api_key, target_dmy=extra_date, update_latest=False)

        # 3. Опережающая генерация и доставка для подписчиков по их часовым поясам
        print("🌍 3/3. Проверка часовых поясов и индивидуальных слотов доставки подписчиков...")
        _process_subscribers_schedule(
            api_key=api_key,
            bot_token=bot_token,
            personal_chat_id=personal_chat_id,
            channel_chat_id=channel_chat_id,
            server_tz_name=server_tz_name,
            server_gen_time=server_gen_time,
            delay_seconds=delay_seconds,
        )

        print("✨ Все астрологические рассылки и архивация успешно завершены!")

    except Exception as e:
        print(f"❌ Критическая ошибка выполнения: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
