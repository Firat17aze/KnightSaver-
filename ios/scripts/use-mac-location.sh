#!/bin/zsh
# Gives the booted iOS Simulator this Mac's real location, so "My Current Location" in
# KnightSaver shows your actual address. The Simulator can't read the Mac's location itself.
#
#   ios/scripts/use-mac-location.sh          # once
#   ios/scripts/use-mac-location.sh --watch  # keep it updated every minute
#
# The first run asks for Location access for "KnightSaver Mac Location". Allow it.
set -e
here=${0:A:h}
build=${TMPDIR:-/tmp}/knightsaver-mac-location
app=$build/KnightSaverMacLocation.app

if [[ ! -x $app/Contents/MacOS/KnightSaverMacLocation || $here/MacLocation.swift -nt $app/Contents/MacOS/KnightSaverMacLocation ]]; then
  mkdir -p $app/Contents/MacOS
  swiftc -O $here/MacLocation.swift -o $app/Contents/MacOS/KnightSaverMacLocation
  cat > $app/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.knightsaver.maclocation</string>
  <key>CFBundleName</key><string>KnightSaver Mac Location</string>
  <key>CFBundleExecutable</key><string>KnightSaverMacLocation</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>NSLocationUsageDescription</key><string>Gives the iOS Simulator this Mac's location for KnightSaver testing.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>Gives the iOS Simulator this Mac's location for KnightSaver testing.</string>
</dict></plist>
PLIST
  codesign --force --sign - $app >/dev/null 2>&1
fi

update() {
  local out=$build/location.txt
  rm -f $out
  open -W -n $app --args $out
  local result=$(cat $out 2>/dev/null)
  if [[ -z $result || $result == error:* ]]; then
    echo "${result:-Couldn't get the Mac's location.}" >&2
    return 1
  fi
  xcrun simctl location booted set $result
  echo "Simulator location set to $result"
}

if [[ $1 == --watch ]]; then
  while true; do update || true; sleep 60; done
else
  update
fi
