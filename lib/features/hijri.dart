import 'package:flutter/material.dart';

/// A Hijri date on the Umm al-Qura calendar.
@immutable
class HijriDate {
  final int year;
  final int month;
  final int day;
  const HijriDate(this.year, this.month, this.day);

  String get monthName => monthNames[month - 1];

  static const monthNames = [
    'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
    'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', 'Shaban',
    'Ramadan', 'Shawwal', 'Dhul-Qadah', 'Dhul-Hijjah',
  ];

  @override
  String toString() => '$day $monthName $year AH';

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// First Hijri year covered by [_ummAlQuraYearInfo].
const int _firstYear = 1356;

/// Modified Julian Day Number of 1 Muharram 1356 (14 March 1937), the first
/// day of the published Umm al-Qura calendar.
const int _epochMcjdn = 28607;

/// Per Hijri year, the length of each of its twelve months.
///
/// Bits 0-11 mark the months that have 30 days (the rest have 29). Bits
/// 12-15 hold the number of the month that has 28 days, or 0 when no month
/// in that year is short. The only 28-day month in the published range is
/// Sha'ban 1364.
const List<int> _ummAlQuraYearInfo = [
  0x04D4, 0x0D55, 0x064B, 0x0497, 0x0D55, 0x0555, 0x0555, 0x0D55,
  0x8755, 0x0D55, 0x0555, 0x0555, 0x0D55, 0x06D5, 0x0555, 0x0EA5,
  0x0D2A, 0x0AAA, 0x0CD5, 0x0655, 0x0572, 0x0DA9, 0x0555, 0x0AAA,
  0x0555, 0x052D, 0x0A6D, 0x055A, 0x0555, 0x074D, 0x0D53, 0x0D54,
  0x0556, 0x0D55, 0x02D5, 0x0D55, 0x0D54, 0x0D45, 0x0655, 0x052D,
  0x0A5D, 0x055A, 0x0AD5, 0x06AA, 0x0D4B, 0x052A, 0x0A57, 0x04AE,
  0x0976, 0x056C, 0x0B55, 0x0AAA, 0x0A55, 0x04AD, 0x095D, 0x02DA,
  0x05D9, 0x0DB2, 0x0BA4, 0x0B4A, 0x0A55, 0x02B5, 0x0575, 0x0B6A,
  0x0BD2, 0x0BC4, 0x0B89, 0x0A95, 0x052D, 0x05AD, 0x0B6A, 0x06E4,
  0x0DC9, 0x0D92, 0x0AA6, 0x0956, 0x02AE, 0x056D, 0x036A, 0x0B55,
  0x0AAA, 0x094D, 0x049D, 0x095D, 0x02BA, 0x05B5, 0x05AA, 0x0D55,
  0x0A9A, 0x092E, 0x025E, 0x055D, 0x0ADA, 0x06D4, 0x06A5, 0x054B,
  0x0A97, 0x054E, 0x0AAE, 0x05AC, 0x0BA9, 0x0D92, 0x0B25, 0x064B,
  0x0CAB, 0x055A, 0x0B55, 0x06D2, 0x0EA5, 0x0E4A, 0x0A95, 0x052D,
  0x0AAD, 0x036C, 0x0759, 0x06D2, 0x0695, 0x052D, 0x0A5B, 0x04BA,
  0x09BA, 0x03B4, 0x0B69, 0x0B52, 0x0AA6, 0x04B6, 0x096D, 0x02EC,
  0x06D9, 0x0DB2, 0x0D54, 0x0D2A, 0x0A56, 0x04AE, 0x096D, 0x0D6A,
  0x0B54, 0x0B29, 0x0A93, 0x052B, 0x0A57, 0x0536, 0x0AB5, 0x06AA,
  0x0E93,
];

int _yearLength(int info) {
  var length = 348; // 12 x 29 days
  var mask = info & 0xFFF;
  while (mask != 0) {
    if (mask & 1 != 0) length++;
    mask >>= 1;
  }
  return length - ((info >> 12) & 0xF == 0 ? 0 : 1);
}

int _monthLength(int info, int month) {
  final short = (info >> 12) & 0xF;
  if (short != 0 && short == month) return 28;
  return (info & (1 << (month - 1))) != 0 ? 30 : 29;
}

/// Modified Julian Day Number for a Gregorian date.
int _toMcjdn(int year, int month, int day) {
  var y = year;
  var m = month;
  if (m < 3) {
    y -= 1;
    m += 12;
  }
  final a = y ~/ 100;
  final jgc = a - a ~/ 4 - 2;
  const monthOffsets = [
    122, 153, 183, 214, 244, 275, //
    306, 336, 367, 397, 428, 459,
  ];
  final shifted = y + 4716;
  return 365 * shifted +
      shifted ~/ 4 +
      monthOffsets[m - 3] +
      day -
      jgc -
      1524 -
      2400000;
}

/// Converts a Gregorian date to the Umm al-Qura Hijri calendar.
///
/// The conversion is fully offline: it uses the published Umm al-Qura month
/// table rather than an approximation, so it matches the official Malaysian
/// and Saudi calendars. Dates outside the published range (1937-2077) fall
/// back to the tabular Islamic calendar.
HijriDate gregorianToHijri(DateTime date) {
  final civil = DateTime.utc(date.year, date.month, date.day);
  final mcjdn = _toMcjdn(civil.year, civil.month, civil.day);
  if (mcjdn < _epochMcjdn || mcjdn > _lastMcjdn) {
    return _tabularHijri(civil);
  }

  var offset = mcjdn - _epochMcjdn;
  var yearIndex = 0;
  while (offset >= _yearLength(_ummAlQuraYearInfo[yearIndex])) {
    offset -= _yearLength(_ummAlQuraYearInfo[yearIndex]);
    yearIndex++;
  }

  final info = _ummAlQuraYearInfo[yearIndex];
  var month = 1;
  while (offset >= _monthLength(info, month)) {
    offset -= _monthLength(info, month);
    month++;
  }
  return HijriDate(_firstYear + yearIndex, month, offset + 1);
}

/// Modified Julian Day Number of 1 Dhul-Hijjah 1500, the last day covered
/// by the published Umm al-Qura table.
final int _lastMcjdn = _epochMcjdn +
    (() {
      var total = 0;
      for (final info in _ummAlQuraYearInfo) {
        total += _yearLength(info);
      }
      return total - 1;
    })();

/// Tabular (Kuwaiti) Islamic calendar, used outside the Umm al-Qura range.
HijriDate _tabularHijri(DateTime civil) {
  final jd = _toMcjdn(civil.year, civil.month, civil.day) + 2400000;
  final l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  var year = 30 * n + (l - 10631 * n - 354) ~/ 10631 + 1;
  var day = jd - _tabularYearStart(year) + 1;
  if (day > 355) {
    year++;
    day = jd - _tabularYearStart(year) + 1;
  }
  var month = 1;
  while (month < 12 && day > _tabularMonthLength(year, month)) {
    day -= _tabularMonthLength(year, month);
    month++;
  }
  return HijriDate(year, month, day);
}

int _tabularYearStart(int year) {
  final cycles = (year - 1) ~/ 30;
  final yearInCycle = year - cycles * 30;
  var days = cycles * 10631 + 1948440;
  for (var y = 1; y < yearInCycle; y++) {
    days += _tabularIsLeap(y) ? 355 : 354;
  }
  return days;
}

int _tabularMonthLength(int year, int month) {
  if (month.isOdd) return 30;
  if (month < 12) return 29;
  return _tabularIsLeap(year % 30) ? 30 : 29;
}

bool _tabularIsLeap(int year) =>
    const {2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29}.contains(year % 30);
