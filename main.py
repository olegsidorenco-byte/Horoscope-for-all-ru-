import os
import sys
import requests
from google import genai

# Получаем ключи из безопасного хранилища GitHub и очищаем от пробелов
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()
TELEGRAM_TOKEN = os.environ.get("TELEGRAM_TOKEN", "").strip()
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()

GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.7-flash")

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

def send_to_telegram(text):
    """Отправляет текст в Telegram, разбивая на части при превышении лимита."""
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    
    # Лимит Telegram 4096, берем с безопасным запасом 4000
    max_len = 4000
    parts = []
    
    # Умная разбивка длинного текста
    while len(text) > 0:
        if len(text) <= max_len:
            parts.append(text)
            break
        
        # Ищем последний перенос строки, чтобы не рубить слово пополам
        split_at = text.rfind('\n', 0, max_len)
        if split_at == -1: 
            split_at = max_len
            
        parts.append(text[:split_at])
        text = text[split_at:].strip()
    
    # Отправляем каждую часть
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
            print(f"Ошибка при отправке в Telegram (часть {i+1}): {e}")
            if 'response' in locals() and response is not None:
                print(f"Ответ сервера Telegram: {response.text}")
            sys.exit(1)
            
    print("Гороскоп успешно отправлен в Telegram-канал!")

if __name__ == "__main__":
    if not all([GEMINI_API_KEY, TELEGRAM_TOKEN, TELEGRAM_CHAT_ID]):
        print("Ошибка: Не заданы необходимые ключи доступа (переменные окружения).")
        sys.exit(1)
        
    print(f"Начинаем генерацию гороскопа (используемая модель: {GEMINI_MODEL})...")
    horoscope_text = generate_horoscope()
    
    print(f"Сгенерирован текст длиной {len(horoscope_text)} символов. Отправляем в канал...")
    send_to_telegram(horoscope_text)
