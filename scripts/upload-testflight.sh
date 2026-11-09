#!/bin/bash
set -euo pipefail
CLAY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${1:-ios}"
case "$PLATFORM" in
    ios) SCHEME=Clay-iOS; PREFLIGHT=distribution-ios ;;
    macos) SCHEME=Clay-macOS; PREFLIGHT=build ;;
    *) echo "Usage: $0 ios|macos" >&2; exit 2 ;;
esac
"$CLAY_ROOT/scripts/preflight.sh" "$PREFLIGHT"
CLAY_ARCHIVE="${CLAY_ARCHIVE_PATH:-$CLAY_ROOT/build/$SCHEME.xcarchive}"
if [[ ! -d "$CLAY_ARCHIVE" ]]; then
    echo "Archive not found at $CLAY_ARCHIVE. Run scripts/archive.sh $PLATFORM or set CLAY_ARCHIVE_PATH." >&2; exit 1
fi
CLAY_EXPORT_DIRECTORY="$(mktemp -d -t clay-export)"
CLAY_EXPORT_OPTIONS="$CLAY_EXPORT_DIRECTORY/ExportOptions.plist"
trap 'rm -rf "$CLAY_EXPORT_DIRECTORY"' EXIT
/usr/libexec/PlistBuddy -c 'Clear dict' "$CLAY_EXPORT_OPTIONS" >/dev/null
/usr/libexec/PlistBuddy -c 'Add :method string app-store-connect' "$CLAY_EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c 'Add :destination string upload' "$CLAY_EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c 'Add :signingStyle string automatic' "$CLAY_EXPORT_OPTIONS"
if [[ -n "${CLAY_TEAM_ID:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Add :teamID string $CLAY_TEAM_ID" "$CLAY_EXPORT_OPTIONS"
fi
/usr/libexec/PlistBuddy -c 'Add :uploadSymbols bool true' "$CLAY_EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c 'Add :stripSwiftSymbols bool true' "$CLAY_EXPORT_OPTIONS"
xcodebuild -exportArchive -archivePath "$CLAY_ARCHIVE" \
    -exportPath "$CLAY_ROOT/build/TestFlight-$PLATFORM" \
    -exportOptionsPlist "$CLAY_EXPORT_OPTIONS" -allowProvisioningUpdates
echo "Upload command completed. Check processing and tester access in App Store Connect; this script does not send invitations."
