import 'dart:convert';

class UserProfile {
  final String name;
  final String birthDate;
  final String birthTime;
  final String birthCity;
  final bool isGeneral;

  UserProfile({
    this.name = '',
    this.birthDate = '',
    this.birthTime = '',
    this.birthCity = '',
    this.isGeneral = false,
  });

  bool get hasNatalData => birthDate.trim().isNotEmpty && !isGeneral;

  Map<String, dynamic> toJson() => {
    'name': name,
    'birth_date': birthDate,
    'birth_time': birthTime,
    'birth_city': birthCity,
    'is_general': isGeneral,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? '',
    birthDate: json['birth_date'] ?? '',
    birthTime: json['birth_time'] ?? '',
    birthCity: json['birth_city'] ?? '',
    isGeneral: json['is_general'] ?? false,
  );

  String serialize() => jsonEncode(toJson());

  factory UserProfile.deserialize(String str) {
    try {
      return UserProfile.fromJson(jsonDecode(str));
    } catch (_) {
      return UserProfile();
    }
  }

  UserProfile copyWith({
    String? name,
    String? birthDate,
    String? birthTime,
    String? birthCity,
    bool? isGeneral,
  }) {
    return UserProfile(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      birthCity: birthCity ?? this.birthCity,
      isGeneral: isGeneral ?? this.isGeneral,
    );
  }
}
