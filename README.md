# 🪐 Астро Гороскоп (Astro Horoscope)

[![Android APK Release](https://img.shields.io/badge/Android-APK%20v1.0.31-brightgreen?logo=android)](https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/latest)
[![iOS / Web PWA](https://img.shields.io/badge/iOS%20%2F%20Web-PWA%20Live-blue?logo=apple)](https://cosmic-horoscope-ru.web.app)
[![Cloud Run](https://img.shields.io/badge/Cloud%20Run-FastAPI%20Active-blue?logo=googlecloud)](https://cosmic-horoscope-api-688107707932.europe-west1.run.app)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-orange?logo=firebase)](https://console.firebase.google.com/project/cosmic-horoscope-ru)
[![GitHub Actions CI/CD](https://img.shields.io/badge/CI%2FCD-Automated%20Builds-purple?logo=githubactions)](https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/actions)

Кроссплатформенная экосистема ежедневного персонализированного астрологического прогнозирования на базе нейросетей **Google Gemini AI (3.7 / 2.5 Flash)** и точных математических алгоритмов сферической астрономии.

---

## 📱 Платформы и способы установки

Приложение доступно на всех популярных платформах без обязательной привязки к магазинам приложений:

### 1. 🍏 Apple iPhone (iOS) & iPad — Progressive Web App (PWA)
- **Веб-адрес:** [https://cosmic-horoscope-ru.web.app](https://cosmic-horoscope-ru.web.app) *(зеркало: [https://cosmic-horoscope-ru.firebaseapp.com](https://cosmic-horoscope-ru.firebaseapp.com))*
- **Как установить на экран iPhone без App Store:**
  1. Откройте ссылку в браузере **Safari**.
  2. Приложение автоматически распознает iOS и покажет интерактивную подсказку (**Smart Install Prompt**) с анимированной стрелочкой.
  3. Нажмите кнопку **«Поделиться»** ⎋ (квадрат со стрелкой вверх) в нижней панели Safari.
  4. Прокрутите меню и выберите **«На экран "Домой"»** ➕ (Add to Home Screen).
  5. Нажмите **«Добавить»** в правом верхнем углу.
- **Преимущества PWA на iOS:**
  - 📲 Запуск в режиме **Standalone (полный экран)** — без адресной строки Safari, вкладок и кнопок браузера.
  - 🔐 **Постоянная сессия:** вход выполняется один раз; токен авторизации надежно сохраняется в `IndexedDB`, повторный ввод пароля не требуется.
  - 🔄 **Мгновенные автообновления:** все улучшения подтягиваются автоматически при открытии приложения.
  - 🌙 Полная поддержка темной космической темы `#0B0E1B` и адаптация под вырезы экрана (Safe Area / Dynamic Island).

### 2. 🤖 Android — Автономное мобильное приложение (Flutter APK)
- **Скачать последнюю версию:** [Horoscope-for-all-ru.apk (v1.0.31)](https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/latest)
- **Особенности Android-версии:**
  - 🚀 **Встроенная система автообновления (In-App Auto-Update):** при запуске приложение сверяет свою версию с GitHub Releases и Cloud Run API. При выходе релиза пользователю показывается диалоговое окно со списком изменений и кнопкой обновления в 1 клик.
  - ⚙️ Возможность ручной проверки обновлений в разделе «Настройки».
  - 🔕 Фоновая предзагрузка утреннего прогноза за 30 минут до назначенного времени.
  - 🔐 Постоянная цифровая подпись (Keystore), позволяющая бесшовно накатывать обновления поверх старых версий без потери данных.

### 3. ✈️ Telegram — Канал и персональный бот
- Ежедневная утренняя потемная доставка для автора и подписчиков каналов.
- Встроенная защита от лимитов (Flood Control), индикация набора текста (`typing`) и защита форматирования.

---

## 🌟 Ключевые возможности системы

### 🪐 1. Высшая натальная точность
- **Сферическая тригонометрия:** при известном времени и месте рождения система рассчитывает точный градус **Асцендента (ASC)**, **Середины Неба (MC)** и натальных домов по алгоритмам Placidus / Коха.
- **Глобальная база координат:** встроенная геобаза городов мира для мгновенного определения географической широты и долготы места рождения.
- **Режим чистой космограммы:** если время рождения неизвестно, астрологический расчет формирует гармоничную космограмму по положению Солнца и планет без искажения домов.
- **6 детальных сфер жизни каждого дня:**
  1. 🌅 *Утреннее приветствие и общий космический фон дня*
  2. 🪐 *Влияние планет и транзиты на сегодня*
  3. 💼 *Работа, карьера и бизнес*
  4. ❤️ *Личные отношения и общение*
  5. 🌿 *Здоровье, самочувствие и тонус*
  6. 💡 *Мудрый астрологический совет дня*

### 🌍 2. Умные часовые пояса и предгенерация
- Время отправки и уведомлений рассчитывается строго по **часовому поясу пользователя** (база IANA: `Europe/Chisinau`, `Europe/Paris`, `Europe/Moscow`, `Asia/Tokyo` и др.), а не сервера.
- **Механизм предгенерации (Pre-generation):**
  - Если пользователь живет в восточном часовом поясе со смещением суток вперед относительно сервера или указал время получения раньше времени стандартной генерации (до 06:30 утра), система заблаговременно формирует персональный прогноз под целевую дату.
  - Защита от дубликатов и перезаписи архивных дней.

### 🌐 3. 100% мультиязычность (Full Localization)
Приложение и генерация прогнозов полностью локализованы для **5 языков**:
- 🇷🇺 **Русский (RU)**
- 🇫🇷 **Французский (FR)**
- 🇬🇧 **Английский (EN)**
- 🇪🇸 **Испанский (ES)**
- 🇩🇪 **Немецкий (DE)**

Мгновенное переключение языка в настройках приложения переводит **весь интерфейс** (натальную карту, карточки приоритетов, заголовки знаков зодиака, авторизацию и диалоговые окна) без необходимости перезагрузки. Прогнозы генерируются на выбранном языке пользователя с полной изоляцией (никаких утечек чужих имен или языков).

---

## 🏗️ Архитектура и технологии

```text
┌────────────────────────────────────────────────────────────────────────┐
│                          КЛИЕНТСКИЙ СЛОЙ                               │
├──────────────────────────┬─────────────────────────────┬───────────────┤
│  Android APK (Flutter)   │   Apple iOS & Web (PWA)     │  Telegram     │
│  • In-App Auto-Update    │   • Safari Smart Prompt     │  • Бот/Канал  │
│  • Фоновая служба        │   • Standalone Fullscreen   │  • Уведомления│
└────────────┬─────────────┴──────────────┬──────────────┴───────┬───────┘
             │                            │                      │
             ▼                            ▼                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        ОБЛАЧНЫЙ БЭКЕНД & ХОСТИНГ                       │
├────────────────────────────────────────────────────────────────────────┤
│ • Google Cloud Run: FastAPI Microservice (europe-west1)                │
│ • Firebase Authentication: Регистрация, Email/Пароль, Восстановление   │
│ • Cloud Firestore: Синхронизация анкет (users/{uid}), архивы и кэш     │
│ • Firebase Hosting: Глобальный CDN для Web PWA (cosmic-horoscope-ru)   │
│ • Google Gemini AI: Модели 3.7 / 2.5 Flash с Auto-Discovery            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Структура проекта

```text
├── mobile_app/                  # Кроссплатформенное приложение Flutter (Android + Web/PWA)
│   ├── lib/
│   │   ├── l10n/                # 100% локализация интерфейса (RU, FR, EN, ES, DE)
│   │   ├── models/              # Модели данных (UserProfile, Horoscope, Zodiac)
│   │   ├── services/            # Сервисы: UpdateService, Storage, Auth, Notifications
│   │   ├── ui/                  # Экраны (Home, Zodiac, Archive, Profile, Settings, Auth)
│   │   └── main.dart            # Инициализация Flutter, Firebase и темной темы
│   ├── web/                     # Конфигурация PWA для iOS Safari и браузеров
│   │   ├── index.html           # Загрузчик с iOS Smart Install Prompt (авто-подсказка)
│   │   ├── manifest.json        # PWA-манифест (иконки, fullscreen, темная тема)
│   │   └── icons/               # Набор иконок (192x192, 512x512, apple-touch-icon)
│   ├── android_custom/          # Нативные компоненты Kotlin (BootReceiver, MethodChannels)
│   └── pubspec.yaml             # Конфигурация зависимостей и версия приложения
├── api/                         # Backend API (FastAPI) для Google Cloud Run
│   ├── main.py                  # Эндпоинты API (/app/latest-version, /horoscope, /users)
│   └── requirements.txt         # Зависимости контейнера Cloud Run
├── .github/workflows/
│   ├── build_apk.yml            # Автоматическая компиляция и публикация Release APK
│   ├── deploy_web.yml           # Автоматическая сборка Flutter Web и PWA
│   └── daily_horoscope.yml      # Расписание фоновой рассылки
├── ai_service.py                # Ядро астрологических расчетов и Gemini AI
├── timezone_scheduler.py        # Умный расчет времени пользователя и предгенерация
├── user_service.py              # Синхронизация профилей пользователей с Firestore
├── telegram_service.py          # Доставка в Telegram (каналы и бот)
├── version.json                 # Реестр актуальных версий для автообновления
├── firebase.json                # Конфигурация Firebase Hosting и Firestore Rules
├── firestore.rules              # Правила безопасности базы данных Cloud Firestore
├── Dockerfile                   # Контейнер Python 3.11 для Google Cloud Run
└── test_security_and_logic.py   # Набор из 21 автоматического теста безопасности и логики
```

---

## 🚀 Руководство для разработчиков

### 1. Требования к окружению
- **Python**: `>= 3.11`
- **Flutter SDK**: `>= 3.22` (для локальной сборки мобильного и веб-приложения)
- **Google Cloud SDK (`gcloud`)**: настроенный проект `cosmic-horoscope-ru`

### 2. Локальный запуск бэкенда и тестов
```bash
# Активация виртуального окружения
source .venv/bin/activate

# Установка зависимостей
pip install -r requirements.txt -r api/requirements.txt

# Запуск полного набора из 21 теста безопасности и логики
python -m unittest test_security_and_logic.py

# Локальный запуск FastAPI сервера
uvicorn api.main:app --reload --port 8080
```

### 3. Локальный запуск мобильного / веб-приложения
```bash
cd mobile_app

# Получение зависимостей
flutter pub get

# Запуск веб-версии в браузере Chrome
flutter run -d chrome

# Сборка Release PWA бандла
flutter build web --release
```

### 4. Развертывание в облако

#### Деплой API на Google Cloud Run:
```bash
gcloud run deploy cosmic-horoscope-api \
  --source . \
  --region europe-west1 \
  --project cosmic-horoscope-ru \
  --allow-unauthenticated
```

#### Деплой Web PWA на Firebase Hosting:
```bash
firebase deploy --only hosting --project cosmic-horoscope-ru
```

---

## 🔒 Безопасность и соответствие стандартам
- Все приватные ключи и токены исключены из исходного кода и хранятся в защищенном хранилище секретов.
- База данных **Cloud Firestore** защищена правилами [firestore.rules](file:///home/os/Документы/Horoscope-for-all-ru/firestore.rules) (пользователь имеет доступ только к своим данным `request.auth.uid == userId`).
- Полное соблюдение политики конфиденциальности [PRIVACY_POLICY.md](file:///home/os/Документы/Horoscope-for-all-ru/PRIVACY_POLICY.md), включая функции удаления учетной записи и безопасного сброса пароля.
