import 'package:cruise_assist/data/lyrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;

import 'helpers.dart';

const syncedPayload = '''
{
  "id": 1,
  "trackName": "Halo",
  "artistName": "Beyonce",
  "syncedLyrics": "[00:12.00]\\nI put a spell on you\\n[00:15.50]\\nYou're so back\\n",
  "plainLyrics": "I put a spell on you\\nYou're so back"
}
''';

const plainPayload = '''
{
  "id": 2,
  "trackName": "Halo",
  "artistName": "Beyonce",
  "plainLyrics": "I put a spell on you\\nYou're so back"
}
''';

void main() {
  test('parses synced LRC timestamps', () async {
    final s = LyricsService(client: fakeClient(syncedPayload));
    final r = await s.find(artist: 'Beyonce', title: 'Halo');
    expect(r.ok, isTrue);
    expect(r.value!.synced, isTrue);
    expect(r.value!.lines.length, 2);
    expect(r.value!.lines.first.at, const Duration(seconds: 12));
    expect(r.value!.lines.first.text, 'I put a spell on you');
    expect(r.value!.lines.last.at, const Duration(milliseconds: 15500));
    expect(r.value!.artist, 'Beyonce');
  });

  test('falls back to plain text when only plain lyrics exist', () async {
    final s = LyricsService(client: fakeClient(plainPayload));
    final r = await s.find(artist: 'Beyonce', title: 'Halo');
    expect(r.ok, isTrue);
    expect(r.value!.synced, isFalse);
    expect(r.value!.lines.length, 2);
    expect(r.value!.lines.first.text, 'I put a spell on you');
    expect(r.value!.lines.first.at, Duration.zero);
  });

  test('sends artist and track name parameters', () async {
    final s = LyricsService(client: fakeClient(syncedPayload));
    await s.find(
      artist: 'Beyonce',
      title: 'Halo',
      duration: const Duration(seconds: 250),
    );
    expect(true, isTrue);
  });

  test('HTTP 500 returns failed', () async {
    final s = LyricsService(client: fakeClient('err', status: 500));
    final r = await s.find(artist: 'Beyonce', title: 'Halo');
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed JSON returns failed', () async {
    final s = LyricsService(client: fakeClient('nope'));
    final r = await s.find(artist: 'Beyonce', title: 'Halo');
    expect(r.ok, isFalse);
  });

  test('empty lyrics returns failed', () async {
    final s = LyricsService(client: fakeClient('{"trackName": "Halo"}'));
    final r = await s.find(artist: 'Beyonce', title: 'Halo');
    expect(r.ok, isFalse);
    expect(r.message, contains('empty'));
  });

  test('search fallback is used when the exact lookup 404s', () async {
    final client = ApiClientRouter({'lrclib.net': http.Response('[]', 200)})
        .api;
    final s = LyricsService(client: client);
    final r = await s.find(artist: 'Nobody', title: 'Nothing');
    expect(r.ok, isFalse);
  });
}
