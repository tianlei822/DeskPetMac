#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-${project_dir}/dist/touch-callout-snapshots/${timestamp}}"

mkdir -p "${output_dir}"

cd "${project_dir}"
DESKPET_TOUCH_CALLOUT_SNAPSHOT_OUTPUT="${output_dir}" \
    swift test --filter PetTouchResponseVisualTests.exportsSequenceOnDemand

echo "Exported touch-callout snapshots to ${output_dir}"
