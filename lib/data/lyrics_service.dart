import 'dart:convert';

import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// LRCLIB exact lookup with search fallback. Synchronised LRC lyrics are
/// parsed to [LyricsLine]; unsynced text uses zero timestamps and synced=false.
/// https://lrclib.net/docs
class LyricsService {
  final ApiClient _api;
  final DiskCache _cache;

  LyricsService({ApiClient? client, DiskCache? cache})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache();

  Future<Fetch<Lyrics>> find({
    required String artist,
    required String title,
    Duration? duration,
  }) {
    final a = artist.trim();
    final t = title.trim();
    return cachedRead<Lyrics>(
      cache: _cache,
      key: 'lyrics.${a.toLowerCase()}.${t.toLowerCase()}.${duration?.inSeconds ?? 0}',
      ttl: const Duration(days: 30),
      encode: (v) => v.toJson(),
      decode: Lyrics.fromJson,
      remote: () async {
        final query = <String, String>{
          'artist_name': a,
          'track_name': t,
          if (duration != null) 'duration': duration.inSeconds.toString(),
        };
        try {
          final exact = ApiClient.asObject(
            await _api.get(Uri.https('lrclib.net', '/api/get', query)),
            'Lyrics',
          );
          return _parse(exact, artist: a, title: t);
        } on ApiException catch (e) {
          // Search covers recordings without an exact metadata/duration match.
          if (duration == null && !e.message.contains('404')) rethrow;
          final search = await _api.get(
            Uri.https('lrclib.net', '/api/search', query),
          );
          final rows = ApiClient.asList(search, 'Lyrics search');
          if (rows.isEmpty) throw ApiException('Lyrics not found');
          return _parse(obj(rows.first), artist: a, title: t);
        }
      },
    );
  }

  Lyrics _parse(Map<String, dynamic> j, {required String artist, required String title}) {
    final syncedText = text(j['syncedLyrics']);
    final plainText = text(j['plainLyrics']);
    final synced = syncedText != null && _timestamp.hasMatch(syncedText);
    final lines = synced ? _lrc(syncedText) : _plain(plainText ?? syncedText ?? '');
    if (lines.isEmpty) throw ApiException('Lyrics: empty lyrics');
    return Lyrics(
      track: text(j['trackName']) ?? title,
      artist: text(j['artistName']) ?? artist,
      synced: synced,
      lines: lines,
    );
  }

  static final _timestamp = RegExp(r'^\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

  List<LyricsLine> _lrc(String source) {
    final raw = const LineSplitter().convert(source);
    final out = <LyricsLine>[];
    for (var i = 0; i < raw.length; i++) {
      final line = raw[i].trimRight();
      final matches = _timestamp.allMatches(line).toList();
      if (matches.isEmpty) continue;
      var lyric = line.substring(matches.last.end).trim();
      if (lyric.isEmpty) {
        // Some releases put the lyric on the line after the timestamp.
        var j = i + 1;
        while (j < raw.length && raw[j].trim().isEmpty) {
          j++;
        }
        if (j < raw.length && !_timestamp.hasMatch(raw[j].trimRight())) {
          lyric = raw[j].trim();
          i = j;
        }
      }
      for (final m in matches) {
        final minutes = int.parse(m.group(1)!);
        final seconds = int.parse(m.group(2)!);
        final fraction = m.group(3) ?? '0';
        final millis = fraction.length == 2
            ? int.parse(fraction) * 10
            : int.parse(fraction.padRight(3, '0'));
        out.add(LyricsLine(
          Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
          lyric,
        ));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  List<LyricsLine> _plain(String source) => const LineSplitter()
      .convert(source)
      .where((line) => line.trim().isNotEmpty)
      .map((line) => LyricsLine(Duration.zero, line.trimRight()))
      .toList(growable: false);
}
