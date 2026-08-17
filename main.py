import os
import sys
import requests
import google.generativeai as genai

# Получаем ключи из безопасного хранилища GitHub
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
TELEGRAM_TOKEN = os.environ.get("TELEGRAM_TOKEN")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID")

def generate_horoscope():
    """Генерирует гороскоп с помощью Gemini API."""
    genai.configure(api_key=GEMINI_API_KEY)
    
    # Используем быструю и современную модель
    model = genai.GenerativeModel('gemini-pro')
    
    # Промпт (задание) для нейросети
    prompt = (
        "Составь подробный астрологический прогноз на сегодня для всех 12 знаков зодиака. "
        "Сделай это одним связным текстом. Каждый знак зодиака выдели жирным шрифтом "
        "и добавь подходящий эмодзи. Текст должен быть на русском языке, "
        "позитивным и мотивирующим. Уложись в 3500 символов, чтобы текст поместился в Telegram."
    )
    
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        print(f"Критическая ошибка при генерации текста: {e}")
        sys.exit(1) # Останавливаем скрипт с ошибкой

def send_to_telegram(text):
    """Отправляет сгенерированный текст в Telegram канал."""
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": text,
        "parse_mode": "Markdown" # Позволяет использовать жирный шрифт
    }
    
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status() # Проверяем, нет ли ошибок от сервера Telegram
        print("Гороскоп успешно отправлен в Telegram-канал!")
    except requests.exceptions.RequestException as e:
        print(f"Ошибка при отправке в Telegram: {e}")
        if response is not None:
            print(f"Ответ сервера Telegram: {response.text}")
        sys.exit(1)

if __name__ == "__main__":
    # Проверка, что все ключи на месте
    if not all([GEMINI_API_KEY, TELEGRAM_TOKEN, TELEGRAM_CHAT_ID]):
        print("Ошибка: Не заданы необходимые ключи доступа (переменные окружения).")
        sys.exit(1)
        
    print("Начинаем генерацию гороскопа...")
    horoscope_text = generate_horoscope()
    
    print("Отправляем в канал...")
    send_to_telegram(horoscope_text)
