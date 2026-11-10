# Cruise Assist — Architecture & Subagent Contract

Clean-room reimplementation of the AutoDeck SL 2.1.0 (54) feature set for personal use.
No licence gate, no accounts, no telemetry, no ads. Rebranded "Cruise Assist".

## Why clean-room
The original is Flutter **AOT** (`libapp.so`, 11 MB, no Dart kernel). Source is not
recoverable; the license check is server-side (`autodeck.my` + Google sign-in + owner
activation). We do not patch DRM. We implement equivalent behaviour ourselves.

## Package
- `my.kulnem.cruise_assist` / app label **Cruise Assist**
- minSdk 26, targetSdk 36, compileSdk 36
- ABIs: arm64-v8a, armeabi-v7a (Xperia 10 IV is arm64-v8a)

## File ownership (STRICT — do not edit files you do not own)
| Owner | Paths |
|---|---|
| core (main agent) | `lib/main.dart`, `lib/app/*`, `lib/theme.dart`, `lib/models/*`, `lib/store.dart`, `pubspec.yaml`, `android/**` |
| SVC | `lib/data/**` (all services, caches, parsers) |
| WID | `lib/widgets/**`, `lib/features/**` |
| CAR | `android/app/src/main/kotlin/**`, `lib/projection/**`, `lib/platform/**` |
| UPD | `lib/update/**`, `.github/workflows/**` |
| DOC | `docs/**`, `README.md`, `CHANGELOG.md` |

## Shared contracts (owned by core — treat as frozen API)

### `lib/models/result.dart`
```dart
class Fetch<T> {
  final T? value;        // last good value
  final DateTime? at;    // when value was produced
  final bool stale;      // value is cached, not fresh
  final String? message; // human readable problem, null when ok
  const Fetch({this.value, this.at, this.stale = false, this.message});
  bool get ok => message == null;
  Fetch<T> asStale(String m) => Fetch(value: value, at: at, stale: true, message: m);
}
```

### `lib/data/api.dart` — every service returns `Future<Fetch<T>>`
Rules:
- Never throw to the UI. Network/parse failure ⇒ `Fetch` carrying the cached value and a message.
- Never silently mark stale data as current: `stale=true` whenever `at` is older than the refresh interval.
- All HTTP through the injected `http.Client` (`ApiClient`), so tests use fakes.
- No API keys in source. If an endpoint needs a key, it must read from
  `--dart-define` and degrade gracefully to "unavailable".

### Widget contract (`lib/widgets/registry.dart`)
Every tile implements:
```dart
abstract class TileRenderer {
  String get id;                 // 'clock', 'weather', ...
  String get label;              // localized display name
  IconData get icon;
  SizeSpan get defaultSpan;      // cells w x h on a 12x8 grid
  SizeSpan get minSpan;
  SizeSpan get maxSpan;
  Widget build(BuildContext c, TileContext ctx);
}
```
`TileContext` carries the live `Fetch` payloads, the tile's own config map, the
current time, and whether the surface is the phone or the car screen.
Tiles must degrade to a labelled placeholder when their payload is missing.

## Feature inventory (parity target)
Widget ids from original: air, alerts, asma, calendar, checklist, clock, ev,
football, forecast, fuel, fx, hijri, map, music, nav, nearby, notes, prayer,
qibla, radar, radio, reminder, shortcuts, speed, sports, transit, vela,
weather, yt, ytm, ytplay.

Data sources (public, no key unless noted):
- Weather/AQI forecast: `api.open-meteo.com`, `air-quality-api.open-meteo.com`
- Weather warnings + earthquakes: `api.data.gov.my/weather/warning/`
- Fuel prices: `api.data.gov.my` (weekly RON95/97/diesel)
- Transit vehicles: `api.data.gov.my/gtfs-realtime/vehicle-position/<agency>`
- Prayer: `api.aladhan.com/v1` (method=JAKIM 17) + `solat.my/api`
- Hijri: computed (Umm al-Qura) — no network
- FX: `api.bnm.gov.my/public/exchange-rate`, fallback `open.er-api.com`
- Radar: `api.rainviewer.com/public/weather-maps.json`
- EV: `api.openchargemap.io/v3/poi` (key via dart-define; optional)
- Nearby/POI: Overpass (`overpass-api.de`, mirrors)
- Reverse geocode: `nominatim.openstreetmap.org` (respect 1 req/s, set UA)
- Sports: `site.api.espn.com`, optional `api.football-data.org/v4` (key)
- Lyrics: `lrclib.net/api`
- Radio: `de1.api.radio-browser.info`
- TV: user-supplied playlist only (no scraped third-party streams)

## Non-goals / deliberate exclusions
- No YouTube/Netflix/Disney+ session hijacking, no Widevine bypass, no DRM.
- No bundled third-party fonts/assets from the original APK.
- No scraping of subscription services.

## Build
`tool/env.sh` sets JAVA_HOME/ANDROID_HOME. Serialize builds — this host has 4 GB RAM.
