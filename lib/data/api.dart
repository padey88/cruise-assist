import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Thin wrapper over `http.Client` shared by every service.
///
/// Responsibilities: base URL, timeout, User-Agent, polite rate limiting per
/// host, and JSON decoding that never throws a FormatException past the client
/// boundary without a readable message.
class ApiClient {
  final http.Client _inner;
  final Duration timeout;
  final String userAgent;

  /// Minimum spacing between requests to the same host (politeness for
  /// Nominatim/Overpass, which rate-limit aggressively).
  final Map<String, Duration> hostSpacing;

  final Map<String, DateTime> _lastCall = {};
  final Map<String, int> _failures = {};

  ApiClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.userAgent = 'CruiseAssist/0.1 (personal use)',
    Map<String, Duration>? hostSpacing,
  })  : _inner = client ?? http.Client(),
        hostSpacing = hostSpacing ??
            const {
              'nominatim.openstreetmap.org': Duration(seconds: 1),
              'overpass-api.de': Duration(seconds: 1),
            };

  static ApiClient fake(Future<http.Response> Function(http.Request) handler) =>
      ApiClient(client: MockClient(handler));

  int failuresFor(String host) => _failures[host] ?? 0;

  Future<void> _respectSpacing(Uri uri) async {
    final gap = hostSpacing[uri.host];
    if (gap == null) return;
    final last = _lastCall[uri.host];
    if (last != null) {
      final wait = gap - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastCall[uri.host] = DateTime.now();
  }

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) async {
    await _respectSpacing(uri);
    var attempt = 0;
    while (true) {
      try {
        final res = await _inner.get(
          uri,
          headers: {
            'User-Agent': userAgent,
            'Accept': 'application/json',
            ...?headers,
          },
        ).timeout(timeout);
        if (res.statusCode >= 500 && attempt < 1) {
          attempt++;
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
        _failures[uri.host] = 0;
        return res;
      } on SocketException {
        if (attempt >= 1) rethrow;
        attempt++;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  Future<http.Response> post(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    await _respectSpacing(uri);
    return _inner
        .post(uri,
            headers: {
              'User-Agent': userAgent,
              'Accept': 'application/json',
              ...?headers,
            },
            body: body)
        .timeout(timeout);
  }

  /// Decodes a JSON object, throwing [ApiException] with a readable message.
  static Map<String, dynamic> asObject(http.Response res, String what) {
    if (res.statusCode != 200) {
      throw ApiException('$what: HTTP ${res.statusCode}');
    }
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException('$what: unexpected response shape');
    } on FormatException {
      throw ApiException('$what: response was not valid JSON');
    }
  }

  static List<dynamic> asList(http.Response res, String what) {
    if (res.statusCode != 200) {
      throw ApiException('$what: HTTP ${res.statusCode}');
    }
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) return decoded['data'] as List;
      throw ApiException('$what: unexpected response shape');
    } on FormatException {
      throw ApiException('$what: response was not valid JSON');
    }
  }

  void close() => _inner.close();
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Great-circle distance in metres.
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * r * asin(min(1, sqrt(a)));
}

double _rad(double d) => d * pi / 180.0;
