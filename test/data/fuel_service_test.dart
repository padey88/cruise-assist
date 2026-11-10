import 'dart:io';

import 'package:cruise_assist/data/cache.dart';
import 'package:cruise_assist/data/fuel_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const fuelPayload = '''
[
  {"date": "2025-07-24", "ron95": 2.05, "ron97": 3.21, "diesel": 2.91,
   "diesel_eastmsia": 2.15, "series_type": "level"},
  {"date": "2025-07-31", "ron95": 2.06, "ron97": 3.22, "diesel": 2.92,
   "diesel_eastmsia": 2.16, "series_type": "level"}
]
''';

const fuelWithDeltaPayload = '''
[
  {"date": "2026-11-05", "ron95": -0.15, "ron97": -0.2, "diesel": -0.15,
   "series_type": "change_weekly"},
  {"date": "2026-11-05", "ron95": 4.27, "ron97": 4.7, "diesel": 5.12,
   "diesel_eastmsia": 5.12, "series_type": "level"},
  {"date": "2026-10-29", "ron95": 4.42, "ron97": 4.9, "diesel": 5.27,
   "series_type": "level"}
]
''';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cruise_fuel');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  DiskCache cache() => DiskCache(directory: () async => tmp);

  test('takes the newest dated row', () async {
    final s = FuelService(client: fakeClient(fuelPayload));
    final r = await s.latest();
    expect(r.ok, isTrue);
    expect(r.value!.ron95, 2.06);
    expect(r.value!.ron97, 3.22);
    expect(r.value!.diesel, 2.92);
    expect(r.value!.effectiveFrom, DateTime(2025, 7, 31));
  });

  test('sends Accept: */* and the fuelprice dataset id', () async {
    http.Request? seen;
    final s = FuelService(
        client: fakeClient(fuelPayload, onRequest: (r) => seen = r));
    await s.latest();
    expect(seen!.headers['Accept'], '*/*');
    expect(seen!.url.queryParameters['id'], 'fuelprice');
    // Newest first, otherwise the catalogue returns the oldest rows.
    expect(seen!.url.queryParameters['sort'], '-date');
  });

  test('ignores change_weekly delta rows and takes the level price', () async {
    final s = FuelService(client: fakeClient(fuelWithDeltaPayload));
    final r = await s.latest();
    expect(r.ok, isTrue);
    expect(r.value!.ron95, 4.27);
    expect(r.value!.ron97, 4.7);
    expect(r.value!.diesel, 5.12);
    expect(r.value!.effectiveFrom, DateTime(2026, 11, 5));
  });

  test('HTTP 500 returns failed', () async {
    final s = FuelService(client: fakeClient('err', status: 500));
    final r = await s.latest();
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = FuelService(client: fakeClient('not json'));
    final r = await s.latest();
    expect(r.ok, isFalse);
  });

  test('empty array returns failed', () async {
    final s = FuelService(client: fakeClient('[]'));
    final r = await s.latest();
    expect(r.ok, isFalse);
    expect(r.message, contains('empty'));
  });

  test('rows without dates return failed', () async {
    final s = FuelService(client: fakeClient('[{"ron95": 2.05}]'));
    final r = await s.latest();
    expect(r.ok, isFalse);
    expect(r.message, contains('no dated rows'));
  });

  test('serves stale cached value after a failure', () async {
    final good = FuelService(client: fakeClient(fuelPayload), cache: cache());
    await good.latest();
    final offline = FuelService(client: failingClient(), cache: cache());
    final r = await offline.latest();
    expect(r.ok, isFalse);
    expect(r.stale, isTrue);
    expect(r.value!.ron95, 2.06);
  });
}
