"""
Сервис доставки сообщений и медиа в Telegram.
Включает:
- Умное разбиение длинных текстов по абзацам (лимит 4000 символов)
- Двухуровневую защиту HTML (мгновенный fallback на чистый текст при ошибке разметки)
- Отправку сгенерированных изображений или резервной обложки
- Поддержку личных чатов и публичных/приватных каналов
"""

import io
import os
import re
import requests


def strip_html_tags(text: str) -> str:
    """
    Очищает текст от всех HTML-тегов для безопасной резервной отправки чистым текстом.
    """
    clean = re.sub(r"<[^>]+>", "", text)
    # Заменяем распространенные HTML-сущности
    clean = clean.replace("&quot;", '"').replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    return clean


def split_text_into_chunks(text: str, max_chars: int = 3800) -> list[str]:
    """
    Разбивает длинный текст на части по границам абзацев.
    Если частей больше одной, добавляет пометку: 📄 Часть X из Y.
    """
    if len(text) <= max_chars:
        return [text]

    paragraphs = text.split("\n\n")
    chunks = []
    current_chunk = ""

    for p in paragraphs:
        # Если отдельный абзац сам по себе длиннее max_chars, делим по одиночным переносам
        if len(p) > max_chars:
            lines = p.split("\n")
            for line in lines:
                if len(current_chunk) + len(line) + 2 > max_chars and current_chunk:
                    chunks.append(current_chunk.strip())
                    current_chunk = line + "\n"
                else:
                    current_chunk += line + "\n"
        else:
            if len(current_chunk) + len(p) + 2 > max_chars and current_chunk:
                chunks.append(current_chunk.strip())
                current_chunk = p + "\n\n"
            else:
                current_chunk += p + "\n\n"

    if current_chunk.strip():
        chunks.append(current_chunk.strip())

    total = len(chunks)
    if total > 1:
        formatted_chunks = []
        for idx, chunk in enumerate(chunks, 1):
            footer = f"\n\n📄 <i>Часть {idx} из {total}</i>"
            formatted_chunks.append(chunk + footer)
        return formatted_chunks

    return chunks


def send_text_message(bot_token: str, chat_id: str, text: str) -> bool:
    """
    Отправляет текстовое сообщение в Telegram.
    При ошибке разметки HTML (код 400) мгновенно делает резервную отправку чистым текстом.
    """
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    chunks = split_text_into_chunks(text)
    
    for i, chunk in enumerate(chunks, 1):
        # 1. Первая попытка: отправка с HTML-разметкой
        payload = {
            "chat_id": chat_id,
            "text": chunk,
            "parse_mode": "HTML"
        }
        
        try:
            response = requests.post(url, json=payload, timeout=20)
            if response.status_code == 200:
                print(f"📨 Сообщение (часть {i}/{len(chunks)}) успешно доставлено в Telegram!")
                continue
            
            # Если Telegram вернул ошибку форматирования HTML (400)
            print(f"⚠️ Ошибка отправки HTML ({response.text}). Применяем резервную отправку чистым текстом...")
            
            # 2. Вторая попытка: отправка без разметки (гарантированная доставка)
            plain_chunk = strip_html_tags(chunk)
            plain_payload = {
                "chat_id": chat_id,
                "text": plain_chunk
            }
            retry_res = requests.post(url, json=plain_payload, timeout=20)
            retry_res.raise_for_status()
            print(f"📨 Сообщение (часть {i}/{len(chunks)}) успешно доставлено чистым текстом!")

        except Exception as e:
            print(f"❌ Критическая ошибка при отправке сообщения в Telegram: {e}")
            raise e

    return True


def send_photo(bot_token: str, chat_id: str, photo_data: bytes | str, caption: str = "✨ <b>Космическая визуализация ключевых аспектов дня</b>") -> bool:
    """
    Отправляет фотографию в Telegram.
    Принимает байты изображения или путь к локальному файлу обложки.
    """
    url = f"https://api.telegram.org/bot{bot_token}/sendPhoto"
    
    try:
        if isinstance(photo_data, bytes):
            files = {"photo": ("cosmic_day.png", io.BytesIO(photo_data), "image/png")}
            data = {"chat_id": chat_id, "caption": caption, "parse_mode": "HTML"}
            response = requests.post(url, data=data, files=files, timeout=30)
        elif isinstance(photo_data, str) and os.path.exists(photo_data):
            with open(photo_data, "rb") as f:
                files = {"photo": ("default_cover.png", f, "image/png")}
                data = {"chat_id": chat_id, "caption": caption, "parse_mode": "HTML"}
                response = requests.post(url, data=data, files=files, timeout=30)
        else:
            print(f"⚠️ Фотография не найдена или имеет неверный формат: {photo_data}")
            return False

        if response.status_code == 200:
            print("🖼️ Иллюстрация дня успешно отправлена в Telegram!")
            return True

        # Резервная отправка без HTML-подписи при ошибке
        print(f"⚠️ Ошибка отправки фото с HTML-подписью ({response.text}). Повторяем с простым текстом...")
        plain_caption = strip_html_tags(caption)
        
        if isinstance(photo_data, bytes):
            files = {"photo": ("cosmic_day.png", io.BytesIO(photo_data), "image/png")}
            data = {"chat_id": chat_id, "caption": plain_caption}
            res_retry = requests.post(url, data=data, files=files, timeout=30)
        else:
            with open(photo_data, "rb") as f:
                files = {"photo": ("default_cover.png", f, "image/png")}
                data = {"chat_id": chat_id, "caption": plain_caption}
                res_retry = requests.post(url, data=data, files=files, timeout=30)

        res_retry.raise_for_status()
        print("🖼️ Иллюстрация успешно отправлена с простой подписью!")
        return True

    except Exception as e:
        print(f"⚠️ Не удалось отправить фотографию: {e}. Текстовая рассылка остается доставленной.")
        return False
