import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_horoscope/utils/date_time_input.dart';

TextEditingValue _applyStep(
  TextInputFormatter formatter,
  TextEditingValue oldVal,
  String newRawText, {
  int? cursorOffset,
}) {
  return formatter.formatEditUpdate(
    oldVal,
    TextEditingValue(
      text: newRawText,
      selection: TextSelection.collapsed(
        offset: cursorOffset ?? newRawText.length,
      ),
    ),
  );
}

void main() {
  group('DateMaskTextInputFormatter', () {
    test('auto-inserts dots when typing 23051978 continuously', () {
      final fmt = DateMaskTextInputFormatter();
      var val = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );

      final steps = [
        ('2', '2', 1),
        ('23', '23', 2),
        ('230', '23.0', 4),
        ('23.05', '23.05', 5),
        ('23.051', '23.05.1', 7),
        ('23.05.19', '23.05.19', 8),
        ('23.05.197', '23.05.197', 9),
        ('23.05.1978', '23.05.1978', 10),
      ];

      for (final (rawInput, expectedText, expectedCursor) in steps) {
        val = _applyStep(fmt, val, val.text + rawInput.substring(val.text.length));
        expect(val.text, expectedText);
        expect(val.selection.baseOffset, expectedCursor);
      }
    });

    test('normalizes pasted separators like 23:05:1978 or 23/05/1978', () {
      final fmt = DateMaskTextInputFormatter();
      const empty = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );

      expect(_applyStep(fmt, empty, '23:05:1978').text, '23.05.1978');
      expect(_applyStep(fmt, empty, '23/05/1978').text, '23.05.1978');
      expect(_applyStep(fmt, empty, '23-05-197899').text, '23.05.1978');
    });

    test('handles backspace over separator cleanly without trapping cursor', () {
      final fmt = DateMaskTextInputFormatter();
      const before = TextEditingValue(
        text: '23.05.1978',
        selection: TextSelection.collapsed(offset: 3),
      );
      // Simulating Backspace on dot at offset 3 ("23|05.1978")
      final after = _applyStep(fmt, before, '2305.1978', cursorOffset: 2);
      expect(after.text, '20.51.978');
      expect(after.selection.baseOffset, 1);

      const tailDot = TextEditingValue(
        text: '23.0',
        selection: TextSelection.collapsed(offset: 4),
      );
      final afterTail = _applyStep(fmt, tailDot, '23.', cursorOffset: 3);
      expect(afterTail.text, '23');
      expect(afterTail.selection.baseOffset, 2);
    });
  });

  group('TimeMaskTextInputFormatter', () {
    test('auto-inserts colon when typing 0930', () {
      final fmt = TimeMaskTextInputFormatter();
      var val = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );

      for (final ch in ['0', '9', '3', '0']) {
        val = _applyStep(fmt, val, val.text + ch);
      }
      expect(val.text, '09:30');
      expect(val.selection.baseOffset, 5);
    });
  });

  group('Strict date and time validators', () {
    final now = DateTime(2026, 11, 23);

    test('validates calendar dates strictly without overflow', () {
      expect(parseStrictBirthDate('23.05.1978', now: now), DateTime(1978, 5, 23));
      expect(parseStrictBirthDate('29.02.2000', now: now), DateTime(2000, 2, 29));
      expect(parseStrictBirthDate('29.02.2001', now: now), isNull);
      expect(parseStrictBirthDate('31.04.1995', now: now), isNull);
      expect(parseStrictBirthDate('24.11.2026', now: now), isNull);
      expect(parseStrictBirthDate('31.12.1919', now: now), isNull);
      expect(parseStrictBirthDate('23.05.19', now: now), isNull);
    });

    test('validates 24-hour times strictly', () {
      expect(parseStrictBirthTime('00:00'), const TimeOfDay(hour: 0, minute: 0));
      expect(parseStrictBirthTime('23:59'), const TimeOfDay(hour: 23, minute: 59));
      expect(parseStrictBirthTime('24:00'), isNull);
      expect(parseStrictBirthTime('12:60'), isNull);
      expect(parseStrictBirthTime('12:3'), isNull);
    });
  });

  testWidgets('TextFormField formats digits into DD.MM.YYYY and HH:MM', (tester) async {
    final dateController = TextEditingController();
    final timeController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextFormField(
                key: const Key('date_field'),
                controller: dateController,
                inputFormatters: [DateMaskTextInputFormatter()],
              ),
              TextFormField(
                key: const Key('time_field'),
                controller: timeController,
                inputFormatters: [TimeMaskTextInputFormatter()],
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('date_field')), '23051978');
    await tester.enterText(find.byKey(const Key('time_field')), '0930');
    await tester.pump();

    expect(dateController.text, '23.05.1978');
    expect(timeController.text, '09:30');
  });
}
