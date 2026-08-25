#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
version="${1:-${VERSION:-}}"
output_path="${2:-$repository_root/dist/release-notes.md}"

if [[ -z "$version" ]]; then
    version="$("$repository_root/scripts/release/verify-version.sh" | sed -E 's/^Pawse ([^ ]+) .*/\1/')"
else
    "$repository_root/scripts/release/verify-version.sh" "$version" >/dev/null
fi

mkdir -p "$(dirname "$output_path")"

awk -v version="$version" '
    $0 ~ "^## \\[" version "\\] - " { in_release = 1; next }
    in_release && $0 ~ "^## \\[" { exit }
    in_release && $0 ~ "^\\[Unreleased\\]:" { exit }
    in_release { print }
' "$repository_root/CHANGELOG.md" > "$output_path"

if [[ ! -s "$output_path" ]]; then
    echo "error: could not extract release notes for $version" >&2
    exit 1
fi

echo "Wrote release notes to $output_path"
