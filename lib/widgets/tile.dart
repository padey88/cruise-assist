import 'package:flutter/material.dart';

import '../models/result.dart';
import '../theme.dart';
import 'tile_contract.dart';

/// Common card chrome. Keeping clipping here prevents large type and images
/// from leaking into neighbouring grid cells.
class TileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  const TileCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: CA.tile(),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 28,
                child: Row(children: [
                  Icon(icon, size: 18, color: CA.accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  if (trailing != null) trailing!,
                ]),
              ),
              const SizedBox(height: 6),
              Expanded(child: child),
            ],
          ),
        ),
      );
}

class TileMessage extends StatelessWidget {
  final String label;
  final IconData icon;
  const TileMessage(this.label, {super.key, this.icon = Icons.cloud_off});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: CA.dim, size: 26),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CA.dim, fontSize: 12)),
        ]),
      );
}

class TileChip extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;
  const TileChip(this.text, {super.key, this.icon, this.color = CA.accent});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12)),
          ),
        ]),
      );
}

/// Minimum 48px target, including on the car surface.
class TileIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const TileIconButton(this.icon,
      {super.key, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        visualDensity: VisualDensity.compact,
      );
}

abstract class SimpleTile extends TileRenderer {
  final String tileId;
  final String title;
  final IconData tileIcon;
  final SizeSpan initialSpan;
  final SizeSpan minimumSpan;
  final SizeSpan maximumSpan;
  final Set<Surface> supportedSurfaces;

  const SimpleTile(
    this.tileId,
    this.title,
    this.tileIcon, {
    this.initialSpan = SizeSpan.one,
    this.minimumSpan = const SizeSpan(2, 2),
    this.maximumSpan = const SizeSpan(12, 6),
    this.supportedSurfaces = const {Surface.phone, Surface.car},
  });

  @override
  String get id => tileId;
  @override
  String label(BuildContext context) => title;
  @override
  IconData get icon => tileIcon;
  @override
  SizeSpan get defaultSpan => initialSpan;
  @override
  SizeSpan get minSpan => minimumSpan;
  @override
  SizeSpan get maxSpan => maximumSpan;
  @override
  Set<Surface> get surfaces => supportedSurfaces;
}

T? payloadValue<T>(TileContext ctx, String key) {
  final raw = ctx.payloads[key];
  if (raw is Fetch<T>) return raw.value;
  // Accept decoded/direct values as well, which keeps previews and cached
  // payloads useful. The normal application path remains Fetch<T>.
  if (raw is T) return raw;
  return null;
}

List<T> payloadList<T>(TileContext ctx, String key) {
  final value = payloadValue<dynamic>(ctx, key);
  if (value is List) return value.whereType<T>().toList(growable: false);
  return const [];
}

Map<String, dynamic> payloadMap(TileContext ctx, String key) {
  final value = payloadValue<dynamic>(ctx, key);
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

String configString(TileContext ctx, String key, [String fallback = '']) {
  final value = ctx.config[key];
  return value == null || value.toString().trim().isEmpty
      ? fallback
      : value.toString();
}

double? configDouble(TileContext ctx, String key) {
  final value = ctx.config[key];
  return value is num ? value.toDouble() : double.tryParse('$value');
}

bool configBool(TileContext ctx, String key, [bool fallback = false]) =>
    ctx.config[key] is bool ? ctx.config[key] as bool : fallback;

String two(int value) => value.toString().padLeft(2, '0');
String hhmm(DateTime value) => '${two(value.hour)}:${two(value.minute)}';

String countdown(Duration value) {
  final safe = value.isNegative ? Duration.zero : value;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  return hours > 0 ? '$hours h ${two(minutes)} min' : '$minutes min ${two(seconds)} s';
}

String shortDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String weatherDescription(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Cloudy';
}

IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm_outlined;
  if (code >= 51) return Icons.umbrella_outlined;
  return Icons.cloud_outlined;
}
