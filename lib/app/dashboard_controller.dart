import 'dart:async';

import 'package:flutter/material.dart';

import '../data/alerts_service.dart';
import '../data/fuel_service.dart';
import '../data/fx_service.dart';
import '../data/prayer_service.dart';
import '../data/weather_service.dart';
import '../models/result.dart';
import '../store.dart';

/// Central refresh coordinator.
///
/// Owns one instance of each service, refreshes them on independent schedules,
/// and publishes the raw payload map that tiles read from. Keeping this out of
/// the widget tree means a rebuild never triggers a network call, and a failed
/// refresh keeps the previous payload visible.
class DashboardController extends ChangeNotifier {
  final AppStore store;
  final WeatherService weather;
  final PrayerService prayer;
  final FuelService fuel;
  final FxService fx;
  final AlertsService alerts;

  DashboardController({
    required this.store,
    WeatherService? weather,
    PrayerService? prayer,
    FuelService? fuel,
    FxService? fx,
    AlertsService? alerts,
  })  : weather = weather ?? WeatherService(),
        prayer = prayer ?? PrayerService(),
        fuel = fuel ?? FuelService(),
        fx = fx ?? FxService(),
        alerts = alerts ?? AlertsService();

  final Map<String, dynamic> payloads = {};
  final Map<String, String> errors = {};
  final Map<String, DateTime> updatedAt = {};

  Timer? _tick;
  Timer? _slow;
  bool _busy = false;

  /// True while any refresh is in flight.
  bool get busy => _busy;
  bool _disposed = false;

  void start() {
    if (_tick != null) return;
    // Seed from cache so the first frame has content.
    for (final e in store.payloads.entries) {
      payloads[e.key] = e.value;
    }
    notifyListeners();
    refreshAll();
    // Minute tick: clock/prayer countdowns and stale checks.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _minuteTick());
    // Slow lane: fuel/FX change at most daily, alerts every 10 min.
    _slow = Timer.periodic(const Duration(minutes: 10), (_) => refreshSlow());
  }

  void _minuteTick() {
    _refreshPrayerIfNeeded();
    notifyListeners();
  }

  DateTime? _lastPrayerFetch;

  void _refreshPrayerIfNeeded() {
    final last = _lastPrayerFetch;
    if (last == null || DateTime.now().difference(last).inHours >= 6) {
      refreshPrayer();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshWeather(),
      refreshPrayer(),
    ]);
    await refreshSlow();
  }

  Future<void> refreshSlow() async {
    await Future.wait([refreshFuel(), refreshFx(), refreshAlerts()]);
  }

  Future<void> refreshWeather() async {
    final s = store.settings;
    final lat = s.lat ?? 3.1390; // Kuala Lumpur
    final lng = s.lng ?? 101.6869;
    await _guard('weather', () async {
      final now = await weather.current(lat, lng);
      _apply('weather', now, (v) => v.toJson());
      final fc = await weather.forecast(lat, lng);
      if (fc.value != null) {
        payloads['forecast'] = fc.value!.map((e) => e.toJson()).toList();
        updatedAt['forecast'] = DateTime.now();
      }
      final air = await weather.air(lat, lng);
      _apply('air', air, (v) => v.toJson());
    });
  }

  Future<void> refreshPrayer() async {
    _lastPrayerFetch = DateTime.now();
    await _guard('prayer', () async {
      final day = await prayer.day(
        zone: store.settings.prayerZone,
        date: DateTime.now(),
      );
      _apply('prayer', day, (v) => v.toJson());
      // Persist the raw shape so the countdown survives an offline launch.
      if (day.value != null) {
        payloads['prayerNext'] = day.value!.next(DateTime.now())?.toJson();
      }
    });
  }

  Future<void> refreshFuel() => _guard('fuel', () async {
        _apply('fuel', await fuel.latest(), (v) => v.toJson());
      });

  Future<void> refreshFx() => _guard('fx', () async {
        final r = await fx.rates();
        if (r.value != null) {
          payloads['fx'] = r.value!.map((e) => e.toJson()).toList();
          updatedAt['fx'] = DateTime.now();
        }
        _note('fx', r.message);
      });

  Future<void> refreshAlerts() => _guard('alerts', () async {
        final a = await alerts.active(
          lat: store.settings.lat,
          lng: store.settings.lng,
        );
        if (a.value != null) {
          payloads['alerts'] = a.value!.map((e) => e.toJson()).toList();
          updatedAt['alerts'] = DateTime.now();
        }
        _note('alerts', a.message);
      });

  /// Runs [work] with a single-flight guard and converts any escaped exception
  /// into a visible error string rather than an unhandled zone error.
  Future<void> _guard(String key, Future<void> Function() work) async {
    _busy = true;
    try {
      await work();
    } catch (e) {
      errors[key] = e.toString();
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _apply<T>(
    String key,
    Fetch<T> f,
    Map<String, dynamic> Function(T value) toJson,
  ) {
    final v = f.value;
    if (v != null) {
      final json = toJson(v);
      payloads[key] = json;
      updatedAt[key] = DateTime.now();
      store.cachePayload(key, json);
    }
    _note(key, f.message);
  }

  void _note(String key, String? message) {
    if (message == null) {
      errors.remove(key);
    } else {
      errors[key] = message;
    }
  }

  /// Milliseconds since the payload was last successfully refreshed.
  Duration? ageOf(String key) {
    final at = updatedAt[key];
    return at == null ? null : DateTime.now().difference(at);
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _slow?.cancel();
    super.dispose();
  }
}
