import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/tile_support.dart';
import '../models/data.dart';
import '../theme.dart';
import 'info_tiles.dart';
import 'tile.dart';
import 'tile_contract.dart';

class EvTile extends SimpleTile {
  const EvTile()
      : super('ev', 'EV charging', Icons.ev_station_outlined,
            initialSpan: const SizeSpan(4, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final chargers = payloadModels<EvCharger>(ctx, 'ev', EvCharger.fromJson);
    return TileCard(title: 'EV charging', icon: icon,
      child: chargers.isEmpty ? const TileMessage('No chargers found', icon: Icons.ev_station_outlined) :
        ListView.separated(padding: EdgeInsets.zero, itemCount: chargers.length,
          separatorBuilder: (_, _) => const Divider(height: 8),
          itemBuilder: (_, i) {
            final c = chargers[i];
            final status = c.status?.toLowerCase();
            final color = status == 'available' ? CA.good
                : status == 'occupied' ? Colors.orange : CA.dim;
            return Row(children: [
              Icon(Icons.ev_station, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                Text(c.status ?? 'Unknown', maxLines: 1, style: TextStyle(fontSize: 12, color: color)),
              ])),
              if (c.maxKw != null) Text('${c.maxKw}kW', style: const TextStyle(fontSize: 12)),
            ]);
          }),
    );
  }
}

class RadarTile extends SimpleTile {
  const RadarTile()
      : super('radar', 'Rain radar', Icons.radar, initialSpan: const SizeSpan(6, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final map = payloadMap(ctx, 'radar');
    final path = map['path']?.toString();
    final host = map['host']?.toString() ?? 'https://tilecache.rainviewer.com';
    final stamp = map['time']?.toString();
    if (path == null || path.isEmpty) {
      return const TileCard(title: 'Rain radar', icon: Icons.radar,
        child: TileMessage('Radar unavailable'));
    }
    final url = Uri.parse('$host/$path/256/0/0/2/1_1.png');
    // The tile URL is time-based; the cache buster keeps the newest frame.
    final busted = url.replace(queryParameters: {
      ...url.queryParameters,
      't': ?stamp,
    });

    return TileCard(title: 'Rain radar', icon: icon,
      child: ClipRRect(borderRadius: BorderRadius.circular(10),
        child: Image.network(busted.toString(), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const TileMessage('Radar image unavailable', icon: Icons.image_not_supported_outlined),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const TileMessage('Loading radar…', icon: Icons.downloading))),
    );
  }
}

class RadioTile extends SimpleTile {
  const RadioTile()
      : super('radio', 'Radio', Icons.radio_outlined, initialSpan: const SizeSpan(4, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final stations = payloadModels<RadioStation>(ctx, 'radio', RadioStation.fromJson);
    return TileCard(title: 'Radio', icon: icon,
      child: stations.isEmpty ? const TileMessage('No stations available', icon: Icons.radio_outlined) :
        ListView.separated(padding: EdgeInsets.zero, itemCount: stations.length,
          separatorBuilder: (_, _) => const Divider(height: 8),
          itemBuilder: (_, i) => Row(children: [
            const Icon(Icons.radio, size: 20, color: CA.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(stations[i].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13))),
          ])),
    );
  }
}

class YtmTile extends SimpleTile {
  const YtmTile()
      : super('ytm', 'YouTube', Icons.play_circle_outline, initialSpan: const SizeSpan(6, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final videos = payloadMaps(ctx, 'ytm');
    return TileCard(title: 'YouTube', icon: icon,
      child: videos.isEmpty ? const TileMessage('No videos available', icon: Icons.ondemand_video_outlined) :
        ListView.separated(padding: EdgeInsets.zero, itemCount: videos.length,
          separatorBuilder: (_, _) => const Divider(height: 8),
          itemBuilder: (_, i) {
            final v = videos[i];
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.play_arrow, color: CA.accent, size: 22),
              const SizedBox(width: 6),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v['title']?.toString() ?? 'Untitled', maxLines: 2,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                if (v['channel'] != null) Text(v['channel'].toString(), maxLines: 1,
                    style: const TextStyle(fontSize: 12, color: CA.dim)),
              ])),
            ]);
          }),
    );
  }
}

class YtTile extends SimpleTile {
  const YtTile()
      : super('yt', 'YouTube link', Icons.smart_display_outlined,
            initialSpan: const SizeSpan(3, 2));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final data = payloadMap(ctx, 'yt');
    final url = data['url']?.toString() ?? configString(ctx, 'url');
    final label = data['title']?.toString() ?? configString(ctx, 'title');
    return TileCard(title: 'YouTube', icon: icon,
      child: url.isEmpty && label.isEmpty
          ? const TileMessage('No YouTube link set', icon: Icons.smart_display_outlined)
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.play_circle_outline, size: 38, color: CA.accent),
              const SizedBox(height: 6),
              Text(label.isEmpty ? url : label, maxLines: 2, textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ]),
    );
  }
}

class YtPlayTile extends SimpleTile {
  const YtPlayTile()
      : super('ytplay', 'YouTube now playing', Icons.play_circle_fill,
            initialSpan: const SizeSpan(6, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final data = payloadMap(ctx, 'ytplay');
    final title = data['title']?.toString();
    return TileCard(title: 'YouTube', icon: icon,
      child: title == null
          ? const TileMessage('Nothing playing', icon: Icons.play_circle_outline)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              if (data['channel'] != null)
                Text(data['channel'].toString(),
                    style: const TextStyle(fontSize: 13, color: CA.dim)),
              const Spacer(),
              const Icon(Icons.play_arrow, size: 30, color: CA.accent),
            ]),
    );
  }
}

class SportsTile extends SimpleTile {
  const SportsTile()
      : super('sports', 'Sports', Icons.sports_score, initialSpan: const SizeSpan(6, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final events = payloadModels<SportEvent>(ctx, 'sports', SportEvent.fromJson);
    return TileCard(title: 'Sports', icon: icon,
      child: events.isEmpty ? const TileMessage('No fixtures available', icon: Icons.event_busy_outlined) :
        ListView.separated(padding: EdgeInsets.zero, itemCount: events.length,
          separatorBuilder: (_, _) => const Divider(height: 8),
          itemBuilder: (_, i) {
            final e = events[i];
            return Row(children: [
              Expanded(child: Text('${e.home} vs ${e.away}', maxLines: 1,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
              Text(e.status, style: const TextStyle(fontSize: 12, color: CA.accent)),
            ]);
          }),
    );
  }
}

class CalendarTile extends SimpleTile {
  const CalendarTile()
      : super('calendar', 'Calendar', Icons.calendar_month_outlined,
            initialSpan: const SizeSpan(4, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final events = payloadMaps(ctx, 'calendar');
    return TileCard(title: 'Calendar', icon: icon,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(shortDate(ctx.now),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Expanded(child: events.isEmpty
            ? const TileMessage('No events', icon: Icons.event_available_outlined)
            : ListView.separated(padding: EdgeInsets.zero, itemCount: events.length,
                separatorBuilder: (_, _) => const Divider(height: 8),
                itemBuilder: (_, i) {
                  final e = events[i];
                  final at = e['at'] == null ? null : DateTime.tryParse(e['at'].toString());
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 46, child: Text(at == null ? '--:--' : hhmm(at.toLocal()),
                        style: const TextStyle(fontSize: 12, color: CA.accent))),
                    Expanded(child: Text(e['title']?.toString() ?? 'Event', maxLines: 2,
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  ]);
                })),
      ]),
    );
  }
}

class QiblaTile extends SimpleTile {
  const QiblaTile()
      : super('qibla', 'Qibla', Icons.explore_outlined, initialSpan: const SizeSpan(4, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final lat = configDouble(ctx, 'lat');
    final lng = configDouble(ctx, 'lng');
    if (lat == null || lng == null) {
      return const TileCard(title: 'Qibla', icon: Icons.explore_outlined,
        child: TileMessage('Set your location to see the qibla', icon: Icons.location_disabled));
    }
    final bearing = qiblaBearing(lat, lng);
    return TileCard(title: 'Qibla', icon: icon,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 110, height: 110, child: CustomPaint(
          painter: _BearingPainter(bearing: bearing),
          child: Center(child: Text('${bearing.round()}°',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
        )),
        const SizedBox(height: 6),
        const Text('Toward the Kaaba', style: TextStyle(fontSize: 12, color: CA.dim)),
      ])),
    );
  }
}

class _BearingPainter extends CustomPainter {
  final double bearing;
  const _BearingPainter({required this.bearing});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = CA.edge;
    canvas.drawCircle(center, radius, ring);
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.drawLine(
        center + Offset(math.cos(angle) * (radius - 7), math.sin(angle) * (radius - 7)),
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        Paint()..color = CA.edge,
      );
    }
    final rad = (bearing - 90) * math.pi / 180;
    final tip = center + Offset(math.cos(rad) * (radius - 10), math.sin(rad) * (radius - 10));
    final left = center + Offset(math.cos(rad + 2.5) * 12, math.sin(rad + 2.5) * 12);
    final right = center + Offset(math.cos(rad - 2.5) * 12, math.sin(rad - 2.5) * 12);
    final paint = Paint()..color = CA.accent;
    canvas.drawLine(tip, left, paint);
    canvas.drawLine(left, right, paint);
    canvas.drawLine(right, tip, paint);
  }
  @override
  bool shouldRepaint(_BearingPainter old) => old.bearing != bearing;
}

class AsmaTile extends SimpleTile {
  const AsmaTile()
      : super('asma', 'Asma ul-Husna', Icons.auto_awesome_outlined,
            initialSpan: const SizeSpan(4, 2));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final index = (ctx.now.day - 1) % asmaUlHusna.length;
    final name = asmaUlHusna[index];
    return TileCard(title: 'Asma ul-Husna', icon: icon,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(name.$1, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(name.$2, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: CA.dim)),
        const SizedBox(height: 2),
        Text('Name ${index + 1} of ${asmaUlHusna.length}',
            style: const TextStyle(fontSize: 11, color: CA.dim)),
      ]),
    );
  }
}

class VelaTile extends SimpleTile {
  const VelaTile()
      : super('vela', 'Vela', Icons.sailing_outlined, initialSpan: const SizeSpan(3, 2));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final data = payloadMap(ctx, 'vela');
    final wind = data['windKph'] ?? data['wind'];
    final dir = data['direction'] ?? data['dir'];
    return TileCard(title: 'Vela', icon: icon,
      child: wind == null ? const TileMessage('No sailing data', icon: Icons.sailing_outlined) :
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$wind', style: const TextStyle(fontSize: 30)),
          Text('km/h wind${dir == null ? '' : ' · $dir'}',
              style: const TextStyle(fontSize: 12, color: CA.dim)),
        ]),
    );
  }
}

class MapTile extends SimpleTile {
  const MapTile()
      : super('map', 'Map', Icons.map_outlined, initialSpan: const SizeSpan(6, 4));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final map = payloadMap(ctx, 'map');
    final lat = map['lat'] ?? configDouble(ctx, 'lat');
    final lng = map['lng'] ?? configDouble(ctx, 'lng');
    final label = map['label']?.toString();
    return TileCard(title: 'Map', icon: icon,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.map, size: 44, color: CA.accent),
        const SizedBox(height: 6),
        if (label != null) Text(label, style: const TextStyle(fontSize: 14)),
        if (lat != null && lng != null)
          Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12, color: CA.dim)),
      ])),
    );
  }
}

class NavTile extends SimpleTile {
  const NavTile()
      : super('nav', 'Navigation', Icons.navigation_outlined,
            initialSpan: const SizeSpan(6, 3));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final nav = payloadMap(ctx, 'nav');
    final instruction = nav['instruction']?.toString();
    final distance = nav['distanceM'];
    final eta = nav['eta'] == null ? null : DateTime.tryParse(nav['eta'].toString());
    return TileCard(title: 'Navigation', icon: icon,
      child: instruction == null ? const TileMessage('No active route', icon: Icons.navigation_outlined) :
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(instruction, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (distance != null)
            Text('${(distance as num).round()} m', style: const TextStyle(fontSize: 15, color: CA.accent)),
          if (eta != null) Text('ETA ${hhmm(eta.toLocal())}',
              style: const TextStyle(fontSize: 12, color: CA.dim)),
        ]),
    );
  }
}

class ReminderTile extends SimpleTile {
  const ReminderTile()
      : super('reminder', 'Reminder', Icons.notifications_active_outlined,
            initialSpan: const SizeSpan(4, 2));
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final reminders = payloadMaps(ctx, 'reminder');
    final text = configString(ctx, 'text');
    return TileCard(title: 'Reminder', icon: icon,
      child: reminders.isEmpty && text.isEmpty
          ? const TileMessage('No reminders', icon: Icons.notifications_none_outlined)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (text.isNotEmpty) Text(text, style: const TextStyle(fontSize: 15)),
              Expanded(child: ListView.separated(padding: EdgeInsets.zero,
                  itemCount: reminders.length,
                  separatorBuilder: (_, _) => const Divider(height: 6),
                  itemBuilder: (_, i) {
                    final r = reminders[i];
                    final at = r['at'] == null ? null : DateTime.tryParse(r['at'].toString());
                    return Row(children: [
                      const Icon(Icons.flag_outlined, size: 18, color: CA.accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r['title']?.toString() ?? 'Reminder',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      if (at != null) Text(hhmm(at.toLocal()),
                          style: const TextStyle(fontSize: 12, color: CA.dim)),
                    ]);
                  })),
            ]),
    );
  }
}
