#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
source_svg="$project_dir/Resources/AppIcon.svg"
iconset_dir="$project_dir/build/AppIcon.iconset"
output_icns="$project_dir/Resources/AppIcon.icns"

if ! command -v magick >/dev/null; then
  echo "ImageMagick is required to regenerate AppIcon.icns from the SVG source." >&2
  exit 1
fi

mkdir -p "$iconset_dir"

render() {
  local filename="$1"
  local pixels="$2"
  magick -background none "$source_svg" -resize "${pixels}x${pixels}" \
    -depth 8 -define png:color-type=6 -strip \
    "$iconset_dir/$filename"
}

render icon_16x16.png 16
render icon_16x16@2x.png 32
render icon_32x32.png 32
render icon_32x32@2x.png 64
render icon_128x128.png 128
render icon_128x128@2x.png 256
render icon_256x256.png 256
render icon_256x256@2x.png 512
render icon_512x512.png 512
render icon_512x512@2x.png 1024

iconutil --convert icns "$iconset_dir" --output "$output_icns"
echo "$output_icns"
