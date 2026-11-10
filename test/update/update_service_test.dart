import 'dart:convert';

import 'package:cruise_assist/update/update_service.dart';
import 'package:cruise_assist/update/version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _release({
  String tag = 'v0.2.0',
  String? body,
  List<Map<String, dynamic>>? assets,
}) =>
    {
      'tag_name': tag,
      'body': body ?? '## Changes\n- Something new',
      'published_at': '2026-01-02T03:04:05Z',
      'assets': assets ??
          [
            {
              'name': 'cruise-assist-universal.apk',
              'browser_download_url':
                  'https://github.com/padey88/cruise-assist/releases/download/'
                      '$tag/cruise-assist-universal.apk',
              'size': 1234,
              'digest': 'sha256:abc123',
            },
          ],
    };

void main() {
  group('ReleaseInfo.fromJson', () {
    test('parses tag, changelog and publish date', () {
      final release = UpdateService.parseRelease(_release());
      expect(release.tag, 'v0.2.0');
      expect(release.version, AppVersion.parse('0.2.0'));
      expect(release.changelog, contains('Something new'));
      expect(release.publishedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    test('parses the apk asset with its size and digest', () {
      final release = UpdateService.parseRelease(_release());
      final apk = release.apk!;
      expect(apk.name, 'cruise-assist-universal.apk');
      expect(apk.size, 1234);
      expect(apk.sha256, 'abc123');
      expect(apk.downloadUrl.host, 'github.com');
    });

    test('prefers a universal apk over split apks', () {
      final release = UpdateService.parseRelease(_release(
        assets: [
          {
            'name': 'app-arm64-v8a-release.apk',
            'browser_download_url': 'https://example.com/arm64.apk',
            'size': 1,
          },
          {
            'name': 'app-universal-release.apk',
            'browser_download_url': 'https://example.com/universal.apk',
            'size': 2,
          },
        ],
      ));
      expect(release.apk!.name, 'app-universal-release.apk');
    });

    test('falls back to the only apk when no universal build exists', () {
      final release = UpdateService.parseRelease(_release(
        assets: [
          {
            'name': 'app-arm64-v8a-release.apk',
            'browser_download_url': 'https://example.com/arm64.apk',
            'size': 1,
          },
        ],
      ));
      expect(release.apk!.name, 'app-arm64-v8a-release.apk');
    });

    test('has no apk when the release carries no apk', () {
      final release = UpdateService.parseRelease(_release(assets: [
        {
          'name': 'notes.txt',
          'browser_download_url': 'https://example.com/notes.txt',
          'size': 1,
        },
      ]));
      expect(release.apk, isNull);
    });

    test('ignores a digest that is not sha256', () {
      final release = UpdateService.parseRelease(_release(assets: [
        {
          'name': 'a.apk',
          'browser_download_url': 'https://example.com/a.apk',
          'size': 1,
          'digest': 'md5:zzz',
        },
      ]));
      expect(release.apk!.sha256, isNull);
    });

    test('rejects a release without a tag', () {
      expect(
        () => UpdateService.parseRelease({'body': 'x'}),
        throwsFormatException,
      );
    });

    test('rejects an unparseable tag', () {
      expect(
        () => UpdateService.parseRelease(_release(tag: 'nightly')),
        throwsFormatException,
      );
    });
  });

  group('UpdateService.checkForUpdates', () {
    UpdateService service(
      Future<http.Response> Function(http.Request request) handler, {
      String installed = '0.1.0',
      String? token,
    }) =>
        UpdateService(
          client: MockClient(handler),
          installedVersionProvider: () async => AppVersion.parse(installed),
          token: token,
        );

    Future<http.Response> Function(http.Request) respond(
      http.Response response,
    ) =>
        (_) async => response;

    test('reports an available update', () async {
      final s = service(respond(_json(_release())));
      final result = await s.checkForUpdates();
      expect(result.ok, isTrue);
      expect(result.value!.updateAvailable, isTrue);
      expect(result.value!.latestVersion, AppVersion.parse('0.2.0'));
      expect(result.value!.installedVersion, AppVersion.parse('0.1.0'));
    });

    test('reports being up to date', () async {
      final s = service(
        respond(_json(_release())),
        installed: '0.2.0',
      );
      final result = await s.checkForUpdates();
      expect(result.ok, isTrue);
      expect(result.value!.updateAvailable, isFalse);
    });

    test('reports no update when the installed version is newer', () async {
      final s = service(
        respond(_json(_release())),
        installed: '0.3.0',
      );
      final result = await s.checkForUpdates();
      expect(result.ok, isTrue);
      expect(result.value!.updateAvailable, isFalse);
    });

    test('sends a User-Agent header', () async {
      String? ua;
      final s = service((request) async {
        ua = request.headers['User-Agent'];
        return _json(_release());
      });
      await s.checkForUpdates();
      expect(ua, isNotNull);
      expect(ua, isNotEmpty);
    });

    test('targets the latest-release endpoint of the repository', () async {
      Uri? called;
      final s = service((request) async {
        called = request.url;
        return _json(_release());
      });
      await s.checkForUpdates();
      expect(
        called.toString(),
        'https://api.github.com/repos/padey88/cruise-assist/releases/latest',
      );
    });

    test('sends an Authorization header when a token is supplied', () async {
      String? auth;
      final s = service((request) async {
        auth = request.headers['Authorization'];
        return _json(_release());
      }, token: 'secret-token');
      await s.checkForUpdates();
      expect(auth, 'Bearer secret-token');
    });

    test('omits the Authorization header when no token is supplied', () async {
      String? auth;
      final s = service((request) async {
        auth = request.headers['Authorization'];
        return _json(_release());
      });
      await s.checkForUpdates();
      expect(auth, isNull);
    });

    test('degrades gracefully on a 404 from a private repository', () async {
      final s = service(
        respond(_json({'message': 'Not Found'}, status: 404)),
      );
      final result = await s.checkForUpdates();
      expect(result.ok, isFalse);
      expect(result.message, UpdateService.unavailableMessage);
    });

    test('degrades gracefully on a 403 rate limit', () async {
      final s = service(
        respond(_json({'message': 'rate limited'}, status: 403)),
      );
      final result = await s.checkForUpdates();
      expect(result.ok, isFalse);
      expect(result.message, contains(UpdateService.unavailableMessage));
    });

    test('degrades gracefully on a server error', () async {
      final s = service(
        respond(_json({'message': 'boom'}, status: 500)),
      );
      final result = await s.checkForUpdates();
      expect(result.ok, isFalse);
      expect(result.message, contains('500'));
    });

    test('degrades gracefully when the network throws', () async {
      final s = service((_) async => throw http.ClientException('offline'));
      final result = await s.checkForUpdates();
      expect(result.ok, isFalse);
      expect(result.message, UpdateService.unavailableMessage);
    });

    test('degrades gracefully on a malformed body', () async {
      final s = service(respond(http.Response('not json', 200)));
      final result = await s.checkForUpdates();
      expect(result.ok, isFalse);
      expect(result.message, contains(UpdateService.unavailableMessage));
    });

    test('degrades gracefully on an unparseable tag', () async {
      final s = service(respond(_json(_release(tag: 'nightly'))));
      final result = await s.checkForUpdates();
      expect(result.ok, isFalse);
      expect(result.message, contains(UpdateService.unavailableMessage));
    });
  });
}
