import 'core_tiles.dart';
import 'extra_tiles.dart';
import 'info_tiles.dart';
import 'personal_tiles.dart';
import 'tile_contract.dart';

/// Every widget the app can place on the dashboard. The ids match the
/// original product's widget keys so existing layouts keep working.
final List<TileRenderer> _allTiles = [
  const ClockTile(),
  const WeatherTile(),
  const ForecastTile(),
  const AirTile(),
  const PrayerTile(),
  const HijriTile(),
  const FuelTile(),
  const FxTile(),
  const AlertsTile(),
  const ChecklistTile(),
  const NotesTile(),
  const ReminderTile(),
  const ShortcutsTile(),
  const SpeedTile(),
  const TransitTile(),
  const NearbyTile(),
  const EvTile(),
  const RadarTile(),
  const RadioTile(),
  const MusicTile(),
  const YtmTile(),
  const SportsTile(),
  const FootballTile(),
  const CalendarTile(),
  const QiblaTile(),
  const AsmaTile(),
  const VelaTile(),
  const MapTile(),
  const NavTile(),
];

/// All registered tile renderers, in display order.
List<TileRenderer> allTiles() => List.unmodifiable(_allTiles);

/// Looks a renderer up by its widget key.
TileRenderer? tileById(String id) {
  for (final tile in _allTiles) {
    if (tile.id == id) return tile;
  }
  return null;
}

/// Renderers usable on a given screen surface.
List<TileRenderer> tilesForSurface(Surface s) =>
    _allTiles.where((t) => t.surfaces.contains(s)).toList(growable: false);
