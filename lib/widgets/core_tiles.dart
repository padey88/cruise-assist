import 'package:flutter/material.dart';

import '../models/data.dart';
import '../theme.dart';
import 'tile.dart';
import 'tile_contract.dart';

String formatClock(DateTime now, {required bool use24h, bool seconds = false}) {
  final h = use24h ? now.hour : (now.hour % 12 == 0 ? 12 : now.hour % 12);
  return '${use24h ? two(h) : h}:${two(now.minute)}'
      '${seconds ? ':${two(now.second)}' : ''}';
}

String clockMeridiem(DateTime now) => now.hour < 12 ? 'AM' : 'PM';

class ClockTile extends SimpleTile {
  const ClockTile()
      : super('clock', 'Clock', Icons.schedule,
            initialSpan: const SizeSpan(6, 3));

  @override
  Widget build(BuildContext context, TileContext ctx) {
    final use24h = configBool(ctx, 'use24h', true);
    final seconds = configBool(ctx, 'showSeconds');
    final prayer = payloadModel<PrayerDay>(ctx, 'prayer', PrayerDay.fromJson);
    final next = prayer?.next(ctx.now);
    final weekday = const [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ][ctx.now.weekday - 1];
    return TileCard(
      title: 'Clock',
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatClock(ctx.now, use24h: use24h, seconds: seconds),
                  style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w300, height: 1)),
              if (!use24h) ...[
                const SizedBox(width: 7),
                Padding(padding: const EdgeInsets.only(bottom: 5),
                    child: Text(clockMeridiem(ctx.now),
                        style: const TextStyle(fontSize: 18, color: CA.accent))),
              ],
            ]),
          ),
          const SizedBox(height: 7),
          Text('$weekday · ${shortDate(ctx.now)}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CA.dim, fontSize: 13)),
          if (next != null) ...[
            const SizedBox(height: 8),
            TileChip('${next.name} · ${hhmm(next.at)}', icon: Icons.mosque_outlined),
          ],
        ],
      ),
    );
  }
}

class WeatherTile extends SimpleTile {
  const WeatherTile()
      : super('weather', 'Weather', Icons.cloud_outlined,
            initialSpan: const SizeSpan(6, 3));

  @override
  Widget build(BuildContext context, TileContext ctx) {
    final w = payloadModel<WeatherNow>(ctx, 'weather', WeatherNow.fromJson);
    return TileCard(
      title: configString(ctx, 'city', 'Weather'),
      icon: icon,
      child: w == null ? const TileMessage('Weather unavailable') : Row(children: [
        Icon(weatherIcon(w.weatherCode), color: CA.accent, size: 48),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${w.tempC.round()}°C',
                style: const TextStyle(fontSize: 38, height: 1.05, fontWeight: FontWeight.w400)),
            Text(weatherDescription(w.weatherCode),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: CA.dim)),
            const SizedBox(height: 4),
            Text('Feels ${w.feelsC.round()}° · ${w.humidity}% humidity',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            Text('Wind ${w.windKph.round()} km/h',
                style: const TextStyle(fontSize: 12, color: CA.dim)),
          ],
        )),
      ]),
    );
  }
}

class ForecastTile extends SimpleTile {
  const ForecastTile()
      : super('forecast', '7-day forecast', Icons.calendar_view_week,
            initialSpan: SizeSpan.full, maximumSpan: const SizeSpan(12, 4));

  @override
  Widget build(BuildContext context, TileContext ctx) {
    final days = payloadModels<DayForecast>(ctx, 'forecast', DayForecast.fromJson).take(7).toList();
    return TileCard(title: '7-day forecast', icon: icon,
      child: days.isEmpty ? const TileMessage('Forecast unavailable') :
          LayoutBuilder(builder: (context, constraints) {
            final low = days.map((d) => d.minC).reduce((a, b) => a < b ? a : b);
            final high = days.map((d) => d.maxC).reduce((a, b) => a > b ? a : b);
            final range = (high - low).abs() < .1 ? 1.0 : high - low;
            return Row(children: [
              for (final d in days)
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(children: [
                    Text(_day(d.day), style: const TextStyle(fontSize: 12, color: CA.dim)),
                    const Spacer(),
                    Icon(weatherIcon(d.code), size: 20, color: CA.accent),
                    const SizedBox(height: 3),
                    Text('${d.maxC.round()}°', style: const TextStyle(fontSize: 12)),
                    SizedBox(height: 32,
                      child: Align(alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 7,
                          height: 6 + 26 * (d.maxC - d.minC) / range,
                          decoration: BoxDecoration(color: CA.accentDeep,
                              borderRadius: BorderRadius.circular(4)),
                        ))),
                    Text('${d.minC.round()}°', style: const TextStyle(fontSize: 12, color: CA.dim)),
                  ]),
                )),
            ]);
          }),
    );
  }

  String _day(DateTime d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
}

class PrayerTile extends SimpleTile {
  const PrayerTile()
      : super('prayer', 'Prayer times', Icons.mosque_outlined,
            initialSpan: const SizeSpan(4, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final day = payloadModel<PrayerDay>(ctx, 'prayer', PrayerDay.fromJson);
    final next = day?.next(ctx.now);
    return TileCard(title: 'Prayer times', icon: icon,
      child: day == null ? const TileMessage('Prayer times unavailable') :
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (next != null) ...[
              Expanded(flex: 3, child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEXT', style: TextStyle(color: CA.accent, fontSize: 12)),
                  Text(next.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
                  Text(hhmm(next.at), style: const TextStyle(fontSize: 20)),
                  Text(countdown(next.at.difference(ctx.now)),
                      style: const TextStyle(fontSize: 12, color: CA.dim)),
                ],
              )),
              const SizedBox(width: 10),
            ],
            Expanded(flex: 2, child: ListView(
              padding: EdgeInsets.zero,
              children: [for (final t in day.times)
                Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(t.name, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12,
                            color: t == next ? CA.accent : CA.ink))),
                    Text(hhmm(t.at), style: const TextStyle(fontSize: 12)),
                  ])),
              ],
            )),
          ]),
    );
  }
}

class FuelTile extends SimpleTile {
  const FuelTile()
      : super('fuel', 'Fuel prices', Icons.local_gas_station_outlined,
            initialSpan: const SizeSpan(4, 2));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final fuel = payloadModel<FuelPrices>(ctx, 'fuel', FuelPrices.fromJson);
    return TileCard(title: 'Fuel prices', icon: icon,
      child: fuel == null ? const TileMessage('Fuel prices unavailable') : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Row(children: [
            _price('RON 95', fuel.ron95),
            _price('RON 97', fuel.ron97),
            _price('Diesel', fuel.diesel),
          ])),
          const SizedBox(height: 4),
          Text('Effective ${shortDate(fuel.effectiveFrom)}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: CA.dim)),
        ]),
    );
  }
  Widget _price(String name, double? value) => Expanded(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(name, maxLines: 1, style: const TextStyle(fontSize: 12, color: CA.dim)),
      const SizedBox(height: 4),
      FittedBox(child: Text(value == null ? '—' : 'RM ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
    ],
  ));
}
