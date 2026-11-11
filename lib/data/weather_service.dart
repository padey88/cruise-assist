import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// Open-Meteo forecast + air quality. No API key required.
/// https://open-meteo.com/en/docs and https://open-meteo.com/en/docs/air-quality-api
class WeatherService {
  final ApiClient _api;
  final DiskCache _cache;

  WeatherService({ApiClient? client, DiskCache? cache})
    : _api = client ?? ApiClient(),
      _cache = cache ?? DiskCache();

  static String _n(double v) => v.toStringAsFixed(5);

  String _key(String kind, double lat, double lng) =>
      'weather.$kind.${_n(lat)},${_n(lng)}';

  Future<Fetch<WeatherNow>> current(double lat, double lng) {
    return cachedRead<WeatherNow>(
      cache: _cache,
      key: _key('current', lat, lng),
      ttl: const Duration(minutes: 15),
      encode: (v) => v.toJson(),
      decode: WeatherNow.fromJson,
      remote: () async {
        final j = await _get(_uri(lat, lng, 1));
        return _parseNow(
          obj(j['current']),
          arr(obj(j['daily'])['sunrise']),
          arr(obj(j['daily'])['sunset']),
        );
      },
    );
  }

  Future<Fetch<List<DayForecast>>> forecast(
    double lat,
    double lng, {
    int days = 7,
  }) {
    final n = days.clamp(1, 16);
    return cachedRead<List<DayForecast>>(
      cache: _cache,
      key: _key('forecast$n', lat, lng),
      ttl: const Duration(hours: 1),
      encode: (v) => {'days': v.map((e) => e.toJson()).toList()},
      decode: (j) =>
          arr(j['days'])
              .map((e) => DayForecast.fromJson(obj(e)))
              .toList(growable: false),
      remote: () async {
        final j = await _get(_uri(lat, lng, n));
        return _parseForecast(obj(j['daily']));
      },
    );
  }

  Future<Fetch<AirQuality>> air(double lat, double lng) {
    return cachedRead<AirQuality>(
      cache: _cache,
      key: _key('air', lat, lng),
      ttl: const Duration(minutes: 30),
      encode: (v) => v.toJson(),
      decode: AirQuality.fromJson,
      remote: () async {
        final uri = Uri.https(
          'air-quality-api.open-meteo.com',
          '/v1/air-quality',
          <String, String>{
            'latitude': lat.toString(),
            'longitude': lng.toString(),
            'current': 'us_aqi,pm2_5',
          },
        );
        final j = ApiClient.asObject(await _api.get(uri), 'Air quality');
        final c = obj(j['current']);
        return AirQuality(
          usAqi: integer(c['us_aqi']) ?? 0,
          pm25: dbl(c['pm2_5']),
          observedAt: when(c['time']) ?? DateTime.now(),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async =>
      ApiClient.asObject(await _api.get(uri), 'Weather');

  Uri _uri(double lat, double lng, int days) =>
      Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,sunrise,sunset',
        'timezone': 'auto',
        'forecast_days': days.toString(),
      });

  WeatherNow _parseNow(
    Map<String, dynamic> c,
    List<dynamic> rises,
    List<dynamic> sets,
  ) {
    if (c.isEmpty) throw ApiException('Weather: empty current block');
    return WeatherNow(
      tempC: dbl(c['temperature_2m']) ?? 0,
      feelsC: dbl(c['apparent_temperature']) ?? 0,
      humidity: integer(c['relative_humidity_2m']) ?? 0,
      windKph: dbl(c['wind_speed_10m']) ?? 0,
      weatherCode: integer(c['weather_code']) ?? 0,
      observedAt: when(c['time']) ?? DateTime.now(),
      sunrise: rises.isEmpty ? null : when(rises.first),
      sunset: sets.isEmpty ? null : when(sets.first),
    );
  }

  List<DayForecast> _parseForecast(Map<String, dynamic> d) {
    final days = arr(d['time']);
    final out = <DayForecast>[];
    for (var i = 0; i < days.length; i++) {
      final at = when(days[i]);
      if (at == null) continue;
      out.add(
        DayForecast(
          day: at,
          code: integer(atOrNull(arr(d['weather_code']), i)) ?? 0,
          minC: dbl(atOrNull(arr(d['temperature_2m_min']), i)) ?? 0,
          maxC: dbl(atOrNull(arr(d['temperature_2m_max']), i)) ?? 0,
          rainMm: dbl(atOrNull(arr(d['precipitation_sum']), i)),
        ),
      );
    }
    return out;
  }
}
