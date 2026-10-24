#!/bin/zsh
# Builds DesktopCat.app next to this script (drag it into Applications).
# Needs only the Swift toolchain (Command Line Tools); no Xcode project.
#   ./build.sh        build DesktopCat.app
#   ./build.sh run    build, then (re)start the cat
#   ./build.sh dist   build, then make dist/DesktopCat.dmg to share
set -e
cd "$(dirname "$0")"
APP=DesktopCat.app

# Universal binary: Apple Silicon + Intel Macs.
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/DesktopCat

rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp $BIN $APP/Contents/MacOS/DesktopCat

# The art and the action list ship inside the app, so it runs fully offline.
cp -R assets $APP/Contents/Resources/assets
find $APP/Contents/Resources/assets -name .gitkeep -delete
cp specs/cats-and-actions.json $APP/Contents/Resources/
cp AppIcon.icns $APP/Contents/Resources/

cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Desktop Cat</string>
  <key>CFBundleDisplayName</key><string>Desktop Cat</string>
  <key>CFBundleIdentifier</key><string>com.danielryan.DesktopCat</string>
  <key>CFBundleExecutable</key><string>DesktopCat</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Free and offline.</string>
</dict></plist>
PLIST
# GitHub's release builds sign with Developer ID + hardened runtime + timestamp, as Apple's notarization needs.
if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp $APP
else
  codesign --force --sign - $APP
fi
echo "Built $APP"

if [[ "$1" == "dist" ]]; then
  rm -rf dist && mkdir -p dist/stage
  cp -R "$APP" dist/stage/
  ln -s /Applications dist/stage/Applications
  hdiutil create -volname "Desktop Cat" -srcfolder dist/stage -ov -format UDZO dist/DesktopCat.dmg >/dev/null
  rm -rf dist/stage
  echo "Made dist/DesktopCat.dmg"
fi

if [[ "$1" == "run" ]]; then
  pkill -x DesktopCat 2>/dev/null || true
  open $APP
fi
