import 'package:flutter_test/flutter_test.dart';

import 'package:cruise_assist/features/hijri.dart';

void main() {
  group('gregorianToHijri', () {
    // Reference values come from the official Umm al-Qura calendar
    // (the same table JAKIM publishes) and were cross-checked against the
    // Aladhan UAQ conversion endpoint.
    test('converts 10 November 2026', () {
      final h = gregorianToHijri(DateTime.utc(2026, 11, 10));
      expect(h.year, 1448);
      expect(h.month, 5);
      expect(h.day, 30);
      expect(h.monthName, 'Jumada al-Ula');
    });

    test('converts 19 March 2024 (start of Ramadan 1445)', () {
      final h = gregorianToHijri(DateTime.utc(2024, 3, 19));
      expect(h.year, 1445);
      expect(h.month, 9);
      expect(h.day, 9);
      expect(h.monthName, 'Ramadan');
    });

    test('converts 1 January 2025', () {
      final h = gregorianToHijri(DateTime.utc(2025, 1, 1));
      expect(h.year, 1446);
      expect(h.month, 7);
      expect(h.day, 1);
    });

    test('converts 1 January 2026', () {
      final h = gregorianToHijri(DateTime.utc(2026, 1, 1));
      expect(h.year, 1447);
      expect(h.month, 7);
      expect(h.day, 12);
    });

    test('converts the epoch: 1 Muharram 1356 is 14 March 1937', () {
      final h = gregorianToHijri(DateTime.utc(1937, 3, 14));
      expect(h.year, 1356);
      expect(h.month, 1);
      expect(h.day, 1);
    });

    test('handles the 28-day month of Sha\'ban 1364', () {
      // Sha'ban 1364 starts 11 July 1945 and is 28 days long.
      final start = gregorianToHijri(DateTime.utc(1945, 7, 11));
      expect(start.year, 1364);
      expect(start.month, 8);
      expect(start.day, 1);

      final end = gregorianToHijri(DateTime.utc(1945, 8, 7));
      expect(end.month, 8);
      expect(end.day, 28);

      // The next day rolls over to Ramadan.
      final next = gregorianToHijri(DateTime.utc(1945, 8, 8));
      expect(next.month, 9);
      expect(next.day, 1);
    });

    test('is continuous across a month boundary', () {
      var previous = gregorianToHijri(DateTime.utc(2026, 11, 9));
      for (var i = 10; i <= 20; i++) {
        final current = gregorianToHijri(DateTime.utc(2026, 11, i));
        final expectedDay = previous.day + 1;
        if (expectedDay > 30) {
          expect(current.month, previous.month + 1);
          expect(current.day, 1);
        } else {
          expect(current.month, previous.month);
          expect(current.day, expectedDay);
        }
        previous = current;
      }
    });

    test('ignores the time of day', () {
      final morning = gregorianToHijri(DateTime.utc(2026, 11, 10, 1, 30));
      final evening = gregorianToHijri(DateTime.utc(2026, 11, 10, 22, 45));
      expect(morning, evening);
    });

    test('supports equality and hashing', () {
      final a = gregorianToHijri(DateTime.utc(2026, 11, 10));
      final b = HijriDate(1448, 5, 30);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
