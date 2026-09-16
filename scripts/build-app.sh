#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/build/CPU Load Bar.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

cd "$project_dir"
swift build -c release --arch arm64 --arch x86_64

rm -rf "$app_dir"
mkdir -p "$macos_dir" "$resources_dir"
cp ".build/apple/Products/Release/CPULoadBar" "$macos_dir/CPULoadBar"
cp "Resources/Info.plist" "$contents_dir/Info.plist"
cp "Resources/AppIcon.icns" "$resources_dir/AppIcon.icns"

codesign --force --sign - "$app_dir"
echo "$app_dir"
