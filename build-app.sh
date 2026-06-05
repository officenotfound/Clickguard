#!/bin/bash
set -e

APP=ClickGuard.app
BINARY_NAME=ClickGuard

echo "Building..."
swift build -c release

# Generate icon if it doesn't exist yet
if [ ! -f ClickGuard/Resources/AppIcon.icns ]; then
    echo "Generating icon..."
    bash make-icon.sh
fi

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/$BINARY_NAME "$APP/Contents/MacOS/$BINARY_NAME"
cp ClickGuard/Info.plist "$APP/Contents/Info.plist"
cp ClickGuard/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc code sign so macOS treats it as a real app
codesign --force --deep --sign - "$APP"

echo "Done — $APP is ready."
echo ""
echo "To run: open $APP"
echo "To install: cp -r $APP /Applications/"
