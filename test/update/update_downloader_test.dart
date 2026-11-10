import 'dart:convert';
import 'dart:io';

import 'package:cruise_assist/update/update_downloader.dart';
import 'package:cruise_assist/update/update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_filex/open_filex.dart';

String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

http.StreamedResponse _stream(
  List<int> bytes, {
  int status = 200,
  int? contentLength,
}) =>
    http.StreamedResponse(
      Stream<List<int>>.fromIterable([bytes]),
      status,
      contentLength: contentLength ?? bytes.length,
    );

void main() {
  late Directory cache;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('cruise-assist-update-test');
  });

  tearDown(() async {
    if (await cache.exists()) await cache.delete(recursive: true);
  });

  ReleaseAsset asset({
    String name = 'cruise-assist-universal.apk',
    String? url,
    int size = 0,
    String? sha256,
  }) =>
      ReleaseAsset(
        name: name,
        downloadUrl: Uri.parse(url ??
            'https://github.com/padey88/cruise-assist/releases/download/'
                'v0.2.0/$name'),
        size: size,
        sha256: sha256,
      );

  group('UpdateDownloader.downloadToCache', () {
    test('streams the apk into the cache directory', () async {
      final bytes = List<int>.generate(2048, (i) => i % 256);
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(bytes)),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(size: bytes.length),
        isMetered: false,
      );
      expect(result.ok, isTrue);
      final file = result.value!.file;
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), bytes);
      expect(file.path, startsWith(cache.path));
    });

    test('reports progress while downloading', () async {
      final bytes = List<int>.generate(1024, (i) => i % 256);
      final progress = <DownloadProgress>[];
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(bytes)),
        cacheDirectory: () async => cache,
      );
      await downloader.downloadToCache(
        asset(size: bytes.length),
        isMetered: false,
        onProgress: progress.add,
      );
      expect(progress, isNotEmpty);
      expect(progress.last.receivedBytes, bytes.length);
      expect(progress.last.totalBytes, bytes.length);
      expect(progress.last.fraction, 1.0);
    });

    test('rejects a download on a metered connection', () async {
      var requested = false;
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async {
          requested = true;
          return _stream(const [1, 2, 3]);
        }),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(),
        isMetered: true,
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('metered'));
      expect(requested, isFalse);
    });

    test('allows a metered download when the caller opts in', () async {
      final bytes = List<int>.generate(16, (i) => i);
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(bytes)),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(size: bytes.length),
        isMetered: true,
        allowMetered: true,
      );
      expect(result.ok, isTrue);
    });

    test('fails when the downloaded size does not match', () async {
      final downloader = UpdateDownloader(
        client: MockClient.streaming(
          (request, bodyStream) async => _stream(List<int>.filled(10, 1)),
        ),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(size: 99),
        isMetered: false,
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('size mismatch'));
      final leftovers = cache.listSync().where((e) => e.path.endsWith('.part'));
      expect(leftovers, isEmpty);
    });

    test('fails when the sha-256 digest does not match', () async {
      final bytes = List<int>.filled(32, 7);
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(bytes)),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(size: bytes.length, sha256: _sha256Hex(List<int>.filled(32, 9))),
        isMetered: false,
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('SHA-256'));
    });

    test('accepts a matching sha-256 digest', () async {
      final bytes = List<int>.filled(32, 3);
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(bytes)),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(size: bytes.length, sha256: _sha256Hex(bytes)),
        isMetered: false,
      );
      expect(result.ok, isTrue);
      expect(result.value!.sha256, _sha256Hex(bytes));
    });

    test('fails on a non-200 response', () async {
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(const [], status: 404)),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(asset(), isMetered: false);
      expect(result.ok, isFalse);
      expect(result.message, contains('404'));
    });

    test('fails when the network throws', () async {
      final downloader = UpdateDownloader(
        client: MockClient.streaming(
          (request, bodyStream) async => throw http.ClientException('x'),
        ),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(asset(), isMetered: false);
      expect(result.ok, isFalse);
      expect(result.message, contains('download failed'));
    });

    test('rejects a non-https download url', () async {
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(const [1])),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(url: 'http://example.com/a.apk'),
        isMetered: false,
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('HTTPS'));
    });

    test('rejects an asset that is not an apk', () async {
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(const [1])),
        cacheDirectory: () async => cache,
      );
      final result = await downloader.downloadToCache(
        asset(name: 'release-notes.txt'),
        isMetered: false,
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('APK'));
    });
  });

  group('UpdateDownloader.install', () {
    test('opens the system installer with the downloaded apk path', () async {
      final bytes = List<int>.filled(8, 1);
      final downloader = UpdateDownloader(
        client: MockClient.streaming((request, bodyStream) async => _stream(bytes)),
        cacheDirectory: () async => cache,
      );
      final downloaded = await downloader.downloadToCache(
        asset(size: bytes.length),
        isMetered: false,
      );
      String? opened;
      final installer = UpdateDownloader(
        cacheDirectory: () async => cache,
        openApk: (path) async {
          opened = path;
          return OpenResult(type: ResultType.done, message: 'done');
        },
      );
      final result = await installer.install(downloaded.value!);
      expect(result.ok, isTrue);
      expect(opened, downloaded.value!.file.path);
    });

    test('reports an installer failure without throwing', () async {
      final downloader = UpdateDownloader(
        cacheDirectory: () async => cache,
        openApk: (_) async =>
            OpenResult(type: ResultType.noAppToOpen, message: 'no installer'),
      );
      final result = await downloader.install(
        InstalledUpdate(
          file: File('${cache.path}/x.apk'),
          size: 1,
        ),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('installer'));
    });

    test('reports a thrown installer error without throwing', () async {
      final downloader = UpdateDownloader(
        cacheDirectory: () async => cache,
        openApk: (_) async => throw StateError('boom'),
      );
      final result = await downloader.install(
        InstalledUpdate(
          file: File('${cache.path}/x.apk'),
          size: 1,
        ),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('installer'));
    });
  });

  group('release payload shape', () {
    test('a real GitHub release payload parses to an apk asset', () {
      final payload = jsonDecode('''
      {
        "tag_name": "v0.2.0",
        "body": "## Added\\n- Update screen",
        "published_at": "2026-02-03T10:00:00Z",
        "assets": [
          {
            "name": "cruise-assist-arm64-v8a.apk",
            "browser_download_url": "https://github.com/padey88/cruise-assist/releases/download/v0.2.0/cruise-assist-arm64-v8a.apk",
            "size": 20000000,
            "digest": "sha256:deadbeef"
          },
          {
            "name": "cruise-assist-universal.apk",
            "browser_download_url": "https://github.com/padey88/cruise-assist/releases/download/v0.2.0/cruise-assist-universal.apk",
            "size": 24000000,
            "digest": "sha256:cafebabe"
          }
        ]
      }
      ''') as Map<String, dynamic>;
      final release = UpdateService.parseRelease(payload);
      expect(release.apk!.name, 'cruise-assist-universal.apk');
      expect(release.apk!.size, 24000000);
      expect(release.apk!.sha256, 'cafebabe');
    });
  });
}
