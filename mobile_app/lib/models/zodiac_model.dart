import 'package:flutter/material.dart';

class ZodiacSign {
  final String id;
  final String name;
  final String symbol;
  final String dates;
  final String element;
  final String colorHex;
  final String focus;
  final String energy;
  final String luckyHours;
  final String forecast;

  ZodiacSign({
    required this.id,
    required this.name,
    required this.symbol,
    required this.dates,
    required this.element,
    required this.colorHex,
    required this.focus,
    required this.energy,
    required this.luckyHours,
    required this.forecast,
  });

  Color get elementColor {
    switch (element.toLowerCase()) {
      case 'огонь':
        return const Color(0xFFE76F51);
      case 'земля':
        return const Color(0xFF2A9D8F);
      case 'воздух':
        return const Color(0xFFE9C46A);
      case 'вода':
        return const Color(0xFF457B9D);
      default:
        return const Color(0xFFD4AF37);
    }
  }

  IconData get elementIcon {
    switch (element.toLowerCase()) {
      case 'огонь':
        return Icons.local_fire_department_rounded;
      case 'земля':
        return Icons.eco_rounded;
      case 'воздух':
        return Icons.air_rounded;
      case 'вода':
        return Icons.water_drop_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  factory ZodiacSign.fromJson(Map<String, dynamic> json) => ZodiacSign(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    symbol: json['symbol'] ?? '✨',
    dates: json['dates'] ?? '',
    element: json['element'] ?? 'Стихия',
    colorHex: json['color'] ?? '0xFFD4AF37',
    focus: json['focus'] ?? 'Развитие',
    energy: json['energy'] ?? '85%',
    luckyHours: json['lucky_hours'] ?? '10:00–12:00',
    forecast: json['forecast'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'symbol': symbol,
    'dates': dates,
    'element': element,
    'color': colorHex,
    'focus': focus,
    'energy': energy,
    'lucky_hours': luckyHours,
    'forecast': forecast,
  };
}

class ZodiacDayData {
  final String date;
  final String rawText;
  final List<ZodiacSign> signs;
  final String updatedAt;

  ZodiacDayData({
    required this.date,
    required this.rawText,
    required this.signs,
    this.updatedAt = '',
  });

  factory ZodiacDayData.fromJson(Map<String, dynamic> json) {
    var rawList = json['signs'] as List? ?? [];
    return ZodiacDayData(
      date: json['date'] ?? '',
      rawText: json['raw_text'] ?? '',
      signs: rawList.map((item) => ZodiacSign.fromJson(item as Map<String, dynamic>)).toList(),
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'raw_text': rawText,
    'signs': signs.map((s) => s.toJson()).toList(),
    'updated_at': updatedAt,
  };
}
