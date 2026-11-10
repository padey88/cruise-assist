# Cruise Assist

A personal in-car dashboard for Android, built clean-room for a Malaysian
driving context: prayer times, weather, fuel prices, exchange rates, alerts,
checklists and shortcuts on one glanceable grid.

**Cruise Assist is not a fork of AutoDeck SL.** See
[Why clean-room](#why-clean-room) for the reasoning; it matters for what this
project can and cannot do.

---

## Status

`0.1.0` — functional phone dashboard. Car-screen projection is partially
implemented; read [What does not work yet](#what-does-not-work-yet) before
expecting it to mirror onto a Perodua head unit.

| Area | State |
|---|---|
| Dashboard grid, ~30 widgets, editor | Working |
| Weather, air quality, 7-day forecast | Working (Open-Meteo) |
| Prayer times + Hijri date | Working (AlAdhan, JAKIM method) |
| Fuel prices | Working (data.gov.my) |
| Exchange rates | Working (BNM, open.er-api fallback) |
| Weather/earthquake alerts | Working (data.gov.my, USGS) |
| Checklist, notes, shortcuts | Working, local only |
| Transit, EV, POI, radar, radio, lyrics, sports | Working, per-widget |
| USB AOA head-unit detection + diagnostics | Working |
| Perodua Smart Link video projection | **Not implemented** |
| In-app updates from GitHub releases | Working |

## Why clean-room

The original app (`com.nasri.autodecksl`) ships its Dart code as an AOT
snapshot (`libapp.so`), so the source cannot be recovered by decompilation. Its
licence gate is also **server-side**: the app signs in with Google and asks
`autodeck.my` whether the account is activated, with a 7-day offline grace
window. Patching that check would mean circumventing a commercial licensing
system, which this project does not do.

Instead, Cruise Assist reimplements the *behaviour* from the outside: the same
public data sources, a comparable widget set, and its own UI. The result has no
licence gate at all — not because one was removed, but because none was ever
built. There are no accounts, no ads, and no telemetry.

## Features

- **Responsive widget grid.** 12 columns in landscape, 8 in portrait. Drag to
  reorder, resize with corner handles, no overlapping tiles.
- **~30 widgets.** Clock, weather, 7-day forecast, air quality, prayer, Hijri
  date, fuel, exchange rates, alerts, checklist, notes, reminders, shortcuts,
  speed, transit, nearby, EV charging, rain radar, radio, now playing, sports,
  football, calendar, qibla, Asma ul-Husna, and more.
- **Offline-first.** Every payload is cached. A failed refresh shows the last
  good value marked as stale — never silently presented as current.
- **English and Bahasa Melayu**, 24-hour clock, larger-text and high-contrast
  options.
- **USB diagnostics.** Attach a head unit and the app enumerates the USB
  accessory, reports its descriptors, and dumps the first bytes of the AOA
  handshake. This is a deliberate reverse-engineering aid.
- **In-app updates.** Checks GitHub releases, verifies the download size and
  SHA-256, and hands the APK to the system installer.

## Requirements

- Android 8.0 (API 26) or newer.
- `arm64-v8a` (Sony Xperia 10 IV, most modern phones) or `armeabi-v7a`.
- Internet only for the network-backed widgets. Local widgets work offline.

## Install

Grab the APK from Releases and sideload it. Full steps, including enabling
unknown sources and the update flow, are in [docs/INSTALL.md](docs/INSTALL.md).

## Build from source

```bash
git clone https://github.com/padey88/cruise-assist.git
cd cruise-assist
./tool/env.sh flutter pub get
./tool/env.sh flutter analyze
./tool/env.sh flutter test
./tool/env.sh flutter build apk --release --split-per-abi
```

`tool/env.sh` wires up `JAVA_HOME`, `ANDROID_HOME` and `GRADLE_USER_HOME`; edit
it if your toolchain lives elsewhere. Release signing is read from
`android/key.properties` (never committed). Without it the release build falls
back to debug signing so the APK stays installable.

## Project layout

```
lib/
  main.dart              app shell, navigation, tab wiring
  theme.dart             design tokens (canvas, accent, glass tiles)
  store.dart             versioned persistent state + migrations
  app/
    strings.dart         EN/MS localisation
    dashboard_controller.dart   refresh scheduling, payload map
  models/                Fetch<T> result type, payload models
  data/                  one file per public API + disk cache
  widgets/               tile contract + ~30 tile renderers + registry
  features/              dashboard grid, editor, settings, about
  projection/            USB/AOA facade + car-surface UI
  update/                GitHub releases client, downloader, version compare
android/                 manifest, Kotlin services, AOA controller
docs/                    ARCHITECTURE, PROJECTION, INSTALL, UPDATES
tools/                   env.sh
```

## What does not work yet

**Perodua Smart Link projection.** The original mirrors its UI onto the head
unit over USB AOA using a proprietary transport (internally "Carbit" /
"DriveDeck"). Cruise Assist implements the half that can be built and tested
without the car: accessory enumeration, permission handling, a foreground
service, descriptor diagnostics, and the car-facing UI. It does **not**
implement the video/input protocol, so it will not mirror onto an Ativa AV head
unit.

[docs/PROJECTION.md](docs/PROJECTION.md) states exactly what is missing and what
to capture from a real head unit to continue. Nothing in this repository claims
Smart Link works end-to-end.

**Deliberately excluded:** YouTube/Netflix/Disney+ playback, Widevine bypass,
scraped third-party TV streams, and any bundled assets or fonts from the
original APK.

## Data sources

All public, no API keys except where noted:

- Weather and air quality — Open-Meteo
- Prayer times — AlAdhan (JAKIM method 17)
- Fuel prices, weather warnings, transit — data.gov.my
- Exchange rates — Bank Negara Malaysia
- Earthquakes — USGS
- Radar — RainViewer
- Lyrics — LRCLIB
- Radio — radio-browser
- Sports — ESPN
- Maps/POI — OpenStreetMap (Nominatim, Overpass)

Please respect each service's rate limits. The app rate-limits per host.

## Licence

Personal project, not distributed on any app store. See [LICENSE](LICENSE).
