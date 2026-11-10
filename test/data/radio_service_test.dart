import 'package:cruise_assist/data/radio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const radioPayload = '''
[
  {"stationuuid": "abc-123", "name": "RTM Klasik",
   "url_resolved": "https://stream.example.com/klasik", "url": "https://rtm.example.com",
   "favicon": "https://rtm.example.com/favicon.png"},
  {"stationuuid": "def-456", "name": "Nasional FM",
   "url_resolved": "https://stream.example.com/nasional",
   "favicon": null},
  {"stationuuid": "", "name": "", "url": ""}
]
''';

void main() {
  test('parses stations and skips entries without a url', () async {
    final s = RadioService(client: fakeClient(radioPayload));
    final r = await s.stations();
    expect(r.ok, isTrue);
    expect(r.value!.length, 2);
    expect(r.value!.first.id, 'abc-123');
    expect(r.value!.first.name, 'RTM Klasik');
    expect(r.value!.first.url, 'https://stream.example.com/klasik');
    expect(r.value!.first.favicon, isNotNull);
    expect(r.value!.last.favicon, isNull);
  });

  test('defaults to a Malaysian country search', () async {
    http.Request? seen;
    final s = RadioService(
        client: fakeClient(radioPayload, onRequest: (r) => seen = r));
    await s.stations();
    expect(seen!.url.queryParameters['country'], 'Malaysia');
    expect(seen!.url.queryParameters['limit'], '30');
  });

  test('uses a name search when a query is given', () async {
    http.Request? seen;
    final s = RadioService(
        client: fakeClient(radioPayload, onRequest: (r) => seen = r));
    await s.stations(query: 'Sinar', limit: 5);
    expect(seen!.url.queryParameters['name'], 'Sinar');
    expect(seen!.url.queryParameters['limit'], '5');
  });

  test('HTTP 500 returns failed', () async {
    final s = RadioService(client: fakeClient('err', status: 500));
    final r = await s.stations();
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = RadioService(client: fakeClient('nope'));
    final r = await s.stations();
    expect(r.ok, isFalse);
  });

  test('empty list yields an empty list', () async {
    final s = RadioService(client: fakeClient('[]'));
    final r = await s.stations();
    expect(r.ok, isTrue);
    expect(r.value, isEmpty);
  });
}
