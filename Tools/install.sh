#!/bin/sh
# Installs the latest Iconeer release in /Applications and opens it.
# Usage: curl -fsSL https://raw.githubusercontent.com/luantedesco/iconeer/main/Tools/install.sh | sh
# curl does not quarantine the download, so Gatekeeper does not block the non-notarized app.
set -e
APP=/Applications/Iconeer.app
URL=https://github.com/luantedesco/iconeer/releases/latest/download/Iconeer.dmg
TMP=$(mktemp -d)
trap 'hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT
echo "Downloading $URL"
curl -fsSL "$URL" -o "$TMP/Iconeer.dmg"
hdiutil attach -nobrowse -readonly -quiet -mountpoint "$TMP/mnt" "$TMP/Iconeer.dmg"
pkill -x Iconeer 2>/dev/null || true
rm -rf "$APP"
ditto "$TMP/mnt/Iconeer.app" "$APP"
open "$APP"
echo "Installed: $APP"
