#!/bin/bash

set -euo pipefail

required_xcode_version="26.6"
required_sdk_version="26.5"
actual_xcode_version="$(xcodebuild -version | sed -nE 's/^Xcode (.+)$/\1/p')"
actual_sdk_version="$(xcrun --sdk macosx --show-sdk-version)"

if [[ "$actual_xcode_version" != "$required_xcode_version" ]]; then
    echo "error: Pawse releases require Xcode $required_xcode_version; found $actual_xcode_version" >&2
    exit 1
fi

if [[ "$actual_sdk_version" != "$required_sdk_version" ]]; then
    echo "error: Pawse releases require the macOS $required_sdk_version SDK; found $actual_sdk_version" >&2
    exit 1
fi

echo "Release toolchain: Xcode $actual_xcode_version, macOS SDK $actual_sdk_version"
