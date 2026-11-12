import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Локализация интерфейса для 5 языков: Русский (ru), English (en),
/// Español (es), Deutsch (de), Français (fr).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
  ];

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'en', 'name': 'English', 'nativeName': 'English', 'flag': '🇬🇧'},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français', 'flag': '🇫🇷'},
    {'code': 'ru', 'name': 'Русский', 'nativeName': 'Русский', 'flag': '🇷🇺'},
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

  // ====================== НАТАЛЬНЫЙ ПРОФИЛЬ ======================
  String get natalProfileTitle {
    switch (langCode) {
      case 'en': return 'Natal Profile';
      case 'es': return 'Perfil Natal';
      case 'de': return 'Natalprofil';
      case 'fr': return 'Profil Natal';
      default: return 'Натальный профиль';
    }
  }

  String get accountLinkedBadge {
    switch (langCode) {
      case 'en': return 'ACCOUNT LINKED';
      case 'es': return 'CUENTA VINCULADA';
      case 'de': return 'KONTO VERBUNDEN';
      case 'fr': return 'COMPTE ASSOCIÉ';
      default: return 'АККАУНТ ПРИВЯЗАН';
    }
  }

  String get elementLabel {
    switch (langCode) {
      case 'en': return 'Element';
      case 'es': return 'Elemento';
      case 'de': return 'Element';
      case 'fr': return 'Élément';
      default: return 'Стихия';
    }
  }

  String get nameLabel {
    switch (langCode) {
      case 'en': return 'Name / Nickname';
      case 'es': return 'Nombre / Apodo';
      case 'de': return 'Name / Pseudonym';
      case 'fr': return 'Nom / Prénom';
      default: return 'Имя / Псевдоним';
    }
  }

  String get nameHint {
    switch (langCode) {
      case 'en': return 'How to address you in your forecast';
      case 'es': return 'Cómo dirigirse a usted en el pronóstico';
      case 'de': return 'Wie Sie im Horoskop genannt werden';
      case 'fr': return 'Comment vous appeler dans vos prévisions';
      default: return 'Как к вам обращаться в прогнозе';
    }
  }

  String get nameValidator {
    switch (langCode) {
      case 'en': return 'Please enter your name';
      case 'es': return 'Por favor, introduzca su nombre';
      case 'de': return 'Bitte geben Sie Ihren Namen ein';
      case 'fr': return 'Veuillez entrer votre nom';
      default: return 'Пожалуйста, введите ваше имя';
    }
  }

  String get emailLabel {
    switch (langCode) {
      case 'en': return 'Email Address';
      case 'es': return 'Correo Electrónico (Email)';
      case 'de': return 'E-Mail-Adresse';
      case 'fr': return 'Adresse e-mail';
      default: return 'Адрес эл. почты (Email)';
    }
  }

  String get emailHint => 'user@example.com';

  String get emailValidator {
    switch (langCode) {
      case 'en': return 'Please enter your email';
      case 'es': return 'Por favor, introduzca su correo';
      case 'de': return 'Bitte E-Mail eingeben';
      case 'fr': return 'Veuillez indiquer votre e-mail';
      default: return 'Пожалуйста, укажите email для регистрации';
    }
  }

  String get emailFormatError {
    switch (langCode) {
      case 'en': return 'Please enter a valid email';
      case 'es': return 'Introduzca un correo válido';
      case 'de': return 'Gültige E-Mail-Adresse eingeben';
      case 'fr': return 'Entrez une adresse e-mail valide';
      default: return 'Введите корректный email';
    }
  }

  String get telegramLabel {
    switch (langCode) {
      case 'en': return 'Your Telegram (for bot delivery)';
      case 'es': return 'Su Telegram (entrega en bot)';
      case 'de': return 'Ihr Telegram (für Bot-Zustellung)';
      case 'fr': return 'Votre Telegram (livraison par bot)';
      default: return 'Ваш Telegram (для доставки в бот)';
    }
  }

  String get telegramHint {
    switch (langCode) {
      case 'en': return 'e.g. alex_horoscope';
      case 'es': return 'ej. alex_horoscopo';
      case 'de': return 'z.B. alex_horoskop';
      case 'fr': return 'ex. alex_horoscope';
      default: return 'например: oleg_sidorenco';
    }
  }

  String get telegramDesc {
    switch (langCode) {
      case 'en': return 'Provide your Telegram username for sync and personal delivery';
      case 'es': return 'Indique su usuario de Telegram para sincronización y entrega';
      case 'de': return 'Geben Sie Ihren Telegram-Benutzernamen für die Synchronisation an';
      case 'fr': return 'Indiquez votre identifiant Telegram pour la synchronisation et la livraison';
      default: return 'Укажите ваш логин Telegram для синхронизации и персональной доставки';
    }
  }

  String get birthDateLabel {
    switch (langCode) {
      case 'en': return 'Date of Birth';
      case 'es': return 'Fecha de Nacimiento';
      case 'de': return 'Geburtsdatum';
      case 'fr': return 'Date de Naissance';
      default: return 'Дата рождения';
    }
  }

  String get pickBirthDateTitle {
    switch (langCode) {
      case 'en': return 'Select Date of Birth';
      case 'es': return 'Seleccione Fecha de Nacimiento';
      case 'de': return 'Geburtsdatum auswählen';
      case 'fr': return 'Sélectionnez la date de naissance';
      default: return 'Выберите дату рождения';
    }
  }

  String get birthTimeLabel {
    switch (langCode) {
      case 'en': return 'Time of Birth';
      case 'es': return 'Hora de Nacimiento';
      case 'de': return 'Geburtszeit';
      case 'fr': return 'Heure de Naissance';
      default: return 'Время рождения';
    }
  }

  String get pickBirthTimeTitle {
    switch (langCode) {
      case 'en': return 'Select Time of Birth';
      case 'es': return 'Seleccione Hora de Nacimiento';
      case 'de': return 'Geburtszeit auswählen';
      case 'fr': return 'Sélectionnez l\'heure de naissance';
      default: return 'Выберите время рождения';
    }
  }

  String get unknownTimeCheckbox {
    switch (langCode) {
      case 'en': return 'Exact time unknown (noon 12:00 solar chart)';
      case 'es': return 'No sé la hora exacta (cálculo solar a las 12:00)';
      case 'de': return 'Genaue Zeit unbekannt (Sonnenhoroskop 12:00)';
      case 'fr': return 'Heure exacte inconnue (cosmogramme à midi 12:00)';
      default: return 'Не знаю точное время (расчет на полдень 12:00)';
    }
  }

  String get birthPlaceLabel {
    switch (langCode) {
      case 'en': return 'Place of Birth (City)';
      case 'es': return 'Lugar de Nacimiento (Ciudad)';
      case 'de': return 'Geburtsort (Stadt)';
      case 'fr': return 'Lieu de Naissance (Ville)';
      default: return 'Место рождения (Город)';
    }
  }

  String get birthPlaceDesc {
    switch (langCode) {
      case 'en': return 'Required to calculate Ascendant coordinates and natal houses';
      case 'es': return 'Requerido para calcular las coordenadas del Ascendente y las casas';
      case 'de': return 'Erforderlich für die Koordinaten des Aszendenten und der Häuser';
      case 'fr': return 'Nécessaire pour calculer l\'Ascendant et les maisons natales';
      default: return 'Необходимо для вычисления координат Асцендента и натальных домов';
    }
  }

  String get birthPlaceHint {
    switch (langCode) {
      case 'en': return 'e.g. London, United Kingdom';
      case 'es': return 'ej. Madrid, España';
      case 'de': return 'z.B. Berlin, Deutschland';
      case 'fr': return 'ex. Paris, France';
      default: return 'Например: Лондон, Великобритания';
    }
  }

  String get birthPlaceValidator {
    switch (langCode) {
      case 'en': return 'Please specify birth city';
      case 'es': return 'Por favor indique la ciudad de nacimiento';
      case 'de': return 'Bitte Geburtsort angeben';
      case 'fr': return 'Veuillez indiquer la ville de naissance';
      default: return 'Пожалуйста, укажите город рождения';
    }
  }

  String get currentCityLabel {
    switch (langCode) {
      case 'en': return 'Current Residence (City)';
      case 'es': return 'Lugar de Residencia Actual (Ciudad)';
      case 'de': return 'Aktueller Aufenthaltsort (Stadt)';
      case 'fr': return 'Lieu de Résidence Actuel (Ville)';
      default: return 'Место текущего пребывания (Город проживания)';
    }
  }

  String get currentCityDesc {
    switch (langCode) {
      case 'en': return 'Used to calculate local transits in your current timezone';
      case 'es': return 'Utilizado para calcular tránsitos locales en su zona horaria';
      case 'de': return 'Für lokale Planetentransite in Ihrer Zeitzone';
      case 'fr': return 'Requis pour calculer les transits locaux dans votre fuseau horaire';
      default: return 'Необходимо для расчета локальных транзитов планет по вашему текущему часовому поясу';
    }
  }

  String get currentCityHint {
    switch (langCode) {
      case 'en': return 'e.g. New York, USA';
      case 'es': return 'ej. Barcelona, España';
      case 'de': return 'z.B. München, Deutschland';
      case 'fr': return 'ex. Chisinau, Moldavie';
      default: return 'Например: Берлин, Германия';
    }
  }

  String get currentCityValidator {
    switch (langCode) {
      case 'en': return 'Please specify your current city';
      case 'es': return 'Por favor indique dónde se encuentra actualmente';
      case 'de': return 'Bitte aktuellen Wohnort angeben';
      case 'fr': return 'Veuillez indiquer votre ville actuelle';
      default: return 'Пожалуйста, укажите где вы находитесь сейчас';
    }
  }

  String get genderLabel {
    switch (langCode) {
      case 'en': return 'Gender (for correct astrological grammar)';
      case 'es': return 'Género (para la gramática correcta)';
      case 'de': return 'Geschlecht (für passende Grammatik)';
      case 'fr': return 'Genre (pour la grammaire appropriée)';
      default: return 'Пол (для правильной грамматики прогноза)';
    }
  }

  String get genderFemale {
    switch (langCode) {
      case 'en': return '👩 Female';
      case 'es': return '👩 Femenino';
      case 'de': return '👩 Weiblich';
      case 'fr': return '👩 Féminin';
      default: return '👩 Женский';
    }
  }

  String get genderMale {
    switch (langCode) {
      case 'en': return '👨 Male';
      case 'es': return '👨 Masculino';
      case 'de': return '👨 Männlich';
      case 'fr': return '👨 Masculin';
      default: return '👨 Мужской';
    }
  }

  String get focusLabel {
    switch (langCode) {
      case 'en': return 'Priority Focus Areas (calculation focus)';
      case 'es': return 'Áreas Prioritarias (enfoque de cálculo)';
      case 'de': return 'Schwerpunktbereiche (Berechnungsfokus)';
      case 'fr': return 'Domaines Prioritaires (focus du calcul)';
      default: return 'Приоритетные сферы внимания (фокус расчета)';
    }
  }

  String get focusDesc {
    switch (langCode) {
      case 'en': return 'Personal emphasis on business strategy, negotiations and peak hours';
      case 'es': return 'Énfasis personal en estrategia, negocios y horas propicias';
      case 'de': return 'Persönlicher Fokus auf Geschäftsstrategie und beste Zeiten';
      case 'fr': return 'Accent personnel sur les affaires, les négociations et les heures clés';
      default: return 'Персональный акцент в деловой стратегии, переговорах и часах активности';
    }
  }

  String get focusHint {
    switch (langCode) {
      case 'en': return 'e.g. business, negotiations, finance and health';
      case 'es': return 'ej. negocios, negociaciones, finanzas y salud';
      case 'de': return 'z.B. Geschäft, Verhandlungen, Finanzen und Gesundheit';
      case 'fr': return 'ex. affaires, négociations, finances et santé';
      default: return 'Например: бизнес, деловые переговоры, финансы и здоровье';
    }
  }

  String get focusBusiness {
    switch (langCode) {
      case 'en': return '💼 Business & Finance';
      case 'es': return '💼 Negocios y Finanzas';
      case 'de': return '💼 Geschäft & Finanzen';
      case 'fr': return '💼 Affaires & Finances';
      default: return '💼 Бизнес и финансы';
    }
  }

  String get focusNegotiations {
    switch (langCode) {
      case 'en': return '🤝 Negotiations & Deals';
      case 'es': return '🤝 Negociaciones y Acuerdos';
      case 'de': return '🤝 Verhandlungen & Deals';
      case 'fr': return '🤝 Négociations & Accords';
      default: return '🤝 Переговоры и сделки';
    }
  }

  String get focusCareer {
    switch (langCode) {
      case 'en': return '📈 Career & Status';
      case 'es': return '📈 Carrera y Estatus';
      case 'de': return '📈 Karriere & Status';
      case 'fr': return '📈 Carrière & Statut';
      default: return '📈 Карьера и статус';
    }
  }

  String get focusRelationships {
    switch (langCode) {
      case 'en': return '❤️ Relationships & Family';
      case 'es': return '❤️ Relaciones y Familia';
      case 'de': return '❤️ Beziehungen & Familie';
      case 'fr': return '❤️ Relations & Famille';
      default: return '❤️ Отношения и семья';
    }
  }

  String get focusHealth {
    switch (langCode) {
      case 'en': return '🌿 Health & Vitality';
      case 'es': return '🌿 Salud y Vitalidad';
      case 'de': return '🌿 Gesundheit & Vitalität';
      case 'fr': return '🌿 Santé & Vitalité';
      default: return '🌿 Здоровье и тонус';
    }
  }

  String get focusSpiritual {
    switch (langCode) {
      case 'en': return '🧘 Spiritual Growth';
      case 'es': return '🧘 Crecimiento Espiritual';
      case 'de': return '🧘 Geistiges Wachstum';
      case 'fr': return '🧘 Épanouissement Spirituel';
      default: return '🧘 Духовный рост';
    }
  }

  String get saveProfileButton {
    switch (langCode) {
      case 'en': return 'Save Natal Profile';
      case 'es': return 'Guardar Perfil Natal';
      case 'de': return 'Natalprofil speichern';
      case 'fr': return 'Enregistrer le Profil Natal';
      default: return 'Сохранить натальный профиль';
    }
  }

  String profileSavedSuccess(String name) {
    switch (langCode) {
      case 'en': return '✨ Natal profile for $name successfully saved!';
      case 'es': return '✨ ¡Perfil natal de $name guardado con éxito!';
      case 'de': return '✨ Natalprofil für $name erfolgreich gespeichert!';
      case 'fr': return '✨ Profil natal de $name enregistré avec succès !';
      default: return '✨ Натальный профиль $name успешно сохранен!';
    }
  }

  String get logoutConfirmTitle {
    switch (langCode) {
      case 'en': return 'Sign Out?';
      case 'es': return '¿Cerrar Sesión?';
      case 'de': return 'Abmelden?';
      case 'fr': return 'Se Déconnecter ?';
      default: return 'Выйти из аккаунта?';
    }
  }

  String get logoutConfirmMessage {
    switch (langCode) {
      case 'en': return 'Your profile data will remain safely stored. You can sign in again anytime.';
      case 'es': return 'Los datos de su perfil permanecerán guardados. Puede volver a iniciar sesión cuando desee.';
      case 'de': return 'Ihre Profildaten bleiben sicher gespeichert. Sie können sich jederzeit wieder anmelden.';
      case 'fr': return 'Les données de votre profil restent sauvegardées en toute sécurité. Vous pouvez vous reconnecter à tout moment.';
      default: return 'Данные вашей анкеты останутся надежно сохранены в учетной записи. Вы сможете войти в нее снова в любой момент.';
    }
  }

  String get logoutButton {
    switch (langCode) {
      case 'en': return 'Sign Out';
      case 'es': return 'Cerrar Sesión';
      case 'de': return 'Abmelden';
      case 'fr': return 'Déconnexion';
      default: return 'Выйти';
    }
  }

  String get selectButton {
    switch (langCode) {
      case 'en': return 'Select';
      case 'es': return 'Seleccionar';
      case 'de': return 'Auswählen';
      case 'fr': return 'Sélectionner';
      default: return 'Выбрать';
    }
  }

  // ====================== TELEGRAM БОТ ======================
  String get telegramBotTitle {
    switch (langCode) {
      case 'en': return 'Telegram Horoscope Delivery';
      case 'es': return 'Entrega de Horóscopo en Telegram';
      case 'de': return 'Horoskop-Zustellung per Telegram';
      case 'fr': return 'Livraison Horoscope sur Telegram';
      default: return 'Доставка гороскопа в Telegram';
    }
  }

  String get telegramBotDesc {
    switch (langCode) {
      case 'en': return 'Our official Telegram bot delivers your personal forecast strictly at your selected time in your timezone.';
      case 'es': return 'Nuestro bot oficial de Telegram entrega su pronóstico estrictamente a la hora elegida en su zona horaria.';
      case 'de': return 'Unser offizieller Telegram-Bot liefert Ihr persönliches Horoskop pünktlich in Ihrer Zeitzone.';
      case 'fr': return 'Notre bot Telegram officiel livre votre horoscope personnel précisément à l\'heure choisie selon votre fuseau horaire.';
      default: return 'Наш официальный Telegram-бот доставляет персональный прогноз строго в выбранное вами время по вашему часовому поясу.';
    }
  }

  String get telegramBotInstructionsTitle {
    switch (langCode) {
      case 'en': return 'Setup Instructions:';
      case 'es': return 'Instrucciones de configuración:';
      case 'de': return 'Einrichtungsanleitung:';
      case 'fr': return 'Instructions de configuration :';
      default: return 'Инструкция по подключению:';
    }
  }

  String get telegramBotInstructions {
    switch (langCode) {
      case 'en': return '1. Copy bot name: @Horoscope_SiDoReCo_bot\n2. Open Telegram and tap Start (/start)\n3. Enter your delivery time with: /delivery HH:MM City';
      case 'es': return '1. Copie el nombre: @Horoscope_SiDoReCo_bot\n2. Abra Telegram y pulse Iniciar (/start)\n3. Configure hora y zona: /delivery HH:MM Ciudad';
      case 'de': return '1. Bot-Name kopieren: @Horoscope_SiDoReCo_bot\n2. Telegram öffnen und Starten (/start) drücken\n3. Lieferzeit festlegen: /delivery HH:MM Stadt';
      case 'fr': return '1. Copiez le bot : @Horoscope_SiDoReCo_bot\n2. Ouvrez Telegram et appuyez sur Démarrer (/start)\n3. Indiquez l\'heure et la ville : /delivery HH:MM Ville';
      default: return '1. Скопируйте имя бота: @Horoscope_SiDoReCo_bot\n2. Откройте Telegram и нажмите «Запустить» (/start)\n3. Укажите время и часовой пояс командой /delivery ЧЧ:ММ Город';
    }
  }

  String get copyBotNameButton {
    switch (langCode) {
      case 'en': return 'Copy @Horoscope_SiDoReCo_bot';
      case 'es': return 'Copiar @Horoscope_SiDoReCo_bot';
      case 'de': return '@Horoscope_SiDoReCo_bot kopieren';
      case 'fr': return 'Copier @Horoscope_SiDoReCo_bot';
      default: return 'Скопировать @Horoscope_SiDoReCo_bot';
    }
  }

  String get botNameCopied {
    switch (langCode) {
      case 'en': return '📋 Bot name @Horoscope_SiDoReCo_bot copied!';
      case 'es': return '📋 ¡Nombre del bot copiado al portapapeles!';
      case 'de': return '📋 Bot-Name @Horoscope_SiDoReCo_bot kopiert!';
      case 'fr': return '📋 Nom du bot @Horoscope_SiDoReCo_bot copié !';
      default: return '📋 Имя бота @Horoscope_SiDoReCo_bot скопировано!';
    }
  }

  // ====================== АВТОРИЗАЦИЯ ======================
  String get authScreenTitle {
    switch (langCode) {
      case 'en': return 'Personal Account';
      case 'es': return 'Cuenta Personal';
      case 'de': return 'Persönliches Konto';
      case 'fr': return 'Compte Personnel';
      default: return 'Личный профиль';
    }
  }

  String get tabSignIn {
    switch (langCode) {
      case 'en': return 'Sign In';
      case 'es': return 'Iniciar Sesión';
      case 'de': return 'Anmelden';
      case 'fr': return 'Connexion';
      default: return 'Вход';
    }
  }

  String get tabSignUp {
    switch (langCode) {
      case 'en': return 'Register';
      case 'es': return 'Registrarse';
      case 'de': return 'Registrieren';
      case 'fr': return 'Inscription';
      default: return 'Регистрация';
    }
  }

  String get passwordLabel {
    switch (langCode) {
      case 'en': return 'Password (min 6 characters)';
      case 'es': return 'Contraseña (mínimo 6 caracteres)';
      case 'de': return 'Passwort (mind. 6 Zeichen)';
      case 'fr': return 'Mot de passe (min 6 caractères)';
      default: return 'Пароль (от 6 символов)';
    }
  }

  String get confirmPasswordLabel {
    switch (langCode) {
      case 'en': return 'Confirm Password';
      case 'es': return 'Confirmar Contraseña';
      case 'de': return 'Passwort bestätigen';
      case 'fr': return 'Confirmer le mot de passe';
      default: return 'Повторите пароль';
    }
  }

  String get forgotPasswordButton {
    switch (langCode) {
      case 'en': return 'Forgot password?';
      case 'es': return '¿Olvidó su contraseña?';
      case 'de': return 'Passwort vergessen?';
      case 'fr': return 'Mot de passe oublié ?';
      default: return 'Забыли пароль?';
    }
  }

  String get resetPasswordTitle {
    switch (langCode) {
      case 'en': return 'Password Reset';
      case 'es': return 'Restablecer Contraseña';
      case 'de': return 'Passwort zurücksetzen';
      case 'fr': return 'Réinitialiser le Mot de Passe';
      default: return 'Сброс пароля';
    }
  }

  String get resetPasswordDesc {
    switch (langCode) {
      case 'en': return 'Enter your account email to receive a password reset link:';
      case 'es': return 'Introduzca el correo para recibir el enlace de restablecimiento:';
      case 'de': return 'Geben Sie Ihre E-Mail-Adresse für den Reset-Link ein:';
      case 'fr': return 'Entrez l\'adresse e-mail pour recevoir le lien de réinitialisation :';
      default: return 'Введите email вашей учетной записи для получения ссылки сброса:';
    }
  }

  String get sendResetLink {
    switch (langCode) {
      case 'en': return 'Send Link';
      case 'es': return 'Enviar Enlace';
      case 'de': return 'Link senden';
      case 'fr': return 'Envoyer le lien';
      default: return 'Отправить ссылку';
    }
  }

  String get resetPasswordSent {
    switch (langCode) {
      case 'en': return 'A password reset link has been sent to your email!';
      case 'es': return '¡Se ha enviado un enlace de restablecimiento a su correo!';
      case 'de': return 'Ein Link zum Zurücksetzen wurde an Ihre E-Mail gesendet!';
      case 'fr': return 'Un lien de réinitialisation a été envoyé à votre adresse e-mail !';
      default: return 'Ссылка для сброса пароля отправлена на ваш email!';
    }
  }

  String get orOtherMethods {
    switch (langCode) {
      case 'en': return 'OR OTHER METHODS';
      case 'es': return 'O CON OTROS MÉTODOS';
      case 'de': return 'ODER ANDERE METHODEN';
      case 'fr': return 'OU AUTRES MÉTHODES';
      default: return 'ИЛИ ДРУГИЕ СПОСОБЫ';
    }
  }

  String get signInGoogle {
    switch (langCode) {
      case 'en': return 'Continue with Google';
      case 'es': return 'Continuar con Google';
      case 'de': return 'Mit Google fortfahren';
      case 'fr': return 'Continuer avec Google';
      default: return 'Войти через Google';
    }
  }

  String get signInTelegram {
    switch (langCode) {
      case 'en': return 'Continue with Telegram';
      case 'es': return 'Continuar con Telegram';
      case 'de': return 'Mit Telegram fortfahren';
      case 'fr': return 'Continuer avec Telegram';
      default: return 'Войти через Telegram';
    }
  }

  String get authSuccess {
    switch (langCode) {
      case 'en': return '✨ Welcome!';
      case 'es': return '✨ ¡Bienvenido!';
      case 'de': return '✨ Willkommen!';
      case 'fr': return '✨ Bienvenue !';
      default: return '✨ Успешный вход!';
    }
  }

  String get passwordTooShort {
    switch (langCode) {
      case 'en': return 'Password must be at least 6 characters';
      case 'es': return 'La contraseña debe tener al menos 6 caracteres';
      case 'de': return 'Passwort muss mindestens 6 Zeichen lang sein';
      case 'fr': return 'Le mot de passe doit comporter au moins 6 caractères';
      default: return 'Пароль должен быть не менее 6 символов';
    }
  }

  String get passwordsDoNotMatch {
    switch (langCode) {
      case 'en': return 'Passwords do not match';
      case 'es': return 'Las contraseñas no coinciden';
      case 'de': return 'Passwörter stimmen nicht überein';
      case 'fr': return 'Les mots de passe ne correspondent pas';
      default: return 'Пароли не совпадают';
    }
  }

  // ====================== ОБНОВЛЕНИЯ ПРИЛОЖЕНИЯ ======================
  String get updateAvailableTitle {
    switch (langCode) {
      case 'en': return 'Update Available 🚀';
      case 'es': return 'Actualización Disponible 🚀';
      case 'de': return 'Update Verfügbar 🚀';
      case 'fr': return 'Mise à Jour Disponible 🚀';
      default: return 'Доступно обновление 🚀';
    }
  }

  String updateAvailableDesc(String version) {
    switch (langCode) {
      case 'en': return 'A new version ($version) is available with important improvements and bug fixes.';
      case 'es': return 'Una nueva versión ($version) está disponible con mejoras importantes y correcciones.';
      case 'de': return 'Eine neue Version ($version) ist mit wichtigen Verbesserungen und Fehlerbehebungen verfügbar.';
      case 'fr': return 'Une nouvelle version ($version) est disponible avec des améliorations et corrections importantes.';
      default: return 'Доступна новая версия ($version) с важными улучшениями и исправлениями.';
    }
  }

  String get downloadUpdateButton {
    switch (langCode) {
      case 'en': return 'Download Update (APK)';
      case 'es': return 'Descargar Actualización (APK)';
      case 'de': return 'Update herunterladen (APK)';
      case 'fr': return 'Télécharger la Mise à Jour (APK)';
      default: return 'Скачать обновление (APK)';
    }
  }

  String get remindLaterButton {
    switch (langCode) {
      case 'en': return 'Remind Later';
      case 'es': return 'Recordar más tarde';
      case 'de': return 'Später erinnern';
      case 'fr': return 'Plus tard';
      default: return 'Напомнить позже';
    }
  }

  String get checkForUpdatesTitle {
    switch (langCode) {
      case 'en': return 'Check for Updates';
      case 'es': return 'Buscar Actualizaciones';
      case 'de': return 'Nach Updates suchen';
      case 'fr': return 'Vérifier les Mises à Jour';
      default: return 'Проверить обновления';
    }
  }

  String checkForUpdatesSubtitle(String version) {
    switch (langCode) {
      case 'en': return 'Current version: v$version';
      case 'es': return 'Versión actual: v$version';
      case 'de': return 'Aktuelle Version: v$version';
      case 'fr': return 'Version actuelle : v$version';
      default: return 'Текущая версия: v$version';
    }
  }

  String get checkingForUpdates {
    switch (langCode) {
      case 'en': return 'Checking for updates...';
      case 'es': return 'Buscando actualizaciones...';
      case 'de': return 'Suche nach Updates...';
      case 'fr': return 'Recherche de mises à jour...';
      default: return 'Проверка обновлений...';
    }
  }

  String get latestVersionInstalled {
    switch (langCode) {
      case 'en': return 'You already have the latest version installed 👍';
      case 'es': return 'Ya tienes instalada la versión más reciente 👍';
      case 'de': return 'Sie haben bereits die neueste Version installiert 👍';
      case 'fr': return 'Vous utilisez déjà la dernière version disponible 👍';
      default: return 'У вас уже установлена самая актуальная версия 👍';
    }
  }

  String get updateCheckFailed {
    switch (langCode) {
      case 'en': return 'Failed to check for updates. Please try again later.';
      case 'es': return 'No se pudo buscar actualizaciones. Inténtelo más tarde.';
      case 'de': return 'Update-Prüfung fehlgeschlagen. Bitte später erneut versuchen.';
      case 'fr': return 'Impossible de vérifier les mises à jour. Réessayez plus tard.';
      default: return 'Не удалось проверить обновления. Попробуйте позже.';
    }
  }

  // ====================== НАСТРОЙКИ (ДОПОЛНИТЕЛЬНО) ======================
  String get morningRemindersTitle {
    switch (langCode) {
      case 'en': return 'Morning Reminders';
      case 'es': return 'Recordatorios Matutinos';
      case 'de': return 'Morgendliche Erinnerungen';
      case 'fr': return 'Rappels Matinaux';
      default: return 'Утренние напоминания';
    }
  }

  String get morningRemindersDesc {
    switch (langCode) {
      case 'en': return 'Time is calculated strictly according to your timezone. If your local day differs from the server or you chose early time, your forecast is pre-generated specifically for your date.';
      case 'es': return 'La hora se calcula estrictamente según su zona horaria. Si difiere del servidor o elige hora temprana, el pronóstico se genera con antelación para su fecha.';
      case 'de': return 'Die Uhrzeit wird genau nach Ihrer Zeitzone berechnet. Bei Zeitverschiebung oder früher Uhrzeit wird Ihr Horoskop im Voraus berechnet.';
      case 'fr': return 'L\'heure est calculée selon votre fuseau horaire. En cas de décalage de date ou d\'heure matinale, vos prévisions sont pré-générées pour votre date locale.';
      default: return 'Время рассчитывается строго по вашему часовому поясу. Если вы находитесь в других сутках относительно сервера или выбрали раннее время, прогноз формируется заранее специально под вашу дату.';
    }
  }

  String detectedTimezoneLabel(String tz, String offset) {
    switch (langCode) {
      case 'en': return 'Timezone: $tz ($offset)';
      case 'es': return 'Zona horaria: $tz ($offset)';
      case 'de': return 'Zeitzone: $tz ($offset)';
      case 'fr': return 'Fuseau horaire : $tz ($offset)';
      default: return 'Часовой пояс: $tz ($offset)';
    }
  }

  String get reminderTimeLabel {
    switch (langCode) {
      case 'en': return 'Reminder Time';
      case 'es': return 'Hora del Recordatorio';
      case 'de': return 'Erinnerungszeit';
      case 'fr': return 'Heure du Rappel';
      default: return 'Время напоминания';
    }
  }

  String reminderTimeSetSnackbar(String time, String tz, String offset) {
    switch (langCode) {
      case 'en': return '⏰ Delivery time set to $time ($tz, $offset)';
      case 'es': return '⏰ Hora de entrega establecida a las $time ($tz, $offset)';
      case 'de': return '⏰ Zustellzeit auf $time ($tz, $offset) eingestellt';
      case 'fr': return '⏰ Heure de livraison réglée à $time ($tz, $offset)';
      default: return '⏰ Время доставки установлено на $time ($tz, $offset)';
    }
  }

  String get testNotifSent {
    switch (langCode) {
      case 'en': return '🔔 Test notification sent to status bar!';
      case 'es': return '🔔 ¡Notificación de prueba enviada!';
      case 'de': return '🔔 Test-Benachrichtigung gesendet!';
      case 'fr': return '🔔 Notification de test envoyée dans la barre d\'état !';
      default: return '🔔 Тестовое уведомление отправлено в шторку Android и на иконку приложения!';
    }
  }

  String get batteryAdviceTitle {
    switch (langCode) {
      case 'en': return 'Battery & Background optimization advice:';
      case 'es': return 'Recomendaciones de batería y segundo plano:';
      case 'de': return 'Tipps zu Akku und Hintergrundaktivität:';
      case 'fr': return 'Conseils d\'optimisation batterie et arrière-plan :';
      default: return 'Рекомендации по питанию и работе в фоновом режиме:';
    }
  }

  String get batteryAdviceDesc {
    switch (langCode) {
      case 'en': return '1. In Settings: Apps → Astro Horoscope → Battery → choose "Unrestricted".\n2. On Xiaomi/Huawei/Samsung enable "Autostart".\n3. Allow alarm and background notifications.';
      case 'es': return '1. En Ajustes: Aplicaciones → Astro Horóscopo → Batería → "Sin restricciones".\n2. En Xiaomi/Huawei habilite el inicio automático.\n3. Permita alarmas y notificaciones.';
      case 'de': return '1. Einstellungen: Apps → Astro Horoskop → Akku → "Keine Einschränkungen".\n2. Bei Xiaomi/Huawei "Autostart" aktivieren.\n3. Wecker und Benachrichtigungen erlauben.';
      case 'fr': return '1. Dans Paramètres : Applications → Astro Horoscope → Batterie → "Non restreinte".\n2. Sur Xiaomi/Huawei, activez le démarrage automatique.\n3. Autorisez les alarmes et notifications.';
      default: return '1. В настройках телефона: Приложения → Астро Гороскоп → Батарея → выберите «Без ограничений».\n2. На смартфонах Xiaomi/Huawei/Samsung включите «Автозапуск» в фоне.\n3. Включите разрешения на будильники и работу в фоновом режиме.';
    }
  }

  String get cloudDeliveryTitle {
    switch (langCode) {
      case 'en': return 'Cloud Horoscope Delivery';
      case 'es': return 'Entrega en la Nube';
      case 'de': return 'Cloud-Zustellung';
      case 'fr': return 'Livraison Cloud des Prévisions';
      default: return 'Облачная доставка прогнозов';
    }
  }

  String get cloudDeliveryDesc {
    switch (langCode) {
      case 'en': return 'Forecasts are calculated by an autonomous astrological system and published each morning.';
      case 'es': return 'Los pronósticos se calculan mediante un sistema astrológico autónomo cada mañana.';
      case 'de': return 'Horoskope werden von einem autonomen astrologischen System jeden Morgen berechnet.';
      case 'fr': return 'Les prévisions sont calculées par un système astrologique autonome et publiées chaque matin.';
      default: return 'Прогнозы рассчитываются автономной астрологической системой и публикуются каждое утро.';
    }
  }

  String offlineStorageCount(int days) {
    switch (langCode) {
      case 'en': return 'Saved in offline memory: $days days';
      case 'es': return 'Guardado en memoria sin conexión: $days días';
      case 'de': return 'Im Offline-Speicher gesichert: $days Tage';
      case 'fr': return 'Enregistré en mémoire hors ligne : $days jours';
      default: return 'Сохранено в офлайн-памяти: $days дн.';
    }
  }

  String get aboutProjectTitle {
    switch (langCode) {
      case 'en': return 'About Project';
      case 'es': return 'Acerca del Proyecto';
      case 'de': return 'Über das Projekt';
      case 'fr': return 'À Propos du Projet';
      default: return 'О проекте';
    }
  }

  String get aboutProjectDesc {
    switch (langCode) {
      case 'en': return '🌌 Autonomous Astrological System\nCalculation of planetary transits, aspects and houses based on fundamental classical astrology.';
      case 'es': return '🌌 Sistema Astrológico Autónomo\nCálculo de tránsitos, aspectos y casas basado en la astrología clásica fundamental.';
      case 'de': return '🌌 Autonomer Astrologie-Komplex\nBerechnung von Planetentransiten, Aspekten und Häusern auf Basis klassischer Astrologie.';
      case 'fr': return '🌌 Complexe Astrologique Autonome\nCalcul des transits planétaires, aspects et maisons basé sur l\'astrologie classique fondamentale.';
      default: return '🌌 Автономный астрологический комплекс\nРасчет планетарных транзитов, аспектов и домов на базе фундаментальной классической астрологии.';
    }
  }

  String get deleteAccountConfirmTitle {
    switch (langCode) {
      case 'en': return 'Delete Account and Data?';
      case 'es': return '¿Eliminar Cuenta y Datos?';
      case 'de': return 'Konto und Daten löschen?';
      case 'fr': return 'Supprimer le Compte et les Données ?';
      default: return 'Удалить аккаунт и данные?';
    }
  }

  String get deleteAccountConfirmDesc {
    switch (langCode) {
      case 'en': return 'All your personal profile data, birth details and preferences will be permanently deleted from servers and local memory.';
      case 'es': return 'Todos sus datos de perfil, fecha de nacimiento y preferencias se eliminarán de forma permanente.';
      case 'de': return 'Alle Ihre Profildaten, Geburtsdaten und Einstellungen werden dauerhaft von Servern und Speicher gelöscht.';
      case 'fr': return 'Toutes vos données de profil natal, date et préférences seront définitivement supprimées des serveurs et de la mémoire.';
      default: return 'Все данные вашего профиля, дата рождения и персональные настройки будут безвозвратно удалены с серверов и из памяти устройства.';
    }
  }

  // ====================== АРХИВ ======================
  String get archiveScreenTitle {
    switch (langCode) {
      case 'en': return 'Daily Horoscope Archive';
      case 'es': return 'Archivo de Horóscopos';
      case 'de': return 'Horoskop-Archiv nach Tagen';
      case 'fr': return 'Archives des Horoscopes par Jour';
      default: return 'Архив гороскопов по дням';
    }
  }

  String get refreshArchiveTooltip {
    switch (langCode) {
      case 'en': return 'Refresh Archive';
      case 'es': return 'Actualizar Archivo';
      case 'de': return 'Archiv aktualisieren';
      case 'fr': return 'Actualiser les archives';
      default: return 'Обновить архив';
    }
  }

  String get archiveEmpty {
    switch (langCode) {
      case 'en': return 'There are no saved days in the archive yet.';
      case 'es': return 'Aún no hay días guardados en el archivo.';
      case 'de': return 'Es sind noch keine Tage im Archiv gespeichert.';
      case 'fr': return 'Aucun jour n\'est encore enregistré dans les archives.';
      default: return 'В архиве пока нет сохраненных дней.';
    }
  }

  String forecastForDate(String date) {
    switch (langCode) {
      case 'en': return 'Horoscope for $date';
      case 'es': return 'Horóscopo del $date';
      case 'de': return 'Horoskop für $date';
      case 'fr': return 'Horoscope du $date';
      default: return 'Гороскоп на $date';
    }
  }

  String archiveForDate(String date) {
    switch (langCode) {
      case 'en': return 'Archive: $date';
      case 'es': return 'Archivo: $date';
      case 'de': return 'Archiv: $date';
      case 'fr': return 'Archives : $date';
      default: return 'Архив: $date';
    }
  }

  String get archiveError {
    switch (langCode) {
      case 'en': return 'Failed to load archive';
      case 'es': return 'No se pudo cargar el archivo';
      case 'de': return 'Archiv konnte nicht geladen werden';
      case 'fr': return 'Impossible de charger les archives';
      default: return 'Ошибка загрузки архивного дня';
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
