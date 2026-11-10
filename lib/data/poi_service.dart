import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// OpenStreetMap Overpass POIs and OpenChargeMap chargers.
/// https://dev.overpass-api.de/overpass-doc/en/ and https://openchargemap.org/site/develop/api
class PoiService {
  final ApiClient _api;
  final DiskCache _cache;
  final String _ocmKey;

  PoiService({ApiClient? client, DiskCache? cache, String? ocmKey})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache(),
        _ocmKey = ocmKey ?? const String.fromEnvironment('OCM_KEY');

  Future<Fetch<List<Place>>> nearby(double lat, double lng,
      {double radiusM = 3000, List<String> kinds = const ['fuel', 'parking']}) {
    final requested = kinds.isEmpty ? const ['fuel', 'parking'] : kinds;
    return cachedRead<List<Place>>(
      cache: _cache,
      key: 'poi.${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)},'
          '${radiusM.round()},${requested.join(',')}',
      ttl: const Duration(hours: 24),
      encode: (v) => {'places': v.map((e) => e.toJson()).toList()},
      decode: (j) => arr(j['places'])
          .map((e) => Place.fromJson(obj(e)))
          .toList(growable: false),
      remote: () async {
        final selectors = <String>[];
        for (final kind in requested) {
          final tag = _tagFor(kind);
          if (tag == null) continue;
          selectors.add('nwr[$tag](around:${radiusM.round()},$lat,$lng);');
        }
        if (selectors.isEmpty) return <Place>[];
        final query = '[out:json][timeout:20];(${selectors.join()});out center tags;';
        final res = await _api.post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'data=${Uri.encodeQueryComponent(query)}',
        );
        final j = ApiClient.asObject(res, 'Nearby places');
        final out = <Place>[];
        for (final element in arr(j['elements'])) {
          final e = obj(element);
          final center = obj(e['center']);
          final plat = dbl(e['lat']) ?? dbl(center['lat']);
          final plng = dbl(e['lon']) ?? dbl(center['lon']);
          if (plat == null || plng == null) continue;
          final tags = obj(e['tags']);
          final kind = _kindOf(tags);
          out.add(Place(
            name: text(tags['name']) ??
                text(tags['operator']) ??
                text(tags['brand']) ??
                _label(kind),
            kind: kind,
            lat: plat,
            lng: plng,
            distanceM: haversineM(lat, lng, plat, plng),
          ));
        }
        out.sort((a, b) =>
            (a.distanceM ?? 0).compareTo(b.distanceM ?? 0));
        return out;
      },
    );
  }

  Future<Fetch<List<EvCharger>>> evChargers(double lat, double lng,
      {double radiusM = 5000}) {
    return cachedRead<List<EvCharger>>(
      cache: _cache,
      key: 'ev.${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)},${radiusM.round()}',
      ttl: const Duration(hours: 6),
      encode: (v) => {'chargers': v.map((e) => e.toJson()).toList()},
      decode: (j) => arr(j['chargers'])
          .map((e) => EvCharger.fromJson(obj(e)))
          .toList(growable: false),
      remote: () async {
        if (_ocmKey.trim().isEmpty) {
          throw ApiException('EV lookup needs a key');
        }
        final uri = Uri.https('api.openchargemap.io', '/v3/poi', {
          'output': 'json',
          'latitude': lat.toString(),
          'longitude': lng.toString(),
          'distance': (radiusM / 1000).toStringAsFixed(2),
          'distanceunit': 'KM',
          'maxresults': '100',
          'compact': 'true',
          'verbose': 'false',
          'key': _ocmKey,
        });
        final rows = ApiClient.asList(await _api.get(uri), 'EV chargers');
        final out = <EvCharger>[];
        for (final row in rows) {
          final r = obj(row);
          final address = obj(r['addressInfo'] ?? r['AddressInfo']);
          final plat = dbl(r['latitude'] ?? r['Latitude'] ?? address['latitude'] ?? address['Latitude']);
          final plng = dbl(r['longitude'] ?? r['Longitude'] ?? address['longitude'] ?? address['Longitude']);
          if (plat == null || plng == null) continue;
          double? maxKw;
          for (final c in arr(r['connections'] ?? r['Connections'])) {
            final kw = dbl(obj(c)['powerKW'] ?? obj(c)['PowerKW']);
            if (kw != null && kw > (maxKw ?? 0)) maxKw = kw;
          }
          final status = obj(r['statusType'] ?? r['StatusType']);
          out.add(EvCharger(
            name: text(r['title'] ?? r['Title'] ?? address['title'] ?? address['Title']) ??
                'EV charger',
            lat: plat,
            lng: plng,
            maxKw: maxKw?.round(),
            status: text(status['title'] ?? status['Title']),
          ));
        }
        return out;
      },
    );
  }

  String? _tagFor(String kind) {
    switch (kind.toLowerCase()) {
      case 'fuel':
      case 'petrol':
        return '"amenity"="fuel"';
      case 'parking':
        return '"amenity"="parking"';
      case 'ev':
      case 'charging':
      case 'charging_station':
        return '"amenity"="charging_station"';
      default:
        return null;
    }
  }

  String _kindOf(Map<String, dynamic> tags) {
    switch (tags['amenity']) {
      case 'fuel':
        return 'fuel';
      case 'parking':
        return 'parking';
      case 'charging_station':
        return 'ev';
    }
    return 'poi';
  }

  String _label(String kind) {
    switch (kind) {
      case 'fuel':
        return 'Petrol station';
      case 'parking':
        return 'Parking';
      case 'ev':
        return 'EV charging station';
    }
    return 'Place';
  }
}
