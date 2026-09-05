#!/usr/bin/env python3
"""
Автономный скрипт локального запуска ежедневного гороскопа.
Предназначен для работы через systemd timer (или cron) на ноутбуке.

Функционал:
1. Ожидание восстановления сети после выхода из спящего режима (до 3 минут).
2. Синхронизация с GitHub (git pull --rebase).
3. Проверка идемпотентности: не генерирует повторно, если сегодня уже рассчитано (поддерживает --force).
4. Запуск генерации и отправки в Telegram (main.py).
5. Автоматическая фиксация и публикация архива в GitHub (git add data/ -> commit -> push).
"""

import sys
import os
import json
import time
import subprocess
import urllib.request
from datetime import datetime
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
LATEST_HOROSCOPE_FILE = DATA_DIR / "latest_horoscope.json"
LATEST_ZODIAC_FILE = DATA_DIR / "latest_zodiac.json"


def log(message: str):
    """Форматированный вывод с временной меткой."""
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{now_str}] {message}", flush=True)


def check_internet(timeout_sec: int = 5) -> bool:
    """Проверяет доступность интернета по надежным хостам."""
    endpoints = [
        "https://www.google.com",
        "https://api.telegram.org",
        "https://1.1.1.1"
    ]
    for url in endpoints:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout_sec) as response:
                if response.status == 200:
                    return True
        except Exception:
            continue
    return False


def wait_for_internet(max_wait_seconds: int = 180, interval_seconds: int = 5) -> bool:
    """Ожидает подключения к интернету при выходе ноутбука из спящего режима."""
    log("🌐 Проверка доступности интернет-соединения...")
    start_time = time.time()
    attempts = 0

    while time.time() - start_time < max_wait_seconds:
        attempts += 1
        if check_internet(timeout_sec=4):
            log(f"✅ Интернет-соединение активно (попытка {attempts}).")
            return True
        log(f"⏳ Сеть пока недоступна (попытка {attempts}), повторная проверка через {interval_seconds} сек...")
        time.sleep(interval_seconds)

    log("❌ Не удалось обнаружить подключение к интернету за отведенное время.")
    return False


def run_cmd(cmd_list: list, cwd: Path = BASE_DIR) -> subprocess.CompletedProcess:
    """Выполняет команду оболочки и возвращает результат."""
    return subprocess.run(cmd_list, cwd=cwd, text=True, capture_output=True)


def sync_git_pull():
    """Синхронизирует репозиторий с удаленным origin/main перед генерацией."""
    log("🔄 Синхронизация с удаленным репозиторием (git pull --rebase)...")
    res = run_cmd(["git", "pull", "--rebase", "origin", "main"])
    if res.returncode == 0:
        log("✅ Репозиторий успешно обновлен.")
    else:
        log(f"⚠️ Предупреждение при git pull: {res.stderr.strip() or res.stdout.strip()}")


def is_already_generated_today() -> bool:
    """Проверяет, был ли уже сформирован прогноз на сегодняшнее число."""
    today_str = datetime.now().strftime("%d.%m.%Y")
    
    if not LATEST_HOROSCOPE_FILE.exists() or not LATEST_ZODIAC_FILE.exists():
        return False

    try:
        with open(LATEST_HOROSCOPE_FILE, "r", encoding="utf-8") as f:
            h_data = json.load(f)
        with open(LATEST_ZODIAC_FILE, "r", encoding="utf-8") as f:
            z_data = json.load(f)

        if h_data.get("date") == today_str and z_data.get("date") == today_str:
            return True
    except Exception as e:
        log(f"⚠️ Ошибка чтения файлов архива при проверке даты: {e}")

    return False


def sync_git_push(target_date: str):
    """Фиксирует изменения в папке data/ и отправляет их в GitHub."""
    log("📤 Проверка изменений архива для публикации на GitHub...")
    status_res = run_cmd(["git", "status", "--porcelain", "data/"])
    if not status_res.stdout.strip():
        log("ℹ️ В папке data/ нет новых изменений для отправки.")
        return

    log("📦 Добавление изменений папки data/ в индекс Git...")
    run_cmd(["git", "add", "data/"])
    
    commit_msg = f"🗄️ Ежедневный гороскоп на {target_date} [skip ci]"
    commit_res = run_cmd(["git", "commit", "-m", commit_msg])
    if commit_res.returncode != 0:
        log(f"⚠️ Не удалось создать коммит: {commit_res.stderr.strip()}")
        return

    log("🚀 Отправка изменений в GitHub (git push origin main)...")
    push_res = run_cmd(["git", "push", "origin", "main"])
    if push_res.returncode == 0:
        log("✅ Архив успешно отправлен на GitHub! Данные доступны в мобильном приложении.")
    else:
        log(f"⚠️ Ошибка при отправке в GitHub: {push_res.stderr.strip()}")


def main():
    force_run = "--force" in sys.argv
    today_str = datetime.now().strftime("%d.%m.%Y")
    log(f"🌟 Запуск координатора ежедневного гороскопа на {today_str}...")

    # 1. Проверка доступности сети
    if not wait_for_internet(max_wait_seconds=180, interval_seconds=5):
        log("⛔ Отмена выполнения: нет подключения к интернету.")
        sys.exit(1)

    # 2. Забираем возможные изменения из GitHub
    sync_git_pull()

    # 3. Проверка идемпотентности
    if not force_run and is_already_generated_today():
        log(f"✨ Гороскоп на сегодня ({today_str}) уже был успешно сгенерирован ранее. Завершение.")
        sys.exit(0)

    # 4. Запуск генерации и отправки в Telegram
    log("🚀 Запуск основного модуля main.py...")
    import main as bot_main
    try:
        bot_main.main()
        log("🎉 Основной модуль main.py успешно отработал!")
    except Exception as e:
        log(f"❌ Критическая ошибка при работе main.py: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    # 5. Публикация архива на GitHub для мобильного приложения
    sync_git_push(today_str)
    log("🏁 Все утренние задачи успешно завершены!")


if __name__ == "__main__":
    main()
