#!/bin/sh
# Packages build/Iconeer.app into build/Iconeer.dmg: the app and a shortcut to
# /Applications, for drag-and-drop install. Run ./build.sh first. The name has no version so the
# releases/latest/download/Iconeer.dmg link always points to the latest release.
set -e
cd "$(dirname "$0")/.."
APP=build/Iconeer.app
DMG=build/Iconeer.dmg
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Iconeer.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Iconeer" -srcfolder "$STAGING" -fs HFS+ -format UDZO -quiet "$DMG"
echo "OK: $DMG"
