import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Общий форматтер цифр для масок вида ДД.ММ.ГГГГ или ЧЧ:ММ.
/// Позволяет набирать только цифры с цифровой клавиатуры и автоматически
/// проставляет разделители, корректно сохраняя позицию курсора.
class _DigitsMaskTextInputFormatter extends TextInputFormatter {
  final String separator;
  final List<int> groupLengths;
  final int maxDigits;

  _DigitsMaskTextInputFormatter({
    required this.separator,
    required this.groupLengths,
  }) : maxDigits = groupLengths.fold(0, (sum, len) => sum + len);

  String _formatDigits(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    int offset = 0;
    for (int g = 0; g < groupLengths.length; g++) {
      if (offset >= digits.length) break;
      if (g > 0) buffer.write(separator);
      final end = (offset + groupLengths[g]).clamp(0, digits.length);
      buffer.write(digits.substring(offset, end));
      offset = end;
    }
    return buffer.toString();
  }

  int _countDigitsBefore(String text, int cursorOffset) {
    final safeEnd = cursorOffset.clamp(0, text.length);
    int count = 0;
    for (int i = 0; i < safeEnd; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 48 && code <= 57) count++;
    }
    return count;
  }

  int _cursorOffsetForDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    int seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      final code = formatted.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        seen++;
        if (seen == digitCount) {
          return i + 1;
        }
      }
    }
    return formatted.length;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    String newDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (newDigits.length > maxDigits) {
      newDigits = newDigits.substring(0, maxDigits);
    }

    final rawSelection = newValue.selection.isValid
        ? newValue.selection.extentOffset
        : newValue.text.length;
    int digitsBeforeCursor = _countDigitsBefore(newValue.text, rawSelection);

    // Если пользователь нажал Backspace прямо на разделителе (например, "23.|05"),
    // удаляем цифру перед этим разделителем, чтобы курсор не застревал.
    if (oldDigits == newDigits &&
        newValue.text.length < oldValue.text.length &&
        digitsBeforeCursor > 0 &&
        digitsBeforeCursor <= newDigits.length) {
      newDigits = newDigits.substring(0, digitsBeforeCursor - 1) +
          newDigits.substring(digitsBeforeCursor);
      digitsBeforeCursor--;
    }

    final formatted = _formatDigits(newDigits);
    final cursorOffset = _cursorOffsetForDigitCount(
      formatted,
      digitsBeforeCursor.clamp(0, newDigits.length),
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

/// Автоматически расставляет точки при вводе даты: `23051978` -> `23.05.1978`.
class DateMaskTextInputFormatter extends _DigitsMaskTextInputFormatter {
  DateMaskTextInputFormatter() : super(separator: '.', groupLengths: const [2, 2, 4]);
}

/// Автоматически расставляет двоеточие при вводе времени: `0930` -> `09:30`.
class TimeMaskTextInputFormatter extends _DigitsMaskTextInputFormatter {
  TimeMaskTextInputFormatter() : super(separator: ':', groupLengths: const [2, 2]);
}

/// Строго разбирает дату вида `DD.MM.YYYY`, проверяя существование календарного дня.
DateTime? parseStrictBirthDate(
  String input, {
  DateTime? now,
  int minYear = 1920,
}) {
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(input.trim());
  if (match == null) return null;

  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;

  final refNow = now ?? DateTime.now();
  if (year < minYear || year > refNow.year) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final dt = DateTime(year, month, day);
  if (dt.year != year || dt.month != month || dt.day != day) return null;

  final todayEnd = DateTime(refNow.year, refNow.month, refNow.day, 23, 59, 59);
  if (dt.isAfter(todayEnd)) return null;
  return dt;
}

/// Строго разбирает время вида `HH:MM` (00:00 .. 23:59).
TimeOfDay? parseStrictBirthTime(String input) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(input.trim());
  if (match == null) return null;

  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
