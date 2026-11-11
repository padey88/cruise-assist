# Changelog

All notable changes to Cruise Assist are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet.

## [0.1.0] - 2026-11-10

First working build: a phone dashboard with no licence gate, no accounts, no
ads and no telemetry.

### Added

- **Dashboard grid** — 12-column landscape / 8-column portrait layout with
  drag-to-reorder, corner-handle resize, overlap prevention, and per-tile config
  persisted across launches.
- **Widgets** — clock, weather, 7-day forecast, air quality, prayer times,
  Hijri date, fuel prices, exchange rates, weather/earthquake alerts, checklist,
  notes, reminders, app shortcuts, speed, transit, nearby places, EV charging,
  rain radar, radio, now playing, sports, football, calendar, qibla, and
  Asma ul-Husna.
- **Data layer** — one service per public API, all returning a `Fetch<T>`
  result carrying the last good value, its timestamp, a stale flag and a
  human-readable problem description. Services never throw at the UI.
- **Offline cache** — every payload is written to disk and restored on launch,
  so the dashboard paints immediately and degrades visibly rather than blankly.
- **Localisation** — English and Bahasa Melayu.
- **Settings** — 24-hour clock, seconds, larger text, high contrast, language,
  prayer zone, weather location.
- **USB head-unit diagnostics** — enumerates USB accessories over AOA, reports
  descriptors, and dumps the first bytes of the handshake. This is a
  reverse-engineering aid, not a working projection pipeline.
- **Car-surface UI** — a head-unit-shaped preview built from the same payloads
  as the phone dashboard.
- **In-app updates** — checks GitHub releases, compares semver including
  prerelease precedence, streams the APK with progress, verifies size and
  SHA-256, and hands it to the system installer.
- **CI** — analyze and test on every push; tagged releases build and publish
  APKs with the changelog section as the release body.

### Verified

- `flutter analyze` — 0 issues.
- `flutter test` — 244 passing, 12 skipped (live-network tests, run with `LIVE=1`).
- Release APKs built and signed; universal, arm64-v8a, armeabi-v7a, x86_64.
- Installed and launched on a physical Android device (Fire TV, API 25,
  1920x1080): process alive, no `FATAL`/`AndroidRuntime` in logcat, dashboard
  rendered with live weather, prayer, fuel and clock data.
- In-app updater checked against the live public release: API returns
  `tag_name`, per-asset `digest`, and the universal APK is selected. All
  published `sha256` digests match the local build hashes.

See [docs/VERIFICATION.md](docs/VERIFICATION.md) for exactly what was and was
not exercised.

### Known limitations

- **Perodua Smart Link projection is not implemented.** The original
  communicates with the head unit over USB AOA using a proprietary
  (Carbit/DriveDrive) transport. Cruise Assist implements accessory detection
  and diagnostics only; it will not mirror onto an Ativa AV head unit. See
  `docs/PROJECTION.md`.
- Deliberately excluded: YouTube/Netflix/Disney+ playback, Widevine bypass,
  scraped third-party TV streams, and any bundled assets or fonts from the
  original APK.
- Release APKs fall back to debug signing when `android/key.properties` is
  absent.
