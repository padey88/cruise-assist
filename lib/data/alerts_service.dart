import 'dart:convert';

import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// Malaysian MET warnings plus the global USGS 2.5+ daily earthquake feed.
class AlertsService {
  final ApiClient _api;
  final DiskCache _cache;

  AlertsService({ApiClient? client, DiskCache? cache})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache();

  Future<Fetch<List<Alert>>> active({double? lat, double? lng}) {
    return cachedRead<List<Alert>>(
      cache: _cache,
      key: 'alerts.active',
      ttl: const Duration(minutes: 15),
      encode: (v) => {'alerts': v.map((e) => e.toJson()).toList()},
      decode: (j) => arr(j['alerts'])
          .map((e) => Alert.fromJson(obj(e)))
          .toList(growable: false),
      remote: () async {
        final results = await Future.wait([
          _malaysia('warning'),
          _malaysia('warning/earthquake'),
          _usgs(lat, lng),
        ]);
        final out = <Alert>[];
        for (final group in results) {
          out.addAll(group);
        }
        return out;
      },
    );
  }

  Future<List<Alert>> _malaysia(String path) async {
    try {
      final res = await _api.get(
        Uri.https('api.data.gov.my', '/weather/$path'),
        headers: {'Accept': '*/*'},
      );
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final out = <Alert>[];
      _flattenMalaysia(decoded, out, path.contains('earthquake'));
      return out;
    } catch (_) {
      return const []; // USGS is an independent source.
    }
  }

  void _flattenMalaysia(Object? value, List<Alert> out, bool earthquake) {
    if (value is List) {
      for (final e in value) {
        _flattenMalaysia(e, out, earthquake);
      }
      return;
    }
    if (value is! Map) return;
    final j = value.map((k, v) => MapEntry(k.toString(), v));

    // MET warning shape:
    // {"warning_issue": {"issued": ..., "title_en": ...},
    //  "valid_from": ..., "valid_to": ..., "heading_en": ..., "text_en": ...}
    final issue = obj(j['warning_issue']);
    final title = text(issue['title_en']) ??
        text(issue['title_bm']) ??
        text(j['title_en']) ??
        text(j['heading_en']) ??
        text(j['title']) ??
        text(j['warning']) ??
        text(j['description']) ??
        text(j['summary']);
    if (title != null) {
      final body = text(j['text_en']) ??
          text(j['text']) ??
          text(j['description']) ??
          text(j['heading_en']);
      out.add(Alert(
        title: title,
        body: body == title ? null : body,
        severity: text(j['severity']) ??
            text(j['level']) ??
            text(j['status']) ??
            text(j['category']),
        at: when(issue['issued']) ??
            when(j['valid_from']) ??
            when(j['datetime']) ??
            when(j['time']) ??
            when(j['date']),
        source: earthquake ? 'MET Malaysia earthquake' : 'MET Malaysia',
      ));
      return;
    }
    for (final v in j.values) {
      if (v is Map || v is List) _flattenMalaysia(v, out, earthquake);
    }
  }

  Future<List<Alert>> _usgs(double? lat, double? lng) async {
    final uri = Uri.parse(
        'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson');
    final j = ApiClient.asObject(await _api.get(uri), 'USGS earthquakes');
    final out = <Alert>[];
    for (final feature in arr(j['features'])) {
      final f = obj(feature);
      final p = obj(f['properties']);
      final mag = dbl(p['mag']);
      final place = text(p['place']) ?? 'Unknown location';
      final geometry = obj(f['geometry']);
      final coords = arr(geometry['coordinates']);
      var distance = '';
      if (lat != null && lng != null && coords.length >= 2) {
        final qlon = dbl(coords[0]);
        final qlat = dbl(coords[1]);
        if (qlat != null && qlon != null) {
          distance = ' (${(haversineM(lat, lng, qlat, qlon) / 1000).round()} km away)';
        }
      }
      out.add(Alert(
        title: 'M${mag?.toStringAsFixed(1) ?? '?'} earthquake — $place',
        body: '${text(p['title']) ?? place}$distance',
        severity: mag == null
            ? null
            : mag >= 6
                ? 'high'
                : mag >= 4.5
                    ? 'moderate'
                    : 'low',
        at: when(p['time']),
        source: 'USGS',
      ));
    }
    return out;
  }
}
