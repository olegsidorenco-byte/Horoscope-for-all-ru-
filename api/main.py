import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from firebase_admin import credentials, auth, firestore
from fastapi import FastAPI, Depends, HTTPException, Header
from pydantic import BaseModel
from dotenv import load_dotenv
from ai_service import generate_horoscope_text

load_dotenv()

# Инициализация Firebase Admin SDK
firebase_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
if firebase_cred_path and os.path.exists(firebase_cred_path):
    cred = credentials.Certificate(firebase_cred_path)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
else:
    print("Внимание: путь к firebase credentials не найден. Используются дефолтные credentials.")
    try:
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
    except Exception as e:
        print(f"Ошибка инициализации Firebase: {e}")

db = firestore.client()
gemini_api_key = os.getenv("GEMINI_API_KEY")

app = FastAPI(title="Cosmic Horoscope API", version="1.0.0")

class HoroscopeRequest(BaseModel):
    lang: str = "ru"

class HoroscopeResponse(BaseModel):
    horoscope: str
    date: str

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
    
    # Получаем профиль пользователя из Firestore
    user_doc = db.collection('users').document(user_id).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User profile not found")
        
    user_profile = user_doc.to_dict()
    
    try:
        horoscope_text = generate_horoscope_text(
            api_key=gemini_api_key, 
            user_profile=user_profile, 
            lang=req.lang
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Generation Error: {str(e)}")
        
    return HoroscopeResponse(
        horoscope=horoscope_text,
        date=datetime.now().strftime("%d.%m.%Y")
    )

