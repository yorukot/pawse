#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
project_file="$repository_root/Pawse.xcodeproj/project.pbxproj"
requested_version="${1:-${VERSION:-}}"

mapfile_compat() {
    local destination_name="$1"
    shift
    local values=()
    while IFS= read -r value; do
        [[ -n "$value" ]] && values+=("$value")
    done < <("$@")
    eval "$destination_name=(\"\${values[@]}\")"
}

mapfile_compat marketing_versions sed -nE 's/^[[:space:]]*MARKETING_VERSION = ([^;]+);/\1/p' "$project_file"
mapfile_compat build_numbers sed -nE 's/^[[:space:]]*CURRENT_PROJECT_VERSION = ([^;]+);/\1/p' "$project_file"

unique_marketing_versions="$(printf '%s\n' "${marketing_versions[@]}" | sort -u)"
unique_build_numbers="$(printf '%s\n' "${build_numbers[@]}" | sort -u)"

if [[ "$(printf '%s\n' "$unique_marketing_versions" | wc -l | tr -d ' ')" != "1" ]]; then
    echo "error: MARKETING_VERSION differs between Pawse build configurations:" >&2
    printf '%s\n' "$unique_marketing_versions" >&2
    exit 1
fi

if [[ "$(printf '%s\n' "$unique_build_numbers" | wc -l | tr -d ' ')" != "1" ]]; then
    echo "error: CURRENT_PROJECT_VERSION differs between Pawse build configurations:" >&2
    printf '%s\n' "$unique_build_numbers" >&2
    exit 1
fi

project_version="$unique_marketing_versions"
build_number="$unique_build_numbers"

if [[ ! "$project_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: MARKETING_VERSION must use semantic versioning (x.y.z), found '$project_version'" >&2
    exit 1
fi

if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: CURRENT_PROJECT_VERSION must be a positive integer, found '$build_number'" >&2
    exit 1
fi

if [[ -n "$requested_version" && "$requested_version" != "$project_version" ]]; then
    echo "error: requested version '$requested_version' does not match project version '$project_version'" >&2
    exit 1
fi

if ! grep -Fq "## [$project_version] - " "$repository_root/CHANGELOG.md"; then
    echo "error: CHANGELOG.md has no dated [$project_version] release section" >&2
    exit 1
fi

echo "Pawse $project_version (build $build_number)"
