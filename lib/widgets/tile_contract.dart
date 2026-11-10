import 'package:flutter/material.dart';

/// Grid cell span. The dashboard grid is 12 columns wide in landscape and
/// 8 in portrait; heights use square-ish rows.
@immutable
class SizeSpan {
  final int w;
  final int h;
  const SizeSpan(this.w, this.h);

  static const SizeSpan one = SizeSpan(3, 2);
  static const SizeSpan wide = SizeSpan(6, 2);
  static const SizeSpan tall = SizeSpan(3, 4);
  static const SizeSpan big = SizeSpan(6, 4);
  static const SizeSpan full = SizeSpan(12, 4);

  @override
  bool operator ==(Object other) =>
      other is SizeSpan && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(w, h);

  @override
  String toString() => '${w}x$h';
}

/// Where the UI is being painted. Some tiles (map, video) are phone-only;
/// others (clock, speed) are car-first.
enum Surface { phone, car }

/// Everything a tile needs, passed in by the dashboard. Tiles must not reach
/// out to services directly — the dashboard refreshes payloads on a schedule.
@immutable
class TileContext {
  final DateTime now;
  final Surface surface;
  final Map<String, dynamic> config;
  final Map<String, dynamic> payloads;
  final void Function(Map<String, dynamic> nextConfig) onConfigChanged;
  final void Function(String tileId) onRemove;

  const TileContext({
    required this.now,
    required this.surface,
    required this.config,
    required this.payloads,
    required this.onConfigChanged,
    required this.onRemove,
  });

  /// Typed read of a payload slot, e.g. `payload<WeatherData>('weather')`.
  T? payload<T>(String key) {
    final v = payloads[key];
    return v is T ? v : null;
  }

  TileContext copyWith({DateTime? now, Map<String, dynamic>? payloads}) =>
      TileContext(
        now: now ?? this.now,
        surface: surface,
        config: config,
        payloads: payloads ?? this.payloads,
        onConfigChanged: onConfigChanged,
        onRemove: onRemove,
      );
}

/// A dashboard tile. Register in `lib/widgets/registry.dart`.
abstract class TileRenderer {
  const TileRenderer();

  /// Stable id; matches the original app's widget keys where one exists.
  String get id;

  /// Localized display name, resolved via AppStrings at build time.
  String label(BuildContext context);

  IconData get icon;

  SizeSpan get defaultSpan;
  SizeSpan get minSpan;
  SizeSpan get maxSpan;

  /// Surfaces this tile supports. Default: both.
  Set<Surface> get surfaces => const {Surface.phone, Surface.car};

  Widget build(BuildContext context, TileContext ctx);
}
