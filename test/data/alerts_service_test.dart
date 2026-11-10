import 'package:cruise_assist/data/alerts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const usgsPayload = '''
{
  "type": "FeatureCollection",
  "metadata": {"count": 2},
  "features": [
    {"type": "Feature",
     "properties": {"mag": 4.8, "place": "20 km S of Kota Kinabalu, Malaysia",
       "title": "M 4.8 - 20 km S of Kota Kinabalu, Malaysia",
       "time": 1762776000000, "url": "https://example.com/a"},
     "geometry": {"coordinates": [116.07, 5.79, 10.0]}},
    {"type": "Feature",
     "properties": {"mag": 2.7, "place": "Some far place",
       "time": 1762770000000},
     "geometry": {"coordinates": [100.0, 3.0, 5.0]}}
  ]
}
''';

const metWarningPayload = '''
[
  {"warning_issue": {"issued": "2026-11-10T20:55:00",
     "title_en": "Strong Winds and Rough Seas Warning",
     "title_bm": "Amaran Angin Kencang dan Laut Bergelora"},
   "valid_from": "2026-11-09T00:00:00",
   "valid_to": "2026-11-12T23:59:59",
   "heading_en": "THIRD CATEGORY WARNING",
   "text_en": "Strong easterly winds of 40 - 50 kmph expected.",
   "instruction_en": "This condition is dangerous."}
]
''';

void main() {
  test('combines MET warnings and USGS earthquakes', () async {
    final router = ApiClientRouter({
      'api.data.gov.my/weather/warning': http.Response(metWarningPayload, 200),
      'api.data.gov.my/weather/warning/earthquake': http.Response('[]', 200),
      'earthquake.usgs.gov': http.Response(usgsPayload, 200),
    });
    final s = AlertsService(client: router.api);
    final r = await s.active(lat: 3.139, lng: 101.6869);
    expect(r.ok, isTrue);
    expect(r.value!.length, 3);
    final sources = r.value!.map((e) => e.source).toSet();
    expect(sources.contains('MET Malaysia'), isTrue);
    expect(sources.contains('USGS'), isTrue);
    final met = r.value!.firstWhere((e) => e.source == 'MET Malaysia');
    expect(met.title, 'Strong Winds and Rough Seas Warning');
    expect(met.body, contains('Strong easterly winds'));
    expect(met.at, isNotNull);
    final quake = r.value!.firstWhere((e) => e.source == 'USGS');
    expect(quake.severity, 'moderate');
    expect(quake.at, isNotNull);
    expect(quake.title, contains('M4.8'));
  });

  test('high-magnitude earthquake gets high severity', () async {
    const big = '''
    {"features": [{"properties": {"mag": 6.4, "place": "X", "time": 1},
      "geometry": {"coordinates": [1, 2, 3]}}]}
    ''';
    final router = ApiClientRouter({
      'api.data.gov.my': http.Response('[]', 200),
      'earthquake.usgs.gov': http.Response(big, 200),
    });
    final s = AlertsService(client: router.api);
    final r = await s.active();
    expect(r.value!.single.severity, 'high');
  });

  test('survives a failing MET source and still returns USGS', () async {
    final router = ApiClientRouter({
      'api.data.gov.my': http.Response('err', 500),
      'earthquake.usgs.gov': http.Response(usgsPayload, 200),
    });
    final s = AlertsService(client: router.api);
    final r = await s.active();
    expect(r.ok, isTrue);
    expect(r.value!.length, 2);
  });

  test('malformed USGS JSON returns failed', () async {
    final router = ApiClientRouter({
      'api.data.gov.my': http.Response('[]', 200),
      'earthquake.usgs.gov': http.Response('not json', 200),
    });
    final s = AlertsService(client: router.api);
    final r = await s.active();
    expect(r.ok, isFalse);
  });

  test('empty USGS feature list yields an empty list', () async {
    final router = ApiClientRouter({
      'api.data.gov.my': http.Response('[]', 200),
      'earthquake.usgs.gov': http.Response('{"features": []}', 200),
    });
    final s = AlertsService(client: router.api);
    final r = await s.active();
    expect(r.ok, isTrue);
    expect(r.value, isEmpty);
  });

  test('malformed MET payload does not break USGS parsing', () async {
    final router = ApiClientRouter({
      'api.data.gov.my': http.Response('garbage', 200),
      'earthquake.usgs.gov': http.Response(usgsPayload, 200),
    });
    final s = AlertsService(client: router.api);
    final r = await s.active();
    expect(r.ok, isTrue);
    expect(r.value!.length, 2);
  });
}
