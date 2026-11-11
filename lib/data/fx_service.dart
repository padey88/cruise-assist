import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// MYR foreign exchange rates. BNM is primary, open.er-api.com is fallback.
/// https://apikijangportal.bnm.gov.my/ and https://www.exchangerate-api.com/
class FxService {
  final ApiClient _api;
  final DiskCache _cache;

  FxService({ApiClient? client, DiskCache? cache})
    : _api = client ?? ApiClient(),
      _cache = cache ?? DiskCache();

  static const wanted = [
    'USD',
    'SGD',
    'EUR',
    'GBP',
    'JPY',
    'IDR',
    'THB',
    'CNY',
    'AUD',
  ];

  Future<Fetch<List<FxRate>>> rates() {
    return cachedRead<List<FxRate>>(
      cache: _cache,
      key: 'fx.rates',
      ttl: const Duration(hours: 6),
      encode: (v) => {'rates': v.map((e) => e.toJson()).toList()},
      decode: (j) =>
          arr(j['rates'])
              .map((e) => FxRate.fromJson(obj(e)))
              .toList(growable: false),
      remote: () async {
        try {
          return await _bnm();
        } catch (_) {
          return _fallback();
        }
      },
    );
  }

  Future<List<FxRate>> _bnm() async {
    final uri = Uri.https('api.bnm.gov.my', '/public/exchange-rate', {
      'session': '0900',
      'quote': 'rm',
    });
    final res = await _api.get(
      uri,
      headers: {'Accept': 'application/vnd.BNM.API.v1+json'},
    );
    final j = ApiClient.asObject(res, 'BNM exchange rates');
    final out = <String, double>{};
    for (final row in arr(j['data'])) {
      final r = obj(row);
      final code = text(r['currency_code'])?.toUpperCase();
      if (code == null || !wanted.contains(code)) continue;
      final unit = dbl(r['unit']);
      final rate = dbl(obj(r['rate'])['middle_rate']);
      if (unit == null || unit == 0 || rate == null) continue;
      out[code] = rate / unit;
    }
    if (out.isEmpty) throw ApiException('BNM exchange rates: no usable rows');
    return [
      for (final c in wanted)
        if (out[c] != null) FxRate(c, out[c]!),
    ];
  }

  Future<List<FxRate>> _fallback() async {
    final uri = Uri.parse('https://open.er-api.com/v6/latest/MYR');
    final j = ApiClient.asObject(
      await _api.get(uri),
      'Fallback exchange rates',
    );
    final table = obj(j['rates']);
    final out = <FxRate>[];
    for (final code in wanted) {
      final perMyr = dbl(table[code]);
      if (perMyr != null && perMyr > 0) out.add(FxRate(code, 1 / perMyr));
    }
    if (out.isEmpty) throw ApiException('Fallback exchange rates: no rates');
    return out;
  }
}
