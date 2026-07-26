#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_root="$project_root/build/FQ4 Launcher.app"
contents_root="$app_root/Contents"
iconset_root="$project_root/build/AppIcon.iconset"

cd "$project_root"

swift test
swift build -c release

rm -rf "$app_root" "$iconset_root"
mkdir -p "$contents_root/MacOS" "$contents_root/Resources"

cp ".build/release/FQ4Wrapper" "$contents_root/MacOS/FQ4Wrapper"
cp "Resources/Info.plist" "$contents_root/Info.plist"
cp "Resources/FirstQueenIVCover.png" "$contents_root/Resources/FirstQueenIVCover.png"
ditto "FQ4" "$contents_root/Resources/FQ4"

swift "Tools/GenerateIcon.swift" "$iconset_root"
iconutil -c icns "$iconset_root" -o "$contents_root/Resources/AppIcon.icns"
rm -rf "$iconset_root"

codesign --force --deep --sign - "$app_root"
codesign --verify --deep --strict "$app_root"

echo "$app_root"
