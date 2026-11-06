FROM python:3.11-slim

# Рабочая директория
WORKDIR /app

# Системная база часовых поясов IANA для точного расчета локального времени и натальных карт
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*

# Установка зависимостей
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем исходный код API, астрологического ядра и планировщика часовых поясов
COPY api/ /app/api/
COPY ai_service.py archive_service.py timezone_scheduler.py telegram_service.py config_loader.py /app/

# Задаем переменные среды для Cloud Run (порт передается автоматически)
ENV PORT=8080

# Открываем порт
EXPOSE 8080

# Запускаем FastAPI через uvicorn
CMD ["sh", "-c", "uvicorn api.main:app --host 0.0.0.0 --port ${PORT}"]
