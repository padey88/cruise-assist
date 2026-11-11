import 'dart:io';

import 'package:cruise_assist/data/cache.dart';
import 'package:cruise_assist/data/geocode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const nominatimPayload = '''
{
  "place_id": 12345,
  "lat": "3.139", "lon": "101.6869",
  "display_name": "Kuala Lumpur, Federal Territory of Kuala Lumpur, Malaysia",
  "name": "Kuala Lumpur",
  "address": {
    "city": "Kuala Lumpur",
    "state": "Federal Territory of Kuala Lumpur",
    "country": "Malaysia"
  }
}
''';

/// Each test gets a private cache directory. The default `cruise_assist_cache`
/// folder is shared per-process, so an earlier test's payload for the same
/// coordinates was being served to a later one, which then never exercised its
/// own fixture.
DiskCache isolatedCache() => DiskCache(
  directory: () async => Directory.systemTemp.createTempSync('geocode_t_'),
);

void main() {
  test('parses the place name from the address block', () async {
    final s = GeocodeService(
      cache: isolatedCache(),
      client: fakeClient(nominatimPayload),
    );
    final r = await s.reverse(3.139, 101.6869);
    expect(r.ok, isTrue);
    expect(r.value, 'Kuala Lumpur, Federal Territory of Kuala Lumpur');
  });

  test('sends a real User-Agent and jsonv2 format', () async {
    http.Request? seen;
    final s = GeocodeService(
      cache: isolatedCache(),
      client: fakeClient(nominatimPayload, onRequest: (r) => seen = r),
    );
    await s.reverse(3.139, 101.6869);
    expect(seen!.headers['User-Agent'], isNotEmpty);
    expect(seen!.headers['User-Agent'], contains('CruiseAssist'));
    expect(seen!.url.queryParameters['format'], 'jsonv2');
  });

  test('HTTP 500 returns failed', () async {
    final s = GeocodeService(
      cache: isolatedCache(),
      client: fakeClient('err', status: 500),
    );
    final r = await s.reverse(3.139, 101.6869);
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = GeocodeService(cache: isolatedCache(), client: fakeClient('<<<'));
    final r = await s.reverse(3.139, 101.6869);
    expect(r.ok, isFalse);
  });

  test('empty address falls back to display_name', () async {
    const payload = '{"display_name": "Somewhere, Malaysia"}';
    final s = GeocodeService(
      cache: isolatedCache(),
      client: fakeClient(payload),
    );
    final r = await s.reverse(3.139, 101.6869);
    expect(r.ok, isTrue);
    expect(r.value, contains('Somewhere'));
  });

  test('response without any name returns failed', () async {
    final s = GeocodeService(cache: isolatedCache(), client: fakeClient('{}'));
    final r = await s.reverse(3.139, 101.6869);
    expect(r.ok, isFalse);
    expect(r.message, contains('not found'));
  });
}
