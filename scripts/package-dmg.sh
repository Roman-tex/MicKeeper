#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
./scripts/build.sh Release
app_path="$project_dir/.build/xcode/Build/Products/Release/MicKeeper.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
mkdir -p dist
stage_dir="$(mktemp -d "$project_dir/dist/.dmg-stage.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
ditto "$app_path" "$stage_dir/MicKeeper.app"
ln -s /Applications "$stage_dir/Applications"
hdiutil create -ov -volname "MicKeeper $version" -srcfolder "$stage_dir" \
    -format UDZO -fs HFS+ "dist/MicKeeper-$version-universal.dmg"
hdiutil verify "dist/MicKeeper-$version-universal.dmg"
shasum -a 256 "dist/MicKeeper-$version-universal.dmg" > "dist/MicKeeper-$version-universal.dmg.sha256"
echo "Created: $project_dir/dist/MicKeeper-$version-universal.dmg"
