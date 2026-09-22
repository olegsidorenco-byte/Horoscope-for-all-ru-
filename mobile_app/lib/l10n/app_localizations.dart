import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Локализация интерфейса для 5 языков: Русский (ru), English (en),
/// Español (es), Deutsch (de), Français (fr).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ru'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('en'),
    Locale('es'),
    Locale('de'),
    Locale('fr'),
  ];

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'ru', 'name': 'Русский', 'nativeName': 'Русский', 'flag': '🇷🇺'},
    {'code': 'en', 'name': 'English', 'nativeName': 'English', 'flag': '🇬🇧'},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español', 'flag': '🇪🇸'},
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français', 'flag': '🇫🇷'},
  ];

  String get langCode => locale.languageCode;

  // ====================== НАВИГАЦИЯ ======================
  String get navMyDay {
    switch (langCode) {
      case 'en': return 'My Day';
      case 'es': return 'Mi Día';
      case 'de': return 'Mein Tag';
      case 'fr': return 'Mon Jour';
      default: return 'Мой день';
    }
  }

  String get navZodiac {
    switch (langCode) {
      case 'en': return 'Zodiac Signs';
      case 'es': return 'Signos';
      case 'de': return 'Sternzeichen';
      case 'fr': return 'Zodiaque';
      default: return 'Знаки зодиака';
    }
  }

  String get navArchive {
    switch (langCode) {
      case 'en': return 'Archive';
      case 'es': return 'Archivo';
      case 'de': return 'Archiv';
      case 'fr': return 'Archives';
      default: return 'Архив';
    }
  }

  // ====================== ОБЩИЕ ======================
  String get appTitle {
    switch (langCode) {
      case 'en': return 'Astro Horoscope';
      case 'es': return 'Astro Horóscopo';
      case 'de': return 'Astro Horoskop';
      case 'fr': return 'Astro Horoscope';
      default: return 'Астро Гороскоп';
    }
  }

  String get newBadge => 'NEW';

  String get markAsRead {
    switch (langCode) {
      case 'en': return 'Read';
      case 'es': return 'Leído';
      case 'de': return 'Gelesen';
      case 'fr': return 'Lu';
      default: return 'Прочитано';
    }
  }

  String get unreadForecast {
    switch (langCode) {
      case 'en': return 'UNREAD FORECAST';
      case 'es': return 'HORÓSCOPO NO LEÍDO';
      case 'de': return 'UNGELESENES HOROSKOP';
      case 'fr': return 'HOROSCOPE NON LU';
      default: return 'НЕПРОЧИТАННЫЙ ГОРОСКОП';
    }
  }

  String newForecastPublished(String date) {
    switch (langCode) {
      case 'en': return 'Fresh forecast for $date is published!';
      case 'es': return '¡El pronóstico para el $date está disponible!';
      case 'de': return 'Frisches Horoskop für den $date ist veröffentlicht!';
      case 'fr': return 'Nouvel horoscope pour le $date publié !';
      default: return 'Свежий прогноз на $date опубликован!';
    }
  }

  String get loading {
    switch (langCode) {
      case 'en': return 'Loading forecast...';
      case 'es': return 'Cargando pronóstico...';
      case 'de': return 'Horoskop wird geladen...';
      case 'fr': return 'Chargement du horoscope...';
      default: return 'Загрузка прогноза...';
    }
  }

  String get errorLoading {
    switch (langCode) {
      case 'en': return 'Failed to load horoscope. Please check your connection.';
      case 'es': return 'No se pudo cargar el horóscopo. Verifique su conexión.';
      case 'de': return 'Horoskop konnte nicht geladen werden. Bitte Verbindung prüfen.';
      case 'fr': return 'Échec du chargement du horoscope. Vérifiez votre connexion.';
      default: return 'Не удалось загрузить прогноз дня. Проверьте соединение.';
    }
  }

  String get retry {
    switch (langCode) {
      case 'en': return 'Retry';
      case 'es': return 'Reintentar';
      case 'de': return 'Wiederholen';
      case 'fr': return 'Réessayer';
      default: return 'Повторить';
    }
  }

  String get save {
    switch (langCode) {
      case 'en': return 'Save';
      case 'es': return 'Guardar';
      case 'de': return 'Speichern';
      case 'fr': return 'Enregistrer';
      default: return 'Сохранить';
    }
  }

  String get cancel {
    switch (langCode) {
      case 'en': return 'Cancel';
      case 'es': return 'Cancelar';
      case 'de': return 'Abbrechen';
      case 'fr': return 'Annuler';
      default: return 'Отмена';
    }
  }

  String get close {
    switch (langCode) {
      case 'en': return 'Close';
      case 'es': return 'Cerrar';
      case 'de': return 'Schließen';
      case 'fr': return 'Fermer';
      default: return 'Закрыть';
    }
  }

  // ====================== ГЛАВНЫЙ ЭКРАН (HOME) ======================
  String get personalForecastTitle {
    switch (langCode) {
      case 'en': return 'Personal Horoscope';
      case 'es': return 'Horóscopo Personal';
      case 'de': return 'Persönliches Horoskop';
      case 'fr': return 'Horoscope Personnel';
      default: return 'Персональный прогноз';
    }
  }

  String get generalForecastTitle {
    switch (langCode) {
      case 'en': return 'General Forecast';
      case 'es': return 'Pronóstico General';
      case 'de': return 'Allgemeines Horoskop';
      case 'fr': return 'Prévision Générale';
      default: return 'Общий космический прогноз';
    }
  }

  String get refreshTooltip {
    switch (langCode) {
      case 'en': return 'Refresh horoscope';
      case 'es': return 'Actualizar horóscopo';
      case 'de': return 'Horoskop aktualisieren';
      case 'fr': return 'Actualiser le horoscope';
      default: return 'Обновить прогноз';
    }
  }

  String get unreadNotification {
    switch (langCode) {
      case 'en': return 'New forecast for today is ready!';
      case 'es': return '¡El nuevo pronóstico de hoy está listo!';
      case 'de': return 'Neues Tageshoroskop ist bereit!';
      case 'fr': return 'Le nouveau horoscope du jour est prêt !';
      default: return 'Свежий расчет на сегодня готов!';
    }
  }

  String get forecastForToday {
    switch (langCode) {
      case 'en': return 'Forecast for today';
      case 'es': return 'Pronóstico para hoy';
      case 'de': return 'Horoskop für heute';
      case 'fr': return 'Horoscope du jour';
      default: return 'Прогноз на сегодня';
    }
  }

  String get astrologicalAspects {
    switch (langCode) {
      case 'en': return 'Astrological Aspects & Spheres of Life';
      case 'es': return 'Aspectos Astrológicos y Esferas de Vida';
      case 'de': return 'Astrologische Aspekte & Lebensbereiche';
      case 'fr': return 'Aspects Astrologiques & Domaines de Vie';
      default: return 'Астрологические аспекты и сферы жизни';
    }
  }

  String get shareForecast {
    switch (langCode) {
      case 'en': return 'Share Forecast';
      case 'es': return 'Compartir Pronóstico';
      case 'de': return 'Horoskop teilen';
      case 'fr': return 'Partager l\'horoscope';
      default: return 'Поделиться прогнозом';
    }
  }

  String get copiedToClipboard {
    switch (langCode) {
      case 'en': return '✨ Horoscope text copied to clipboard';
      case 'es': return '✨ Texto del horóscopo copiado al portapapeles';
      case 'de': return '✨ Horoskoptext in Zwischenablage kopiert';
      case 'fr': return '✨ Texte du horoscope copié dans le presse-papiers';
      default: return '✨ Текст прогноза скопирован в буфер обмена';
    }
  }

  // ====================== ТЕМЫ ПРОГНОЗА ======================
  String get topicPlanets {
    switch (langCode) {
      case 'en': return 'Planetary Influence Today';
      case 'es': return 'Influencia Planetaria de Hoy';
      case 'de': return 'Planetarer Einfluss Heute';
      case 'fr': return 'Influence Planétaire du Jour';
      default: return 'Влияние планет на сегодня';
    }
  }

  String get topicCareer {
    switch (langCode) {
      case 'en': return 'Work, Business & Finance';
      case 'es': return 'Trabajo, Negocios y Finanzas';
      case 'de': return 'Arbeit, Wirtschaft & Finanzen';
      case 'fr': return 'Travail, Affaires & Finances';
      default: return 'Работа, бизнес и финансы';
    }
  }

  String get topicLove {
    switch (langCode) {
      case 'en': return 'Personal Relationships & Communication';
      case 'es': return 'Relaciones Personales y Comunicación';
      case 'de': return 'Persönliche Beziehungen & Kommunikation';
      case 'fr': return 'Relations Personnelles & Communication';
      default: return 'Личные отношения и общение';
    }
  }

  String get topicHealth {
    switch (langCode) {
      case 'en': return 'Health & Vitality';
      case 'es': return 'Salud y Vitalidad';
      case 'de': return 'Gesundheit & Vitalität';
      case 'fr': return 'Santé & Vitalité';
      default: return 'Здоровье и тонус';
    }
  }

  String get topicAdvice {
    switch (langCode) {
      case 'en': return 'Daily Advice';
      case 'es': return 'Consejo del Día';
      case 'de': return 'Tagesratschlag';
      case 'fr': return 'Conseil du Jour';
      default: return 'Добрый совет на сегодня';
    }
  }

  String get topicWish {
    switch (langCode) {
      case 'en': return 'Daily Wish';
      case 'es': return 'Deseo del Día';
      case 'de': return 'Tageswunsch';
      case 'fr': return 'Vœu du Jour';
      default: return 'Пожелание на сегодня';
    }
  }

  // ====================== ЗНАКИ ЗОДИАКА ======================
  String get zodiacScreenTitle {
    switch (langCode) {
      case 'en': return 'Horoscope by Signs';
      case 'es': return 'Horóscopo por Signos';
      case 'de': return 'Horoskop nach Sternzeichen';
      case 'fr': return 'Horoscope par Signes';
      default: return 'Гороскоп по знакам';
    }
  }

  String get zodiacAllSigns {
    switch (langCode) {
      case 'en': return 'All 12 Zodiac Signs';
      case 'es': return 'Los 12 Signos del Zodíaco';
      case 'de': return 'Alle 12 Sternzeichen';
      case 'fr': return 'Les 12 Signes du Zodiaque';
      default: return 'Все 12 знаков зодиака';
    }
  }

  String get elementAll {
    switch (langCode) {
      case 'en': return 'All';
      case 'es': return 'Todos';
      case 'de': return 'Alle';
      case 'fr': return 'Tous';
      default: return 'Все';
    }
  }

  String get elementFire {
    switch (langCode) {
      case 'en': return 'Fire';
      case 'es': return 'Fuego';
      case 'de': return 'Feuer';
      case 'fr': return 'Feu';
      default: return 'Огонь';
    }
  }

  String get elementEarth {
    switch (langCode) {
      case 'en': return 'Earth';
      case 'es': return 'Tierra';
      case 'de': return 'Erde';
      case 'fr': return 'Terre';
      default: return 'Земля';
    }
  }

  String get elementAir {
    switch (langCode) {
      case 'en': return 'Air';
      case 'es': return 'Aire';
      case 'de': return 'Luft';
      case 'fr': return 'Air';
      default: return 'Воздух';
    }
  }

  String get elementWater {
    switch (langCode) {
      case 'en': return 'Water';
      case 'es': return 'Agua';
      case 'de': return 'Wasser';
      case 'fr': return 'Eau';
      default: return 'Вода';
    }
  }

  String get luckyHoursLabel {
    switch (langCode) {
      case 'en': return 'Lucky Hours';
      case 'es': return 'Horas Favorables';
      case 'de': return 'Glücksstunden';
      case 'fr': return 'Heures Favorables';
      default: return 'Благоприятные часы';
    }
  }

  String get energyLabel {
    switch (langCode) {
      case 'en': return 'Energy Level';
      case 'es': return 'Nivel de Energía';
      case 'de': return 'Energieniveau';
      case 'fr': return 'Niveau d\'Énergie';
      default: return 'Уровень энергии';
    }
  }

  String get adviceOfDayLabel {
    switch (langCode) {
      case 'en': return 'ADVICE OF THE DAY';
      case 'es': return 'CONSEJO DEL DÍA';
      case 'de': return 'RAT DES TAGES';
      case 'fr': return 'CONSEIL DU JOUR';
      default: return 'СОВЕТ ДНЯ';
    }
  }

  String zodiacSignName(String signId) {
    switch (signId.toLowerCase()) {
      case 'aries':
        switch (langCode) {
          case 'en': return 'Aries';
          case 'es': return 'Aries';
          case 'de': return 'Widder';
          case 'fr': return 'Bélier';
          default: return 'Овен';
        }
      case 'taurus':
        switch (langCode) {
          case 'en': return 'Taurus';
          case 'es': return 'Tauro';
          case 'de': return 'Stier';
          case 'fr': return 'Taureau';
          default: return 'Телец';
        }
      case 'gemini':
        switch (langCode) {
          case 'en': return 'Gemini';
          case 'es': return 'Géminis';
          case 'de': return 'Zwillinge';
          case 'fr': return 'Gémeaux';
          default: return 'Близнецы';
        }
      case 'cancer':
        switch (langCode) {
          case 'en': return 'Cancer';
          case 'es': return 'Cáncer';
          case 'de': return 'Krebs';
          case 'fr': return 'Cancer';
          default: return 'Рак';
        }
      case 'leo':
        switch (langCode) {
          case 'en': return 'Leo';
          case 'es': return 'Leo';
          case 'de': return 'Löwe';
          case 'fr': return 'Lion';
          default: return 'Лев';
        }
      case 'virgo':
        switch (langCode) {
          case 'en': return 'Virgo';
          case 'es': return 'Virgo';
          case 'de': return 'Jungfrau';
          case 'fr': return 'Vierge';
          default: return 'Дева';
        }
      case 'libra':
        switch (langCode) {
          case 'en': return 'Libra';
          case 'es': return 'Libra';
          case 'de': return 'Waage';
          case 'fr': return 'Balance';
          default: return 'Весы';
        }
      case 'scorpio':
        switch (langCode) {
          case 'en': return 'Scorpio';
          case 'es': return 'Escorpio';
          case 'de': return 'Skorpion';
          case 'fr': return 'Scorpion';
          default: return 'Скорпион';
        }
      case 'sagittarius':
        switch (langCode) {
          case 'en': return 'Sagittarius';
          case 'es': return 'Sagitario';
          case 'de': return 'Schütze';
          case 'fr': return 'Sagittaire';
          default: return 'Стрелец';
        }
      case 'capricorn':
        switch (langCode) {
          case 'en': return 'Capricorn';
          case 'es': return 'Capricornio';
          case 'de': return 'Steinbock';
          case 'fr': return 'Capricorne';
          default: return 'Козерог';
        }
      case 'aquarius':
        switch (langCode) {
          case 'en': return 'Aquarius';
          case 'es': return 'Acuario';
          case 'de': return 'Wassermann';
          case 'fr': return 'Verseau';
          default: return 'Водолей';
        }
      case 'pisces':
        switch (langCode) {
          case 'en': return 'Pisces';
          case 'es': return 'Piscis';
          case 'de': return 'Fische';
          case 'fr': return 'Poissons';
          default: return 'Рыбы';
        }
      default:
        return signId;
    }
  }

  // ====================== НАСТРОЙКИ (SETTINGS) ======================
  String get settingsTitle {
    switch (langCode) {
      case 'en': return 'Settings & System';
      case 'es': return 'Ajustes y Sistema';
      case 'de': return 'Einstellungen & System';
      case 'fr': return 'Paramètres & Système';
      default: return 'Настройки и система';
    }
  }

  String get languageSectionTitle {
    switch (langCode) {
      case 'en': return 'App & Horoscope Language';
      case 'es': return 'Idioma de la App y Horóscopo';
      case 'de': return 'Sprache der App & Horoskope';
      case 'fr': return 'Langue de l\'App & Horoscopes';
      default: return 'Язык приложения и гороскопов';
    }
  }

  String get selectLanguageTitle {
    switch (langCode) {
      case 'en': return 'Select Language';
      case 'es': return 'Seleccionar Idioma';
      case 'de': return 'Sprache wählen';
      case 'fr': return 'Choisir la langue';
      default: return 'Выберите язык';
    }
  }

  String get languageChangedSnackbar {
    switch (langCode) {
      case 'en': return 'Language changed to English 🇬🇧';
      case 'es': return 'Idioma cambiado a Español 🇪🇸';
      case 'de': return 'Sprache auf Deutsch geändert 🇩🇪';
      case 'fr': return 'Langue changée en Français 🇫🇷';
      default: return 'Язык успешно изменен на Русский 🇷🇺';
    }
  }

  String get profileSectionTitle {
    switch (langCode) {
      case 'en': return 'Personal Natal Profile';
      case 'es': return 'Perfil Natal Personal';
      case 'de': return 'Persönliches Geburtsprofil';
      case 'fr': return 'Profil Natal Personnel';
      default: return 'Персональный натальный профиль';
    }
  }

  String get editProfileButton {
    switch (langCode) {
      case 'en': return 'Edit Profile';
      case 'es': return 'Editar Perfil';
      case 'de': return 'Profil bearbeiten';
      case 'fr': return 'Modifier le Profil';
      default: return 'Настроить профиль';
    }
  }

  String get backgroundServiceTitle {
    switch (langCode) {
      case 'en': return 'Background Monitoring';
      case 'es': return 'Monitoreo en Segundo Plano';
      case 'de': return 'Hintergrund-Überwachung';
      case 'fr': return 'Surveillance en Arrière-plan';
      default: return 'Фоновый мониторинг';
    }
  }

  String get backgroundServiceSubtitle {
    switch (langCode) {
      case 'en': return 'Periodic checks for new daily horoscopes';
      case 'es': return 'Comprobaciones periódicas de nuevos horóscopos';
      case 'de': return 'Regelmäßige Prüfung auf neue Tageshoroskope';
      case 'fr': return 'Vérifications périodiques des nouveaux horoscopes';
      default: return 'Периодическая проверка публикации нового расчета';
    }
  }

  String get notificationsTitle {
    switch (langCode) {
      case 'en': return 'Morning Reminders';
      case 'es': return 'Recordatorios Matutinos';
      case 'de': return 'Morgendliche Erinnerungen';
      case 'fr': return 'Rappels Matinaux';
      default: return 'Утренние напоминания';
    }
  }

  String get notificationsDesc {
    switch (langCode) {
      case 'en': return 'Daily notification when your fresh astrological forecast is ready.';
      case 'es': return 'Notificación diaria cuando esté listo su nuevo pronóstico.';
      case 'de': return 'Tägliche Benachrichtigung, wenn Ihr neues Horoskop bereit ist.';
      case 'fr': return 'Notification quotidienne lorsque votre horoscope est prêt.';
      default: return 'Ежедневное напоминание о готовности свежего астрологического прогноза дня.';
    }
  }

  String get notifTimeLabel {
    switch (langCode) {
      case 'en': return 'Reminder Time';
      case 'es': return 'Hora de Notificación';
      case 'de': return 'Erinnerungszeit';
      case 'fr': return 'Heure de Rappel';
      default: return 'Время напоминания';
    }
  }

  String get testNotifButton {
    switch (langCode) {
      case 'en': return 'Test notification now';
      case 'es': return 'Probar notificación ahora';
      case 'de': return 'Benachrichtigung jetzt testen';
      case 'fr': return 'Tester la notification maintenant';
      default: return 'Проверить уведомление сейчас';
    }
  }

  String get batteryTitle {
    switch (langCode) {
      case 'en': return 'Battery & Background Guidelines:';
      case 'es': return 'Recomendaciones de Batería y Segundo Plano:';
      case 'de': return 'Batterie- und Hintergrund-Empfehlungen:';
      case 'fr': return 'Recommandations Batterie et Arrière-plan :';
      default: return 'Рекомендации по питанию и работе в фоновом режиме:';
    }
  }

  String get batteryDesc {
    switch (langCode) {
      case 'en': return '1. Settings → Apps → Astro Horoscope → Battery → Unrestricted.\n2. Enable Auto-start on Xiaomi/Huawei/Samsung devices.\n3. Allow alarm and notification permissions.';
      case 'es': return '1. Ajustes → Aplicaciones → Astro Horóscopo → Batería → Sin restricciones.\n2. Habilite Inicio automático en dispositivos Xiaomi/Huawei/Samsung.\n3. Permita permisos de alarmas y notificaciones.';
      case 'de': return '1. Einstellungen → Apps → Astro Horoskop → Akku → Keine Einschränkungen.\n2. Autostart auf Xiaomi/Huawei/Samsung aktivieren.\n3. Wecker- und Benachrichtigungsberechtigungen erteilen.';
      case 'fr': return '1. Paramètres → Applications → Astro Horoscope → Batterie → Sans restriction.\n2. Activez le Démarrage automatique sur Xiaomi/Huawei/Samsung.\n3. Autorisez les alarmes et notifications.';
      default: return '1. В настройках телефона: Приложения → Астро Гороскоп → Батарея → выберите «Без ограничений».\n2. На смартфонах Xiaomi/Huawei/Samsung включите «Автозапуск» в фоне.\n3. Включите разрешения на будильники и работу в фоновом режиме.';
    }
  }

  String get cacheTitle {
    switch (langCode) {
      case 'en': return 'Storage & Cache';
      case 'es': return 'Almacenamiento y Caché';
      case 'de': return 'Speicher & Cache';
      case 'fr': return 'Stockage & Cache';
      default: return 'Память и кэш';
    }
  }

  String get clearCacheButton {
    switch (langCode) {
      case 'en': return 'Clear Local Cache';
      case 'es': return 'Limpiar Caché Local';
      case 'de': return 'Lokalen Cache leeren';
      case 'fr': return 'Vider le Cache Local';
      default: return 'Очистить локальный кэш';
    }
  }

  String get cacheCleared {
    switch (langCode) {
      case 'en': return '✨ Local cache successfully cleared';
      case 'es': return '✨ Caché local limpiado con éxito';
      case 'de': return '✨ Lokaler Cache erfolgreich geleert';
      case 'fr': return '✨ Cache local vidé avec succès';
      default: return '✨ Локальный кэш успешно очищен';
    }
  }

  String get privacyPolicyButton {
    switch (langCode) {
      case 'en': return 'Privacy Policy & Terms';
      case 'es': return 'Política de Privacidad y Términos';
      case 'de': return 'Datenschutzerklärung & Bedingungen';
      case 'fr': return 'Politique de Confidentialité & Conditions';
      default: return 'Политика конфиденциальности и условия';
    }
  }

  String get deleteAccountButton {
    switch (langCode) {
      case 'en': return 'Delete Account and Personal Data';
      case 'es': return 'Eliminar Cuenta y Datos Personales';
      case 'de': return 'Konto und persönliche Daten löschen';
      case 'fr': return 'Supprimer le Compte et les Données';
      default: return 'Удалить аккаунт и персональные данные';
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ru', 'en', 'es', 'de', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
