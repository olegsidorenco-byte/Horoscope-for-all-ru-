FROM python:3.11-slim

# Рабочая директория
WORKDIR /app

# Установка зависимостей
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем исходный код API и ИИ-модуля
COPY api/ /app/api/
COPY ai_service.py /app/

# Задаем переменные среды для Cloud Run (порт передается автоматически)
ENV PORT=8080

# Открываем порт
EXPOSE 8080

# Запускаем FastAPI через uvicorn
CMD ["sh", "-c", "uvicorn api.main:app --host 0.0.0.0 --port ${PORT}"]
