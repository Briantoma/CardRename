#!/bin/bash
# Build Card Rename.app with the Command Line Tools (no Xcode needed).
#   ./build.sh           build into build/
#   ./build.sh test      run the naming rule tests
#   ./build.sh install   build, copy to /Applications and open it
#   ./build.sh icon      redraw Resources/AppIcon.icns from Tools/make_icon.swift
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "test" ]; then
  mkdir -p build
  swiftc -swift-version 5 Sources/CardScan.swift Tests/main.swift -o build/tests
  ./build/tests
  exit
fi

if [ "${1:-}" = "icon" ]; then
  mkdir -p build Resources
  swiftc -swift-version 5 Tools/make_icon.swift -o build/make_icon
  ./build/make_icon build/icon_1024.png
  /bin/rm -rf build/AppIcon.iconset
  mkdir build/AppIcon.iconset
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon_1024.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) build/icon_1024.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
  echo "Wrote Resources/AppIcon.icns"
  exit
fi

APP="build/Card Rename.app"
/bin/rm -rf "build/Card Rename.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14 \
  Sources/*.swift -o "$APP/Contents/MacOS/CardRename"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "install" ]; then
  /usr/bin/osascript -e 'tell application id "local.cardrename" to quit' 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x CardRename >/dev/null || break; sleep 0.5; done
  /bin/rm -rf "/Applications/Card Rename.app"
  /usr/bin/ditto "$APP" "/Applications/Card Rename.app"
  open "/Applications/Card Rename.app"
  echo "Installed in /Applications"
fi
