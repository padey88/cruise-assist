import 'package:cruise_assist/data/sports_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const espnPayload = '''
{
  "leagues": [{"name": "English Premier League"}],
  "events": [
    {"id": "401879244", "date": "2026-11-08T14:00Z",
     "competitions": [
       {"status": {"type": {"detail": "FT"}},
        "competitors": [
          {"homeAway": "home", "score": "2",
           "team": {"displayName": "Brighton & Hove Albion"}},
          {"homeAway": "away", "score": "1",
           "team": {"displayName": "Brentford"}}
        ]}
     ]}
  ]
}
''';

void main() {
  test('parses teams, scores and status', () async {
    final s = SportsService(client: fakeClient(espnPayload));
    final r = await s.scoreboard();
    expect(r.ok, isTrue);
    expect(r.value!.single.league, 'English Premier League');
    expect(r.value!.single.home, 'Brighton & Hove Albion');
    expect(r.value!.single.away, 'Brentford');
    expect(r.value!.single.homeScore, '2');
    expect(r.value!.single.awayScore, '1');
    expect(r.value!.single.status, 'FT');
    expect(r.value!.single.kickoff, isNotNull);
  });

  test('sends the requested league in the path', () async {
    http.Request? seen;
    final s = SportsService(
      client: fakeClient(espnPayload, onRequest: (r) => seen = r),
    );
    await s.scoreboard(league: 'esp.1');
    expect(seen!.url.path, contains('/soccer/esp.1/scoreboard'));
  });

  test('tolerates missing fields', () async {
    const payload = '{"leagues": [], "events": [{"competitions": []}]}';
    final s = SportsService(client: fakeClient(payload));
    final r = await s.scoreboard();
    expect(r.ok, isTrue);
    expect(r.value!.single.home, '');
    expect(r.value!.single.away, '');
    expect(r.value!.single.homeScore, isNull);
    expect(r.value!.single.status, '');
  });

  test('empty events yields an empty list', () async {
    final s = SportsService(client: fakeClient('{"events": []}'));
    final r = await s.scoreboard();
    expect(r.ok, isTrue);
    expect(r.value, isEmpty);
  });

  test('HTTP 500 returns failed', () async {
    final s = SportsService(client: fakeClient('err', status: 500));
    final r = await s.scoreboard();
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = SportsService(client: fakeClient('nope'));
    final r = await s.scoreboard();
    expect(r.ok, isFalse);
  });
}
