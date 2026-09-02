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
from datetime import datetime, timedelta

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
ARCHIVE_DIR = os.path.join(DATA_DIR, "archive")
MAX_ARCHIVE_DAYS = 60

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


def ensure_directories():
    """Создает необходимые каталоги data и data/archive."""
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(ARCHIVE_DIR, exist_ok=True)


def parse_horoscope_structure(raw_text: str, target_date: str) -> dict:
    """Парсит сгенерированный текст общего натального гороскопа."""
    clean_text = raw_text.strip()
    paragraphs = [p.strip() for p in clean_text.split("\n\n") if p.strip()]
    greeting = paragraphs[0] if paragraphs else clean_text
    
    topics = []
    topic_blocks = clean_text.split("<b>")
    for block in topic_blocks[1:]:
        parts = block.split("</b>", 1)
        if len(parts) == 2:
            raw_title = parts[0].strip()
            content = parts[1].strip()
            icon = "✨"
            if "Влияние планет" in raw_title:
                icon = "🪐"
            elif "Работа" in raw_title or "бизнес" in raw_title:
                icon = "💼"
            elif "Личные отношения" in raw_title or "общение" in raw_title:
                icon = "❤️"
            elif "Здоровье" in raw_title or "тонус" in raw_title:
                icon = "🌿"
            elif "Добрый совет" in raw_title:
                icon = "💡"
            elif "Пожелание" in raw_title:
                icon = "✨"
                
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
        "updated_at": datetime.utcnow().isoformat() + "Z"
    }


def parse_zodiac_structure(raw_text: str, target_date: str) -> dict:
    """Парсит текст гороскопа по 12 знакам зодиака в структурированный JSON."""
    clean_text = raw_text.strip()
    signs_data = []

    for meta in ZODIAC_SIGNS_META:
        sign_name = meta["name"]
        symbol = meta["symbol"]
        
        pattern = re.compile(rf"{symbol}\s*{sign_name}[^<]*</b>(.*?)(?=<b>[♈♉♊♋♌♍♎♏♐♑♒♓]|\Z)", re.DOTALL | re.IGNORECASE)
        match = pattern.search(clean_text)
        
        block_text = ""
        focus = "Гармония и развитие"
        energy = "85%"
        lucky_hours = "10:00–12:00"
        forecast = ""

        if match:
            block_text = match.group(1).strip()
        else:
            simple_pattern = re.compile(rf"{sign_name}.*?\n(.*?)(?=\n[♈♉♊♋♌♍♎♏♐♑♒♓]|\Z)", re.DOTALL | re.IGNORECASE)
            simple_match = simple_pattern.search(clean_text)
            if simple_match:
                block_text = simple_match.group(1).strip()

        if block_text:
            lines = [l.strip() for l in block_text.split("\n") if l.strip()]
            forecast_lines = []
            for line in lines:
                if "Фокус:" in line:
                    focus = line.replace("•", "").replace("Фокус:", "").strip()
                elif "Энергия:" in line or "Часы удачи:" in line:
                    parts = line.split("|")
                    for p in parts:
                        if "Энергия:" in p:
                            energy = p.replace("•", "").replace("Энергия:", "").strip()
                        if "Часы удачи:" in p or "Часы:" in p:
                            lucky_hours = p.replace("Часы удачи:", "").replace("Часы:", "").strip()
                else:
                    forecast_lines.append(line)
            
            forecast = " ".join(forecast_lines).strip()
            forecast = re.sub(r'<[^>]*>', '', forecast).strip()

        if not forecast:
            forecast = f"Благоприятный день для знака {sign_name}. Сосредоточьтесь на ключевых задачах и доверяйте интуиции."

        signs_data.append({
            "id": meta["id"],
            "name": meta["name"],
            "symbol": meta["symbol"],
            "dates": meta["dates"],
            "element": meta["element"],
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
        "updated_at": datetime.utcnow().isoformat() + "Z"
    }


def prune_archive(max_days: int = MAX_ARCHIVE_DAYS):
    """
    Очищает серверный архив, сохраняя только последние max_days (60 дней).
    Удаляет устаревшие файлы гороскопов и обновляет index.json.
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

    # Парсинг дат и сортировка по убыванию (сначала самые свежие)
    def parse_entry_date(item):
        d_str = item.get("date", "")
        try:
            return datetime.strptime(d_str, "%d.%m.%Y")
        except Exception:
            return datetime.min

    sorted_entries = sorted(entries, key=parse_entry_date, reverse=True)

    # Если записей больше 60, отсекаем старые
    kept_entries = sorted_entries[:max_days]
    removed_entries = sorted_entries[max_days:]

    # Удаление устаревших файлов
    for old_item in removed_entries:
        iso_key = old_item.get("iso_date", "")
        if iso_key:
            h_file = os.path.join(ARCHIVE_DIR, f"horoscope_{iso_key}.json")
            z_file = os.path.join(ARCHIVE_DIR, f"zodiac_{iso_key}.json")
            if os.path.exists(h_file):
                try:
                    os.remove(h_file)
                except OSError:
                    pass
            if os.path.exists(z_file):
                try:
                    os.remove(z_file)
                except OSError:
                    pass

    # Сохраняем обновленный index.json
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(kept_entries, f, ensure_ascii=False, indent=2)

    if removed_entries:
        print(f"🧹 Серверный архив очищен: удалено {len(removed_entries)} старых записей. Хранится: {len(kept_entries)} дн. (макс. {max_days})")


def save_horoscope_to_archive(raw_text: str, target_date: str = None) -> dict:
    """Сохраняет персональный прогноз в data/latest_horoscope.json и data/archive/."""
    ensure_directories()
    if not target_date:
        target_date = datetime.now().strftime("%d.%m.%Y")
        
    try:
        dt = datetime.strptime(target_date, "%d.%m.%Y")
        iso_key = dt.strftime("%Y_%m_%d")
        display_date = target_date
    except Exception:
        iso_key = target_date.replace(".", "_")
        display_date = target_date

    data_payload = parse_horoscope_structure(raw_text, display_date)

    latest_path = os.path.join(DATA_DIR, "latest_horoscope.json")
    with open(latest_path, "w", encoding="utf-8") as f:
        json.dump(data_payload, f, ensure_ascii=False, indent=2)

    archive_file_name = f"horoscope_{iso_key}.json"
    archive_file_path = os.path.join(ARCHIVE_DIR, archive_file_name)
    with open(archive_file_path, "w", encoding="utf-8") as f:
        json.dump(data_payload, f, ensure_ascii=False, indent=2)

    index_path = os.path.join(ARCHIVE_DIR, "index.json")
    index_data = []
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                index_data = json.load(f)
        except Exception:
            index_data = []

    existing_entry = next((item for item in index_data if item.get("date") == display_date), None)
    new_entry = {
        "date": display_date,
        "iso_date": iso_key,
        "file": f"archive/{archive_file_name}",
        "preview": data_payload["greeting"][:160] + "...",
        "updated_at": data_payload["updated_at"]
    }
    
    if existing_entry:
        index_data = [new_entry if item.get("date") == display_date else item for item in index_data]
    else:
        index_data.insert(0, new_entry)

    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index_data, f, ensure_ascii=False, indent=2)

    # Применение правила 60 дней
    prune_archive(MAX_ARCHIVE_DAYS)

    print(f"🗄️ Персональный гороскоп на {display_date} сохранен в архив: {archive_file_name} (период хранения: {MAX_ARCHIVE_DAYS} дн.)")
    return data_payload


def save_zodiac_to_archive(raw_text: str, target_date: str = None) -> dict:
    """Сохраняет гороскоп по 12 знакам зодиака в data/latest_zodiac.json и data/archive/."""
    ensure_directories()
    if not target_date:
        target_date = datetime.now().strftime("%d.%m.%Y")

    try:
        dt = datetime.strptime(target_date, "%d.%m.%Y")
        iso_key = dt.strftime("%Y_%m_%d")
        display_date = target_date
    except Exception:
        iso_key = target_date.replace(".", "_")
        display_date = target_date

    zodiac_payload = parse_zodiac_structure(raw_text, display_date)

    latest_zodiac_path = os.path.join(DATA_DIR, "latest_zodiac.json")
    with open(latest_zodiac_path, "w", encoding="utf-8") as f:
        json.dump(zodiac_payload, f, ensure_ascii=False, indent=2)

    archive_zodiac_name = f"zodiac_{iso_key}.json"
    archive_zodiac_path = os.path.join(ARCHIVE_DIR, archive_zodiac_name)
    with open(archive_zodiac_path, "w", encoding="utf-8") as f:
        json.dump(zodiac_payload, f, ensure_ascii=False, indent=2)

    # Применение правила 60 дней
    prune_archive(MAX_ARCHIVE_DAYS)

    print(f"♈ Гороскоп по 12 знакам зодиака на {display_date} сохранен: {archive_zodiac_name} (период хранения: {MAX_ARCHIVE_DAYS} дн.)")
    return zodiac_payload
