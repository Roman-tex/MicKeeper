#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
./scripts/build.sh Release
app_path="$project_dir/.build/xcode/Build/Products/Release/MicKeeper.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"

# dmgbuild writes the Finder window layout without scripting Finder, so the
# result is identical locally and on headless CI. It is a build-time tool only,
# installed into a private virtual environment at a pinned version.
dmgbuild_version="1.6.5"
venv="$project_dir/.build/dmgbuild-venv"
if ! "$venv/bin/dmgbuild" --help >/dev/null 2>&1 \
    || [[ "$("$venv/bin/python" -m pip show dmgbuild 2>/dev/null | awk '/^Version:/ {print $2}')" != "$dmgbuild_version" ]]; then
    rm -rf "$venv"
    python3 -m venv "$venv"
    "$venv/bin/python" -m pip install --quiet --disable-pip-version-check "dmgbuild==$dmgbuild_version"
fi

# Window background at 1x and 2x, combined so Finder picks the Retina variant.
art_dir="$project_dir/.build/dmg"
rm -rf "$art_dir" && mkdir -p "$art_dir"
swift scripts/dmg/make-background.swift "$art_dir"
tiffutil -cathidpicheck "$art_dir/background.png" "$art_dir/background@2x.png" -out "$art_dir/background.tiff"

# Build a writable image, drop the background bookmark Finder cannot resolve,
# then compress it.
rw_dmg="$art_dir/MicKeeper-rw.dmg"
# On hosted CI runners the freshly attached volume occasionally disappears
# while dmgbuild copies into it; a clean retry succeeds.
for attempt in 1 2 3; do
    rm -f "$rw_dmg"
    if "$venv/bin/dmgbuild" -s scripts/dmg/settings.py \
        -D app="$app_path" -D background="$art_dir/background.tiff" "MicKeeper" "$rw_dmg"; then
        break
    fi
    if [[ $attempt == 3 ]]; then
        echo "dmgbuild failed three times" >&2
        exit 1
    fi
    echo "dmgbuild failed (attempt $attempt), retrying" >&2
    sleep 5
done
mount_point="$art_dir/volume"
mkdir -p "$mount_point"
hdiutil attach -quiet -readwrite -nobrowse -noautoopen -mountpoint "$mount_point" "$rw_dmg"
trap 'hdiutil detach -quiet -force "$mount_point" 2>/dev/null || true' EXIT
"$venv/bin/python" -I scripts/dmg/remove-background-bookmark.py "$mount_point"
# Mounting the image read-write lets fseventsd add its log folder; drop it.
rm -rf "$mount_point/.fseventsd"
hdiutil detach -quiet "$mount_point"
trap - EXIT

mkdir -p dist
# A version-free file name keeps releases/latest/download/MicKeeper.dmg stable.
dmg="dist/MicKeeper.dmg"
rm -f "$dmg"
hdiutil convert -quiet "$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$dmg"
hdiutil verify "$dmg"
(cd dist && shasum -a 256 MicKeeper.dmg > MicKeeper.dmg.sha256)
echo "Created: $project_dir/$dmg (MicKeeper $version, universal)"
