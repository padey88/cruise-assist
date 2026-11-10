# Projection Module — Status & Limitations

## What is implemented

### Android native (Kotlin)

| Component | File | Purpose |
|---|---|---|
| **UsbAoaController** | `UsbAoaController.kt` | Enumerates USB accessories, requests permission, opens the accessory via `openAccessory()`, and reads the bulk pipe on a background thread. Writes are exposed but unused — the framing is unknown |
| **HeadUnitDiagnostics** | `HeadUnitDiagnostics.kt` | Logs first 64 bytes (hex + ASCII) of every packet, classifies AOA handshake signatures, recognises known patterns (Ativa, Perodua, SmartLink text) |
| **ProjectionService** | `ProjectionService.kt` | Foreground service (`connectedDevice` type), manages AOA controller lifecycle, handles USB detach, persistent notification with Stop action |
| **ProjectionEvents** | `ProjectionEvents.kt` | In-process event bridge to Flutter via EventChannel, ring buffer of last 64 events |
| **UsbAccessoryActivity** | `UsbAccessoryActivity.kt` | Receives `USB_ACCESSORY_ATTACHED` intent, starts ProjectionService, finishes immediately |
| **CruiseCarAppService** | `CruiseCarAppService.kt` | Placeholder for `androidx.car.app` (disabled in manifest) |

### Dart layer

| Component | File | Purpose |
|---|---|---|
| **ProjectionController** | `lib/projection/projection.dart` | State machine (`unavailable → idle → awaitingPermission → attached → streaming → error`), MethodChannel/EventChannel wiring, graceful non-Android degradation |
| **CarScreenPage** | `lib/projection/car_surface.dart` | Full-page view: car surface preview at 1280×480 aspect, USB connect/disconnect button, live state chip, device compatibility line, expandable USB diagnostics |
| **CarSurface** | `lib/projection/car_surface.dart` | Head-unit UI: large clock, next prayer + countdown, weather temperature, RON 95 price, alert count, USD exchange rate. Reads raw JSON payloads; null data renders as `—` |
| **DeviceInfo** | `lib/platform/device_info.dart` | Device model/SDK/ABI via platform channel |
| **DeviceCompatibility** | `lib/platform/device_info.dart` | Evaluates USB AOA support from SDK version, flags device-specific caveats |
| **SmartLinkProfile** | `lib/platform/device_info.dart` | Documents what the Ativa AV head unit is expected to need (mostly unknowns) |

### Manifest

- USB accessory attachment activity with `device_filter.xml` (matches all accessories)
- Foreground service with `foregroundServiceType=connectedDevice`
- CarAppService declared but `enabled=false` (inert — there is no `androidx.car.app` dependency, so it exposes no car-app surface)
- Permissions: INTERNET, FOREGROUND_SERVICE, FOREGROUND_SERVICE_CONNECTED_DEVICE, USB_PERMISSION, POST_NOTIFICATIONS, WAKE_LOCK, location, RECEIVE_BOOT_COMPLETED, REQUEST_INSTALL_PACKAGES
- `USB_PERMISSION` is the qualifying "connected device" permission required by the `connectedDevice` foreground-service type on API 34+. The service catches `SecurityException` and degrades to a plain foreground notification if USB access has not been granted yet.
- `uses-feature android.hardware.usb.accessory` and `android.hardware.usb.host`, both `required=false`
- `FileProvider` for `open_filex`: authority `${applicationId}.fileProvider.com.crazecoder.openfile`, pointing at our own `@xml/file_paths.xml` — a superset of the plugin's `filepaths.xml`, so the `files-path`/`cache-path` coverage needed to open the downloaded update APK is preserved. Merged with `tools:replace`; verified in the built APK as a single provider with the expected authority.

---

## What is NOT implemented

### Carbit / DriveDeck video protocol
The original app uses proprietary classes (`CarbitVideoOut`, `CarbitEncode`, `AdbAoaTransport`, `SmartLinkBridge`) to encode and frame video for the head unit. We do **not** implement or reverse-engineer this protocol. The AOA controller opens the raw USB pipe and logs what it receives — it does not send video frames.

### SmartLink AIDL service
The original exports `ISmartLink`/`ISmartLinkClient` AIDL interfaces and a `SmartLinkService`. These are part of the DriveDeck SDK's discovery and pairing protocol. Not implemented.

### Widevine / DRM
No DRM-protected content playback.

### Head-unit pairing
There is no pairing, authentication, or handshake sequence implemented. The controller opens the accessory and reads/logs whatever the head unit sends.

### Touch input reverse channel
The head unit presumably sends touch events back over USB. This direction is not parsed or forwarded to Flutter.

### Android Auto / AAOS
The `CruiseCarAppService` is a stub. Adding `androidx.car.app` requires a gradle dependency and a real `CarAppService` + `Session` implementation.

---

## How to continue with a real head unit

### What you need
1. A Perodua Ativa AV (or similar unit running Carbit/DriveDeck firmware)
2. A USB cable (the car's USB-A port in the centre console)
3. An Android phone running Cruise Assist debug build

### Capture procedure
1. Install the debug APK
2. Open **Car screen** tab → tap **Connect to head unit**
3. Plug the USB cable into the car's port
4. Grant USB permission when prompted
5. Expand **USB diagnostics** to see the accessory descriptor and incoming bytes
6. The native layer also logs to `logcat` under tag `CruiseHeadUnit`:

```bash
adb logcat -s CruiseHeadUnit:I
```

### What to capture and report
- **Accessory descriptor**: manufacturer, model, version, description, uri, permission state (`UsbAccessory` exposes no vendor/product ID, so those are not logged)
- **First 64 bytes** of the first few packets (hex + ASCII, logged automatically)
- The **handshake classifier** output (e.g. `contains-smartlink-text`, `pngm-prefix`)
- Any error messages from the USB read loop

### What the bytes tell us
- If the head unit sends a text-based handshake (e.g. JSON, XML, or ASCII protocol name), the `first64Ascii` field will show it
- If it sends a binary protocol, the hex dump + any magic-byte prefix will narrow down the framing format
- The classifier checks for known patterns: `AOA`, `SMART`/`LINK` text, and a `PNGM` prefix. These are **heuristic guesses at a signature, not observations from a real head unit** — treat any hit as a hypothesis to confirm against a real capture

### USB IDs
The original app's `device_filter.xml` was not extracted with specific vendor/product IDs, so ours matches **all** USB accessories. Once real IDs are captured from a genuine head unit, narrow the filter to avoid claiming unrelated devices.

---

## Test coverage

- `test/projection/projection_test.dart` — 10 tests: state enum completeness, non-Android degradation, no-op start/stop/accessories/diagnostics/status, listener notification, Android event-stream attach
- `test/projection/device_info_test.dart` — 10 tests: supported/unsupported/unknown verdicts, SDK boundary behaviour, manufacturer capitalisation, SmartLinkProfile constants

---

## Build status

Verified on the development host:

- `flutter analyze lib/projection lib/platform test/projection` — **no issues found**
- `flutter test test/projection` — **20/20 passed**
- `flutter build apk --debug` — **succeeded** (`build/app/outputs/flutter-apk/app-debug.apk`)

This proves the Kotlin compiles and the manifest merges correctly. It does **not** prove projection works: nothing in this module has been exercised against a real Ativa AV head unit.
