import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/hijri.dart';
import '../models/data.dart';
import '../theme.dart';
import 'tile.dart';
import 'tile_contract.dart';

class HijriTile extends SimpleTile {
  const HijriTile()
    : super(
        'hijri',
        'Hijri date',
        Icons.dark_mode_outlined,
        initialSpan: const SizeSpan(4, 2),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final h = gregorianToHijri(ctx.now);
    return TileCard(
      title: 'Hijri date',
      icon: icon,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            h.monthName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          Text(
            '${h.day} · ${h.year} AH',
            style: const TextStyle(fontSize: 24, color: CA.accent),
          ),
          Text(
            shortDate(ctx.now),
            style: const TextStyle(fontSize: 12, color: CA.dim),
          ),
        ],
      ),
    );
  }
}

({Color color, String band}) airBand(int aqi) {
  if (aqi <= 50) return (color: CA.good, band: 'Good');
  if (aqi <= 100) return (color: const Color(0xFFFFDE59), band: 'Moderate');
  if (aqi <= 150) return (color: Colors.orange, band: 'Sensitive groups');
  if (aqi <= 200) return (color: CA.danger, band: 'Unhealthy');
  if (aqi <= 300) return (color: Colors.purpleAccent, band: 'Very unhealthy');
  return (color: const Color(0xFF9E554E), band: 'Hazardous');
}

class AirTile extends SimpleTile {
  const AirTile()
    : super('air', 'Air quality', Icons.air, initialSpan: const SizeSpan(3, 2));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final air = payloadModel<AirQuality>(ctx, 'air', AirQuality.fromJson);
    return TileCard(
      title: 'Air quality',
      icon: icon,
      child: air == null
          ? const TileMessage('Air quality unavailable')
          : Builder(
              builder: (_) {
                final band = airBand(air.usAqi);
                return Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: band.color, width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${air.usAqi}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: band.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            band.band,
                            maxLines: 2,
                            style: TextStyle(
                              color: band.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'US AQI',
                            style: const TextStyle(color: CA.dim, fontSize: 12),
                          ),
                          if (air.pm25 != null)
                            Text(
                              'PM2.5 ${air.pm25!.toStringAsFixed(1)} µg/m³',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class FxTile extends SimpleTile {
  const FxTile()
    : super(
        'fx',
        'Exchange rates',
        Icons.currency_exchange,
        initialSpan: const SizeSpan(4, 2),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final rates = payloadModels<FxRate>(ctx, 'fx', FxRate.fromJson);
    return TileCard(
      title: '1 unit = MYR',
      icon: icon,
      child: rates.isEmpty
          ? const TileMessage('Exchange rates unavailable')
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rates.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (_, i) => Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      rates[i].code,
                      style: const TextStyle(
                        color: CA.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rates[i].myr.toStringAsFixed(4),
                    style: const TextStyle(
                      fontSize: 16,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

Color severityColor(String? severity) {
  switch (severity?.toLowerCase()) {
    case 'extreme':
    case 'severe':
    case 'high':
      return CA.danger;
    case 'moderate':
    case 'medium':
      return Colors.orange;
    default:
      return const Color(0xFFFFDE59);
  }
}

class AlertsTile extends SimpleTile {
  const AlertsTile()
    : super(
        'alerts',
        'Alerts',
        Icons.warning_amber_rounded,
        initialSpan: const SizeSpan(6, 2),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final alerts = payloadModels<Alert>(ctx, 'alerts', Alert.fromJson);
    return TileCard(
      title: 'Alerts',
      icon: icon,
      child: alerts.isEmpty
          ? const TileMessage(
              'No warnings right now',
              icon: Icons.check_circle_outline,
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (_, i) {
                final a = alerts[i];
                final color = severityColor(a.severity);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, size: 21, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (a.body?.isNotEmpty == true)
                            Text(
                              a.body!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CA.dim,
                              ),
                            ),
                          Text(
                            a.source,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 12, color: CA.dim),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class SpeedTile extends SimpleTile {
  const SpeedTile()
    : super(
        'speed',
        'Speed',
        Icons.speed,
        initialSpan: const SizeSpan(4, 3),
        supportedSurfaces: const {Surface.phone, Surface.car},
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final raw = ctx.payloads['speed'];
    final value = raw is num
        ? raw.toDouble()
        : raw is Map
        ? (raw['speedKph'] as num?)?.toDouble()
        : null;
    final mph = configString(ctx, 'unit', 'kmh') == 'mph';
    final shown = value == null ? null : value * (mph ? 0.621371 : 1);
    final limit = configDouble(ctx, 'limit');
    final over = shown != null && limit != null && shown > limit;
    return TileCard(
      title: 'Speed',
      icon: icon,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shown?.round().toString() ?? '—',
                style: TextStyle(
                  fontSize: 72,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  color: over ? CA.danger : CA.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                mph ? 'mph' : 'km/h',
                style: const TextStyle(fontSize: 18, color: CA.accent),
              ),
              if (configBool(ctx, 'showGps'))
                const Text(
                  'GPS',
                  style: TextStyle(fontSize: 12, color: CA.dim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MusicTile extends SimpleTile {
  const MusicTile()
    : super(
        'music',
        'Now playing',
        Icons.music_note_outlined,
        initialSpan: const SizeSpan(6, 3),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final lyrics = payloadModel<Lyrics>(ctx, 'lyrics', Lyrics.fromJson);
    final track = payloadMap(ctx, 'music');
    final title = lyrics?.track ?? track['title']?.toString();
    final artist = lyrics?.artist ?? track['artist']?.toString();
    final elapsedMs = (track['positionMs'] as num?)?.toInt() ?? 0;
    final active = lyrics == null
        ? -1
        : lyrics.lines.lastIndexWhere((l) => l.at.inMilliseconds <= elapsedMs);
    return TileCard(
      title: 'Now playing',
      icon: icon,
      child: title == null
          ? const TileMessage('Nothing playing', icon: Icons.music_off_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (artist != null)
                  Text(
                    artist,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12, color: CA.dim),
                  ),
                const SizedBox(height: 5),
                Expanded(
                  child: lyrics == null || lyrics.lines.isEmpty
                      ? const Center(
                          child: Icon(Icons.lyrics_outlined, color: CA.dim),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: lyrics.lines.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              lyrics.lines[i].text,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 12,
                                color: i == active ? CA.accent : CA.dim,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class FootballTile extends SimpleTile {
  const FootballTile()
    : super(
        'football',
        'Football',
        Icons.sports_soccer,
        initialSpan: const SizeSpan(6, 3),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final events = payloadModels<SportEvent>(
      ctx,
      'football',
      SportEvent.fromJson,
    );
    return TileCard(
      title: 'Football',
      icon: icon,
      child: events.isEmpty
          ? const TileMessage(
              'Football fixtures unavailable',
              icon: Icons.event_busy_outlined,
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: events.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (_, i) {
                final e = events[i];
                final score = e.homeScore != null
                    ? '${e.homeScore} – ${e.awayScore ?? '—'}'
                    : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.league} · ${e.status}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: CA.accent),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${e.home}\n${e.away}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          score ??
                              (e.kickoff == null
                                  ? 'TBD'
                                  : hhmm(e.kickoff!.toLocal())),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class TransitTile extends SimpleTile {
  const TransitTile()
    : super(
        'transit',
        'Buses & trains',
        Icons.directions_transit_outlined,
        initialSpan: const SizeSpan(6, 3),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final vehicles = payloadModels<TransitVehicle>(
      ctx,
      'transit',
      TransitVehicle.fromJson,
    );
    return TileCard(
      title: 'Buses & trains',
      icon: icon,
      child: vehicles.isEmpty
          ? const TileMessage(
              'Live transit unavailable',
              icon: Icons.directions_bus_outlined,
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: vehicles.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (_, i) {
                final v = vehicles[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  minLeadingWidth: 30,
                  leading: const Icon(Icons.directions_bus, color: CA.accent),
                  title: Text(
                    v.route.isEmpty ? 'Unassigned route' : v.route,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    v.id,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${v.lat.toStringAsFixed(3)}, ${v.lng.toStringAsFixed(3)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}

class NearbyTile extends SimpleTile {
  const NearbyTile()
    : super(
        'nearby',
        'Nearby',
        Icons.place_outlined,
        initialSpan: const SizeSpan(4, 3),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final places = payloadModels<Place>(ctx, 'nearby', Place.fromJson);
    return TileCard(
      title: 'Nearby',
      icon: icon,
      child: places.isEmpty
          ? const TileMessage(
              'Nearby places unavailable',
              icon: Icons.location_off_outlined,
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: places.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (_, i) {
                final p = places[i];
                final distance = p.distanceM;
                return Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      color: CA.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (p.kind != null)
                            Text(
                              p.kind!,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CA.dim,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (distance != null)
                      Text(
                        distance < 1000
                            ? '${distance.round()} m'
                            : '${(distance / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

double qiblaBearing(double lat, double lng) {
  const kaabaLat = 21.4225;
  const kaabaLng = 39.8262;
  final phi1 = lat * math.pi / 180;
  final phi2 = kaabaLat * math.pi / 180;
  final dLng = (kaabaLng - lng) * math.pi / 180;
  final y = math.sin(dLng);
  final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
