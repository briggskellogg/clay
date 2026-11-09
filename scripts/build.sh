#!/bin/bash
set -euo pipefail
CLAY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${1:-macos}"
"$CLAY_ROOT/scripts/preflight.sh" build
cd "$CLAY_ROOT"
xcrun --sdk macosx swift scripts/prepare_assets.swift "$CLAY_ROOT"
xcrun swift test
case "$PLATFORM" in
    macos)
        xcodebuild -project Clay.xcodeproj -scheme Clay-macOS -configuration Debug \
            -destination 'platform=macOS' -derivedDataPath build/DerivedData-macOS \
            CODE_SIGNING_ALLOWED=NO build
        ;;
    ios)
        xcodebuild -project Clay.xcodeproj -scheme Clay-iOS -configuration Debug \
            -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData-iOS \
            CODE_SIGNING_ALLOWED=NO build
        ;;
    *) echo "Usage: $0 macos|ios" >&2; exit 2 ;;
esac
