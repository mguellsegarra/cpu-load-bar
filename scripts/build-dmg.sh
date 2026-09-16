#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/build/CPU Load Bar.app"
output_dmg="$project_dir/build/CPU-Load-Bar.dmg"
scratch_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/cpu-load-bar-dmg.XXXXXX")"
mount_dir="$scratch_dir/mount"
mounted=false

cleanup() {
  if "$mounted"; then
    hdiutil detach "$mount_dir" -quiet || true
  fi
  rm -rf "$scratch_dir"
}
trap cleanup EXIT

if ! command -v magick >/dev/null; then
  echo "ImageMagick is required to render the DMG background." >&2
  exit 1
fi

"$project_dir/scripts/build-app.sh"

mkdir -p "$mount_dir"
hdiutil create -size 32m -fs HFS+ -volname "CPU Load Bar" \
  "$scratch_dir/CPU-Load-Bar-rw.dmg"
hdiutil attach "$scratch_dir/CPU-Load-Bar-rw.dmg" -readwrite -noverify \
  -noautoopen -mountpoint "$mount_dir"
mounted=true

ditto "$app_dir" "$mount_dir/CPU Load Bar.app"
ln -s /Applications "$mount_dir/Applications"
mkdir "$mount_dir/.background"
magick -font /System/Library/Fonts/Supplemental/Arial.ttf -background none \
  "$project_dir/Resources/DMGBackground.svg" \
  "$mount_dir/.background/background.png"

osascript "$project_dir/scripts/layout-dmg.applescript" "$mount_dir"
sync
hdiutil detach "$mount_dir"
mounted=false

hdiutil convert "$scratch_dir/CPU-Load-Bar-rw.dmg" -format UDZO \
  -imagekey zlib-level=9 -ov -o "$output_dmg"
hdiutil verify "$output_dmg"
echo "$output_dmg"
