import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// Nominatim reverse geocoding. ApiClient supplies a real User-Agent and
/// enforces the service's one-request-per-second spacing.
/// https://nominatim.org/release-docs/latest/api/Reverse/
class GeocodeService {
  final ApiClient _api;
  final DiskCache _cache;

  GeocodeService({ApiClient? client, DiskCache? cache})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache();

  Future<Fetch<String>> reverse(double lat, double lng) {
    return cachedRead<String>(
      cache: _cache,
      key: 'geocode.${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}',
      ttl: const Duration(days: 7),
      encode: (v) => {'name': v},
      decode: (j) => text(j['name']) ?? 'Unknown place',
      remote: () async {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'jsonv2',
          'lat': lat.toString(),
          'lon': lng.toString(),
          'zoom': '16',
        });
        final j = ApiClient.asObject(await _api.get(uri), 'Reverse geocode');
        final a = obj(j['address']);
        final locality = text(a['city']) ??
            text(a['town']) ??
            text(a['village']) ??
            text(a['municipality']) ??
            text(a['county']);
        final state = text(a['state']);
        final name = locality != null && state != null && locality != state
            ? '$locality, $state'
            : locality ?? text(j['name']) ?? text(j['display_name']);
        if (name == null) {
          throw ApiException('Reverse geocode: place not found');
        }
        return name;
      },
    );
  }
}
