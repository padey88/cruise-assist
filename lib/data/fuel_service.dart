import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// Malaysia weekly retail fuel prices from the open data catalogue.
/// https://developer.data.gov.my/static-api/data-catalogue
class FuelService {
  final ApiClient _api;
  final DiskCache _cache;

  FuelService({ApiClient? client, DiskCache? cache})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache();

  Future<Fetch<FuelPrices>> latest() {
    return cachedRead<FuelPrices>(
      cache: _cache,
      key: 'fuel.latest',
      ttl: const Duration(hours: 12),
      encode: (v) => v.toJson(),
      decode: FuelPrices.fromJson,
      remote: () async {
        final uri = Uri.https('api.data.gov.my', '/data-catalogue', {
          'id': 'fuelprice',
          // Newest first: without sort the catalogue returns oldest-first.
          'sort': '-date',
          'limit': '40',
        });
        // data.gov.my returns 406 to Accept: application/json.
        final res = await _api.get(uri, headers: {'Accept': '*/*'});
        final rows = ApiClient.asList(res, 'Fuel prices');
        if (rows.isEmpty) throw ApiException('Fuel prices: empty dataset');
        Map<String, dynamic>? newest;
        DateTime? newestDate;
        for (final row in rows) {
          final r = obj(row);
          // Each date has a "level" row (the actual price) and a
          // "change_weekly" row (a delta) — only levels are prices.
          final series = text(r['series_type']);
          if (series != null && series != 'level') continue;
          final at = when(r['date']);
          if (at == null) continue;
          if (newestDate == null || at.isAfter(newestDate)) {
            newestDate = at;
            newest = r;
          }
        }
        if (newest == null || newestDate == null) {
          throw ApiException('Fuel prices: no dated rows');
        }
        return FuelPrices(
          ron95: dbl(newest['ron95']),
          ron97: dbl(newest['ron97']),
          diesel: dbl(newest['diesel']),
          effectiveFrom: newestDate,
        );
      },
    );
  }
}
