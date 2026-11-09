import 'package:intl/intl.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String authType; // "email", "phone", "telegram", "guest"
  final String telegramUsername;
  final String passwordHash;
  final DateTime birthDate;
  final String birthTime; // Формат "12:00"
  final bool isTimeExact;
  final String birthPlace;
  final String currentCity;
  final String gender; // "male", "female", "other"
  final String focus; // Приоритетные сферы внимания
  final String timezone; // IANA часовой пояс пользователя (напр. "Asia/Vladivostok")
  final int? utcOffsetMinutes; // Смещение пользователя от UTC в минутах
  final String deliveryTime; // Желаемое локальное время доставки "HH:MM"
  final bool notificationsEnabled;
  final String lang; // Язык прогноза ("ru", "en", "es", "de", "fr")
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.name,
    this.email = "",
    this.phone = "",
    this.authType = "guest",
    this.telegramUsername = "",
    this.passwordHash = "",
    required this.birthDate,
    required this.birthTime,
    this.isTimeExact = true,
    required this.birthPlace,
    required this.currentCity,
    this.gender = "female",
    this.focus = "бизнес, деловые переговоры, финансы и здоровье",
    this.timezone = "",
    this.utcOffsetMinutes,
    this.deliveryTime = "06:45",
    this.notificationsEnabled = true,
    this.lang = "ru",
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Создает дефолтный профиль: 1 января 2000 года, 12:00
  factory UserProfile.defaultProfile() {
    return UserProfile(
      id: "guest_user",
      name: "",
      email: "",
      phone: "",
      authType: "guest",
      telegramUsername: "",
      passwordHash: "",
      birthDate: DateTime(2000, 1, 1),
      birthTime: "12:00",
      isTimeExact: false,
      birthPlace: "",
      currentCity: "",
      gender: "female",
      focus: "бизнес, деловые переговоры, финансы и здоровье",
      timezone: "",
      utcOffsetMinutes: null,
      deliveryTime: "06:45",
      notificationsEnabled: true,
      lang: "ru",
    );
  }

  bool get isRegistered =>
      (email.trim().isNotEmpty || phone.trim().isNotEmpty || telegramUsername.trim().isNotEmpty) &&
      name.trim().isNotEmpty;

  /// Основной контакт пользователя для отображения
  String get primaryContact {
    if (phone.trim().isNotEmpty) return phone.trim();
    if (email.trim().isNotEmpty) return email.trim();
    if (telegramUsername.trim().isNotEmpty) {
      return telegramUsername.startsWith("@") ? telegramUsername : "@$telegramUsername";
    }
    return "Не привязан";
  }

  String get formattedBirthDate => DateFormat('dd.MM.yyyy').format(birthDate);

  String get genderDisplay {
    if (gender == "male") return "Мужской";
    if (gender == "female") return "Женский";
    return "Не указан";
  }

  /// Вычисление знака зодиака по дате рождения
  String get zodiacSign {
    final m = birthDate.month;
    final d = birthDate.day;

    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return "Овен";
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return "Телец";
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return "Близнецы";
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return "Рак";
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return "Лев";
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return "Дева";
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return "Весы";
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return "Скорпион";
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return "Стрелец";
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return "Козерог";
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return "Водолей";
    return "Рыбы";
  }

  String get zodiacSymbol {
    switch (zodiacSign) {
      case "Овен": return "♈";
      case "Телец": return "♉";
      case "Близнецы": return "♊";
      case "Рак": return "♋";
      case "Лев": return "♌";
      case "Дева": return "♍";
      case "Весы": return "♎";
      case "Скорпион": return "♏";
      case "Стрелец": return "♐";
      case "Козерог": return "♑";
      case "Водолей": return "♒";
      case "Рыбы": return "♓";
      default: return "✨";
    }
  }

  /// Системный идентификатор знака зодиака ('aries'..'pisces')
  String get zodiacSignId {
    switch (zodiacSign) {
      case "Овен": return "aries";
      case "Телец": return "taurus";
      case "Близнецы": return "gemini";
      case "Рак": return "cancer";
      case "Лев": return "leo";
      case "Дева": return "virgo";
      case "Весы": return "libra";
      case "Скорпион": return "scorpio";
      case "Стрелец": return "sagittarius";
      case "Козерог": return "capricorn";
      case "Водолей": return "aquarius";
      case "Рыбы": return "pisces";
      default: return "gemini";
    }
  }

  /// Сигнатура натальных параметров для инвалидации кеша при изменении даты/времени/места рождения
  String get natalConfigSignature =>
      "${name.trim()}|$formattedBirthDate|${birthTime.trim()}|$isTimeExact|${birthPlace.trim()}|${currentCity.trim()}|$gender|${focus.trim()}";

  String get element {
    switch (zodiacSign) {
      case "Овен":
      case "Лев":
      case "Стрелец":
        return "Огонь";
      case "Телец":
      case "Дева":
      case "Козерог":
        return "Земля";
      case "Близнецы":
      case "Весы":
      case "Водолей":
        return "Воздух";
      case "Рак":
      case "Скорпион":
      case "Рыбы":
        return "Вода";
      default:
        return "Космос";
    }
  }

  String localizedZodiacSign([String? langCode]) {
    final code = _resolveLang(langCode);
    switch (zodiacSignId) {
      case 'aries':
        switch (code) {
          case 'en': return 'Aries';
          case 'es': return 'Aries';
          case 'de': return 'Widder';
          case 'fr': return 'Bélier';
          default: return 'Овен';
        }
      case 'taurus':
        switch (code) {
          case 'en': return 'Taurus';
          case 'es': return 'Tauro';
          case 'de': return 'Stier';
          case 'fr': return 'Taureau';
          default: return 'Телец';
        }
      case 'gemini':
        switch (code) {
          case 'en': return 'Gemini';
          case 'es': return 'Géminis';
          case 'de': return 'Zwillinge';
          case 'fr': return 'Gémeaux';
          default: return 'Близнецы';
        }
      case 'cancer':
        switch (code) {
          case 'en': return 'Cancer';
          case 'es': return 'Cáncer';
          case 'de': return 'Krebs';
          case 'fr': return 'Cancer';
          default: return 'Рак';
        }
      case 'leo':
        switch (code) {
          case 'en': return 'Leo';
          case 'es': return 'Leo';
          case 'de': return 'Löwe';
          case 'fr': return 'Lion';
          default: return 'Лев';
        }
      case 'virgo':
        switch (code) {
          case 'en': return 'Virgo';
          case 'es': return 'Virgo';
          case 'de': return 'Jungfrau';
          case 'fr': return 'Vierge';
          default: return 'Дева';
        }
      case 'libra':
        switch (code) {
          case 'en': return 'Libra';
          case 'es': return 'Libra';
          case 'de': return 'Waage';
          case 'fr': return 'Balance';
          default: return 'Весы';
        }
      case 'scorpio':
        switch (code) {
          case 'en': return 'Scorpio';
          case 'es': return 'Escorpio';
          case 'de': return 'Skorpion';
          case 'fr': return 'Scorpion';
          default: return 'Скорпион';
        }
      case 'sagittarius':
        switch (code) {
          case 'en': return 'Sagittarius';
          case 'es': return 'Sagitario';
          case 'de': return 'Schütze';
          case 'fr': return 'Sagittaire';
          default: return 'Стрелец';
        }
      case 'capricorn':
        switch (code) {
          case 'en': return 'Capricorn';
          case 'es': return 'Capricornio';
          case 'de': return 'Steinbock';
          case 'fr': return 'Capricorne';
          default: return 'Козерог';
        }
      case 'aquarius':
        switch (code) {
          case 'en': return 'Aquarius';
          case 'es': return 'Acuario';
          case 'de': return 'Wassermann';
          case 'fr': return 'Verseau';
          default: return 'Водолей';
        }
      case 'pisces':
        switch (code) {
          case 'en': return 'Pisces';
          case 'es': return 'Piscis';
          case 'de': return 'Fische';
          case 'fr': return 'Poissons';
          default: return 'Рыбы';
        }
      default:
        return zodiacSign;
    }
  }

  String _resolveLang([String? explicitLang, String? sampleText]) {
    if (explicitLang != null && explicitLang.trim().isNotEmpty) {
      return explicitLang.trim().toLowerCase();
    }
    if (lang.trim().isNotEmpty && lang.trim().toLowerCase() != 'ru') {
      return lang.trim().toLowerCase();
    }
    if (sampleText != null && sampleText.trim().isNotEmpty) {
      final hasCyrillic = RegExp(r'[а-яА-ЯёЁ]{2,}').hasMatch(sampleText);
      if (!hasCyrillic) {
        final lower = sampleText.toLowerCase();
        if (lower.contains('bonjour') || lower.contains('planètes') || lower.contains('votre') || lower.contains('aujourd')) {
          return 'fr';
        }
        if (lower.contains('buenos días') || lower.contains('planetas') || lower.contains('usted')) {
          return 'es';
        }
        if (lower.contains('guten morgen') || lower.contains('planeten') || lower.contains('ihnen')) {
          return 'de';
        }
        return 'en';
      }
    }
    return lang.trim().isNotEmpty ? lang.trim().toLowerCase() : 'ru';
  }

  static String _guestWelcomeByLang(String code) {
    switch (code) {
      case 'fr':
        return '☕✨ Bienvenue dans Astro Horoscope !\n\n'
            'Que cette journée vous apporte harmonie, clarté d\'esprit et inspiration 🌿 '
            'Choisissez votre signe du zodiaque pour consulter les prévisions du jour ou complétez votre profil natal.';
      case 'en':
        return '☕✨ Welcome to Astro Horoscope!\n\n'
            'May this day bring you harmony, clarity of mind, and inspiration 🌿 '
            'Choose your zodiac sign to view today\'s forecast or complete your natal profile.';
      case 'es':
        return '☕✨ ¡Bienvenido a Astro Horóscopo!\n\n'
            'Que este día le brinde armonía, claridad mental e inspiración 🌿 '
            'Elija su signo del zodíaco para ver el pronóstico actual o complete su perfil natal.';
      case 'de':
        return '☕✨ Willkommen bei Astro Horoskop!\n\n'
            'Möge dieser Tag Ihnen Harmonie, Klarheit und Inspiration schenken 🌿 '
            'Wählen Sie Ihr Sternzeichen für das aktuelle Tageshoroskop oder füllen Sie Ihr Geburtsprofil aus.';
      default:
        return '☕✨ Добро пожаловать в Астро Гороскоп!\n\n'
            'Пусть этот день подарит вам гармонию, ясность мыслей и вдохновение 🌿 '
            'Выберите свой знак зодиака для просмотра актуального прогноза или заполните анкету натального профиля.';
    }
  }

  static String _fallbackDayContextByLang(String code, String signName) {
    switch (code) {
      case 'fr':
        return 'Que les énergies cosmiques de ce jour révèlent tout le potentiel de votre signe $signName et vous apportent clarté d\'esprit, inspiration et harmonie dans toutes vos entreprises.';
      case 'en':
        return 'May today\'s cosmic energies unlock the full potential of your zodiac sign $signName and bring clarity of mind, inspiration, and harmony to all your endeavors.';
      case 'es':
        return 'Que las energías cósmicas de hoy revelen todo el potencial de su signo zodiacal $signName y le brinden claridad mental, inspiración y armonía en todos sus proyectos.';
      case 'de':
        return 'Mögen die kosmischen Energien des heutigen Tages das volle Potenzial Ihres Sternzeichens $signName entfalten und Ihnen Klarheit, Inspiration und Harmonie schenken.';
      default:
        return 'Пусть космические энергии сегодняшнего дня раскроют потенциал вашего знака зодиака $signName и подарят ясность мыслей, вдохновение и гармонию во всех начинаниях.';
    }
  }

  /// Форматирует приветствие с учетом статуса регистрации, выбранного языка и имени пользователя.
  /// Для неавторизованных возвращается нейтральное гостевое приветствие на выбранном языке.
  /// Для автора (Олег, 23.05.1978) возвращается его персональный расчет.
  /// Для всех остальных зарегистрированных формируется персональное обращение
  /// с их собственным знаком зодиака, датой рождения и общепланетарным контекстом дня.
  String formatGreeting(String rawGreeting, {String? langCode}) {
    final activeLang = _resolveLang(langCode, rawGreeting);

    if (!isRegistered) {
      return _guestWelcomeByLang(activeLang);
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return _guestWelcomeByLang(activeLang);
    }

    // Только для реального автора сохраняем оригинальный натальный расчет 1978 года
    final isAuthorOleg = (trimmedName.toLowerCase() == 'олег' || trimmedName.toLowerCase() == 'oleg') &&
        birthDate.year == 1978 &&
        birthDate.month == 5 &&
        birthDate.day == 23;

    if (isAuthorOleg) {
      return rawGreeting;
    }

    // 1. Извлекаем вступительные эмодзи из начала сырого приветствия (напр. ☀️🌿🕊️, ☕🌤️🍀, 🌅✨🍃)
    final emojiMatch = RegExp(r'^([\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\s]+)', unicode: true).firstMatch(rawGreeting);
    final emojis = (emojiMatch != null && emojiMatch.group(1)!.trim().isNotEmpty)
        ? emojiMatch.group(1)!.trim()
        : '☀️🌿🕊️';

    // 2. Персональная фраза приветствия на выбранном языке
    String greetingPhrase;
    final lowerRaw = rawGreeting.toLowerCase();
    switch (activeLang) {
      case 'fr':
        if (lowerRaw.contains('bonsoir')) {
          greetingPhrase = 'Bonsoir, $trimmedName !';
        } else {
          greetingPhrase = 'Bonjour, $trimmedName !';
        }
        break;
      case 'en':
        if (lowerRaw.contains('good evening')) {
          greetingPhrase = 'Good evening, $trimmedName!';
        } else if (lowerRaw.contains('good afternoon')) {
          greetingPhrase = 'Good afternoon, $trimmedName!';
        } else {
          greetingPhrase = 'Good morning, $trimmedName!';
        }
        break;
      case 'es':
        if (lowerRaw.contains('buenas noches')) {
          greetingPhrase = '¡Buenas noches, $trimmedName!';
        } else if (lowerRaw.contains('buenas tardes')) {
          greetingPhrase = '¡Buenas tardes, $trimmedName!';
        } else {
          greetingPhrase = '¡Buenos días, $trimmedName!';
        }
        break;
      case 'de':
        if (lowerRaw.contains('guten abend')) {
          greetingPhrase = 'Guten Abend, $trimmedName!';
        } else if (lowerRaw.contains('guten tag')) {
          greetingPhrase = 'Guten Tag, $trimmedName!';
        } else {
          greetingPhrase = 'Guten Morgen, $trimmedName!';
        }
        break;
      default:
        if (lowerRaw.contains('доброе утро') || lowerRaw.contains('доброго утра')) {
          greetingPhrase = 'Доброе утро, $trimmedName!';
        } else if (lowerRaw.contains('добрый день')) {
          greetingPhrase = 'Добрый день, $trimmedName!';
        } else if (lowerRaw.contains('добрый вечер')) {
          greetingPhrase = 'Добрый вечер, $trimmedName!';
        } else if (lowerRaw.contains('здравствуйте')) {
          final honorific = gender == 'female' ? 'уважаемая ' : (gender == 'male' ? 'уважаемый ' : '');
          greetingPhrase = 'Здравствуйте, $honorific$trimmedName!';
        } else {
          greetingPhrase = 'Приветствую Вас, $trimmedName!';
        }
    }

    // 3. Натальный бейдж пользователя на выбранном языке
    final signName = localizedZodiacSign(activeLang);
    final cityStr = birthPlace.isNotEmpty ? birthPlace : currentCity;
    final detailsList = <String>[];
    if (formattedBirthDate.isNotEmpty) detailsList.add(formattedBirthDate);
    if (birthTime.isNotEmpty) detailsList.add(birthTime);
    if (cityStr.isNotEmpty) detailsList.add(cityStr);

    final natalBadge = detailsList.isNotEmpty
        ? '($zodiacSymbol $signName • ${detailsList.join(", ")})'
        : '($zodiacSymbol $signName)';

    // 4. Извлекаем общепланетарный контекст текущего дня (день недели, планета-управитель, лунные сутки)
    final sentences = rawGreeting
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final daySentences = <String>[];
    for (final s in sentences) {
      // Пропускаем формулы приветствия на всех 5 языках
      if (RegExp(
            r'^(☀️|🌿|🕊️|☕|🌤️|🍀|🌅|✨|🍃|🌸|💫|🌻|🌱|\s)*(Доброе утро|Добрый день|Добрый вечер|Здравствуйте|Приветствую|Good morning|Good afternoon|Good evening|Dear|Hello|Bonjour|Bonsoir|Cher|Chère|¡?Buenos días|¡?Buenas tardes|¡?Buenas noches|Estimad|Guten Morgen|Guten Tag|Guten Abend|Liebe)',
            caseSensitive: false,
          ).hasMatch(s) &&
          s.length < 75) {
        continue;
      }
      // Пропускаем предложения с натальными данными автора на всех 5 языках
      if (RegExp(
        r'(1978|кишинев|кишинёв|chisinau|chișinău|паспорт подтверждает|расчет на|расчете вашей натальной|при вашем рождении|при рождении|восходящ|асцендент|ascendant|ascendente|aszendent|середина неба|milieu du ciel|midheaven|medio cielo|medium coeli|\bмс\b|10 дом|10-й дом|5-й дом|7-й дом|8-й дом|6-й дом|олег|\boleg\b)',
        caseSensitive: false,
      ).hasMatch(s)) {
        continue;
      }
      daySentences.add(s);
    }

    String dayContext = daySentences.join(' ').trim();
    final hasUnwantedCyrillic = activeLang != 'ru' && RegExp(r'[а-яА-ЯёЁ]{2,}').hasMatch(dayContext);
    if (dayContext.isEmpty || dayContext.length < 15 || hasUnwantedCyrillic) {
      dayContext = _fallbackDayContextByLang(activeLang, signName);
    }

    var finalGreeting = '$emojis $greetingPhrase $natalBadge\n\n$dayContext';

    // 5. Железный предохранитель: зачищаем любые возможные остатки данных автора на всех языках
    finalGreeting = finalGreeting.replaceAll(RegExp(r'\b(Олег[а-яА-Я]*|Oleg)\b', caseSensitive: false), trimmedName);
    finalGreeting = finalGreeting.replaceAll(
      RegExp(r'кишинев[а-яА-Я]*|кишинёв[а-яА-Я]*|chisinau|chișinău', caseSensitive: false),
      cityStr.isNotEmpty ? cityStr : '',
    );
    finalGreeting = finalGreeting.replaceAll(RegExp(r'23\.05\.1978|00:05|00:50', caseSensitive: false), formattedBirthDate);
    finalGreeting = finalGreeting.replaceAll(RegExp(r'\(1°32\x27 Водолея\),?\s*', caseSensitive: false), '');
    finalGreeting = finalGreeting.replaceAll(RegExp(r'\(8°53\x27[^)]*\),?\s*', caseSensitive: false), '');
    finalGreeting = finalGreeting.replaceAll(RegExp(r'Ваш восходящий знак — [^,.]*,\s*', caseSensitive: false), '');

    return finalGreeting;
  }

  /// Форматирует текст тематических карточек дня, заменяя натальные ссылки автора на данные пользователя
  String formatTopicContent(String content, {String? langCode}) {
    final activeLang = _resolveLang(langCode, content);
    final trimmedName = name.trim();
    final isAuthorOleg = isRegistered &&
        (trimmedName.toLowerCase() == 'олег' || trimmedName.toLowerCase() == 'oleg') &&
        birthDate.year == 1978 &&
        birthDate.month == 5 &&
        birthDate.day == 23;

    if (isAuthorOleg) return content;

    final signName = localizedZodiacSign(activeLang);
    var res = content;

    // Заменяем натальные аспекты автора в тексте
    res = res.replaceAll(
      RegExp(r'\(Солнце в Близнецах с восходящим Водолеем\)', caseSensitive: false),
      '($signName)',
    );
    res = res.replaceAll(
      RegExp(r'Вашего натального Водолея', caseSensitive: false),
      'вашего знака зодиака $signName',
    );
    res = res.replaceAll(
      RegExp(r'сдержанности Водолея', caseSensitive: false),
      'сдержанности',
    );
    res = res.replaceAll(
      RegExp(r'восходящ[а-я]* Водоле[а-я]*', caseSensitive: false),
      'знака $signName',
    );

    final defaultReader = switch (activeLang) {
      'fr' => 'Cher lecteur',
      'en' => 'Dear Reader',
      'es' => 'Estimado lector',
      'de' => 'Liebe Leserin, lieber Leser',
      _ => 'Пользователь',
    };
    final targetName = trimmedName.isNotEmpty ? trimmedName : defaultReader;
    res = res.replaceAll(RegExp(r'\b(Олег[а-яА-Я]*|Oleg)\b', caseSensitive: false), targetName);

    return res;
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "phone": phone,
      "authType": authType,
      "telegramUsername": telegramUsername,
      "passwordHash": passwordHash,
      "birthDate": birthDate.toIso8601String(),
      "birthTime": birthTime,
      "isTimeExact": isTimeExact,
      "birthPlace": birthPlace,
      "currentCity": currentCity,
      "gender": gender,
      "focus": focus,
      "timezone": timezone,
      if (utcOffsetMinutes != null) "utcOffsetMinutes": utcOffsetMinutes,
      "deliveryTime": deliveryTime,
      "notificationsEnabled": notificationsEnabled,
      "lang": lang,
      "updatedAt": updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawOffset = json["utcOffsetMinutes"] ?? json["utc_offset_minutes"];
    int? parsedOffset;
    if (rawOffset is int) {
      parsedOffset = rawOffset;
    } else if (rawOffset is num) {
      parsedOffset = rawOffset.toInt();
    } else if (rawOffset is String) {
      parsedOffset = int.tryParse(rawOffset);
    }

    return UserProfile(
      id: json["id"] ?? "user_${DateTime.now().millisecondsSinceEpoch}",
      name: json["name"] ?? "",
      email: json["email"] ?? "",
      phone: json["phone"] ?? "",
      authType: json["authType"] ?? json["auth_type"] ?? "guest",
      telegramUsername: json["telegramUsername"] ?? json["telegram_username"] ?? "",
      passwordHash: json["passwordHash"] ?? "",
      birthDate: (json["birthDate"] ?? json["birth_date"]) != null
          ? DateTime.tryParse((json["birthDate"] ?? json["birth_date"]).toString()) ?? DateTime(2000, 1, 1)
          : DateTime(2000, 1, 1),
      birthTime: json["birthTime"] ?? json["birth_time"] ?? "12:00",
      isTimeExact: json["isTimeExact"] ?? json["is_time_exact"] ?? true,
      birthPlace: json["birthPlace"] ?? json["birth_place"] ?? "",
      currentCity: json["currentCity"] ?? json["current_city"] ?? "",
      gender: json["gender"] ?? "female",
      focus: json["focus"] ?? "бизнес, деловые переговоры, финансы и здоровье",
      timezone: json["timezone"] ?? "",
      utcOffsetMinutes: parsedOffset,
      deliveryTime: json["deliveryTime"] ?? json["delivery_time"] ?? "06:45",
      notificationsEnabled: json["notificationsEnabled"] ?? json["notifications_enabled"] ?? true,
      lang: json["lang"] ?? "ru",
      updatedAt: json["updatedAt"] != null
          ? DateTime.tryParse(json["updatedAt"])
          : null,
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? authType,
    String? telegramUsername,
    String? passwordHash,
    DateTime? birthDate,
    String? birthTime,
    bool? isTimeExact,
    String? birthPlace,
    String? currentCity,
    String? gender,
    String? focus,
    String? timezone,
    int? utcOffsetMinutes,
    String? deliveryTime,
    bool? notificationsEnabled,
    String? lang,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      authType: authType ?? this.authType,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      passwordHash: passwordHash ?? this.passwordHash,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      isTimeExact: isTimeExact ?? this.isTimeExact,
      birthPlace: birthPlace ?? this.birthPlace,
      currentCity: currentCity ?? this.currentCity,
      gender: gender ?? this.gender,
      focus: focus ?? this.focus,
      timezone: timezone ?? this.timezone,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lang: lang ?? this.lang,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
