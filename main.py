import os
import sys
import requests
from google import genai

# Получаем ключи из безопасного хранилища GitHub и очищаем от случайных пробелов
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()
TELEGRAM_TOKEN = os.environ.get("TELEGRAM_TOKEN", "").strip()
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()

# Унификация: берем модель из переменных окружения. 
# Если переменная не задана в GitHub, по умолчанию используем актуальную 3.7-flash.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.7-flash")

def generate_horoscope():
    """Генерирует гороскоп с помощью новой библиотеки Google GenAI."""
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        prompt = (
            "Составь подробный астрологический прогноз на сегодня для всех 12 знаков зодиака. "
            "Сделай это одним связным текстом. Каждый знак зодиака выдели жирным шрифтом "
            "и добавь подходящий эмодзи. Текст должен быть на русском языке, "
            "позитивным и мотивирующим. Уложись в 3500 символов, чтобы текст поместился в Telegram."
        )
        
        # Модель теперь подставляется автоматически
        response = client.models.generate_content(
            model=GEMINI_MODEL, 
            contents=prompt
        )
        return response.text
        
    except Exception as e:
        print(f"Критическая ошибка при генерации текста: {e}")
        sys.exit(1)

def send_to_telegram(text):
    """Отправляет сгенерированный текст в Telegram канал."""
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": text,
        "parse_mode": "Markdown"
    }
    
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status() 
        print("Гороскоп успешно отправлен в Telegram-канал!")
    except requests.exceptions.RequestException as e:
        print(f"Ошибка при отправке в Telegram: {e}")
        if 'response' in locals() and response is not None:
            print(f"Ответ сервера Telegram: {response.text}")
        sys.exit(1)

if __name__ == "__main__":
    if not all([GEMINI_API_KEY, TELEGRAM_TOKEN, TELEGRAM_CHAT_ID]):
        print("Ошибка: Не заданы необходимые ключи доступа (переменные окружения).")
        sys.exit(1)
        
    print(f"Начинаем генерацию гороскопа (используемая модель: {GEMINI_MODEL})...")
    horoscope_text = generate_horoscope()
    
    print("Отправляем в канал...")
    send_to_telegram(horoscope_text)
