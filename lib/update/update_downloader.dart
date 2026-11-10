import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/result.dart';
import 'update_service.dart';

/// Progress for a streamed APK download.
class DownloadProgress {
  final int receivedBytes;
  final int? totalBytes;

  const DownloadProgress(this.receivedBytes, this.totalBytes);

  double? get fraction => totalBytes == null || totalBytes! <= 0
      ? null
      : (receivedBytes / totalBytes!).clamp(0.0, 1.0);

  @override
  String toString() => '$receivedBytes/${totalBytes ?? '?'} bytes';
}

/// Where an installer operation stopped.
enum UpdateInstallStage { download, verification, installer }

/// A successful download carries its file and, when available, its digest.
class InstalledUpdate {
  final File file;
  final int size;
  final String? sha256;

  const InstalledUpdate({
    required this.file,
    required this.size,
    this.sha256,
  });
}

/// Failure returned from the downloader or installer, never thrown to UI.
/// Extends [Exception] so `on UpdateInstallFailure` can actually catch it.
class UpdateInstallFailure implements Exception {
  final UpdateInstallStage stage;
  final String message;

  const UpdateInstallFailure(this.stage, this.message);

  @override
  String toString() => message;
}

typedef UpdateProgressCallback = void Function(DownloadProgress progress);
typedef UpdateResult = Fetch<InstalledUpdate>;

/// Collects the single [Digest] emitted by a chunked hash conversion.
class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;

  @override
  void add(Digest value) {
    if (_value != null) throw StateError('Digest already produced');
    _value = value;
  }

  @override
  void close() {
    if (_value == null) throw StateError('No digest produced');
  }
}

/// Streams a release APK to cache, verifies it, and opens Android's installer.
class UpdateDownloader {
  static const String defaultAuthority =
      UpdateService.fileProviderAuthority;

  final http.Client _client;
  final bool _ownsClient;
  final Future<Directory> Function() _cacheDirectory;
  final Future<OpenResult> Function(String path) _openApk;

  UpdateDownloader({
    http.Client? client,
    Future<Directory> Function()? cacheDirectory,
    Future<OpenResult> Function(String path)? openApk,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
        _openApk = openApk ?? _systemOpen;

  static Future<OpenResult> _systemOpen(String path) => OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );

  /// Downloads [asset]. The caller must pass the current metered state.
  ///
  /// Metered downloads are refused by default. A UI can offer an explicit
  /// "download anyway" action with [allowMetered] after user confirmation.
  /// When [onProgress] is non-null, progress is also emitted there.
  Stream<DownloadProgress> download(
    ReleaseAsset asset, {
    required bool isMetered,
    bool allowMetered = false,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    if (isMetered && !allowMetered) {
      return Stream<DownloadProgress>.error(
        const UpdateInstallFailure(
          UpdateInstallStage.download,
          'Download paused: unmetered connection required',
        ),
      );
    }
    return _download(asset).asBroadcastStream();
  }

  Stream<DownloadProgress> _download(ReleaseAsset asset) async* {
    File? partial;
    try {
      _validateAsset(asset);
      final directory = await _cacheDirectory();
      await directory.create(recursive: true);
      final safeName = _safeFilename(asset.name);
      final destination = File('${directory.path}/$safeName');
      partial = File('${destination.path}.part');
      if (await partial.exists()) await partial.delete();

      final request = http.Request('GET', asset.downloadUrl)
        ..headers['User-Agent'] = 'CruiseAssist/0.1 (personal use)'
        ..headers['Accept'] = 'application/vnd.android.package-archive';
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        throw UpdateInstallFailure(
          UpdateInstallStage.download,
          'Update download failed (HTTP ${response.statusCode})',
        );
      }

      final expectedTotal = asset.size > 0 ? asset.size : response.contentLength;
      final sink = partial.openWrite();
      final digestSink = _DigestSink();
      final hashSink = sha256.startChunkedConversion(digestSink);
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          hashSink.add(chunk);
          received += chunk.length;
          yield DownloadProgress(received, expectedTotal);
        }
        hashSink.close();
        await sink.flush();
        await sink.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }

      if (expectedTotal != null && received != expectedTotal) {
        throw UpdateInstallFailure(
          UpdateInstallStage.verification,
          'Download size mismatch (expected $expectedTotal, got $received)',
        );
      }
      final digest = digestSink.value.toString();
      if (asset.sha256 != null && digest != asset.sha256!.toLowerCase()) {
        throw UpdateInstallFailure(
          UpdateInstallStage.verification,
          'Downloaded APK failed SHA-256 verification',
        );
      }
      if (await destination.exists()) await destination.delete();
      await partial.rename(destination.path);
      partial = null;
    } on UpdateInstallFailure {
      rethrow;
    } catch (_) {
      throw const UpdateInstallFailure(
        UpdateInstallStage.download,
        'Update download failed; check your connection and try again',
      );
    } finally {
      if (partial != null && await partial.exists()) await partial.delete();
    }
  }

  /// Convenience API for callers that prefer a single [Fetch] result.
  Future<UpdateResult> downloadToCache(
    ReleaseAsset asset, {
    required bool isMetered,
    bool allowMetered = false,
    UpdateProgressCallback? onProgress,
  }) async {
    try {
      await for (final progress in download(
        asset,
        isMetered: isMetered,
        allowMetered: allowMetered,
      )) {
        onProgress?.call(progress);
      }
      final directory = await _cacheDirectory();
      final file = File('${directory.path}/${_safeFilename(asset.name)}');
      return Fetch<InstalledUpdate>(
        value: InstalledUpdate(
          file: file,
          size: await file.length(),
          sha256: asset.sha256,
        ),
        at: DateTime.now(),
      );
    } on UpdateInstallFailure catch (error) {
      return Fetch<InstalledUpdate>(message: error.message);
    } catch (_) {
      return Fetch<InstalledUpdate>(message: 'Update download failed');
    }
  }

  /// Launches the system package installer for a verified downloaded APK.
  Future<Fetch<InstalledUpdate>> install(InstalledUpdate update) async {
    try {
      final result = await _openApk(update.file.path);
      if (result.type != ResultType.done) {
        return Fetch<InstalledUpdate>(
          value: update,
          at: DateTime.now(),
          message: 'Could not open the Android installer: ${result.message}',
        );
      }
      return Fetch<InstalledUpdate>(value: update, at: DateTime.now());
    } catch (_) {
      return Fetch<InstalledUpdate>(
        value: update,
        at: DateTime.now(),
        message: 'Could not open the Android installer',
      );
    }
  }

  /// Downloads, verifies, and launches the installer in one operation.
  Future<UpdateResult> downloadAndInstall(
    ReleaseAsset asset, {
    required bool isMetered,
    bool allowMetered = false,
    UpdateProgressCallback? onProgress,
  }) async {
    final downloaded = await downloadToCache(
      asset,
      isMetered: isMetered,
      allowMetered: allowMetered,
      onProgress: onProgress,
    );
    final value = downloaded.value;
    if (!downloaded.ok || value == null) return downloaded;
    return install(value);
  }

  static void _validateAsset(ReleaseAsset asset) {
    if (!asset.downloadUrl.isAbsolute ||
        asset.downloadUrl.scheme != 'https' ||
        !asset.name.toLowerCase().endsWith('.apk')) {
      throw const UpdateInstallFailure(
        UpdateInstallStage.download,
        'Release does not contain a valid HTTPS APK download',
      );
    }
  }

  static String _safeFilename(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'cruise-assist-update.apk';
    }
    return sanitized;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
