#!/bin/bash

set -euo pipefail

version="${1:-}"
dmg_path="${2:-}"
checksum_path="${3:-}"
output_path="${4:-}"
notarized="${PAWSE_RELEASE_NOTARIZED:-false}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: version must use MAJOR.MINOR.PATCH" >&2
    exit 1
fi

for required_path in "$dmg_path" "$checksum_path"; do
    if [[ ! -f "$required_path" ]]; then
        echo "error: release asset not found at $required_path" >&2
        exit 1
    fi
done

if [[ -z "$output_path" ]]; then
    echo "error: output path is required" >&2
    exit 1
fi

if [[ "$notarized" != "true" && "$notarized" != "false" ]]; then
    echo "error: PAWSE_RELEASE_NOTARIZED must be true or false" >&2
    exit 1
fi

sha256="$(awk 'NR == 1 { print $1 }' "$checksum_path")"
if [[ ! "$sha256" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "error: checksum file does not contain a SHA-256 digest" >&2
    exit 1
fi
sha256="$(printf '%s' "$sha256" | tr '[:upper:]' '[:lower:]')"

byte_count="$(wc -c < "$dmg_path" | tr -d ' ')"
file_size="$(awk -v bytes="$byte_count" 'BEGIN { printf "%.1f MB", bytes / 1000000 }')"
early_access=false
if [[ "$version" == 0.* ]]; then
    early_access=true
fi

signature="ad-hoc"
if [[ "$notarized" == "true" ]]; then
    signature="Developer ID"
fi

mkdir -p "$(dirname "$output_path")"

printf '%s\n' \
    '{' \
    "  \"version\": \"$version\"," \
    "  \"fileSize\": \"$file_size\"," \
    '  "minimumMacOS": "14",' \
    '  "architectures": [' \
    '    "arm64",' \
    '    "x86_64"' \
    '  ],' \
    '  "architectureLabel": "Apple silicon and Intel",' \
    '  "architectureShortLabel": "Universal app",' \
    "  \"downloadURL\": \"https://github.com/yorukot/pawse/releases/download/v$version/Pawse-$version.dmg\"," \
    "  \"releaseURL\": \"https://github.com/yorukot/pawse/releases/tag/v$version\"," \
    "  \"checksumURL\": \"https://github.com/yorukot/pawse/releases/download/v$version/Pawse-$version.dmg.sha256\"," \
    "  \"sha256\": \"$sha256\"," \
    "  \"earlyAccess\": $early_access," \
    "  \"notarized\": $notarized," \
    "  \"signature\": \"$signature\"" \
    '}' > "$output_path"

echo "Created $output_path"
