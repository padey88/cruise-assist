import 'dart:convert';

import 'package:cruise_assist/data/api.dart';
import 'package:http/http.dart' as http;

/// Builds a fake [ApiClient] whose handler receives the request and returns
/// the given body with the given status.
ApiClient fakeClient(
  String body, {
  int status = 200,
  void Function(http.Request request)? onRequest,
}) {
  return ApiClient.fake((request) async {
    onRequest?.call(request);
    return http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// A client that always fails, to exercise the offline/cached path.
ApiClient failingClient({Object error = 'boom'}) {
  return ApiClient.fake((request) async => throw error);
}

/// A client that returns a different body per host, so multi-source services
/// (alerts) can be exercised.
ApiClient multiClient(Map<String, String> byHost, {String fallback = '{}'}) {
  return ApiClient.fake((request) async {
    final body = byHost[request.url.host] ?? fallback;
    return http.Response(
      body,
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

String jsonOf(Object value) => jsonEncode(value);

/// Routes responses by request host (and optionally by `host/path`), so
/// services with primary+fallback sources (FX, alerts) can be tested offline.
class ApiClientRouter {
  final Map<String, http.Response> responses;
  ApiClientRouter(this.responses);

  ApiClient get api => ApiClient.fake((request) async {
    final key = '${request.url.host}${request.url.path}';
    final res =
        responses[key] ??
        responses[request.url.host] ??
        http.Response('unrouted host ${request.url.host}', 404);
    return res;
  });
}
