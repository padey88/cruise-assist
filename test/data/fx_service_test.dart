import 'dart:io';

import 'package:cruise_assist/data/cache.dart';
import 'package:cruise_assist/data/fx_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const bnmPayload = '''
{
  "data": [
    {"currency_code": "USD", "unit": 1,
     "rate": {"date": "2026-11-10", "middle_rate": 4.05}},
    {"currency_code": "JPY", "unit": 100,
     "rate": {"date": "2026-11-10", "middle_rate": 2.5666}},
    {"currency_code": "IDR", "unit": 100,
     "rate": {"date": "2026-11-10", "middle_rate": 0.0224}},
    {"currency_code": "SGD", "unit": 1,
     "rate": {"date": "2026-11-10", "middle_rate": 3.1754}},
    {"currency_code": "THB", "unit": 100,
     "rate": {"date": "2026-11-10", "middle_rate": 12.1591}},
    {"currency_code": "SDR", "unit": 1,
     "rate": {"date": "2026-11-10", "middle_rate": null}},
    {"currency_code": "ZZZ", "unit": 1,
     "rate": {"date": "2026-11-10", "middle_rate": 1.0}}
  ]
}
''';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cruise_fx');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  DiskCache cache() => DiskCache(directory: () async => tmp);

  test('parses BNM rates and divides by unit', () async {
    final s = FxService(client: fakeClient(bnmPayload));
    final r = await s.rates();
    expect(r.ok, isTrue);
    final rates = {for (final e in r.value!) e.code: e.myr};
    expect(rates['USD'], 4.05);
    expect(rates['JPY'], closeTo(0.025666, 1e-9));
    expect(rates['IDR'], closeTo(0.000224, 1e-9));
    expect(rates['THB'], closeTo(0.121591, 1e-9));
    expect(rates.containsKey('SDR'), isFalse);
    expect(rates.containsKey('ZZZ'), isFalse);
  });

  test('sends the BNM Accept header and session params', () async {
    http.Request? seen;
    final s = FxService(
      client: fakeClient(bnmPayload, onRequest: (r) => seen = r),
    );
    await s.rates();
    expect(seen!.headers['Accept'], 'application/vnd.BNM.API.v1+json');
    expect(seen!.url.queryParameters['quote'], 'rm');
    expect(seen!.url.queryParameters['session'], isNotNull);
  });

  test('falls back to open.er-api.com when BNM fails', () async {
    final client = ApiClientRouter({
      'api.bnm.gov.my': (http.Response('err', 500)),
      'open.er-api.com': (http.Response(
        '{"rates": {"USD": 0.25, "SGD": 0.31}}',
        200,
      )),
    });
    final s = FxService(client: client.api);
    final r = await s.rates();
    expect(r.ok, isTrue);
    final rates = {for (final e in r.value!) e.code: e.myr};
    expect(rates['USD'], closeTo(4.0, 1e-9));
    expect(rates['SGD'], closeTo(1 / 0.31, 1e-9));
  });

  test('HTTP 500 on both sources returns failed', () async {
    final client = ApiClientRouter({
      'api.bnm.gov.my': http.Response('err', 500),
      'open.er-api.com': http.Response('err', 500),
    });
    final s = FxService(client: client.api);
    final r = await s.rates();
    expect(r.ok, isFalse);
  });

  test('malformed JSON returns failed', () async {
    final client = ApiClientRouter({
      'api.bnm.gov.my': http.Response('bad', 200),
      'open.er-api.com': http.Response('bad', 200),
    });
    final s = FxService(client: client.api);
    final r = await s.rates();
    expect(r.ok, isFalse);
  });

  test('empty BNM data falls through to fallback', () async {
    final client = ApiClientRouter({
      'api.bnm.gov.my': http.Response('{"data": []}', 200),
      'open.er-api.com': http.Response('{"rates": {"EUR": 0.2}}', 200),
    });
    final s = FxService(client: client.api);
    final r = await s.rates();
    expect(r.ok, isTrue);
    expect(r.value!.single.code, 'EUR');
  });

  test('serves stale cached value after a failure', () async {
    final good = FxService(client: fakeClient(bnmPayload), cache: cache());
    await good.rates();
    final offline = FxService(client: failingClient(), cache: cache());
    final r = await offline.rates();
    expect(r.ok, isFalse);
    expect(r.stale, isTrue);
    expect(r.value!.length, 5);
  });
}
