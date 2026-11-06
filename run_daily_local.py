#!/usr/bin/env python3
"""
Автономный скрипт локального запуска и планирования ежедневного гороскопа.
Предназначен для работы через systemd timer (каждые 15 минут в режиме --scheduled) или ручного запуска.

Функционал:
1. Ожидание восстановления сети после выхода из спящего режима.
2. Синхронизация входящих команд Telegram (/start, /profile, /delivery, /set_time).
3. В режиме --scheduled:
   - Учет часового пояса каждого получателя (автора и подписчиков).
   - Опережающая генерация прогнозов заранее под целевую дату (при смещении в другие сутки или раннем времени доставки).
   - Доставка строго в выбранное пользователем локальное время.
4. Безопасная публикация ТОЛЬКО публичного обезличенного архива в GitHub (без приватных данных пользователей).
"""

import sys
import glob
import json
import time
import subprocess
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
ARCHIVE_DIR = DATA_DIR / "archive"
LATEST_HOROSCOPE_FILE = DATA_DIR / "latest_horoscope.json"
LATEST_ZODIAC_FILE = DATA_DIR / "latest_zodiac.json"

PUBLIC_GIT_PATHS = [
    "data/archive",
    "mobile_app/assets/data",
]


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


def _public_git_targets() -> list[str]:
    targets = list(PUBLIC_GIT_PATHS)
    for p in sorted(glob.glob(str(DATA_DIR / "latest_*.json"))):
        targets.append(str(Path(p).relative_to(BASE_DIR)))
    return targets


def sync_git_pull():
    """Синхронизирует репозиторий с удаленным origin/main перед генерацией публичного архива."""
    log("🔄 Синхронизация с удаленным репозиторием (git pull --rebase)...")
    has_changes = bool(run_cmd(["git", "status", "--porcelain"]).stdout.strip())
    if has_changes:
        run_cmd(["git", "stash", "push", "-m", "auto-stash-before-pull"])

    res = run_cmd(["git", "pull", "--rebase", "origin", "main"])
    if res.returncode == 0:
        log("✅ Репозиторий успешно обновлен.")
    else:
        log(f"⚠️ Предупреждение при git pull: {res.stderr.strip() or res.stdout.strip()}")

    if has_changes:
        run_cmd(["git", "stash", "pop"])


def is_already_generated_for_date(date_dmy: str) -> bool:
    """Проверяет, был ли уже сформирован публичный прогноз на заданное число DD.MM.YYYY."""
    if not LATEST_HOROSCOPE_FILE.exists() or not LATEST_ZODIAC_FILE.exists():
        return False

    try:
        with open(LATEST_HOROSCOPE_FILE, "r", encoding="utf-8") as f:
            h_data = json.load(f)
        with open(LATEST_ZODIAC_FILE, "r", encoding="utf-8") as f:
            z_data = json.load(f)

        if h_data.get("date") == date_dmy and z_data.get("date") == date_dmy:
            return True
    except Exception as e:
        log(f"⚠️ Ошибка чтения файлов архива при проверке даты: {e}")

    return False


def _needs_public_archive_sync() -> bool:
    """Проверяет, требуется ли генерация/обновление публичных архивных файлов на текущие или восточные сутки."""
    try:
        from timezone_scheduler import compute_zodiac_target_dates
        info = compute_zodiac_target_dates(now_utc=datetime.now(timezone.utc))
        for d_str in info["dates_to_ensure"]:
            iso_key = datetime.strptime(d_str, "%d.%m.%Y").strftime("%Y_%m_%d")
            if not (ARCHIVE_DIR / f"zodiac_{iso_key}.json").exists():
                return True
        if not is_already_generated_for_date(info["server_today"]):
            return True
    except Exception:
        return True
    return False


def sync_git_push(target_date: str):
    """Фиксирует изменения ТОЛЬКО публичного архива (без приватных профилей) и отправляет их в GitHub."""
    log("📤 Проверка изменений публичного архива для публикации на GitHub...")
    targets = _public_git_targets()
    status_res = run_cmd(["git", "status", "--porcelain", "--"] + targets)
    if not status_res.stdout.strip():
        log("ℹ️ В публичном архиве нет новых изменений для отправки.")
        return

    log("📦 Добавление публичного архива в индекс Git...")
    run_cmd(["git", "add", "--"] + targets)

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
    scheduled_mode = "--scheduled" in sys.argv
    today_str = datetime.now().strftime("%d.%m.%Y")

    if scheduled_mode:
        log("⏱️ Плановый тик координатора часовых поясов (--scheduled)...")
        if not wait_for_internet(max_wait_seconds=35, interval_seconds=5):
            log("ℹ️ Сеть временно недоступна, повтор на следующем тике таймера.")
            sys.exit(0)

        try:
            from update_profile import sync_from_telegram_updates
            sync_from_telegram_updates()
        except Exception as e:
            log(f"ℹ️ Проверка обновлений профиля: {e}")

        if _needs_public_archive_sync():
            sync_git_pull()

        import main as bot_main
        try:
            public_changed = bot_main.run_scheduled_tick()
            if public_changed:
                sync_git_push(today_str)
        except Exception as e:
            log(f"❌ Ошибка при выполнении планового тика: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)

        log("✅ Плановый тик успешно завершен.")
        return

    log(f"🌟 Запуск координатора ежедневного гороскопа на {today_str}...")

    if not wait_for_internet(max_wait_seconds=180, interval_seconds=5):
        log("⛔ Отмена выполнения: нет подключения к интернету.")
        sys.exit(1)

    sync_git_pull()

    try:
        from update_profile import sync_from_telegram_updates
        sync_from_telegram_updates()
    except Exception as e:
        log(f"ℹ️ Проверка обновлений профиля: {e}")

    if not force_run and is_already_generated_for_date(today_str):
        log(f"✨ Публичный гороскоп на {today_str} уже сформирован. Проверяем индивидуальные часовые пояса подписчиков...")
        import main as bot_main
        public_changed = bot_main.run_scheduled_tick()
        if public_changed:
            sync_git_push(today_str)
        sys.exit(0)

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

    sync_git_push(today_str)
    log("🏁 Все задачи успешно завершены!")


if __name__ == "__main__":
    main()
