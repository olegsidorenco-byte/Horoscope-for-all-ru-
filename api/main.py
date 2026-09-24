import os
import firebase_admin
from firebase_admin import credentials, auth
from fastapi import FastAPI, Depends, HTTPException, Header
from pydantic import BaseModel
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

# Инициализация Firebase Admin SDK
# Для локальной разработки нужен файл ключа сервисного аккаунта Firebase
firebase_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
if firebase_cred_path and os.path.exists(firebase_cred_path):
    cred = credentials.Certificate(firebase_cred_path)
    firebase_admin.initialize_app(cred)
else:
    # В облаке (например, на Google Cloud) можно инициализировать без явного файла
    print("Внимание: путь к firebase credentials не найден. Используются дефолтные credentials.")
    try:
        firebase_admin.initialize_app()
    except Exception as e:
        print(f"Ошибка инициализации Firebase: {e}")

# Настройка Google Gemini
gemini_api_key = os.getenv("GEMINI_API_KEY")
if gemini_api_key:
    genai.configure(api_key=gemini_api_key)

app = FastAPI(title="Cosmic Horoscope API", version="1.0.0")

class HoroscopeRequest(BaseModel):
    lang: str = "ru"

class HoroscopeResponse(BaseModel):
    horoscope: str
    date: str

# Зависимость для проверки Firebase токена
def verify_firebase_token(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid token format")
    token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Unauthorized: {str(e)}")

@app.get("/")
def read_root():
    return {"status": "ok", "message": "Cosmic Horoscope API is running"}

@app.post("/horoscope/personal", response_model=HoroscopeResponse)
def get_personal_horoscope(req: HoroscopeRequest, user_token: dict = Depends(verify_firebase_token)):
    user_id = user_token.get("uid")
    # TODO: Получить натальные данные пользователя из Firestore по user_id
    # TODO: Вызвать Gemini с натальными данными и вернуть персональный гороскоп
    
    return HoroscopeResponse(
        horoscope=f"Здесь будет персональный гороскоп для пользователя {user_id} на языке {req.lang}",
        date="Текущая дата"
    )
