import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// A single Rainviewer radar frame: the tile host plus the frame path.
class RadarFrame {
  final String host;
  final String path;
  final DateTime at;

  const RadarFrame({required this.host, required this.path, required this.at});

  /// Builds a Rainviewer tile URL for the given zoom/sl tile.
  String tileUrl({int z = 6, int x = 50, int y = 32, int size = 256}) =>
      '$host$path/$size/$z/$x/$y/2/1_1.png';

  Map<String, dynamic> toJson() => {
        'host': host,
        'path': path,
        'at': at.toIso8601String(),
      };

  factory RadarFrame.fromJson(Map<String, dynamic> j) => RadarFrame(
        host: j['host'] as String? ?? '',
        path: j['path'] as String? ?? '',
        at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Rainviewer public weather-maps feed.
/// https://www.rainviewer.com/api.html
class RadarService {
  final ApiClient _api;
  final DiskCache _cache;

  RadarService({ApiClient? client, DiskCache? cache})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache();

  Future<Fetch<RadarFrame>> latest() {
    return cachedRead<RadarFrame>(
      cache: _cache,
      key: 'radar.latest',
      ttl: const Duration(minutes: 10),
      encode: (v) => v.toJson(),
      decode: RadarFrame.fromJson,
      remote: () async {
        final uri = Uri.parse('https://api.rainviewer.com/public/weather-maps.json');
        final j = ApiClient.asObject(await _api.get(uri), 'Radar');
        final host = text(j['host']);
        if (host == null) throw ApiException('Radar: no host in payload');
        final radar = obj(j['radar']);
        final past = arr(radar['past']);
        final nowcast = arr(radar['nowcast']);
        final frames = [...past, ...nowcast];
        if (frames.isEmpty) throw ApiException('Radar: no frames available');
        Map<String, dynamic>? newest;
        DateTime? newestAt;
        for (final f in frames) {
          final m = obj(f);
          final path = text(m['path']);
          final at = when(m['time']);
          if (path == null || at == null) continue;
          if (newestAt == null || at.isAfter(newestAt)) {
            newestAt = at;
            newest = m;
          }
        }
        if (newest == null || newestAt == null) {
          throw ApiException('Radar: no usable frames');
        }
        return RadarFrame(
          host: host,
          path: text(newest['path'])!,
          at: newestAt,
        );
      },
    );
  }
}
