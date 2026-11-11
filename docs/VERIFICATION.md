# Verification log

What was actually executed, on what hardware, and what the result was. Split
into what can be verified in this environment and what cannot.

Environment: Hermes LXC, no `/dev/kvm` (nested virtualization unavailable) and
no `free`/`/proc/meminfo`, so the bundled x86_64 API-26 emulator images cannot
run — software emulation would take hours and saturate the CPU, which is
explicitly out of bounds for this project. Verification therefore used attached
physical hardware plus the test suite.

## Automated checks — PASS

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | 0 issues (no errors, warnings or infos) |
| Unit + widget tests | `flutter test` | **244 passing, 12 skipped** |
| Release build (universal) | `flutter build apk --release` | 51.6 MB, signed |
| Release build (per-ABI) | `flutter build apk --release --split-per-abi` | arm64 18.2 MB, armv7 15.7 MB, x86_64 19.7 MB |
| Manifest sanity | `aapt2 dump badging` | `my.kulnem.cruise_assist`, v0.1.0 (1), minSdk 26, targetSdk 36 |
| Signing | `apksigner verify --print-certs` | `CN=Cruise Assist, O=Fadhil Rashid`, SHA-256 `7613b1b4…4557` |

The 12 skipped tests are the live-network smoke tests in
`test/live/live_smoke_test.dart`, which only run when `LIVE=1` is set. They are
skipped by design so the suite is hermetic and CI does not depend on third-party
uptime.

## On-device test — PASS

**Device:** Fire TV Stick (AFTMM, `192.168.100.10:5555`), Android 7.1.2
(API 25), armeabi-v7a, 1920x1080.

This is *not* the target device. It was used because it is the only physical
Android device reachable from this host, and because a real install catches
failures that widget tests cannot: AOT compilation, plugin registration,
manifest merging, native library loading, and first-frame rendering.

Procedure:

1. Temporarily lowered `minSdk` 26 → 25 (Fire TV is API 25; the shipped build
   stays at 26). Backup at `/tmp/build.gradle.kts.bak`, restored afterwards.
2. `flutter build apk --release --target-platform android-arm` → 16.8 MB.
3. `adb install -r` → `Success`.
4. `adb shell am start -n my.kulnem.cruise_assist/.MainActivity`.
5. Waited, then `adb shell pidof` → **9458** (process alive).
6. `adb logcat -d | grep -E "FATAL|AndroidRuntime"` → **no matches**.
7. `adb shell screencap` → captured frame, inspected visually.

**Observed:** the dashboard rendered with live data. Clock, weather (with
current conditions and temperature), prayer times, fuel prices and shortcuts
were all populated — meaning network calls to Open-Meteo, AlAdhan and
data.gov.my succeeded from a real device, JSON parsing worked against live
responses, and the grid laid out without overflow on a 1920x1080 landscape
surface at a very different DPI than the test harness.

`minSdk` was restored to 26 and the app uninstalled from the Fire TV afterwards.

## Not verified — and why

### Perodua Smart Link projection

**Cannot be verified here.** No Ativa AV head unit is attached, and the
projection transport is not implemented (see `docs/PROJECTION.md`). This is the
one headline feature that does not work. Nothing in this repository claims
otherwise.

### Sony Xperia 10 IV

**Not tested on that exact handset.** No Xperia 10 IV is reachable. What can be
said: it is arm64-v8a with Android 12+, comfortably above minSdk 26, and the
arm64 APK was built and signed. The APK will install. The dashboard was proven
to render on a different Android device, and the widget suite asserts layout at
multiple surface sizes. That is strong evidence, not proof.

### USB/AOA accessory path

**Not verified end-to-end.** No USB host peripherals are attached to any
reachable device. The Kotlin AOA controller, `HeadUnitDiagnostics` and
`ProjectionService` compile and are covered by 20 projection tests (with the
EventChannel subscription-leak fix), but descriptor enumeration and the
handshake dump have not been exercised against real hardware.

### In-app update flow

**Partly verified.** Download, size verification, SHA-256 verification and
semver precedence are unit-tested (`test/update/`, 3 files). The end-to-end
flow — GitHub API → download → `FileProvider` → system installer — needs a
published release AND a phone. Note the repository is currently **private**,
so the unauthenticated GitHub API returns 404 and the About tab correctly
reports "Update check unavailable". Making the repo public enables it.

## Reproducing

```bash
cd /home/hermes/projects/cruise-assist
./tool/env.sh flutter analyze
./tool/env.sh flutter test
LIVE=1 ./tool/env.sh flutter test test/live   # hits real APIs
./tool/release.sh 0.1.0 --dry-run             # build + sign, no push
```

For the on-device check on any attached device:

```bash
./tool/env.sh adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
./tool/env.sh adb shell am start -n my.kulnem.cruise_assist/.MainActivity
./tool/env.sh adb logcat -d | grep -E "FATAL|AndroidRuntime"
```
