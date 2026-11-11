# Release and update pipeline

How a change becomes an installed update on the phone.

## Overview

```
  commit ──► tag v0.2.0 ──► GitHub Actions ──► Release + APK asset
                                                    │
                                            in-app check (About tab)
                                                    │
                                     download ──► verify ──► installer
```

## Cutting a release

1. Bump the version in `pubspec.yaml`. The `+N` build number must increase for
   Android to accept the upgrade:

   ```yaml
   version: 0.2.0+2
   ```

2. Update `CHANGELOG.md`: move items out of `Unreleased` into a new
   `## [0.2.0] - YYYY-MM-DD` section. This section becomes the release body.

3. Commit, then tag and push:

   ```bash
   git add -A
   git commit -m "release: 0.2.0"
   git tag -a v0.2.0 -m "Cruise Assist 0.2.0"
   git push origin main --tags
   ```

4. The `release` workflow runs: analyze, test, build, publish.

## What CI does

`.github/workflows/release.yml`, triggered by any `v*` tag:

1. Sets up JDK 17 and Flutter stable.
2. Runs `flutter analyze` (must be clean) and `flutter test`.
3. Decodes the signing keystore from secrets, if present.
4. Builds a universal APK and per-ABI APKs.
5. Creates the GitHub Release for the tag, attaching the APKs.
6. Uses the matching `CHANGELOG.md` section as the release body.

### Required secrets

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of your `.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Create them once:

```bash
base64 -w0 android/app/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD
```

If the secrets are absent the workflow still builds, but with **debug**
signing, and prints a loud warning. That APK installs fine for personal use;
it just cannot upgrade over a release-signed install, and vice versa.

> **Current state:** the PAT in use cannot write Actions secrets (`403` on
> `repos/…/actions/secrets/public-key`), so the keystore is **not** in CI.
> `v0.1.0` was therefore built and signed locally with `tool/release.sh`.
> Until a token with the `secrets` scope is configured, use that script rather
> than the workflow — otherwise CI would publish debug-signed APKs that cannot
> upgrade over `v0.1.0`.

> **Important:** pick one signing key and keep it forever. Switching keys means
> every user (you) must uninstall before installing, losing local state.

## How the app checks for updates

`lib/update/update_service.dart` calls:

```
GET https://api.github.com/repos/padey88/cruise-assist/releases/latest
```

It reads `tag_name`, `body`, `published_at` and the `.apk` asset
(`name`, `browser_download_url`, `size`, optional `digest`), then compares the
tag against the installed version from `package_info_plus`.

Version comparison (`lib/update/version.dart`) follows semver precedence,
including prereleases: `0.2.0-beta.1 < 0.2.0`. Build metadata (`+2`) is ignored
for precedence, which is correct per semver — but note Android uses the build
number for upgrade eligibility, so still bump it.

While the repository was private, the unauthenticated API returned 404 and the
service reported "Update check unavailable" rather than failing silently. The
repository is now **public**, so the check works without a token — verified
against the live `v0.1.0` release: the API returns `tag_name`, per-asset
`digest` (`sha256:…`) and the universal APK is selected correctly.

## How the download works

`lib/update/update_downloader.dart`:

1. Streams the APK to the app cache directory, reporting progress. It is never
   held in memory.
2. Verifies the byte count against the release asset `size`.
3. Verifies SHA-256 against the release asset `digest` when GitHub provides one.
4. Launches the system package installer via a `FileProvider` with authority
   `my.kulnem.cruise_assist.fileprovider`.

Android shows its own confirmation dialog; the app cannot install silently.

## Rolling back

Releases are immutable. To go back, download the previous APK from its release
page and install it. Android permits a downgrade only with
`adb install -r -d <apk>`; through the UI it will refuse, and the clean path is
uninstall then install the older build.

## CI on pull requests

`.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on every
push and pull request. No artifacts are published from it.
