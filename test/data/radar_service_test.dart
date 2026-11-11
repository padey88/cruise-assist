import 'package:cruise_assist/data/radar_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const radarPayload = '''
{
  "host": "https://tilecache.rainviewer.com",
  "radar": {
    "past": [
      {"time": 1762776000, "path": "/v2/radar/1762773000"},
      {"time": 1762779000, "path": "/v2/radar/1762776000"}
    ],
    "nowcast": [
      {"time": 1762780000, "path": "/v2/radar/1762779000"}
    ]
  }
}
''';

void main() {
  test('returns the newest frame and builds a tile URL', () async {
    final s = RadarService(client: fakeClient(radarPayload));
    final r = await s.latest();
    expect(r.ok, isTrue);
    expect(r.value!.host, 'https://tilecache.rainviewer.com');
    expect(r.value!.path, '/v2/radar/1762779000');
    expect(r.value!.at, DateTime.fromMillisecondsSinceEpoch(1762780000 * 1000));
    expect(
      r.value!.tileUrl(),
      'https://tilecache.rainviewer.com/v2/radar/1762779000/256/6/50/32/2/1_1.png',
    );
  });

  test('tileUrl accepts zoom and tile coordinates', () async {
    final s = RadarService(client: fakeClient(radarPayload));
    final r = await s.latest();
    expect(
      r.value!.tileUrl(z: 10, x: 800, y: 600),
      'https://tilecache.rainviewer.com/v2/radar/1762779000/256/10/800/600/2/1_1.png',
    );
  });

  test('HTTP 500 returns failed', () async {
    final s = RadarService(client: fakeClient('err', status: 500));
    final r = await s.latest();
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = RadarService(client: fakeClient('nope'));
    final r = await s.latest();
    expect(r.ok, isFalse);
  });

  test('missing host returns failed', () async {
    final s = RadarService(client: fakeClient('{"radar": {"past": []}}'));
    final r = await s.latest();
    expect(r.ok, isFalse);
    expect(r.message, contains('host'));
  });

  test('empty radar frames return failed', () async {
    final s = RadarService(
      client: fakeClient('{"host": "https://x", "radar": {"past": []}}'),
    );
    final r = await s.latest();
    expect(r.ok, isFalse);
    expect(r.message, contains('no frames'));
  });

  test('falls back to nowcast frames when past is empty', () async {
    const payload = '''
    {"host": "https://tilecache.rainviewer.com",
     "radar": {"past": [], "nowcast": [
       {"time": 1762780000, "path": "/v2/radar/now"}]}}
    ''';
    final s = RadarService(client: fakeClient(payload));
    final r = await s.latest();
    expect(r.ok, isTrue);
    expect(r.value!.path, '/v2/radar/now');
  });
}
