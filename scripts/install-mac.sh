#!/bin/bash
set -euo pipefail
CLAY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$CLAY_ROOT/scripts/preflight.sh" build
if pgrep -x Clay >/dev/null 2>&1; then
    echo "Quit Clay first so the current writing can finish saving, then run this installer again." >&2
    exit 1
fi
"$CLAY_ROOT/scripts/build.sh" macos
CLAY_APP="$CLAY_ROOT/build/DerivedData-macOS/Build/Products/Debug/Clay.app"
if [[ ! -d "$CLAY_APP" ]]; then echo "Build did not produce Clay.app." >&2; exit 1; fi
/usr/bin/codesign --force --sign - --entitlements "$CLAY_ROOT/Config/Clay-macOS.entitlements" "$CLAY_APP"
/usr/bin/codesign --verify --deep --strict "$CLAY_APP"

if [[ -d /Applications && -w /Applications ]]; then
    CLAY_APPLICATIONS=/Applications/Developer
else
    CLAY_APPLICATIONS="$HOME/Applications/Developer"
fi
mkdir -p "$CLAY_APPLICATIONS"
CLAY_STAGE="$(mktemp -d "$CLAY_APPLICATIONS/.clay-install.XXXXXX")"
trap 'rm -rf "$CLAY_STAGE"' EXIT
/usr/bin/ditto "$CLAY_APP" "$CLAY_STAGE/Clay.app"
/usr/bin/codesign --verify --deep --strict "$CLAY_STAGE/Clay.app"
CLAY_DESTINATION="$CLAY_APPLICATIONS/Clay.app"
CLAY_BACKUP=""
if [[ -e "$CLAY_DESTINATION" ]]; then
    CLAY_BACKUP_ROOT="$HOME/Library/Application Support/Clay/InstallBackups"
    mkdir -p "$CLAY_BACKUP_ROOT"
    CLAY_BACKUP_DIRECTORY="$(mktemp -d "$CLAY_BACKUP_ROOT/$(date +%Y%m%d-%H%M%S).XXXXXX")"
    CLAY_BACKUP="$CLAY_BACKUP_DIRECTORY/Clay.app"
    mv "$CLAY_DESTINATION" "$CLAY_BACKUP"
fi
if ! mv "$CLAY_STAGE/Clay.app" "$CLAY_DESTINATION"; then
    if [[ -n "$CLAY_BACKUP" ]]; then mv "$CLAY_BACKUP" "$CLAY_DESTINATION"; fi
    echo "Installation failed; the previous app was restored if present." >&2
    exit 1
fi
printf 'Installed Clay at %s\n' "$CLAY_DESTINATION"
open "$CLAY_DESTINATION"
