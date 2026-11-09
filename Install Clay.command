#!/bin/bash
set -euo pipefail
CLAY_ROOT="$(cd "$(dirname "$0")" && pwd)"
if "$CLAY_ROOT/scripts/install-mac.sh"; then
    echo "Clay is installed and opening. You may close this Terminal window."
else
    echo "Clay could not be installed. Read the error above and README.md for the required Xcode setup." >&2
    read -r -p "Press Return to close this window. " _ || true
    exit 1
fi
