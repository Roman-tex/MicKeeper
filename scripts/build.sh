#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
configuration="${1:-Release}"
if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
    echo "Usage: scripts/build.sh [Debug|Release]" >&2
    exit 2
fi
xcodebuild -project MicKeeper.xcodeproj -scheme MicKeeper \
    -configuration "$configuration" -derivedDataPath .build/xcode \
    -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES build
app_path="$project_dir/.build/xcode/Build/Products/$configuration/MicKeeper.app"
# Xcode suppresses hardened runtime for ad-hoc builds. Explicitly apply it to the release executable.
if [[ "$configuration" == Release ]]; then
    codesign --force --sign - --options runtime --timestamp=none "$app_path"
fi
codesign --verify --deep --strict "$app_path"
lipo "$app_path/Contents/MacOS/MicKeeper" -verify_arch arm64 x86_64
echo "Built: $app_path"
