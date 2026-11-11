import 'dart:async';

import '../models/result.dart';
import 'api.dart';
import 'cache.dart';

/// Shared read-through-cache plumbing so every service behaves the same:
/// success refreshes the cache, failure returns the last good payload with
/// `stale=true` and never throws.
const Duration defaultTtl = Duration(minutes: 10);

Future<Fetch<T>> cachedRead<T>({
  required DiskCache cache,
  required String key,
  required Future<T> Function() remote,
  required Map<String, dynamic> Function(T) encode,
  required T Function(Map<String, dynamic>) decode,
  Duration ttl = defaultTtl,
}) async {
  final now = DateTime.now();
  try {
    final fresh = await remote();
    final payload = <String, dynamic>{
      'at': now.toIso8601String(),
      'v': encode(fresh),
    };
    await cache.put(key, payload);
    return Fetch.success(fresh, now);
  } catch (e) {
    final cached = await _readCache(cache, key, decode);
    final msg = describeError(e);
    if (cached == null) return Fetch.failure(msg);
    final age = now.difference(cached.at);
    // Age is informational: anything served after a failure is stale.
    return Fetch.failure(
      age > ttl ? '$msg (cached ${_human(age)} old)' : msg,
      value: cached.value,
      at: cached.at,
    );
  }
}

class _Cached<T> {
  final T value;
  final DateTime at;
  _Cached(this.value, this.at);
}

Future<_Cached<T>?> _readCache<T>(
  DiskCache cache,
  String key,
  T Function(Map<String, dynamic>) decode,
) async {
  try {
    final raw = await cache.get(key);
    if (raw == null) return null;
    final v = raw['v'];
    if (v is! Map<String, dynamic>) return null;
    final at =
        DateTime.tryParse(raw['at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return _Cached<T>(decode(v), at);
  } catch (_) {
    return null;
  }
}

String describeError(Object e) {
  if (e is ApiException) return e.message;
  if (e is TimeoutException) return 'request timed out';
  return e.toString().replaceFirst('Exception: ', '');
}

String _human(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}

/// Decode helpers that tolerate the optional fields the upstream APIs drop.
Map<String, dynamic> obj(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

List<dynamic> arr(Object? v) => v is List ? v : const <dynamic>[];

double? dbl(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? integer(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? text(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// First element of a list, or null when the list is empty.
dynamic firstOrNull(List<dynamic> list) => list.isEmpty ? null : list.first;

/// Element at [i], or null when out of range.
dynamic atOrNull(List<dynamic> list, int i) => i < list.length ? list[i] : null;

DateTime? when(Object? v) {
  if (v is num) {
    final n = v.toInt();
    final ms = n > 100000000000 ? n : n * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return DateTime.tryParse(v?.toString() ?? '');
}
