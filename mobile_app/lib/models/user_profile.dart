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
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
