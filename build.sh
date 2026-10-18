#!/bin/sh
# Builds Iconeer.app in build/. Signs it with the "Iconeer Local Signing" certificate when it is
# in the Keychain, which keeps macOS permissions across builds; without it, signs ad hoc.
set -e
cd "$(dirname "$0")"
APP=build/Iconeer.app
IDENTITY="Iconeer Local Signing"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Universal binary: runs on Apple Silicon and Intel.
for ARCH in arm64 x86_64; do
  swift build -c release --arch "$ARCH" --product Iconeer
  cp "$(swift build -c release --arch "$ARCH" --show-bin-path)/Iconeer" "build/Iconeer-$ARCH"
done
lipo -create build/Iconeer-arm64 build/Iconeer-x86_64 -output "$APP/Contents/MacOS/Iconeer"
rm build/Iconeer-arm64 build/Iconeer-x86_64
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
swift Tools/make-icon.swift "$APP/Contents/Resources/AppIcon.icns"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force -s "$IDENTITY" "$APP"
else
  echo "Certificate \"$IDENTITY\" not found: signing ad hoc."
  codesign --force -s - "$APP"
fi
echo "OK: $APP"
