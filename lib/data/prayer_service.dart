import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// AlAdhan timings, JAKIM method (17).
/// https://aladhan.com/prayer-times-api
class PrayerService {
  final ApiClient _api;
  final DiskCache _cache;

  PrayerService({ApiClient? client, DiskCache? cache})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache();

  /// JAKIM zone codes grouped by state/region.
  static const List<String> zones = [
    'JHR01', 'JHR02', 'JHR03', 'JHR04',
    'KDH01', 'KDH02', 'KDH03', 'KDH04', 'KDH05', 'KDH06', 'KDH07',
    'KTN01', 'KTN03',
    'MLK01',
    'NGS01', 'NGS02',
    'PHG01', 'PHG02', 'PHG03', 'PHG04', 'PHG05', 'PHG06',
    'PLS01',
    'PNG01',
    'PRK01', 'PRK02', 'PRK03', 'PRK04', 'PRK05', 'PRK06', 'PRK07',
    'SBH01', 'SBH02', 'SBH03', 'SBH04', 'SBH05', 'SBH06', 'SBH07', 'SBH08', 'SBH09',
    'SGR01', 'SGR02', 'SGR03',
    'SWK01', 'SWK02', 'SWK03', 'SWK04', 'SWK05', 'SWK06', 'SWK07', 'SWK08', 'SWK09',
    'TRG01', 'TRG02', 'TRG03', 'TRG04',
    'WLY01', 'WLY02',
  ];

  /// Approximate zone for a coordinate (nearest JAKIM zone reference point).
  static String zoneForLatLng(double lat, double lng) {
    if (lat < 0.5 || lat > 7.5 || lng < 99.0 || lng > 119.5) return 'WLY01';
    if (lng >= 115.0) {
      if (lat >= 5.9) return 'SBH05'; // Kota Kinabalu
      if (lat >= 5.3) return lng < 117.0 ? 'SBH09' : 'SBH03'; // Kudat/Sandakan
      if (lat >= 4.9) return lng < 117.2 ? 'SBH07' : 'SBH03'; // Beaufort/Sandakan
      if (lat >= 4.4) return lng < 117.4 ? 'SBH06' : 'SBH04'; // Tawau
      return 'SBH01'; // Sipitang / Lawas
    }
    if (lng >= 109.0) {
      if (lat < 2.0) return 'SWK09'; // Kuching / Samarahan
      if (lat < 2.9) return 'SWK03'; // Sri Aman / Sarikei
      if (lat < 3.4) return 'SWK04'; // Sibu / Mukah
      if (lat < 4.5) return lng < 113.9 ? 'SWK05' : 'SWK06'; // Bintulu / Miri
      return 'SWK07'; // Limbang / Lawas
    }
    if (lat < 2.2) return lng > 103.3 ? 'JHR02' : 'JHR01'; // Johor Bahru / Muar
    if (lat < 2.9) return 'MLK01';
    // Kuala Lumpur / Putrajaya have their own zone (WLY01).
    if (lat >= 2.85 && lat <= 3.30 && lng >= 101.55 && lng <= 101.85) {
      return 'WLY01';
    }
    if (lat < 3.6) return lng < 101.6 ? 'SGR02' : 'SGR01';
    if (lat < 4.8) return 'PRK03'; // Ipoh / Manjung
    if (lng > 103.2) {
      if (lat < 4.5) return 'PHG01'; // Pekan / Kuantan
      if (lat < 5.4) return 'TRG01';
      if (lat < 6.3) return 'KTN01';
      return 'KTN03';
    }
    if (lat < 5.5) return lng < 100.4 ? 'PNG01' : 'PRK01';
    if (lat < 6.4) return lng > 100.2 ? 'KDH02' : 'KDH01';
    return 'PLS01';
  }

  static const Map<String, List<double>> zonePoints = {
    'WLY01': [3.139, 101.6869],
    'WLY02': [5.329, 116.194],
    'SGR01': [3.0738, 101.5183],
    'SGR02': [3.3404, 101.2520],
    'SGR03': [3.2330, 101.7000],
    'JHR01': [2.0496, 102.5889],
    'JHR02': [1.4927, 103.7414],
    'JHR03': [1.8542, 102.9325],
    'JHR04': [2.0310, 103.3180],
    'MLK01': [2.1960, 102.2500],
    'NGS01': [2.7297, 101.9381],
    'NGS02': [2.7000, 102.1500],
    'PHG01': [3.8077, 103.3260],
    'PHG02': [3.4833, 102.4000],
    'PHG03': [3.5333, 101.9167],
    'PHG04': [3.8000, 102.2500],
    'PHG05': [3.4667, 102.4167],
    'PHG06': [3.4500, 102.4167],
    'TRG01': [5.3302, 103.1408],
    'TRG02': [5.0500, 102.8500],
    'TRG03': [5.1000, 103.0500],
    'TRG04': [5.6000, 102.6000],
    'KTN01': [6.1254, 102.2386],
    'KTN03': [5.9167, 101.9667],
    'KDH01': [6.1167, 100.3667],
    'KDH02': [6.1210, 100.3601],
    'KDH03': [5.9167, 100.5000],
    'KDH04': [5.6500, 100.5000],
    'KDH05': [5.8333, 100.5500],
    'KDH06': [5.8333, 100.8500],
    'KDH07': [6.3333, 100.2500],
    'PLS01': [6.4414, 100.1986],
    'PNG01': [5.4141, 100.3288],
    'PRK01': [5.4167, 100.7000],
    'PRK02': [5.0000, 100.9500],
    'PRK03': [4.5972, 101.0901],
    'PRK04': [4.8500, 100.7500],
    'PRK05': [4.2000, 100.6500],
    'PRK06': [4.0500, 100.9000],
    'PRK07': [4.7500, 100.9500],
    'SBH01': [5.0833, 115.5500],
    'SBH02': [5.7333, 116.1000],
    'SBH03': [5.8402, 118.1179],
    'SBH04': [4.2500, 117.8900],
    'SBH05': [5.9749, 116.0724],
    'SBH06': [4.4833, 118.6167],
    'SBH07': [5.0333, 116.0833],
    'SBH08': [6.8833, 116.8333],
    'SBH09': [5.7167, 115.9333],
    'SWK01': [2.3000, 111.8167],
    'SWK02': [2.0000, 112.5000],
    'SWK03': [2.1310, 111.5237],
    'SWK04': [2.2870, 111.8320],
    'SWK05': [3.1667, 113.0333],
    'SWK06': [4.3995, 113.9914],
    'SWK07': [4.7500, 115.0000],
    'SWK08': [3.8000, 114.0000],
    'SWK09': [1.5535, 110.3593],
  };

  Future<Fetch<PrayerDay>> day({required String zone, required DateTime date}) {
    final z = zone.toUpperCase().trim();
    final points = zonePoints[z] ?? zonePoints['WLY01']!;
    return dayAt(lat: points[0], lng: points[1], zone: z, date: date);
  }

  /// Coordinate-based variant used by [zoneForLatLng] callers.
  Future<Fetch<PrayerDay>> dayAt({
    required double lat,
    required double lng,
    required DateTime date,
    String zone = '',
  }) {
    final d = DateTime(date.year, date.month, date.day);
    final label = zone.isEmpty ? zoneForLatLng(lat, lng) : zone;
    return cachedRead<PrayerDay>(
      cache: _cache,
      key: 'prayer.$label.${d.toIso8601String().substring(0, 10)}',
      ttl: const Duration(hours: 6),
      encode: (v) => v.toJson(),
      decode: PrayerDay.fromJson,
      remote: () async {
        final stamp = '${d.day.toString().padLeft(2, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-${d.year}';
        final uri = Uri.https('api.aladhan.com', '/v1/timings/$stamp', {
          'latitude': lat.toString(),
          'longitude': lng.toString(),
          'method': '17',
        });
        final j = ApiClient.asObject(await _api.get(uri), 'Prayer times');
        if (j['code'] != 200) {
          throw ApiException('Prayer times: ${j['status'] ?? 'bad response'}');
        }
        final data = obj(j['data']);
        final timings = obj(data['timings']);
        if (timings.isEmpty) throw ApiException('Prayer times: empty timings');
        const names = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
        final times = <PrayerTime>[];
        for (final name in names) {
          final raw = text(timings[name]);
          if (raw == null) continue;
          final clean = raw.split(' ').first;
          final parts = clean.split(':');
          if (parts.length < 2) continue;
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h == null || m == null) continue;
          times.add(PrayerTime(
              name, DateTime(d.year, d.month, d.day, h, m)));
        }
        if (times.isEmpty) {
          throw ApiException('Prayer times: could not parse timings');
        }
        return PrayerDay(date: d, zone: label, times: times);
      },
    );
  }
}
