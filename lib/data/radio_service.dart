import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// Community-maintained Radio Browser directory (no account or key).
/// https://api.radio-browser.info/
class RadioService {
  final ApiClient _api;
  final DiskCache _cache;

  RadioService({ApiClient? client, DiskCache? cache})
    : _api = client ?? ApiClient(),
      _cache = cache ?? DiskCache();

  Future<Fetch<List<RadioStation>>> stations({
    String query = '',
    int limit = 30,
  }) {
    final q = query.trim();
    final count = limit.clamp(1, 100);
    return cachedRead<List<RadioStation>>(
      cache: _cache,
      key: 'radio.${q.toLowerCase()}.$count',
      ttl: const Duration(hours: 12),
      encode: (v) => {'stations': v.map((e) => e.toJson()).toList()},
      decode: (j) =>
          arr(j['stations'])
              .map((e) => RadioStation.fromJson(obj(e)))
              .toList(growable: false),
      remote: () async {
        final params = <String, String>{
          'country': q.isEmpty ? 'Malaysia' : '',
          if (q.isNotEmpty) 'name': q,
          'limit': count.toString(),
          'hidebroken': 'true',
          'order': 'votes',
          'reverse': 'true',
        };
        final uri = Uri.https(
          'de1.api.radio-browser.info',
          '/json/stations/search',
          params,
        );
        final rows = ApiClient.asList(await _api.get(uri), 'Radio stations');
        final seen = <String>{};
        final out = <RadioStation>[];
        for (final row in rows) {
          final r = obj(row);
          final url = text(r['url_resolved']) ?? text(r['url']);
          final name = text(r['name']);
          if (url == null || name == null || !seen.add(url)) continue;
          out.add(
            RadioStation(
              id: text(r['stationuuid']) ?? url,
              name: name,
              url: url,
              favicon: text(r['favicon']),
            ),
          );
        }
        return out;
      },
    );
  }
}
