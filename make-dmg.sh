#!/bin/bash
set -e

APP=ClickGuard.app
VOL="ClickGuard"
DMG="ClickGuard.dmg"
STAGE=$(mktemp -d)

# Ensure the app is freshly built
bash build-app.sh

echo "Staging DMG contents..."
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "Creating $DMG..."
rm -f "$DMG"
hdiutil create \
    -volname "$VOL" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGE"
echo "Done — $DMG ($(du -h "$DMG" | cut -f1)) ready."
