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
    # Заменяем переводы строк в тегах br и p
    clean = re.sub(r"<\/?(br|p)\s*\/?>", "\n", text, flags=re.IGNORECASE)
    clean = re.sub(r"<[^>]+>", "", clean)
    # Заменяем распространенные HTML-сущности
    clean = clean.replace("&quot;", '"').replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    clean = re.sub(r"\n{3,}", "\n\n", clean)
    return clean.strip()


def split_text_into_chunks(text: str, max_chars: int = 3800) -> list[str]:
    """
    Разбивает длинный текст на части по границам абзацев.
    Если частей больше одной, добавляет пометку: 📄 Часть X из Y.
    """
    if len(text) <= max_chars:
        return [text]

    paragraphs = text.split("\n\n")
    raw_pieces = []

    for p in paragraphs:
        if len(p) <= max_chars:
            raw_pieces.append(p)
        else:
            lines = p.split("\n")
            for line in lines:
                if len(line) <= max_chars:
                    raw_pieces.append(line)
                else:
                    words = line.split(" ")
                    buf = ""
                    for w in words:
                        if len(buf) + len(w) + 1 <= max_chars:
                            buf = f"{buf} {w}".strip()
                        else:
                            if buf:
                                raw_pieces.append(buf)
                            buf = w
                    if buf:
                        raw_pieces.append(buf)

    chunks = []
    current_chunk = ""

    for piece in raw_pieces:
        sep = "\n\n" if "\n" not in piece else "\n"
        if len(current_chunk) + len(piece) + len(sep) <= max_chars:
            current_chunk = f"{current_chunk}{sep}{piece}".strip()
        else:
            if current_chunk:
                chunks.append(current_chunk)
            current_chunk = piece

    if current_chunk:
        chunks.append(current_chunk)

    total = len(chunks)
    if total > 1:
        formatted_chunks = []
        for idx, chunk in enumerate(chunks, 1):
            footer = f"\n\n📄 <i>Часть {idx} из {total}</i>"
            formatted_chunks.append(chunk + footer)
        return formatted_chunks

    return chunks


def send_chat_action(bot_token: str, chat_id: str, action: str = "typing") -> bool:
    """
    Отправляет статус действия бота в чат (по умолчанию 'typing' — печатает...).
    Это снижает риск спам-блокировки и делает поведение бота естественным.
    """
    url = f"https://api.telegram.org/bot{bot_token}/sendChatAction"
    try:
        requests.post(url, json={"chat_id": chat_id, "action": action}, timeout=5)
        return True
    except Exception:
        # Не критично, если статус действия не прошел
        return False


def send_single_message_with_retry(bot_token: str, chat_id: str, text: str, max_retries: int = 3) -> bool:
    """
    Отправляет одиночное сообщение с автоматической защитой от анти-спама:
    - При ошибке 429 Too Many Requests: выжидает время из retry_after и повторяет.
    - При ошибке 400 Bad Request (разметка HTML): мгновенно отправляет чистый текст.
    - При сетевых сбоях: повторяет с экспоненциальной задержкой до max_retries раз.
    """
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"

    for attempt in range(1, max_retries + 1):
        payload = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML"
        }

        try:
            response = requests.post(url, json=payload, timeout=20)
            
            # Успешная доставка
            if response.status_code == 200:
                return True

            # 1. Защита от спам-лимитов Telegram (HTTP 429 Too Many Requests / Flood Control)
            if response.status_code == 429:
                try:
                    resp_json = response.json()
                    retry_after = resp_json.get("parameters", {}).get("retry_after", 5)
                except Exception:
                    retry_after = 5
                
                print(f"⏳ [Анти-спам Telegram] Превышен лимит запросов. Ожидание {retry_after + 1} сек...")
                import time
                time.sleep(retry_after + 1)
                continue

            # 2. Ошибка форматирования HTML (400) — резервная отправка чистым текстом
            if response.status_code == 400:
                print(f"⚠️ Ошибка разметки HTML ({response.text[:120]}). Отправляем резервную копию чистым текстом...")
                plain_payload = {
                    "chat_id": chat_id,
                    "text": strip_html_tags(text)
                }
                fallback_res = requests.post(url, json=plain_payload, timeout=20)
                if fallback_res.status_code == 200:
                    return True
                fallback_res.raise_for_status()

            # 3. Серверные сбои (5xx) — пауза и повтор
            if response.status_code >= 500:
                print(f"⚠️ Ошибка сервера Telegram (HTTP {response.status_code}), попытка {attempt}/{max_retries}...")
                import time
                time.sleep(2 * attempt)
                continue

            response.raise_for_status()

        except requests.exceptions.RequestException as e:
            print(f"⚠️ Сетевая ошибка при отправке ({e}), попытка {attempt}/{max_retries}...")
            import time
            time.sleep(2 * attempt)

    raise RuntimeError(f"Не удалось доставить сообщение в Telegram после {max_retries} попыток.")


def send_topic_messages(bot_token: str, chat_id: str, messages: list[str], delay_seconds: float = 2.0) -> bool:
    """
    Отправляет пакет тематических сообщений отдельными частями с соблюдением
    строгих анти-спам правил Telegram (задержка между сообщениями, typing-индикатор,
    автоматический Flood Control).
    """
    import time
    import sys

    total = len(messages)
    print(f"📦 Подготовка к отправке пакета из {total} тематических сообщений...")

    for idx, msg in enumerate(messages, 1):
        if not msg.strip():
            continue

        # Проверяем, если отдельная тема длиннее лимита Telegram (4096 симв.)
        chunks = split_text_into_chunks(msg)

        for c_idx, chunk in enumerate(chunks, 1):
            # Индикация набора текста для естественного темпа
            send_chat_action(bot_token, chat_id, action="typing")
            
            # Небольшая пауза для имитации набора перед сообщением
            time.sleep(0.4)

            # Отправка сообщения
            send_single_message_with_retry(bot_token, chat_id, chunk)
            
            part_info = f" (часть {c_idx}/{len(chunks)})" if len(chunks) > 1 else ""
            print(f"📨 Тематическое сообщение [{idx}/{total}]{part_info} успешно доставлено!")
            sys.stdout.flush()

        # Анти-спам задержка перед следующим тематическим сообщением
        if idx < total and delay_seconds > 0:
            time.sleep(delay_seconds)

    print("✨ Все тематические сообщения успешно доставлены без нарушений анти-спама!")
    sys.stdout.flush()
    return True


def send_text_message(bot_token: str, chat_id: str, text: str) -> bool:
    """
    Отправляет полный текст гороскопа в Telegram единым сообщением.
    Если текст по какой-то причине превысит лимит Telegram (3800 символов),
    он будет аккуратно разделен по абзацам.
    """
    import time
    chunks = split_text_into_chunks(text)
    
    if len(chunks) == 1:
        send_chat_action(bot_token, chat_id, action="typing")
        time.sleep(0.4)
        send_single_message_with_retry(bot_token, chat_id, chunks[0])
        print(f"📨 Гороскоп успешно доставлен единым сообщением в Telegram! (длина: {len(text)} симв.)")
        return True

    print(f"ℹ️ Текст превысил лимит одного сообщения ({len(text)} симв.). Отправка по частям ({len(chunks)} шт.)...")
    return send_topic_messages(bot_token, chat_id, chunks, delay_seconds=2.0)


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
