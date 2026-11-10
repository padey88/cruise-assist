import 'dart:io';

import 'package:cruise_assist/data/cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cruise_cache_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  DiskCache cache() => DiskCache(directory: () async => tmp);

  test('put then get returns the stored map', () async {
    final c = cache();
    await c.put('k', {'a': 1, 'b': 'two'});
    final got = await c.get('k');
    expect(got, isNotNull);
    expect(got!['a'], 1);
    expect(got['b'], 'two');
  });

  test('get on a missing key returns null', () async {
    expect(await cache().get('missing'), isNull);
  });

  test('clear removes entries', () async {
    final c = cache();
    await c.put('k', {'a': 1});
    await c.clear();
    expect(await c.get('k'), isNull);
  });

  test('key with special characters round-trips', () async {
    final c = cache();
    await c.put('weather.current.3.1,101.6', {'v': true});
    expect((await c.get('weather.current.3.1,101.6'))!['v'], isTrue);
  });

  test('overwriting a key replaces the value', () async {
    final c = cache();
    await c.put('k', {'v': 1});
    await c.put('k', {'v': 2});
    expect((await c.get('k'))!['v'], 2);
  });
}
