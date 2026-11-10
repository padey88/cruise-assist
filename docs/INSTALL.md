# Installing Cruise Assist

## Requirements

- Android 8.0 (API 26) or newer.
- A 64-bit ARM device (`arm64-v8a`) — Sony Xperia 10 IV, Pixel, most phones
  since 2017. A 32-bit `armeabi-v7a` build is also published.

## Sideload the APK

1. Download `cruise-assist-<version>-arm64-v8a.apk` from the latest release.
   If you are unsure which ABI you need, take the `universal` APK instead — it
   is larger but works everywhere.
2. Open the downloaded file from your notification shade or file manager.
3. Android will refuse the first time. Tap **Settings** on the prompt and
   enable **Allow from this source** for the app you are installing from
   (Files, Chrome, or your browser).
4. Tap **Install**.
5. Launch Cruise Assist from the app drawer.

### Over ADB, if you prefer

```bash
adb install -r cruise-assist-0.1.0-arm64-v8a.apk
```

## First run

The app opens on the dashboard with a default layout. It needs no account, no
sign-in and no licence.

- **Location is optional.** Weather and prayer widgets default to Kuala Lumpur
  with a manual city or prayer zone. Set your own zone in Settings; grant
  location only if you want nearby/EV/transit widgets to work.
- **Notifications** are only requested if you enable reminders.
- **Data** refreshes on its own: weather every 30 minutes, prayer every 6
  hours, fuel and exchange rates every 10 minutes (they change daily, so this
  is generous). Pull down on the dashboard to force a refresh.

## Updating

Cruise Assist checks GitHub releases for a newer version.

1. Open the **About** tab.
2. Tap **Check for updates**.
3. If a newer release exists, tap **Download update**. The APK is downloaded to
   the app cache, its size and SHA-256 are verified against the release asset,
   and the system installer opens.
4. Confirm the install. Android upgrades in place and keeps your layout and
   checklist.

The update check never runs automatically on a metered connection, and nothing
is downloaded without you tapping the button.

If the in-app updater is unavailable (for example, the release is still marked
private), download the APK from the releases page and install it over the top —
signatures match, so it upgrades rather than duplicating.

## Uninstalling

Standard Android uninstall removes the app and its local data (layout,
checklist, notes, cached payloads). Export anything you want to keep first;
there is no cloud sync by design.

## Troubleshooting

**"App not installed" on upgrade.** The installed copy was signed with a
different key. Uninstall the old copy first — this only happens if you
previously installed a locally built APK with a different keystore.

**Widgets show "Unavailable".** That widget's data source did not answer.
Check your connection; the widget keeps showing the last good value marked as
stale until a refresh succeeds.

**Nothing appears on the car screen.** Expected — see
[docs/PROJECTION.md](PROJECTION.md). Smart Link projection is not implemented.

**Fuel prices look wrong or old.** The `data.gov.my` dataset is weekly. The
widget shows the effective date of the newest row it received, so compare that
date rather than assuming it is today.
