import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// ESPN public soccer scoreboards. Tolerates partial competitions and scores.
class SportsService {
  final ApiClient _api;
  final DiskCache _cache;

  SportsService({ApiClient? client, DiskCache? cache})
    : _api = client ?? ApiClient(),
      _cache = cache ?? DiskCache();

  Future<Fetch<List<SportEvent>>> scoreboard({String league = 'eng.1'}) {
    return cachedRead<List<SportEvent>>(
      cache: _cache,
      key: 'sports.${league.toLowerCase()}',
      ttl: const Duration(minutes: 5),
      encode: (v) => {'events': v.map((e) => e.toJson()).toList()},
      decode: (j) =>
          arr(j['events'])
              .map((e) => SportEvent.fromJson(obj(e)))
              .toList(growable: false),
      remote: () async {
        final uri = Uri.https(
          'site.api.espn.com',
          '/apis/site/v2/sports/soccer/$league/scoreboard',
        );
        final res = await _api.get(
          uri,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/125.0 Safari/537.36',
          },
        );
        final j = ApiClient.asObject(res, 'Sports scoreboard');
        final leagueName =
            text(obj(firstOrNull(arr(j['leagues'])))['name']) ?? league;
        final out = <SportEvent>[];
        for (final event in arr(j['events'])) {
          final e = obj(event);
          final comp = obj(firstOrNull(arr(e['competitions'])));
          var home = '';
          var away = '';
          String? homeScore;
          String? awayScore;
          for (final competitor in arr(comp['competitors'])) {
            final c = obj(competitor);
            final team = obj(c['team']);
            final name =
                text(team['displayName']) ??
                text(team['name']) ??
                text(team['shortDisplayName']) ??
                text(team['abbreviation']) ??
                '';
            if (c['homeAway'] == 'home') {
              home = name;
              homeScore = text(c['score']);
            } else if (c['homeAway'] == 'away') {
              away = name;
              awayScore = text(c['score']);
            }
          }
          final status = obj(
            obj(comp.isEmpty ? e['status'] : comp['status'])['type'],
          );
          out.add(
            SportEvent(
              league: leagueName,
              home: home,
              away: away,
              homeScore: homeScore,
              awayScore: awayScore,
              kickoff: when(e['date']) ?? when(comp['date']),
              status:
                  text(status['detail']) ??
                  text(status['shortDetail']) ??
                  text(status['description']) ??
                  text(status['state']) ??
                  '',
            ),
          );
        }
        return out;
      },
    );
  }
}
