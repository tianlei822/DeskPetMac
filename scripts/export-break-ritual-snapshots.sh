#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-${project_dir}/dist/break-ritual-snapshots/${timestamp}}"

mkdir -p "${output_dir}"

cd "${project_dir}"
DESKPET_BREAK_RITUAL_SNAPSHOT_OUTPUT="${output_dir}" \
    swift test --filter PetBreakRitualVisualTests.exportsSequenceOnDemand

echo "Exported break-ritual snapshots to ${output_dir}"
