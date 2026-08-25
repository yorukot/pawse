#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
project="$repository_root/Pawse.xcodeproj"
scheme="Pawse"
version="${VERSION:-}"
derived_data="${DERIVED_DATA:-$repository_root/.build/ReleaseDerivedData}"
dist_dir="${DIST_DIR:-$repository_root/dist}"
staging_dir="$repository_root/.build/dmg-staging"
verify_mount_dir="$repository_root/.build/dmg-verify-mount"
background_path="$repository_root/scripts/release/assets/PawseDMGBackground.png"
mounted_path=""

cleanup() {
    if [[ -n "$mounted_path" ]]; then
        hdiutil detach "$mounted_path" >/dev/null 2>&1 || true
    fi
    rm -rf "$staging_dir" "$verify_mount_dir"
    if [[ -n "${rw_dmg_path:-}" ]]; then
        rm -f "$rw_dmg_path"
    fi
}
trap cleanup EXIT

if [[ -z "$version" ]]; then
    version="$("$repository_root/scripts/release/verify-version.sh" | sed -E 's/^Pawse ([^ ]+) .*/\1/')"
else
    "$repository_root/scripts/release/verify-version.sh" "$version" >/dev/null
fi

"$repository_root/scripts/release/verify-toolchain.sh" >/dev/null

app_path="$derived_data/Build/Products/Release/Pawse.app"
volume_name="Pawse $version"
mount_dir="/Volumes/$volume_name"
dmg_path="$dist_dir/Pawse-$version.dmg"
rw_dmg_path="$dist_dir/.Pawse-$version-rw.dmg"
checksum_path="$dmg_path.sha256"

if [[ ! -f "$background_path" ]]; then
    echo "error: DMG background not found at $background_path" >&2
    exit 1
fi

rm -rf "$staging_dir" "$verify_mount_dir"
mkdir -p "$staging_dir/.background" "$verify_mount_dir" "$dist_dir"
rm -f "$dmg_path" "$rw_dmg_path" "$checksum_path"

if [[ -e "$mount_dir" ]]; then
    echo "error: $mount_dir is already mounted; eject it before packaging" >&2
    exit 1
fi

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
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")"
actual_sdk="$(/usr/libexec/PlistBuddy -c 'Print :DTSDKName' "$app_path/Contents/Info.plist")"
if [[ "$actual_version" != "$version" ]]; then
    echo "error: built app version '$actual_version' does not match '$version'" >&2
    exit 1
fi
if [[ "$actual_sdk" != "macosx26.5" ]]; then
    echo "error: built app SDK '$actual_sdk' is not the required macosx26.5" >&2
    exit 1
fi

ditto "$app_path" "$staging_dir/Pawse.app"
cp "$background_path" "$staging_dir/.background/PawseDMGBackground.png"
cp "$app_path/Contents/Resources/AppIcon.icns" "$staging_dir/.VolumeIcon.icns"
ln -s /Applications "$staging_dir/Applications"

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

hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDRW \
    "$rw_dmg_path"

hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    "$rw_dmg_path" >/dev/null
if [[ ! -d "$mount_dir" ]]; then
    echo "error: writable DMG did not mount at $mount_dir" >&2
    exit 1
fi
mounted_path="$mount_dir"

SetFile -a V "$mount_dir/.VolumeIcon.icns" "$mount_dir/.background"
SetFile -a C "$mount_dir"

osascript - "$volume_name" <<'APPLESCRIPT'
on run arguments
    set volumeName to item 1 of arguments

    tell application "Finder"
        tell disk volumeName
            open
            set installerWindow to container window
            set current view of installerWindow to icon view
            set toolbar visible of installerWindow to false
            set statusbar visible of installerWindow to false
            set pathbar visible of installerWindow to false
            set bounds of installerWindow to {180, 120, 880, 520}

            set viewOptions to icon view options of installerWindow
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 96
            set text size of viewOptions to 14
            set background picture of viewOptions to file ".background:PawseDMGBackground.png"

            set position of item "Pawse.app" to {190, 235}
            set position of item "Applications" to {510, 235}
            set extension hidden of item "Pawse.app" to true
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
APPLESCRIPT

# Finder can refresh volume metadata while it writes .DS_Store. Restore the
# volume artwork last so both the icon file and custom-icon flag survive
# conversion to the final read-only image.
cp "$app_path/Contents/Resources/AppIcon.icns" "$mount_dir/.VolumeIcon.icns"
SetFile -a V "$mount_dir/.VolumeIcon.icns" "$mount_dir/.background"
SetFile -a C "$mount_dir"

sync
if [[ ! -f "$mount_dir/.DS_Store" ]]; then
    echo "error: Finder did not write the DMG layout metadata" >&2
    exit 1
fi
if [[ ! -f "$mount_dir/.VolumeIcon.icns" || "$(GetFileInfo -a "$mount_dir")" != *C* ]]; then
    echo "error: writable DMG did not retain its custom volume icon" >&2
    exit 1
fi

hdiutil detach "$mount_dir" >/dev/null
mounted_path=""

hdiutil convert \
    "$rw_dmg_path" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$dmg_path"
rm -f "$rw_dmg_path"

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

hdiutil verify "$dmg_path" >/dev/null
hdiutil attach \
    -readonly \
    -noverify \
    -noautoopen \
    -nobrowse \
    -mountpoint "$verify_mount_dir" \
    "$dmg_path" >/dev/null
mounted_path="$verify_mount_dir"

volume_attributes="$(GetFileInfo -a "$verify_mount_dir")"
icon_attributes="$(GetFileInfo -a "$verify_mount_dir/.VolumeIcon.icns")"
if [[ "$volume_attributes" != *C* ]]; then
    echo "error: final DMG is missing its custom volume icon flag" >&2
    exit 1
fi
if [[ "$icon_attributes" != *V* ]]; then
    echo "error: final DMG volume icon is not hidden" >&2
    exit 1
fi
for required_path in \
    "$verify_mount_dir/Pawse.app" \
    "$verify_mount_dir/Applications" \
    "$verify_mount_dir/.VolumeIcon.icns" \
    "$verify_mount_dir/.background/PawseDMGBackground.png" \
    "$verify_mount_dir/.DS_Store"; do
    if [[ ! -e "$required_path" ]]; then
        echo "error: final DMG is missing $required_path" >&2
        exit 1
    fi
done
layout_metadata="$(strings -a "$verify_mount_dir/.DS_Store")"
for layout_marker in bwsp icvp PawseDMGBackground.png; do
    if [[ "$layout_metadata" != *"$layout_marker"* ]]; then
        echo "error: final DMG layout metadata is missing $layout_marker" >&2
        exit 1
    fi
done
if [[ "$(readlink "$verify_mount_dir/Applications")" != "/Applications" ]]; then
    echo "error: final DMG Applications alias has the wrong target" >&2
    exit 1
fi

packaged_info="$verify_mount_dir/Pawse.app/Contents/Info.plist"
packaged_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$packaged_info")"
packaged_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$packaged_info")"
packaged_sdk="$(/usr/libexec/PlistBuddy -c 'Print :DTSDKName' "$packaged_info")"
if [[ "$packaged_version" != "$version" || "$packaged_build" != "$actual_build" ]]; then
    echo "error: packaged app metadata does not match the Release build" >&2
    exit 1
fi
if [[ "$packaged_sdk" != "macosx26.5" ]]; then
    echo "error: packaged app SDK '$packaged_sdk' is not macosx26.5" >&2
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$verify_mount_dir/Pawse.app"
lipo "$verify_mount_dir/Pawse.app/Contents/MacOS/Pawse" -verify_arch arm64 x86_64

hdiutil detach "$verify_mount_dir" >/dev/null
mounted_path=""

(
    cd "$dist_dir"
    shasum -a 256 "$(basename "$dmg_path")" > "$(basename "$checksum_path")"
)

echo "Created $dmg_path"
echo "Created $checksum_path"
