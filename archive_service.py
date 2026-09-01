"""
Модуль архивации и публикации ежедневных астрологических прогнозов.
Сохраняет актуальный гороскоп в data/latest_horoscope.json,
создает архивные копии по дням в data/archive/ и обновляет data/archive/index.json.
"""

import os
import json
import re
from datetime import datetime

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
ARCHIVE_DIR = os.path.join(DATA_DIR, "archive")


def ensure_directories():
    """Создает необходимые каталоги data и data/archive."""
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(ARCHIVE_DIR, exist_ok=True)


def parse_horoscope_structure(raw_text: str, target_date: str) -> dict:
    """Парсит сгенерированный текст гороскопа на структурированные поля."""
    clean_text = raw_text.strip()
    
    # Очистка HTML тегов для превью
    plain_text = re.sub(r'<[^>]*>', '', clean_text)
    
    # Поиск первого абзаца (приветствие)
    paragraphs = [p.strip() for p in clean_text.split("\n\n") if p.strip()]
    greeting = paragraphs[0] if paragraphs else clean_text
    
    # Извлечение тем
    topics = []
    topic_blocks = clean_text.split("<b>")
    for block in topic_blocks[1:]:
        parts = block.split("</b>", 1)
        if len(parts) == 2:
            raw_title = parts[0].strip()
            content = parts[1].strip()
            # Определение иконки
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


def save_horoscope_to_archive(raw_text: str, target_date: str = None) -> dict:
    """
    Сохраняет гороскоп в:
    1. data/latest_horoscope.json (для мгновенной загрузки в приложении)
    2. data/archive/horoscope_YYYY_MM_DD.json (персональный архив дня)
    3. data/archive/index.json (каталог доступных дат)
    """
    ensure_directories()
    
    if not target_date:
        target_date = datetime.now().strftime("%d.%m.%Y")
        
    try:
        # Формируем ISO дату для имени файла (YYYY_MM_DD)
        dt = datetime.strptime(target_date, "%d.%m.%Y")
        iso_key = dt.strftime("%Y_%m_%d")
        display_date = target_date
    except Exception:
        iso_key = target_date.replace(".", "_")
        display_date = target_date

    data_payload = parse_horoscope_structure(raw_text, display_date)

    # 1. Сохранение latest_horoscope.json
    latest_path = os.path.join(DATA_DIR, "latest_horoscope.json")
    with open(latest_path, "w", encoding="utf-8") as f:
        json.dump(data_payload, f, ensure_ascii=False, indent=2)

    # 2. Сохранение архивного файла за день
    archive_file_name = f"horoscope_{iso_key}.json"
    archive_file_path = os.path.join(ARCHIVE_DIR, archive_file_name)
    with open(archive_file_path, "w", encoding="utf-8") as f:
        json.dump(data_payload, f, ensure_ascii=False, indent=2)

    # 3. Обновление индекса архива data/archive/index.json
    index_path = os.path.join(ARCHIVE_DIR, "index.json")
    index_data = []
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                index_data = json.load(f)
        except Exception:
            index_data = []

    # Проверяем, есть ли уже эта дата в индексе
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

    # Сортировка индекса по дате (самые свежие сверху)
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index_data, f, ensure_ascii=False, indent=2)

    print(f"🗄️ Гороскоп на {display_date} успешно добавлен в архив: {archive_file_name}")
    return data_payload
