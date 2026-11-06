"""
Модуль архивации и публикации ежедневных астрологических прогнозов.
Сохраняет актуальный гороскоп в data/latest_horoscope.json,
сохраняет гороскоп по 12 знакам зодиака в data/latest_zodiac.json,
создает архивные копии по дням в data/archive/ и обновляет data/archive/index.json.
Ограничивает хранение архива на сервере периодом в 60 дней.
"""

import os
import json
import re
from datetime import datetime, timezone

from ai_service import format_date_dmy

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
ARCHIVE_DIR = os.path.join(DATA_DIR, "archive")
MOBILE_DATA_DIR = os.path.join(os.path.dirname(__file__), "mobile_app", "assets", "data")
MOBILE_ARCHIVE_DIR = os.path.join(MOBILE_DATA_DIR, "archive")
MAX_ARCHIVE_DAYS = 60
SUPPORTED_LANGS = ("ru", "en", "es", "de", "fr")

ZODIAC_SIGNS_META = [
    {"id": "aries", "name": "Овен", "symbol": "♈", "dates": "21.03 – 19.04", "element": "Огонь", "color": "0xFFE63946"},
    {"id": "taurus", "name": "Телец", "symbol": "♉", "dates": "20.04 – 20.05", "element": "Земля", "color": "0xFF2A9D8F"},
    {"id": "gemini", "name": "Близнецы", "symbol": "♊", "dates": "21.05 – 20.06", "element": "Воздух", "color": "0xFFE9C46A"},
    {"id": "cancer", "name": "Рак", "symbol": "♋", "dates": "21.06 – 22.07", "element": "Вода", "color": "0xFF457B9D"},
    {"id": "leo", "name": "Лев", "symbol": "♌", "dates": "23.07 – 22.08", "element": "Огонь", "color": "0xFFF4A261"},
    {"id": "virgo", "name": "Дева", "symbol": "♍", "dates": "23.08 – 22.09", "element": "Земля", "color": "0xFF588157"},
    {"id": "libra", "name": "Весы", "symbol": "♎", "dates": "23.09 – 22.10", "element": "Воздух", "color": "0xFFA8DADC"},
    {"id": "scorpio", "name": "Скорпион", "symbol": "♏", "dates": "23.10 – 21.11", "element": "Вода", "color": "0xFF9D0208"},
    {"id": "sagittarius", "name": "Стрелец", "symbol": "♐", "dates": "22.11 – 21.12", "element": "Огонь", "color": "0xFFE76F51"},
    {"id": "capricorn", "name": "Козерог", "symbol": "♑", "dates": "22.12 – 19.01", "element": "Земля", "color": "0xFF3A5A40"},
    {"id": "aquarius", "name": "Водолей", "symbol": "♒", "dates": "20.01 – 18.02", "element": "Воздух", "color": "0xFF00B4D8"},
    {"id": "pisces", "name": "Рыбы", "symbol": "♓", "dates": "19.02 – 20.03", "element": "Вода", "color": "0xFF7209B7"},
]

ZODIAC_LOCALIZED_NAMES = {
    "ru": ["Овен", "Телец", "Близнецы", "Рак", "Лев", "Дева", "Весы", "Скорпион", "Стрелец", "Козерог", "Водолей", "Рыбы"],
    "en": ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"],
    "es": ["Aries", "Tauro", "Géminis", "Cáncer", "Leo", "Virgo", "Libra", "Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis"],
    "de": ["Widder", "Stier", "Zwillinge", "Krebs", "Löwe", "Jungfrau", "Waage", "Skorpion", "Schütze", "Steinbock", "Wassermann", "Fische"],
    "fr": ["Bélier", "Taureau", "Gémeaux", "Cancer", "Lion", "Vierge", "Balance", "Scorpion", "Sagittaire", "Capricorne", "Verseau", "Poissons"],
}

ELEMENT_TRANSLATIONS = {
    "Огонь": {"ru": "Огонь", "en": "Fire", "es": "Fuego", "de": "Feuer", "fr": "Feu"},
    "Земля": {"ru": "Земля", "en": "Earth", "es": "Tierra", "de": "Erde", "fr": "Terre"},
    "Воздух": {"ru": "Воздух", "en": "Air", "es": "Aire", "de": "Luft", "fr": "Air"},
    "Вода": {"ru": "Вода", "en": "Water", "es": "Agua", "de": "Wasser", "fr": "Eau"},
}

ZODIAC_LABELS_BY_LANG = {
    "ru": {"default_focus": "Гармония и осознанность", "advice_prefix": "Совет", "fallback_fmt": "Благоприятный день для знака {sign}. Сосредоточьтесь на ключевых задачах и доверяйте интуиции."},
    "en": {"default_focus": "Harmony & mindfulness", "advice_prefix": "Tip", "fallback_fmt": "A favorable day for {sign}. Focus on your key priorities and trust your intuition."},
    "es": {"default_focus": "Armonía y consciencia", "advice_prefix": "Consejo", "fallback_fmt": "Día favorable para {sign}. Concéntrate en tus prioridades y confía en tu intuición."},
    "de": {"default_focus": "Harmonie & Achtsamkeit", "advice_prefix": "Tipp", "fallback_fmt": "Ein günstiger Tag für {sign}. Konzentrieren Sie sich auf das Wesentliche und vertrauen Sie Ihrer Intuition."},
    "fr": {"default_focus": "Harmonie et pleine conscience", "advice_prefix": "Conseil", "fallback_fmt": "Journée favorable pour {sign}. Concentrez-vous sur l'essentiel et faites confiance à votre intuition."},
}


def ensure_directories():
    """Создает необходимые каталоги data и data/archive."""
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(ARCHIVE_DIR, exist_ok=True)


def _detect_topic_icon(raw_title: str, prev_block_tail: str = "") -> str:
    """Определяет иконку рубрики по эмодзи перед <b> или по названию на любом из 5 языков."""
    t_low = raw_title.lower()
    for candidate in ("🪐", "💼", "❤️", "❤", "🌿", "💡", "✨"):
        if candidate in raw_title or candidate in prev_block_tail:
            return "❤️" if candidate == "❤" else candidate

    if any(k in t_low for k in ("влияние планет", "planetary", "influencia", "planeteneinflüsse", "influence des planètes")):
        return "🪐"
    if any(k in t_low for k in ("работа", "бизнес", "финанс", "work", "business", "finance", "trabajo", "negocios", "arbeit", "finanzen", "travail", "affaires")):
        return "💼"
    if any(k in t_low for k in ("личные отношения", "общение", "relationship", "communication", "relaciones", "beziehungen", "relations")):
        return "❤️"
    if any(k in t_low for k in ("здоровье", "тонус", "health", "vitality", "salud", "vitalidad", "gesundheit", "santé")):
        return "🌿"
    if any(k in t_low for k in ("добрый совет", "advice", "consejo", "guter rat", "rat für", "conseil")):
        return "💡"
    if any(k in t_low for k in ("пожелание", "blessing", "deseo", "wunsch", "vœu")):
        return "✨"
    return "✨"


def parse_horoscope_structure(raw_text: str, target_date: str) -> dict:
    """Парсит сгенерированный текст персонального/общего гороскопа (поддерживает RU/EN/ES/DE/FR)."""
    clean_text = raw_text.strip()
    paragraphs = [p.strip() for p in clean_text.split("\n\n") if p.strip()]
    greeting = paragraphs[0] if paragraphs else clean_text
    greeting = re.sub(r'(?:\n+\s*(?:\d+\.\s*)?)?[\s\U00010000-\U0010ffff\u2600-\u26FF\u2700-\u27BF\ufe00-\ufe0f]+$', '', greeting).strip() or (paragraphs[0] if paragraphs else clean_text)

    topics = []
    topic_blocks = clean_text.split("<b>")
    for idx, block in enumerate(topic_blocks[1:], 1):
        parts = block.split("</b>", 1)
        if len(parts) == 2:
            raw_title = parts[0].strip()
            content = parts[1].strip()
            prev_tail = topic_blocks[idx - 1][-12:] if topic_blocks[idx - 1] else ""
            icon = _detect_topic_icon(raw_title, prev_tail)

            # Очищаем возможный номер/эмодзи следующего заголовка в конце блока
            content = re.sub(
                r'(?:\n+\s*(?:\d+\.\s*)?)?[\s\U00010000-\U0010ffff\u2600-\u26FF\u2700-\u27BF\ufe00-\ufe0f]+$',
                '',
                content,
            ).strip()
            topics.append({
                "title": raw_title,
                "icon": icon,
                "content": content
            })

    return {
        "date": target_date,
        "greeting": greeting,
        "raw_text": clean_text,
        "topics": topics,
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    }


def parse_zodiac_structure(raw_text: str, target_date: str, lang: str = "ru") -> dict:
    """Парсит текст гороскопа по 12 знакам зодиака в структурированный JSON с локализацией по языку."""
    lang_clean = (lang or "ru").strip().lower()
    if lang_clean not in ZODIAC_LOCALIZED_NAMES:
        lang_clean = "ru"

    clean_text = raw_text.strip()
    signs_data = []
    localized_names = ZODIAC_LOCALIZED_NAMES[lang_clean]
    labels = ZODIAC_LABELS_BY_LANG[lang_clean]

    for idx, meta in enumerate(ZODIAC_SIGNS_META):
        ru_sign_name = meta["name"]
        local_sign_name = localized_names[idx]
        symbol = meta["symbol"]
        local_element = ELEMENT_TRANSLATIONS.get(meta["element"], {}).get(lang_clean, meta["element"])

        # Ищем блок знака по символу в заголовке <b>...</b> или имени
        pattern = re.compile(rf"(?:<b>)?\s*{symbol}[^<]*</b>(.*?)(?=(?:<b>)?\s*[♈♉♊♋♌♍♎♏♐♑♒♓]|\Z)", re.DOTALL | re.IGNORECASE)
        match = pattern.search(clean_text)

        block_text = ""
        focus = labels["default_focus"]
        energy = "85%"
        lucky_hours = "10:00–12:00"
        forecast = ""

        if match:
            block_text = match.group(1).strip()
        else:
            sym_pattern = re.compile(rf"{symbol}.*?\n(.*?)(?=\n[♈♉♊♋♌♍♎♏♐♑♒♓]|\Z)", re.DOTALL | re.IGNORECASE)
            sym_match = sym_pattern.search(clean_text)
            if sym_match:
                block_text = sym_match.group(1).strip()
            else:
                name_regex = rf"(?:{re.escape(local_sign_name)}|{re.escape(ru_sign_name)})"
                simple_pattern = re.compile(rf"{name_regex}.*?\n(.*?)(?=\n[♈♉♊♋♌♍♎♏♐♑♒♓]|\Z)", re.DOTALL | re.IGNORECASE)
                simple_match = simple_pattern.search(clean_text)
                if simple_match:
                    block_text = simple_match.group(1).strip()

        if block_text:
            lines = [l.strip() for l in block_text.split("\n") if l.strip()]
            forecast_lines = []
            for line in lines:
                if any(fk in line for fk in ("Фокус:", "Focus:", "Enfoque:", "Fokus:")):
                    focus = re.sub(r"^[•\-\s]*(?:Фокус|Focus|Enfoque|Fokus):\s*", "", line).strip()
                elif any(kw in line.upper() for kw in ("СОВЕТ ДНЯ", "TIP OF THE DAY", "CONSEJO DEL DÍA", "CONSEJO DEL DIA", "TIPP DES TAGES", "CONSEIL DU JOUR")):
                    clean_adv = re.sub(r'<[^>]*>', '', line)
                    clean_adv = re.sub(
                        r'(?:СОВЕТ ДНЯ|TIP OF THE DAY|CONSEJO DEL D[ÍI]A|TIPP DES TAGES|CONSEIL DU JOUR)\s*(?:☝️|☝)?\s*[:\-–—]?\s*',
                        '',
                        clean_adv,
                        flags=re.IGNORECASE,
                    ).strip()
                    if clean_adv:
                        focus = f"{labels['advice_prefix']}: {clean_adv[:60]}"
                    forecast_lines.append(line)
                elif "Энергия:" in line or "Часы удачи:" in line or "Energy:" in line:
                    parts = line.split("|")
                    for p in parts:
                        if "Энергия:" in p or "Energy:" in p:
                            energy = p.replace("•", "").replace("Энергия:", "").replace("Energy:", "").strip()
                        if any(hk in p for hk in ("Часы удачи:", "Часы:", "Lucky hours:")):
                            lucky_hours = p.replace("Часы удачи:", "").replace("Часы:", "").replace("Lucky hours:", "").strip()
                else:
                    # Отсекаем финальную притчу ✨✨✨ ... ✨✨✨ от последнего знака (Рыбы)
                    if line.startswith("✨✨✨"):
                        continue
                    forecast_lines.append(line)

            forecast = "\n\n".join(forecast_lines).strip()
            forecast = re.sub(r'\n*✨✨✨.*$', '', forecast, flags=re.DOTALL).strip()
            forecast = re.sub(r'<[^>]*>', '', forecast).strip()

        if not forecast:
            forecast = labels["fallback_fmt"].format(sign=local_sign_name)

        signs_data.append({
            "id": meta["id"],
            "name": local_sign_name,
            "symbol": meta["symbol"],
            "dates": meta["dates"],
            "element": local_element,
            "color": meta["color"],
            "focus": focus,
            "energy": energy,
            "lucky_hours": lucky_hours,
            "forecast": forecast
        })

    return {
        "date": target_date,
        "raw_text": clean_text,
        "signs": signs_data,
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    }


def _sync_index_to_mobile_assets(index_data: list):
    """Синхронизирует index.json со встроенными ассетами мобильного приложения."""
    if os.path.exists(MOBILE_ARCHIVE_DIR):
        try:
            with open(os.path.join(MOBILE_ARCHIVE_DIR, "index.json"), "w", encoding="utf-8") as f:
                json.dump(index_data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass


def prune_archive(max_days: int = MAX_ARCHIVE_DAYS):
    """
    Очищает серверный архив, сохраняя только последние max_days (60 дней).
    Удаляет устаревшие файлы гороскопов на всех языках и обновляет index.json.
    """
    index_path = os.path.join(ARCHIVE_DIR, "index.json")
    if not os.path.exists(index_path):
        return

    try:
        with open(index_path, "r", encoding="utf-8") as f:
            entries = json.load(f)
    except Exception:
        return

    if not isinstance(entries, list):
        return

    def parse_entry_date(item):
        d_str = item.get("date", "")
        try:
            return datetime.strptime(d_str, "%d.%m.%Y")
        except Exception:
            return datetime.min

    sorted_entries = sorted(entries, key=parse_entry_date, reverse=True)

    kept_entries = sorted_entries[:max_days]
    removed_entries = sorted_entries[max_days:]

    for old_item in removed_entries:
        iso_key = old_item.get("iso_date", "")
        if iso_key:
            suffixes = [""] + [f"_{l}" for l in SUPPORTED_LANGS if l != "ru"]
            for sfx in suffixes:
                for prefix in ("horoscope_", "zodiac_"):
                    fpath = os.path.join(ARCHIVE_DIR, f"{prefix}{iso_key}{sfx}.json")
                    if os.path.exists(fpath):
                        try:
                            os.remove(fpath)
                        except OSError:
                            pass

    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(kept_entries, f, ensure_ascii=False, indent=2)
    _sync_index_to_mobile_assets(kept_entries)

    if removed_entries:
        print(f"🧹 Серверный архив очищен: удалено {len(removed_entries)} старых записей. Хранится: {len(kept_entries)} дн. (макс. {max_days})")


def generate_archive_preview(greeting: str, display_date: str = "") -> str:
    """
    Генерирует нейтральное публичное превью архива без персональных данных автора (Олег, 1978, Кишинев, градусы Асцендента).
    """
    clean = greeting.strip()
    clean = re.sub(
        r'^(☀️|🌿|🕊️|☕|🌤️|🍀|🌅|✨|🍃|🌸|💫|🌻|🌱|\s)*(Приветствую(\s+Вас)?|Здравствуйте|Доброе\s+утро|Добрый\s+день|Доброго\s+утра),?\s*(уважаемый|уважаемая|дорогой|дорогая)?\s*Олег[а-яА-Я]*[!.,]?\s*',
        '',
        clean,
        flags=re.IGNORECASE,
    )
    clean = re.sub(r'\bОлег[а-яА-Я]*\b', '', clean, flags=re.IGNORECASE)
    # Удаляем любые предложения с натальным расчетом автора, Асцендентом, МС и домами
    clean = re.sub(r'[^.!?]*(?:восходящий знак|Асцендент|Asc|Середин[ауы] Неба|МС|MC|натальн[а-я]+ карт[а-я]+|персональный астрологический)[^.!?]*[.!?]\s*', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'\(\s*\d{1,2}°\d{0,2}\'?\s*[А-Яа-яA-Za-z\s]*\)', '', clean)
    clean = re.sub(r'\b\d{1,2}°\d{0,2}\'?\s*[А-Яа-яA-Za-z]*', '', clean)
    clean = re.sub(r'23\.05\.1978|1978-05-23|00:05|00:50|Кишинев[а-яА-Я]*|Кишинёв[а-яА-Я]*|Chisinau', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'\(\s*[,;:\s]*\)', '', clean)
    clean = re.sub(r'\s+', ' ', clean).strip(' ,;:-')

    if not clean or len(clean) < 25:
        return f"✨ Астрологический прогноз на {display_date}: ключевые аспекты планет, лунный день и рекомендации для всех знаков зодиака."

    if len(clean) > 150:
        clean = clean[:147].rstrip() + "..."
    return clean


def save_horoscope_to_archive(
    raw_text: str,
    target_date: str = None,
    lang: str = "ru",
    update_latest: bool = True,
) -> dict:
    """
    Сохраняет прогноз в data/archive/horoscope_<iso>[_<lang>].json и (если update_latest=True) в data/latest_horoscope[_<lang>].json.
    При заблаговременной предгенерации на завтрашние сутки (update_latest=False) сохраняет архивный файл по дате,
    не перезаписывая преждевременно текущий latest_horoscope.json, если он уже существует.
    """
    ensure_directories()
    lang_clean = (lang or "ru").strip().lower()
    display_date = format_date_dmy(target_date) if target_date else ""
    if not display_date:
        display_date = datetime.now().strftime("%d.%m.%Y")

    try:
        dt = datetime.strptime(display_date, "%d.%m.%Y")
        iso_key = dt.strftime("%Y_%m_%d")
    except Exception:
        iso_key = display_date.replace(".", "_")

    data_payload = parse_horoscope_structure(raw_text, display_date)

    latest_file_name = "latest_horoscope.json" if lang_clean == "ru" else f"latest_horoscope_{lang_clean}.json"
    latest_path = os.path.join(DATA_DIR, latest_file_name)

    if update_latest or not os.path.exists(latest_path):
        with open(latest_path, "w", encoding="utf-8") as f:
            json.dump(data_payload, f, ensure_ascii=False, indent=2)

        if os.path.exists(MOBILE_DATA_DIR):
            try:
                with open(os.path.join(MOBILE_DATA_DIR, latest_file_name), "w", encoding="utf-8") as f:
                    json.dump(data_payload, f, ensure_ascii=False, indent=2)
            except Exception:
                pass

    archive_file_name = f"horoscope_{iso_key}.json" if lang_clean == "ru" else f"horoscope_{iso_key}_{lang_clean}.json"
    archive_file_path = os.path.join(ARCHIVE_DIR, archive_file_name)
    with open(archive_file_path, "w", encoding="utf-8") as f:
        json.dump(data_payload, f, ensure_ascii=False, indent=2)

    # Обновляем index.json строго канонической записью (файл без языкового суффикса horoscope_<iso>.json),
    # чтобы мультиязычный цикл не перезаписывал ссылку на _fr.json
    index_path = os.path.join(ARCHIVE_DIR, "index.json")
    index_data = []
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                index_data = json.load(f)
            if not isinstance(index_data, list):
                index_data = []
        except Exception:
            index_data = []

    existing_entry = next((item for item in index_data if item.get("date") == display_date), None)
    if lang_clean == "ru" or existing_entry is None:
        preview_text = (
            generate_archive_preview(data_payload["greeting"], display_date)
            if lang_clean == "ru"
            else (existing_entry.get("preview") if existing_entry else f"✨ Астрологический прогноз на {display_date}: ключевые аспекты планет и рекомендации дня.")
        )
        new_entry = {
            "date": display_date,
            "iso_date": iso_key,
            "file": f"archive/horoscope_{iso_key}.json",
            "preview": preview_text,
            "updated_at": data_payload["updated_at"]
        }

        if existing_entry:
            index_data = [new_entry if item.get("date") == display_date else item for item in index_data]
        else:
            index_data.insert(0, new_entry)

        with open(index_path, "w", encoding="utf-8") as f:
            json.dump(index_data, f, ensure_ascii=False, indent=2)
        _sync_index_to_mobile_assets(index_data)

    prune_archive(MAX_ARCHIVE_DAYS)

    print(f"🗄️ Персональный гороскоп на {display_date} ({lang_clean}) сохранен в архив: {archive_file_name}")
    return data_payload


def save_zodiac_to_archive(
    raw_text: str,
    target_date: str = None,
    lang: str = "ru",
    update_latest: bool = True,
) -> dict:
    """
    Сохраняет гороскоп по 12 знакам зодиака в data/archive/zodiac_<iso>[_<lang>].json
    и (если update_latest=True) в data/latest_zodiac[_<lang>].json.
    """
    ensure_directories()
    lang_clean = (lang or "ru").strip().lower()
    display_date = format_date_dmy(target_date) if target_date else ""
    if not display_date:
        display_date = datetime.now().strftime("%d.%m.%Y")

    try:
        dt = datetime.strptime(display_date, "%d.%m.%Y")
        iso_key = dt.strftime("%Y_%m_%d")
    except Exception:
        iso_key = display_date.replace(".", "_")

    zodiac_payload = parse_zodiac_structure(raw_text, display_date, lang=lang_clean)

    latest_zodiac_file_name = "latest_zodiac.json" if lang_clean == "ru" else f"latest_zodiac_{lang_clean}.json"
    latest_zodiac_path = os.path.join(DATA_DIR, latest_zodiac_file_name)

    if update_latest or not os.path.exists(latest_zodiac_path):
        with open(latest_zodiac_path, "w", encoding="utf-8") as f:
            json.dump(zodiac_payload, f, ensure_ascii=False, indent=2)

        if os.path.exists(MOBILE_DATA_DIR):
            try:
                with open(os.path.join(MOBILE_DATA_DIR, latest_zodiac_file_name), "w", encoding="utf-8") as f:
                    json.dump(zodiac_payload, f, ensure_ascii=False, indent=2)
            except Exception:
                pass

    archive_zodiac_name = f"zodiac_{iso_key}.json" if lang_clean == "ru" else f"zodiac_{iso_key}_{lang_clean}.json"
    archive_zodiac_path = os.path.join(ARCHIVE_DIR, archive_zodiac_name)
    with open(archive_zodiac_path, "w", encoding="utf-8") as f:
        json.dump(zodiac_payload, f, ensure_ascii=False, indent=2)

    prune_archive(MAX_ARCHIVE_DAYS)

    print(f"♈ Гороскоп по 12 знакам зодиака на {display_date} ({lang_clean}) сохранен: {archive_zodiac_name} (период хранения: {MAX_ARCHIVE_DAYS} дн.)")
    return zodiac_payload
