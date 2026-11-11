import 'dart:io';

import 'package:cruise_assist/data/cache.dart';
import 'package:cruise_assist/data/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const currentPayload = '''
{
  "current": {
    "time": "2026-11-10T08:00",
    "temperature_2m": 31.2,
    "apparent_temperature": 34.5,
    "relative_humidity_2m": 78,
    "weather_code": 2,
    "wind_speed_10m": 11.4
  },
  "daily": {
    "sunrise": ["2026-11-10T06:22"],
    "sunset": ["2026-11-10T18:11"]
  }
}
''';

const dailyPayload = '''
{
  "daily": {
    "time": ["2026-11-10", "2026-11-11"],
    "weather_code": [2, 61],
    "temperature_2m_max": [32.1, 30.4],
    "temperature_2m_min": [24.0, 23.5],
    "precipitation_sum": [0.0, 4.2],
    "sunrise": ["2026-11-10T06:22", "2026-11-11T06:22"],
    "sunset": ["2026-11-10T18:11", "2026-11-11T18:11"]
  }
}
''';

const airPayload = '''
{
  "current": {"time": "2026-11-10T08:00", "us_aqi": 58, "pm2_5": 12.7}
}
''';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cruise_weather');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  DiskCache cache() => DiskCache(directory: () async => tmp);

  group('WeatherService.current', () {
    test('parses current conditions', () async {
      final s = WeatherService(client: fakeClient(currentPayload));
      final r = await s.current(3.139, 101.6869);
      expect(r.ok, isTrue);
      expect(r.value!.tempC, 31.2);
      expect(r.value!.feelsC, 34.5);
      expect(r.value!.humidity, 78);
      expect(r.value!.weatherCode, 2);
      expect(r.value!.windKph, 11.4);
      expect(r.value!.sunrise, isNotNull);
      expect(r.value!.sunset, isNotNull);
      expect(r.stale, isFalse);
    });

    test('HTTP 500 returns failed without throwing', () async {
      final s = WeatherService(client: fakeClient('boom', status: 500));
      final r = await s.current(3.139, 101.6869);
      expect(r.ok, isFalse);
      expect(r.message, contains('500'));
      expect(r.value, isNull);
    });

    test('malformed JSON returns failed', () async {
      final s = WeatherService(client: fakeClient('{not json'));
      final r = await s.current(3.139, 101.6869);
      expect(r.ok, isFalse);
      expect(r.message, isNotNull);
    });

    test('empty but valid JSON returns failed (no current block)', () async {
      final s = WeatherService(client: fakeClient('{}'));
      final r = await s.current(3.139, 101.6869);
      expect(r.ok, isFalse);
      expect(r.message, contains('empty current'));
    });

    test('serves stale cached value after a failure', () async {
      final good = WeatherService(
        client: fakeClient(currentPayload),
        cache: cache(),
      );
      await good.current(3.139, 101.6869);
      final offline = WeatherService(client: failingClient(), cache: cache());
      final r = await offline.current(3.139, 101.6869);
      expect(r.ok, isFalse);
      expect(r.stale, isTrue);
      expect(r.value!.tempC, 31.2);
    });
  });

  group('WeatherService.forecast', () {
    test('parses the daily list', () async {
      final s = WeatherService(client: fakeClient(dailyPayload));
      final r = await s.forecast(3.139, 101.6869);
      expect(r.ok, isTrue);
      expect(r.value!.length, 2);
      expect(r.value!.first.maxC, 32.1);
      expect(r.value!.first.minC, 24.0);
      expect(r.value!.last.rainMm, 4.2);
    });

    test('empty daily array yields an empty list', () async {
      final s = WeatherService(client: fakeClient('{"daily":{}}'));
      final r = await s.forecast(3.139, 101.6869);
      expect(r.ok, isTrue);
      expect(r.value, isEmpty);
    });

    test('HTTP 500 returns failed', () async {
      final s = WeatherService(client: fakeClient('x', status: 500));
      final r = await s.forecast(3.139, 101.6869);
      expect(r.ok, isFalse);
    });
  });

  group('WeatherService.air', () {
    test('parses us_aqi and pm2.5', () async {
      final s = WeatherService(client: fakeClient(airPayload));
      final r = await s.air(3.139, 101.6869);
      expect(r.ok, isTrue);
      expect(r.value!.usAqi, 58);
      expect(r.value!.pm25, 12.7);
    });

    test('missing pm2.5 leaves it null', () async {
      final s = WeatherService(
        client: fakeClient('{"current":{"time":"2026-11-10T08:00"}}'),
      );
      final r = await s.air(3.139, 101.6869);
      expect(r.ok, isTrue);
      expect(r.value!.pm25, isNull);
    });

    test('malformed JSON returns failed', () async {
      final s = WeatherService(client: fakeClient('nope'));
      final r = await s.air(3.139, 101.6869);
      expect(r.ok, isFalse);
    });
  });
}
