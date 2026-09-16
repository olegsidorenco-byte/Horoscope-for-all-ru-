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

  /// Форматирует приветствие с учетом статуса регистрации и имени пользователя.
  /// Для неавторизованных возвращается нейтральное гостевое приветствие.
  /// Для автора (Олег, 23.05.1978) возвращается его персональный расчет.
  /// Для всех остальных зарегистрированных формируется персональное обращение
  /// с их собственным знаком зодиака, датой рождения и общепланетарным контекстом дня.
  String formatGreeting(String rawGreeting) {
    if (!isRegistered) {
      return '☕✨ Добро пожаловать в Астро Гороскоп!\n\n'
          'Пусть этот день подарит вам гармонию, ясность мыслей и вдохновение 🌿 '
          'Выберите свой знак зодиака для просмотра актуального прогноза или заполните анкету натального профиля.';
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '☕✨ Добро пожаловать в Астро Гороскоп!\n\n'
          'Пусть этот день подарит вам гармонию, ясность мыслей и вдохновение 🌿 '
          'Выберите свой знак зодиака для просмотра актуального прогноза или заполните анкету натального профиля.';
    }

    // Только для реального автора сохраняем оригинальный натальный расчет 1978 года
    final isAuthorOleg = trimmedName.toLowerCase() == 'олег' &&
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

    // 2. Персональная фраза приветствия
    String greetingPhrase;
    final lowerRaw = rawGreeting.toLowerCase();
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

    // 3. Натальный бейдж пользователя
    final cityStr = birthPlace.isNotEmpty ? birthPlace : currentCity;
    final detailsList = <String>[];
    if (formattedBirthDate.isNotEmpty) detailsList.add(formattedBirthDate);
    if (birthTime.isNotEmpty) detailsList.add(birthTime);
    if (cityStr.isNotEmpty) detailsList.add(cityStr);

    final natalBadge = detailsList.isNotEmpty
        ? '($zodiacSymbol $zodiacSign • ${detailsList.join(", ")})'
        : '($zodiacSymbol $zodiacSign)';

    // 4. Извлекаем общепланетарный контекст текущего дня (день недели, планета-управитель, лунные сутки)
    final sentences = rawGreeting
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final daySentences = <String>[];
    for (final s in sentences) {
      // Пропускаем формулы приветствия
      if (RegExp(r'^(☀️|🌿|🕊️|☕|🌤️|🍀|🌅|✨|🍃|\s)*(Доброе утро|Добрый день|Добрый вечер|Здравствуйте|Приветствую)', caseSensitive: false).hasMatch(s) && s.length < 60) {
        continue;
      }
      // Пропускаем предложения с натальными данными автора
      if (RegExp(r'(1978|кишинев|кишинёв|паспорт подтверждает|расчет на|расчете вашей натальной|при вашем рождении|при рождении|восходящ|асцендент|середина неба|\bмс\b|10 дом|10-й дом|5-й дом|7-й дом|8-й дом|6-й дом|олег)', caseSensitive: false).hasMatch(s)) {
        continue;
      }
      daySentences.add(s);
    }

    String dayContext = daySentences.join(' ').trim();
    if (dayContext.isEmpty || dayContext.length < 15) {
      dayContext = 'Пусть космические энергии сегодняшнего дня раскроют потенциал вашего знака зодиака $zodiacSign и подарят ясность мыслей, вдохновение и гармонию во всех начинаниях.';
    }

    var finalGreeting = '$emojis $greetingPhrase $natalBadge\n\n$dayContext';

    // 5. Железный предохранитель: зачищаем любые возможные остатки данных автора
    finalGreeting = finalGreeting.replaceAll(RegExp(r'\bОлег[а-яА-Я]*\b', caseSensitive: false), trimmedName);
    finalGreeting = finalGreeting.replaceAll(RegExp(r'кишинев[а-яА-Я]*|кишинёв[а-яА-Я]*', caseSensitive: false), cityStr.isNotEmpty ? cityStr : '');
    finalGreeting = finalGreeting.replaceAll(RegExp(r'23\.05\.1978|00:05|00:50', caseSensitive: false), formattedBirthDate);
    finalGreeting = finalGreeting.replaceAll(RegExp(r'\(1°32\x27 Водолея\),?\s*', caseSensitive: false), '');
    finalGreeting = finalGreeting.replaceAll(RegExp(r'Ваш восходящий знак — [^,.]*,\s*', caseSensitive: false), '');

    return finalGreeting;
  }

  /// Форматирует текст тематических карточек дня, заменяя натальные ссылки автора на данные пользователя
  String formatTopicContent(String content) {
    final trimmedName = name.trim();
    final isAuthorOleg = isRegistered &&
        trimmedName.toLowerCase() == 'олег' &&
        birthDate.year == 1978 &&
        birthDate.month == 5 &&
        birthDate.day == 23;

    if (isAuthorOleg) return content;

    var res = content;
    // Заменяем натальные аспекты автора в тексте
    res = res.replaceAll(
      RegExp(r'\(Солнце в Близнецах с восходящим Водолеем\)', caseSensitive: false),
      '(знак $zodiacSign)',
    );
    res = res.replaceAll(
      RegExp(r'Вашего натального Водолея', caseSensitive: false),
      'вашего знака зодиака $zodiacSign',
    );
    res = res.replaceAll(
      RegExp(r'сдержанности Водолея', caseSensitive: false),
      'сдержанности',
    );
    res = res.replaceAll(
      RegExp(r'восходящ[а-я]* Водоле[а-я]*', caseSensitive: false),
      'знака $zodiacSign',
    );

    // Принудительно заменяем имя Олег в тексте тем на имя пользователя
    final targetName = trimmedName.isNotEmpty ? trimmedName : 'Пользователь';
    res = res.replaceAll(RegExp(r'\bОлег[а-яА-Я]*\b', caseSensitive: false), targetName);

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
      "updatedAt": updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json["id"] ?? "user_${DateTime.now().millisecondsSinceEpoch}",
      name: json["name"] ?? "",
      email: json["email"] ?? "",
      phone: json["phone"] ?? "",
      authType: json["authType"] ?? "guest",
      telegramUsername: json["telegramUsername"] ?? "",
      passwordHash: json["passwordHash"] ?? "",
      birthDate: json["birthDate"] != null
          ? DateTime.tryParse(json["birthDate"]) ?? DateTime(2000, 1, 1)
          : DateTime(2000, 1, 1),
      birthTime: json["birthTime"] ?? "12:00",
      isTimeExact: json["isTimeExact"] ?? true,
      birthPlace: json["birthPlace"] ?? "",
      currentCity: json["currentCity"] ?? "",
      gender: json["gender"] ?? "female",
      focus: json["focus"] ?? "бизнес, деловые переговоры, финансы и здоровье",
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
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
