#!/bin/zsh
# Dev only: build Rokko for the connected iPad, install it, and launch it.
# Usage: Tools/run_on_ipad.sh   (DEVICE_ID overrides the iPad UDID)
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE_ID="${DEVICE_ID:-00008112-000479441E9A601E}"
DERIVED="build/DeviceDerivedData"

xcodebuild -scheme rokko -destination "id=$DEVICE_ID" -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates build -quiet

APP=$(ls -d "$DERIVED"/Build/Products/Debug-iphoneos/*.app | head -1)
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

xcrun devicectl device install app --device "$DEVICE_ID" "$APP" >/dev/null
xcrun devicectl device process launch --terminate-existing --device "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
echo "Rokko running on iPad ($BUNDLE_ID)"
