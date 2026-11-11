import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Small disk+memory cache for last-good payloads.
///
/// One JSON file per key under `<app cache>/cruise_assist_cache`. A failed
/// plugin lookup (unit tests) degrades to memory-only rather than throwing.
class DiskCache {
  final String folder;
  final Future<Directory> Function()? _directoryOverride;

  final Map<String, Map<String, dynamic>> _memory = {};
  Future<Directory>? _dirFuture;

  DiskCache({
    this.folder = 'cruise_assist_cache',
    Future<Directory> Function()? directory,
  }) : _directoryOverride = directory;

  Future<Directory> _dir() {
    return _dirFuture ??=
        () async {
          final base = _directoryOverride != null
              ? await _directoryOverride()
              : await getApplicationCacheDirectory();
          final d = Directory('${base.path}/$folder');
          if (!await d.exists()) await d.create(recursive: true);
          return d;
        }().catchError(
          (Object _) => Directory.systemTemp.createTempSync('cruise_cache_'),
        );
  }

  File _file(Directory dir, String key) {
    final safe = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return File('${dir.path}/$safe.json');
  }

  Future<void> put(String key, Map<String, dynamic> json) async {
    _memory[key] = json;
    try {
      final dir = await _dir();
      final file = _file(dir, key);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(json), flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('DiskCache.put($key) failed: $e');
    }
  }

  Future<Map<String, dynamic>?> get(String key) async {
    final mem = _memory[key];
    if (mem != null) return mem;
    try {
      final dir = await _dir();
      final file = _file(dir, key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        _memory[key] = decoded;
        return decoded;
      }
    } catch (e) {
      debugPrint('DiskCache.get($key) failed: $e');
    }
    return null;
  }

  Future<void> clear() async {
    _memory.clear();
    try {
      final dir = await _dir();
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          if (e is File) await e.delete();
        }
      }
    } catch (e) {
      debugPrint('DiskCache.clear failed: $e');
    }
  }
}
