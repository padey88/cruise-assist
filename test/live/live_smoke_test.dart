// LIVE smoke test — hits real endpoints. NOT part of the offline unit suite.
// Run: ./tool/env.sh flutter test test/live/live_smoke_test.dart
import 'dart:io';

import 'package:cruise_assist/data/alerts_service.dart';
import 'package:cruise_assist/data/fuel_service.dart';
import 'package:cruise_assist/data/fx_service.dart';
import 'package:cruise_assist/data/lyrics_service.dart';
import 'package:cruise_assist/data/prayer_service.dart';
import 'package:cruise_assist/data/radar_service.dart';
import 'package:cruise_assist/data/radio_service.dart';
import 'package:cruise_assist/data/sports_service.dart';
import 'package:cruise_assist/data/transient_service.dart';
import 'package:cruise_assist/data/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

const lat = 3.139;
const lng = 101.6869;

/// Live checks need the network, so they only run when explicitly enabled:
///   CRUISE_LIVE=1 flutter test test/live/live_smoke_test.dart
final liveEnabled = Platform.environment['CRUISE_LIVE'] == '1';

void main() {
  // ignore: avoid_print
  print(liveEnabled
      ? 'CRUISE_LIVE=1 — running live endpoint checks'
      : 'CRUISE_LIVE not set — skipping live endpoint checks');
  test('weather.current', () async {
    final r = await WeatherService().current(lat, lng);
    // ignore: avoid_print
    print('WEATHER ok=${r.ok} temp=${r.value?.tempC} code=${r.value?.weatherCode} '
        'sunrise=${r.value?.sunrise} sunset=${r.value?.sunset} msg=${r.message}');
    expect(r.value?.tempC, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('weather.forecast', () async {
    final r = await WeatherService().forecast(lat, lng);
    // ignore: avoid_print
    print('FORECAST ok=${r.ok} days=${r.value?.length} '
        'day0=${r.value?.first.day} max0=${r.value?.first.maxC} msg=${r.message}');
    expect(r.value?.length, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('weather.air', () async {
    final r = await WeatherService().air(lat, lng);
    // ignore: avoid_print
    print('AIR ok=${r.ok} aqi=${r.value?.usAqi} pm25=${r.value?.pm25} msg=${r.message}');
    expect(r.ok, isTrue);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('prayer.day', () async {
    final r = await PrayerService().day(zone: 'WLY01', date: DateTime.now());
    // ignore: avoid_print
    print('PRAYER ok=${r.ok} zone=${r.value?.zone} '
        'times=${r.value?.times.map((t) => '${t.name} ${t.at.hour}:${t.at.minute.toString().padLeft(2, '0')}').join(", ")} '
        'msg=${r.message}');
    expect(r.value?.times.length, 6);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('fuel.latest', () async {
    final r = await FuelService().latest();
    // ignore: avoid_print
    print('FUEL ok=${r.ok} ron95=${r.value?.ron95} ron97=${r.value?.ron97} '
        'diesel=${r.value?.diesel} from=${r.value?.effectiveFrom} msg=${r.message}');
    expect(r.value?.ron95, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('fx.rates', () async {
    final r = await FxService().rates();
    // ignore: avoid_print
    print('FX ok=${r.ok} '
        '${r.value?.map((e) => "${e.code}=${e.myr.toStringAsFixed(4)}").join(" ")} msg=${r.message}');
    expect(r.value?.length, greaterThan(5));
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('alerts.active', () async {
    final r = await AlertsService().active(lat: lat, lng: lng);
    // ignore: avoid_print
    print('ALERTS ok=${r.ok} n=${r.value?.length} '
        'first=${r.value?.take(2).map((a) => "${a.source}:${a.title}").join(" | ")} msg=${r.message}');
    expect(r.ok, isTrue);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('transit.prasarana', () async {
    final r = await TransitService().vehicles('prasarana');
    // ignore: avoid_print
    print('TRANSIT ok=${r.ok} n=${r.value?.length} '
        'first=${r.value?.take(2).map((v) => "${v.route} ${v.lat.toStringAsFixed(4)},${v.lng.toStringAsFixed(4)}").join(" | ")} '
        'msg=${r.message}');
    expect(r.value?.length, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('radar.latest', () async {
    final r = await RadarService().latest();
    // ignore: avoid_print
    print('RADAR ok=${r.ok} host=${r.value?.host} path=${r.value?.path} '
        'tile=${r.value?.tileUrl()} msg=${r.message}');
    expect(r.value?.host, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('radio.stations', () async {
    final r = await RadioService().stations(limit: 3);
    // ignore: avoid_print
    print('RADIO ok=${r.ok} n=${r.value?.length} '
        'first=${r.value?.take(2).map((s) => s.name).join(" | ")} msg=${r.message}');
    expect(r.value?.length, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('lyrics.find', () async {
    final r = await LyricsService().find(
        artist: 'Beyonce', title: 'Halo', duration: const Duration(seconds: 250));
    // ignore: avoid_print
    print('LYRICS ok=${r.ok} synced=${r.value?.synced} lines=${r.value?.lines.length} '
        'first=${r.value?.lines.isNotEmpty == true ? r.value!.lines.first.text : null} '
        'msg=${r.message}');
    expect(r.value?.lines.length, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');

  test('sports.eng.1', () async {
    final r = await SportsService().scoreboard();
    // ignore: avoid_print
    print('SPORTS ok=${r.ok} n=${r.value?.length} '
        'first=${r.value?.take(2).map((e) => "${e.home} ${e.homeScore}-${e.awayScore} ${e.away}").join(" | ")} '
        'msg=${r.message}');
    expect(r.value, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: liveEnabled ? false : 'set CRUISE_LIVE=1 to run live checks');
}
