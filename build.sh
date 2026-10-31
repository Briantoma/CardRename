#!/bin/bash
# Build Card Rename.app with the Command Line Tools (no Xcode needed).
#   ./build.sh           build into build/
#   ./build.sh test      run the naming rule tests
#   ./build.sh install   build, copy to /Applications and open it
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "test" ]; then
  mkdir -p build
  swiftc -swift-version 5 Sources/CardScan.swift Tests/main.swift -o build/tests
  ./build/tests
  exit
fi

APP="build/Card Rename.app"
/bin/rm -rf "build/Card Rename.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14 \
  Sources/*.swift -o "$APP/Contents/MacOS/CardRename"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "install" ]; then
  /usr/bin/osascript -e 'tell application id "local.cardrename" to quit' 2>/dev/null || true
  /bin/rm -rf "/Applications/Card Rename.app"
  /usr/bin/ditto "$APP" "/Applications/Card Rename.app"
  open "/Applications/Card Rename.app"
  echo "Installed in /Applications"
fi
