#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-${project_dir}/dist/accessibility-contrast-snapshots/${timestamp}}"

mkdir -p "${output_dir}"

cd "${project_dir}"
DESKPET_ACCESSIBILITY_CONTRAST_SNAPSHOT_OUTPUT="${output_dir}" \
    swift test --filter PetAccessibilityContrastVisualTests.exportsSequenceOnDemand

echo "Exported accessibility-contrast snapshots to ${output_dir}"
