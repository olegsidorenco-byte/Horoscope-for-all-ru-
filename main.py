import os
import sys
import time
import urllib.parse
import requests
from google import genai

# Получаем ключи из безопасного хранилища GitHub
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()
TELEGRAM_TOKEN = os.environ.get("TELEGRAM_TOKEN", "").strip()
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.7-flash").strip()

def generate_horoscope():
    """Генерирует гороскоп с помощью Google GenAI."""
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        prompt = (
            "Составь астрологический прогноз на сегодня для всех 12 знаков зодиака. "
            "Каждый знак зодиака выдели жирным шрифтом и добавь подходящий эмодзи. "
            "Текст должен быть на русском языке, позитивным и мотивирующим. "
            "Пиши лаконично, максимум по 2-3 предложения на каждый знак, "
            "чтобы общий текст легко читался и поместился в одно сообщение."
        )
        
        response = client.models.generate_content(
            model=GEMINI_MODEL, 
            contents=prompt
        )
        return response.text
        
    except Exception as e:
        print(f"Критическая ошибка при генерации текста: {e}")
        sys.exit(1)

def send_photo_to_telegram(photo_data, is_local=False):
    """Отправляет фотографию в Telegram (локальный файл или по URL)."""
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendPhoto"
    
    try:
        if is_local:
            # Отправка локального файла (нашего логотипа)
            with open(photo_data, 'rb') as photo_file:
                payload = {"chat_id": TELEGRAM_CHAT_ID}
                files = {"photo": photo_file}
                response = requests.post(url, data=payload, files=files)
        else:
            # Отправка картинки по прямой ссылке (ИИ-генерация)
            payload = {
                "chat_id": TELEGRAM_CHAT_ID,
                "photo": photo_data
            }
            response = requests.post(url, json=payload)
            
        response.raise_for_status()
        print(f"Фотография успешно отправлена!")
    except Exception as e:
        print(f"Ошибка при отправке фото: {e}")
        if hasattr(e, 'response') and getattr(e, 'response') is not None:
            print(f"Ответ сервера Telegram: {e.response.text}")
        # Мы не делаем sys.exit(1) здесь, чтобы сбой одной картинки 
        # не отменил публикацию самого текстового гороскопа.

def send_text_to_telegram(text):
    """Отправляет текст в Telegram, разбивая на части при превышении лимита."""
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    
    max_len = 4000
    parts = []
    
    while len(text) > 0:
        if len(text) <= max_len:
            parts.append(text)
            break
        
        split_at = text.rfind('\n', 0, max_len)
        if split_at == -1: 
            split_at = max_len
            
        parts.append(text[:split_at])
        text = text[split_at:].strip()
    
    for i, part in enumerate(parts):
        payload = {
            "chat_id": TELEGRAM_CHAT_ID,
            "text": part,
            "parse_mode": "Markdown"
        }
        
        try:
            response = requests.post(url, json=payload)
            response.raise_for_status() 
        except requests.exceptions.RequestException as e:
            print(f"Ошибка при отправке текста (часть {i+1}): {e}")
            sys.exit(1)
            
    print("Текст гороскопа успешно отправлен!")

def get_ai_image_url():
    """Формирует ссылку для бесплатной генерации уникального ИИ-арта."""
    # Используем текущее время (seed), чтобы каждый день картинка была новой
    seed = int(time.time())
    
    # Промпт для ИИ-художника (на английском языке для лучшего качества)
    image_prompt = "Astrology, zodiac circle, mystical space, glowing stars, tarot card style, cinematic lighting, 8k resolution"
    encoded_prompt = urllib.parse.quote(image_prompt)
    
    # Ссылка-генератор Pollinations
    return f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1024&height=1024&nologo=true&seed={seed}"

if __name__ == "__main__":
    if not all([GEMINI_API_KEY, TELEGRAM_TOKEN, TELEGRAM_CHAT_ID]):
        print("Ошибка: Не заданы необходимые ключи доступа.")
        sys.exit(1)
        
    print(f"Начинаем процесс публикации...")

    # 1. Отправляем верхний логотип
    logo_filename = "Astro_main_top25.png"
    if os.path.exists(logo_filename):
        print("Отправляем логотип...")
        send_photo_to_telegram(logo_filename, is_local=True)
    else:
        print(f"Внимание: Файл {logo_filename} не найден в репозитории. Пропускаем этот шаг.")

    # 2. Генерируем и отправляем текст гороскопа
    print(f"Генерируем текст (модель: {GEMINI_MODEL})...")
    horoscope_text = generate_horoscope()
    print("Отправляем текст...")
    send_text_to_telegram(horoscope_text)

    # 3. Генерируем и отправляем нижнюю ИИ-картинку
    print("Запрашиваем уникальную ИИ-картинку для финала...")
    ai_image_url = get_ai_image_url()
    send_photo_to_telegram(ai_image_url, is_local=False)
    
    print("Публикация полностью завершена!")
