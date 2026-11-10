import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:cruise_assist/data/cache.dart';
import 'package:cruise_assist/data/prayer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const timingsPayload = '''
{
  "code": 200,
  "status": "OK",
  "data": {
    "timings": {
      "Fajr": "05:37 (MYT)",
      "Sunrise": "06:57 (MYT)",
      "Dhuhr": "12:57 (MYT)",
      "Asr": "16:20 (MYT)",
      "Sunset": "18:57 (MYT)",
      "Maghrib": "18:57 (MYT)",
      "Isha": "20:09 (MYT)"
    },
    "date": {"gregorian": {"day": "10", "month": {"number": 11}, "year": "2026"}}
  }
}
''';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cruise_prayer');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  DiskCache cache() => DiskCache(directory: () async => tmp);

  test('parses the five prayers plus sunrise', () async {
    final s = PrayerService(client: fakeClient(timingsPayload));
    final r = await s.day(zone: 'WLY01', date: DateTime(2026, 11, 10));
    expect(r.ok, isTrue);
    final times = r.value!.times;
    expect(times.map((t) => t.name).toList(),
        ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);
    expect(times.first.at, DateTime(2026, 11, 10, 5, 37));
    expect(times.last.at, DateTime(2026, 11, 10, 20, 9));
    expect(r.value!.zone, 'WLY01');
  });

  test('requests method=17 and the DD-MM-YYYY date path', () async {
    http.Request? seen;
    final s = PrayerService(
        client: fakeClient(timingsPayload, onRequest: (r) => seen = r));
    await s.day(zone: 'SGR01', date: DateTime(2026, 11, 10));
    expect(seen!.url.path, contains('/v1/timings/10-11-2026'));
    expect(seen!.url.queryParameters['method'], '17');
  });

  test('HTTP 500 returns failed', () async {
    final s = PrayerService(client: fakeClient('err', status: 500));
    final r = await s.day(zone: 'WLY01', date: DateTime(2026, 11, 10));
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = PrayerService(client: fakeClient('{{{'));
    final r = await s.day(zone: 'WLY01', date: DateTime(2026, 11, 10));
    expect(r.ok, isFalse);
  });

  test('empty timings object returns failed', () async {
    final s = PrayerService(
        client: fakeClient('{"code":200,"data":{"timings":{}}}'));
    final r = await s.day(zone: 'WLY01', date: DateTime(2026, 11, 10));
    expect(r.ok, isFalse);
    expect(r.message, contains('empty timings'));
  });

  test('non-200 API code returns failed', () async {
    final s = PrayerService(
        client: fakeClient('{"code":400,"status":"Bad Request"}'));
    final r = await s.day(zone: 'WLY01', date: DateTime(2026, 11, 10));
    expect(r.ok, isFalse);
  });

  test('serves stale cached value after a failure', () async {
    final good = PrayerService(
        client: fakeClient(timingsPayload), cache: cache());
    await good.day(zone: 'WLY01', date: DateTime(2026, 11, 10));
    final offline = PrayerService(client: failingClient(), cache: cache());
    final r = await offline.day(zone: 'WLY01', date: DateTime(2026, 11, 10));
    expect(r.ok, isFalse);
    expect(r.stale, isTrue);
    expect(r.value!.times.length, 6);
  });

  group('zone helpers', () {
    test('zones list contains the major JAKIM zones', () {
      expect(PrayerService.zones, contains('WLY01'));
      expect(PrayerService.zones, contains('SGR01'));
      expect(PrayerService.zones, contains('JHR02'));
      expect(PrayerService.zones.length, greaterThan(40));
    });

    test('zoneForLatLng maps KL, Penang and Johor', () {
      expect(PrayerService.zoneForLatLng(3.139, 101.6869), 'WLY01');
      expect(PrayerService.zoneForLatLng(5.4141, 100.3288), 'PNG01');
      expect(PrayerService.zoneForLatLng(1.4927, 103.7414), 'JHR02');
    });

    test('zoneForLatLng falls back to WLY01 outside Malaysia', () {
      expect(PrayerService.zoneForLatLng(51.5, -0.12), 'WLY01');
    });

    test('every listed zone has coordinates', () {
      for (final z in PrayerService.zones) {
        expect(PrayerService.zonePoints[z], isNotNull, reason: z);
      }
    });
  });
}
