import 'package:cruise_assist/data/poi_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const overpassPayload = '''
{
  "elements": [
    {"type": "node", "id": 1, "lat": 3.1400, "lon": 101.6900,
     "tags": {"amenity": "fuel", "name": "Petronas KLCC"}},
    {"type": "way", "id": 2, "center": {"lat": 3.1450, "lon": 101.6950},
     "tags": {"amenity": "parking", "name": "KLCC Park"}},
    {"type": "node", "id": 3, "lat": 3.1500, "lon": 101.7000,
     "tags": {"amenity": "charging_station", "name": "Chargify"}}
  ]
}
''';

void main() {
  test('parses nodes and ways with a centre', () async {
    final s = PoiService(client: fakeClient(overpassPayload));
    final r = await s.nearby(3.139, 101.6869);
    expect(r.ok, isTrue);
    expect(r.value!.length, 3);
    expect(r.value!.first.name, 'Petronas KLCC');
    expect(r.value!.first.kind, 'fuel');
    expect(r.value!.first.distanceM, isNotNull);
    // Sorted by distance from the query point.
    expect(r.value!.first.distanceM!, lessThan(r.value!.last.distanceM!));
  });

  test('sends an Overpass query for the requested kinds', () async {
    http.Request? seen;
    final s = PoiService(
      client: fakeClient(overpassPayload, onRequest: (r) => seen = r),
    );
    await s.nearby(3.139, 101.6869, kinds: ['fuel']);
    expect(seen!.url.host, 'overpass-api.de');
    expect(seen!.body, contains('amenity'));
    expect(seen!.body, contains('fuel'));
  });

  test('empty element list yields an empty list', () async {
    final s = PoiService(client: fakeClient('{"elements": []}'));
    final r = await s.nearby(3.139, 101.6869);
    expect(r.ok, isTrue);
    expect(r.value, isEmpty);
  });

  test('HTTP 500 returns failed', () async {
    final s = PoiService(client: fakeClient('err', status: 500));
    final r = await s.nearby(3.139, 101.6869);
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = PoiService(client: fakeClient('nope'));
    final r = await s.nearby(3.139, 101.6869);
    expect(r.ok, isFalse);
  });

  group('evChargers', () {
    test('without a key returns failed with a clear message', () async {
      final s = PoiService(client: fakeClient('[]'), ocmKey: '');
      final r = await s.evChargers(3.139, 101.6869);
      expect(r.ok, isFalse);
      expect(r.message, 'EV lookup needs a key');
    });

    test('parses chargers when a key is present', () async {
      const payload = '''
      [{"id": 1, "latitude": 3.14, "longitude": 101.69,
        "title": "KLCC Charger", "connections": [{"powerKW": 22.0}],
        "statusType": {"title": "Available"}}]
      ''';
      http.Request? seen;
      final s = PoiService(
        client: fakeClient(payload, onRequest: (r) => seen = r),
        ocmKey: 'test-key',
      );
      final r = await s.evChargers(3.139, 101.6869);
      expect(r.ok, isTrue);
      expect(r.value!.single.name, 'KLCC Charger');
      expect(r.value!.single.maxKw, 22);
      expect(r.value!.single.status, 'Available');
      expect(seen!.url.queryParameters['key'], 'test-key');
    });

    test('HTTP 500 returns failed', () async {
      final s = PoiService(client: fakeClient('err', status: 500), ocmKey: 'k');
      final r = await s.evChargers(3.139, 101.6869);
      expect(r.ok, isFalse);
    });

    test('malformed JSON returns failed', () async {
      final s = PoiService(client: fakeClient('nope'), ocmKey: 'k');
      final r = await s.evChargers(3.139, 101.6869);
      expect(r.ok, isFalse);
    });
  });
}
