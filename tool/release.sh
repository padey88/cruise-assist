#!/usr/bin/env bash
# Cut a Cruise Assist release from this machine.
#
# The GitHub PAT in use cannot write Actions secrets (403 on
# repos/actions/secrets/public-key), so .github/workflows/release.yml cannot
# receive the keystore. Until a token with the `secrets` scope is configured,
# release APKs are built and signed HERE, then pushed to a GitHub release.
#
# Usage:
#   ./tool/release.sh 0.2.0            # verify, build, sign, publish release
#   ./tool/release.sh 0.2.0 --dry-run  # everything except the network push
set -euo pipefail

cd "$(dirname "$0")/.."

VER="${1:?usage: release.sh <version> [--dry-run]}"
DRY="${2:-}"

# ---- sanity -----------------------------------------------------------------
PUBSPEC_VER="$(grep -E '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d+ -f1)"
if [ "$PUBSPEC_VER" != "$VER" ]; then
  echo "ERROR: pubspec.yaml says $PUBSPEC_VER, asked to release $VER."
  echo "Bump pubspec.yaml first, then rerun."
  exit 1
fi

CHANGELOG_OK="$(grep -cE "^##\s*\[?${VER}\]?" CHANGELOG.md || true)"
if [ "$CHANGELOG_OK" -lt 1 ]; then
  echo "ERROR: CHANGELOG.md has no section for $VER. Write it, then rerun."
  exit 1
fi

KEYFILE="android/key.properties"
[ -f "$KEYFILE" ] || { echo "ERROR: $KEYFILE missing — release build would be debug-signed."; exit 1; }

echo "== gate: analyze"
./tool/env.sh flutter analyze

echo "== gate: test"
./tool/env.sh flutter test

echo "== build (signed, universal + per-ABI)"
./tool/env.sh flutter build apk --release
./tool/env.sh flutter build apk --release --split-per-abi

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk          "dist/cruise-assist-${VER}-universal.apk"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "dist/cruise-assist-${VER}-arm64-v8a.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "dist/cruise-assist-${VER}-armeabi-v7a.apk"
( cd dist && sha256sum ./*.apk > SHA256SUMS.txt )
cat dist/SHA256SUMS.txt

echo "== signatures (must show the release key, not debug)"
for f in dist/cruise-assist-"$VER"-universal.apk; do
  "$HOME/.hermes/toolchains/jdk21/bin/jarsigner" -verify -verbose:summary "$f" | tail -2
done

# ---- changelog → release notes ----------------------------------------------
VER_ESC="$(printf '%s' "$VER" | sed 's/[.[\*^$]/\\&/g')"
awk -v v="$VER_ESC" '
  $0 ~ "^##[[:space:]]*\\[?"v"\\]?[[:space:]]*-?" { found=1; next }
  found && /^##[[:space:]]/ { exit }
  found { print }
' CHANGELOG.md > dist/release_notes.md
[ -s dist/release_notes.md ] || echo "Release $VER." > dist/release_notes.md

if [ "$DRY" = "--dry-run" ]; then
  echo "== dry run: stopping before tag/push/release"
  exit 0
fi

# ---- tag + release -----------------------------------------------------------
TAG="v${VER}"
git add -A
git commit -m "release: ${VER}" --allow-empty
git tag -a "$TAG" -m "Cruise Assist ${VER}"
git push origin HEAD --tags

BODY="$(pwd)/dist/release_notes.md"
if gh release view "$TAG" --repo padey88/cruise-assist >/dev/null 2>&1; then
  gh release upload "$TAG" dist/*.apk dist/SHA256SUMS.txt --repo padey88/cruise-assist --clobber
  gh release edit "$TAG" --notes-file "$BODY" --repo padey88/cruise-assist
else
  gh release create "$TAG" dist/*.apk dist/SHA256SUMS.txt \
    --repo padey88/cruise-assist \
    --title "Cruise Assist $TAG" \
    --notes-file "$BODY"
fi

echo "Published: https://github.com/padey88/cruise-assist/releases/tag/$TAG"
echo "NOTE: the repo is PRIVATE, so the unauthenticated in-app update check"
echo "returns 404 and the About tab reports 'Update check unavailable'."
echo "Make the repo public (gh repo edit padey88/cruise-assist --visibility public)"
echo "to enable GitHub-linked in-app updates on the phone."
