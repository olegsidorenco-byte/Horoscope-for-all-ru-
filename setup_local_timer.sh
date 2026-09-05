#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "🔧 Настройка локального таймера systemd для ежедневного гороскопа..."

mkdir -p "$SYSTEMD_USER_DIR"
cp "$SCRIPT_DIR/systemd/horoscope.service" "$SYSTEMD_USER_DIR/horoscope.service"
cp "$SCRIPT_DIR/systemd/horoscope.timer" "$SYSTEMD_USER_DIR/horoscope.timer"

echo "🔄 Перезагрузка конфигурации systemd daemon..."
systemctl --user daemon-reload

echo "⏰ Активация и запуск таймера horoscope.timer..."
systemctl --user enable horoscope.timer
systemctl --user restart horoscope.timer

echo "✅ Таймер успешно настроен и активирован!"
echo "📋 Текущий статус таймера:"
systemctl --user list-timers horoscope.timer
