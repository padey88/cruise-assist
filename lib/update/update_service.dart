import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../data/api.dart';
import '../models/result.dart';
import 'version.dart';

/// A downloadable file attached to a GitHub release.
class ReleaseAsset {
  final String name;
  final Uri downloadUrl;
  final int size;

  /// SHA-256 digest as published by GitHub (`sha256:<hex>`), when present.
  final String? sha256;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    this.sha256,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    final rawDigest = json['digest'];
    String? digest;
    if (rawDigest is String && rawDigest.startsWith('sha256:')) {
      digest = rawDigest.substring('sha256:'.length).toLowerCase();
    }
    final rawSize = json['size'];
    return ReleaseAsset(
      name: (json['name'] as String?) ?? '',
      downloadUrl: Uri.parse((json['browser_download_url'] as String?) ?? ''),
      size: rawSize is num ? rawSize.toInt() : 0,
      sha256: digest,
    );
  }
}

/// A parsed GitHub release.
class ReleaseInfo {
  final String tag;
  final AppVersion version;
  final String changelog;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  /// The APK that should be installed on this device.
  final ReleaseAsset? apk;

  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.changelog,
    required this.publishedAt,
    required this.assets,
    required this.apk,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?)?.trim() ?? '';
    if (tag.isEmpty) {
      throw const FormatException('Release has no tag_name');
    }
    final version = AppVersion.tryParse(tag);
    if (version == null) {
      throw FormatException('Unparseable release tag: $tag');
    }
    final rawAssets = json['assets'];
    final assets = <ReleaseAsset>[];
    if (rawAssets is List) {
      for (final entry in rawAssets) {
        if (entry is Map<String, dynamic>) {
          assets.add(ReleaseAsset.fromJson(entry));
        }
      }
    }
    DateTime? published;
    final rawPublished = json['published_at'];
    if (rawPublished is String) {
      published = DateTime.tryParse(rawPublished)?.toUtc();
    }
    return ReleaseInfo(
      tag: tag,
      version: version,
      changelog: (json['body'] as String?)?.trim() ?? '',
      publishedAt: published,
      assets: List.unmodifiable(assets),
      apk: _selectApk(assets),
    );
  }

  /// Prefers a universal APK, then a plain release APK, then any APK.
  static ReleaseAsset? _selectApk(List<ReleaseAsset> assets) {
    final apks = assets
        .where((a) => a.name.toLowerCase().endsWith('.apk'))
        .toList(growable: false);
    if (apks.isEmpty) return null;
    for (final candidate in apks) {
      final name = candidate.name.toLowerCase();
      if (name.contains('universal') || name.contains('app-release.apk')) {
        return candidate;
      }
    }
    return apks.first;
  }
}

/// The outcome of a successful update check.
class UpdateCheck {
  final AppVersion installedVersion;
  final AppVersion latestVersion;
  final ReleaseInfo release;

  const UpdateCheck({
    required this.installedVersion,
    required this.latestVersion,
    required this.release,
  });

  bool get updateAvailable => latestVersion.compareTo(installedVersion) > 0;
}

/// Reads the latest GitHub release and compares it with the installed app.
///
/// Never throws: every failure is returned as a [Fetch] carrying a
/// human-readable message.
class UpdateService {
  /// Message shown when no release information could be obtained.
  static const String unavailableMessage = 'Update check unavailable';

  static const String defaultOwner = 'padey88';
  static const String defaultRepo = 'cruise-assist';

  /// FileProvider authority used by `open_filex` for this package.
  static const String fileProviderAuthority =
      'my.kulnem.cruise_assist.fileProvider.com.crazecoder.openfile';

  final ApiClient _api;
  final bool _ownsApi;
  final Uri _releasesUri;

  /// Resolves the installed version. Overridable for tests.
  final Future<AppVersion> Function() installedVersionProvider;

  /// Optional GitHub token. Public repositories need none; a private
  /// repository requires a token with `repo` scope. Supply it through
  /// `--dart-define=GITHUB_TOKEN=...` — never hardcode it.
  final String? token;

  UpdateService({
    ApiClient? api,
    http.Client? client,
    String owner = defaultOwner,
    String repo = defaultRepo,
    this.token,
    Future<AppVersion> Function()? installedVersionProvider,
  })  : _releasesUri = Uri.https(
          'api.github.com',
          '/repos/$owner/$repo/releases/latest',
        ),
        installedVersionProvider = installedVersionProvider ?? _platformVersion,
        _api = api ?? (client != null ? ApiClient(client: client) : ApiClient()),
        _ownsApi = api == null;

  /// Parses a release payload. Exposed for tests and for callers that fetch
  /// the release JSON themselves.
  static ReleaseInfo parseRelease(Map<String, dynamic> json) =>
      ReleaseInfo.fromJson(json);

  /// Fetches the latest release and compares it with the installed version.
  Future<Fetch<UpdateCheck>> checkForUpdates() async {
    final authToken = token;
    try {
      final response = await _api.get(
        _releasesUri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 404) {
        return Fetch<UpdateCheck>(message: unavailableMessage);
      }
      if (response.statusCode != 200) {
        return Fetch<UpdateCheck>(
          message: '$unavailableMessage (HTTP ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return Fetch<UpdateCheck>(
          message: '$unavailableMessage (bad payload)',
        );
      }

      final ReleaseInfo release;
      try {
        release = parseRelease(decoded);
      } on FormatException catch (e) {
        return Fetch<UpdateCheck>(
          message: '$unavailableMessage (${e.message})',
        );
      }

      final installed = await installedVersionProvider();
      return Fetch<UpdateCheck>(
        value: UpdateCheck(
          installedVersion: installed,
          latestVersion: release.version,
          release: release,
        ),
        at: DateTime.now(),
      );
    } catch (_) {
      return Fetch<UpdateCheck>(message: unavailableMessage);
    }
  }

  static Future<AppVersion> _platformVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersion.tryParse(info.version) ?? const AppVersion(0, 0, 0);
    } catch (_) {
      return const AppVersion(0, 0, 0);
    }
  }

  void close() {
    if (_ownsApi) _api.close();
  }
}
