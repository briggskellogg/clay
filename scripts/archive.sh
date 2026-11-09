#!/bin/bash
set -euo pipefail
CLAY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${1:-ios}"
case "$PLATFORM" in
    ios) SCHEME=Clay-iOS; DESTINATION='generic/platform=iOS'; PREFLIGHT=distribution-ios ;;
    macos) SCHEME=Clay-macOS; DESTINATION='generic/platform=macOS'; PREFLIGHT=build ;;
    *) echo "Usage: $0 ios|macos" >&2; exit 2 ;;
esac
"$CLAY_ROOT/scripts/preflight.sh" "$PREFLIGHT"
cd "$CLAY_ROOT"
xcrun --sdk macosx swift scripts/prepare_assets.swift "$CLAY_ROOT"
xcrun swift test
SIGNING_ARGUMENTS=()
if [[ -n "${CLAY_TEAM_ID:-}" ]]; then SIGNING_ARGUMENTS+=("DEVELOPMENT_TEAM=$CLAY_TEAM_ID"); fi
xcodebuild -project Clay.xcodeproj -scheme "$SCHEME" -configuration Release \
    -destination "$DESTINATION" -archivePath "build/$SCHEME.xcarchive" \
    -allowProvisioningUpdates "${SIGNING_ARGUMENTS[@]}" archive
printf 'Archive created at %s/build/%s.xcarchive\n' "$CLAY_ROOT" "$SCHEME"
