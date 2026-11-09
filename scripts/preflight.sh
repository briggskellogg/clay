#!/bin/bash
set -euo pipefail

MODE="${1:-build}"
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Clay requires macOS and full Xcode to build Apple apps. This machine is not a Mac." >&2
    exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
    echo "Install full Xcode, open it once to finish setup, then select it in Xcode > Settings > Locations > Command Line Tools." >&2
    exit 1
fi
XCODE_MAJOR="$(xcodebuild -version | awk '/^Xcode / {split($2, v, "."); print v[1]}')"
if [[ -z "$XCODE_MAJOR" || "$XCODE_MAJOR" -lt 15 ]]; then
    echo "Clay needs Xcode 15 or newer for local development." >&2
    exit 1
fi
if [[ "$MODE" == "distribution-ios" && "$XCODE_MAJOR" -lt 26 ]]; then
    echo "Current iOS TestFlight uploads require Xcode 26 or newer with the iOS 26 SDK or newer." >&2
    exit 1
fi
xcodebuild -version
