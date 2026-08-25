#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
project="$repository_root/Pawse.xcodeproj"
scheme="Pawse"
version="${VERSION:-}"
derived_data="${DERIVED_DATA:-$repository_root/.build/ReleaseDerivedData}"
dist_dir="${DIST_DIR:-$repository_root/dist}"
staging_dir="$repository_root/.build/dmg-staging"

if [[ -z "$version" ]]; then
    version="$("$repository_root/scripts/release/verify-version.sh" | sed -E 's/^Pawse ([^ ]+) .*/\1/')"
else
    "$repository_root/scripts/release/verify-version.sh" "$version" >/dev/null
fi

app_path="$derived_data/Build/Products/Release/Pawse.app"
dmg_path="$dist_dir/Pawse-$version.dmg"
checksum_path="$dmg_path.sha256"

rm -rf "$staging_dir"
mkdir -p "$staging_dir" "$dist_dir"
rm -f "$dmg_path" "$checksum_path"

xcodebuild \
    -project "$project" \
    -scheme "$scheme" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

if [[ ! -d "$app_path" ]]; then
    echo "error: Release build did not produce $app_path" >&2
    exit 1
fi

actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
if [[ "$actual_version" != "$version" ]]; then
    echo "error: built app version '$actual_version' does not match '$version'" >&2
    exit 1
fi

ditto "$app_path" "$staging_dir/Pawse.app"

if [[ -n "${PAWSE_CODESIGN_IDENTITY:-}" ]]; then
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --entitlements "$repository_root/Pawse/Pawse.entitlements" \
        --sign "$PAWSE_CODESIGN_IDENTITY" \
        "$staging_dir/Pawse.app"
else
    codesign \
        --force \
        --deep \
        --options runtime \
        --entitlements "$repository_root/Pawse/Pawse.entitlements" \
        --sign - \
        "$staging_dir/Pawse.app"
fi

codesign --verify --deep --strict --verbose=2 "$staging_dir/Pawse.app"
lipo "$staging_dir/Pawse.app/Contents/MacOS/Pawse" -verify_arch arm64 x86_64
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
    -volname "Pawse $version" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    "$dmg_path"

if [[ -n "${PAWSE_CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --timestamp --sign "$PAWSE_CODESIGN_IDENTITY" "$dmg_path"
fi

if [[ -n "${PAWSE_NOTARY_PROFILE:-}" ]]; then
    if [[ -z "${PAWSE_CODESIGN_IDENTITY:-}" ]]; then
        echo "error: PAWSE_NOTARY_PROFILE requires PAWSE_CODESIGN_IDENTITY" >&2
        exit 1
    fi
    xcrun notarytool submit "$dmg_path" --keychain-profile "$PAWSE_NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
fi

(
    cd "$dist_dir"
    shasum -a 256 "$(basename "$dmg_path")" > "$(basename "$checksum_path")"
)

echo "Created $dmg_path"
echo "Created $checksum_path"
